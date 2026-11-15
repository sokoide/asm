#!/usr/bin/env python3
"""QEMU のシリアル出力をシナリオ別の期待値と照合する。

ビルド済みの .img は書き換えないよう一時ディレクトリへコピーしてから
QEMU を実行する。期待出力の欠落、QEMU 起動失敗、無効命令 /
期待出力前の異常停止、img 未存在を
非ゼロ終了で報告する。
"""
import argparse
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# シナリオ別の期待部分文字列。シリアル出力は CRLF 改行のため、
# 行内の部分文字列で照合する (行末の CR を含まない)。
# s08 の PIT カウンタ値は実行ごとに変動するため、接頭辞のみ照合する。
EXPECTED = {
    "s01_hello": ["Hello, x86_64 World!"],
    "s02_registers": ["RAX=0x1234567890ABCDEF", "RAX=0x1234567890ABCDFF",
                      "RAX=0x1234567890ABBEEF", "RAX=0x0000000090ABCDEF",
                      "R9=0x1122334455667788",
                      "10 + 20      = 0x0000001E",
                      "30 - 5       = 0x00000019", "Done!"],
    "s03_stack": ["RSP after 1 PUSH = 0x000000000008FFF8",
                  "RSP after 2 PUSH = 0x000000000008FFF0",
                  "1st POP = 0x99AABBCCDDEEFF00",
                  "2nd POP = 0x1122334455667788",
                  "RSP back to start = 0x0000000000090000",
                  "Saved/restored RAX = 0x0000002A", "Stack demo done!"],
    "s04_loops": ["LOOP  5..1: 5 4 3 2 1", "RCX after LOOP = 0x0000000000000000",
                  "Count 1..5: 1 2 3 4 5", "7 is odd", "Loops done!"],
    "s05_strings": ["Length of 'Hello': 5", "Copied: World", "String ops done!"],
    "s06_serial_in": ["Type chars (Enter=quit):", "Bye!"],
    "s07_subroutines": ["RSP at _start: 0x0000000000090000",
                        "show_entry_rsp entry: 0x000000000008FFF8",
                        "PUSH 1x then CALL:   0x000000000008FFF0",
                        "PUSH + sub rsp,8:    0x000000000008FFE8",
                        "Hello from subroutine!", "Hex: 0x00000000DEADBEEF",
                        "42+13=0x0000000000000037",
                        "RBX still: 0x0000000000005A5A",
                        "Subroutines done!"],
    "s08_hardware": ["PIT Counter 0: 0x", "Hardware access done!"],
    "s09_branching": ["42 == 42? Yes!", "-5 < 10?  Yes!", "30 > 10?  Yes!",
                      "-1 < 1?  (JL, signed)     Yes!",
                      "0xFFFFFFFFFFFFFFFF > 1?  (JA, unsigned)  Yes!",
                      "50: mid (10..100)", "Done!"],
    "s10_bitwise": ["AND 0x5A5A5A5A5A5A5A5A, 0x0F0F0F0F0F0F0F0F: 0000101000001010000010100000101000001010000010100000101000001010 = 0A0A0A0A0A0A0A0A",
                    "OR  0x5050505050505050, 0x0A0A0A0A0A0A0A0A: 0x5A5A5A5A5A5A5A5A",
                    "XOR 0xFFFFFFFFFFFFFFFF, 0x0F0F0F0F0F0F0F0F: 0xF0F0F0F0F0F0F0F0",
                    "SHL 0x4000000000000000, 1: 0x8000000000000000",
                    "SHR 0x8000000000000000, 1: 0x4000000000000000",
                    "ROR 0x123456789ABCDEF0, 8: 0xF0123456789ABCDE",
                    "Bitwise done!"],
    "s11_memory": ["Fill:  ....................", "Copy:  Hello", "Index: WORLD",
                   "[RBX+RSI*1] display[3]=0x0000004C",
                   "[RBX+RSI*8] table[2]=0x3333333333333333", "Memory ops done!"],
    "s12_minishell": ["x86_64 MiniShell", "> help", "> quit", "Bye!"],
    "s13_copybench": ["COPY OK CHECKSUM=1356"],
    "s101_riprel": ["lea  [rel msg]    = 0x00000000000081C2",
                    "lea2 [rel msg]    = 0x00000000000081C2",
                    "mov  [rel value]  = 0x1122334455667788",
                    "res diff          = 0x0000000000000000",
                    "disp diff         = 0x000000000000000A",
                    "RIP-relative done!"],
    "s102_paging": ["CR3          = 0x0000000000001000",
                    "PML4[0]      = 0x0000000000002003 (P=1 RW=1 US=0 -> PDPT@0x2000)",
                    "PDPT[0]      = 0x0000000000003003 (P=1 RW=1 US=0 -> PD@0x3000)",
                    "PD[0]        = 0x0000000000000083 (P=1 RW=1 US=0 PS=1 2MB@0x000000)",
                    "PD[1]        = 0x0000000000200083 (P=1 RW=1 US=0 PS=1 2MB@0x200000)",
                    "walk 0x004123456 -> 0x004123456 (identity)",
                    "Paging done!"],
    "s103_syscall": ["CPUID syscall = yes", "EFER.SCE on",
                     "STAR = 0x0020000800000000", "enter CPL=3",
                     "syscall count = 5, last value = 5"],
    "s104_sse": ["CPUID SSE      = 1", "CR4            = 0x0000000000000620",
                 "addps lanes    = 5678", "subps lanes    = 7531",
                 "SSE done!"],
}

# 対話シナリオの標準入力 (runall / trace と同じ文字列)。
# シリアル (COM1) が stdio に接続されているため、そのまま入力になる。
INPUT = {
    "s06_serial_in": b"q\n",
    "s12_minishell": b"help\nquit\n",
}

# 無効命令やトリプルフォルト時は期待出力前に停止した場合、
# 出力欠落として検出する。

parser = argparse.ArgumentParser()
parser.add_argument("--qemu", default="qemu-system-x86_64")
parser.add_argument("--timeout", type=float, default=1)
parser.add_argument("--qflags", default="",
                    help="QEMU 起動フラグ (Makefile の QFLAGS。空なら既定値)")
parser.add_argument("--dfilter", default="",
                    help="-dfilter の値 (Makefile の DFILTER。--require-halt と併用)")
parser.add_argument("--require-halt", action="store_true",
                    help="scenario_halt への到達 (-d cpu ログ) も検証する")
args = parser.parse_args()
# Makefile が真実の源: make test は --qflags "$(QFLAGS)" を渡す。
# 空の場合 (直接実行) は既定値 (Makefile の QFLAGS と同じ) を使う。
qemu_flags = shlex.split(args.qflags) or [
    "-machine", "pc",
    "-accel", "tcg",
    "-cpu", "qemu64",
    "-no-reboot", "-no-shutdown",
]
dfilter_flags = shlex.split(args.dfilter) if args.dfilter else []
failed = False
images = tempfile.TemporaryDirectory(prefix="asm-x86_64-test-")
for name, expected in EXPECTED.items():
    image = Path(images.name) / f"{name}.img"
    if not Path(f"{name}.img").exists():
        print(f"FAIL {name}: {name}.img が無い (make を先に実行)")
        failed = True
        continue
    shutil.copyfile(f"{name}.img", image)
    command = [args.qemu, *qemu_flags,
               "-drive", f"file={image},format=raw,if=floppy",
               "-serial", "stdio", "-display", "none", "-monitor", "none"]
    # 終了位置 (scenario_halt) の検証準備: nm でアドレスを取得し
    # -d cpu ログ (dfilter でカーネル領域のみ) に到達するか確認する
    log = Path(images.name) / f"{name}.cpulog"
    halt = None
    if args.require_halt:
        elf = Path(f"{name}.elf")
        if not elf.exists():
            print(f"FAIL {name}: {name}.elf が無い (--require-halt には nm で読む ELF が必要)")
            failed = True
            continue
        try:
            symbols = subprocess.check_output(["nm", "-n", str(elf)], text=True)
            halts = re.findall(r"^([0-9a-fA-F]+)\s+\w\s+scenario_halt$", symbols, re.M)
        except (OSError, subprocess.CalledProcessError) as exc:
            print(f"FAIL {name}: scenario_halt の取得に失敗: {exc}")
            failed = True
            continue
        if len(halts) != 1:
            print(f"FAIL {name}: scenario_halt が一意でない ({len(halts)} 個)")
            failed = True
            continue
        halt = int(halts[0], 16)
        command += dfilter_flags + ["-d", "cpu", "-D", str(log)]
    try:
        result = subprocess.run(command, input=INPUT.get(name, b""),
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, timeout=args.timeout, check=False)
        output = result.stdout.decode("utf-8", "replace")
        if result.returncode != 0:
            print(f"FAIL {name}: QEMU exit {result.returncode}: {result.stderr.decode(errors='replace')}")
            failed = True
            continue
    except subprocess.TimeoutExpired as exc:
        # HLT 後も QEMU は終了しないため、タイムアウトまでの出力を検査する。
        output = (exc.stdout or b"").decode("utf-8", "replace")
    except OSError as exc:
        print(f"FAIL {name}: {exc}")
        failed = True
        continue
    # 期待文字列が出ても、その直後に不正命令や無限ループがあれば
    # scenario_halt に到達しない。到達しなければ失敗にする
    if args.require_halt:
        text = log.read_text(errors="replace") if log.exists() else ""
        reached = [int(m, 16) for m in re.findall(r"^RIP=([0-9a-fA-F]+)", text, re.M)]
        if halt not in reached:
            print(f"FAIL {name}: 終了位置 (scenario_halt) に未到達 — 期待出力後の不正命令・無限ループの可能性")
            failed = True
            continue
    missing = [item for item in expected if item not in output]
    if missing:
        print(f"FAIL {name}: missing {missing}; output={output!r}")
        failed = True
    else:
        print(f"PASS {name}")
# EXPECTED に無いビルド済みシナリオがあると無テストのまま緑になるため検出する
untested = sorted(
    p.stem for p in Path(".").glob("s*.img") if p.stem not in EXPECTED
)
if untested:
    print(f"FAIL: 期待値未定義のシナリオがあります: {untested} (EXPECTED に追加してください)")
    failed = True
images.cleanup()
sys.exit(1 if failed else 0)
