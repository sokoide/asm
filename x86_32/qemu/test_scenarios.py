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
    "s01_hello": ["Hello, 80386 World!"],
    "s02_registers": ["EAX=12345678", "0x123456FF", "0x1234BEEF",
                      "10 + 20      = 0x0000001E",
                      "30 - 5       = 0x00000019", "Done!"],
    "s03_stack": ["ESP after 2 PUSH = 0x0008FFF8", "1st POP = 0x9ABCDEF0",
                  "2nd POP = 0x12345678", "ESP back to start = 0x00090000",
                  "Saved/restored EAX = 0x0000002A", "Stack demo done!"],
    "s04_loops": ["LOOP  5..1: 5 4 3 2 1", "ECX after LOOP = 0x00000000",
                  "Count 1..5: 1 2 3 4 5", "7 is odd", "Loops done!"],
    "s05_strings": ["Length of 'Hello': 5", "Copied: World", "String ops done!"],
    "s06_serial_in": ["Type chars (Enter=quit):", "Bye!"],
    "s07_subroutines": ["Hello from subroutine!", "Hex: 0xDEADBEEF",
                        "Hex: 0x00C0FFEE", "42+13=0x00000037",
                        "Subroutines done!"],
    "s08_hardware": ["PIT Counter 0: 0x", "Hardware access done!"],
    "s09_branching": ["42 == 42? Yes!", "-5 < 10?  Yes!", "30 > 10?  Yes!",
                      "-1 < 1?  (JL, signed)     Yes!",
                      "0xFFFFFFFF > 1?  (JA, unsigned)  Yes!",
                      "50: mid (10..100)", "Done!"],
    "s10_bitwise": ["AND 0x5A5A5A5A, 0x0F0F0F0F: 00001010000010100000101000001010 = 0A0A0A0A",
                    "OR  0x50505050, 0x0A0A0A0A: 0x5A5A5A5A",
                    "XOR 0xFFFFFFFF, 0x0F0F0F0F: 0xF0F0F0F0",
                    "SHL 0x40000000, 1: 0x80000000",
                    "SHR 0x80000000, 1: 0x40000000",
                    "ROR 0x12345678, 8: 0x78123456",
                    "Bitwise done!"],
    "s11_memory": ["Fill:  ....................", "Copy:  Hello", "Index: WORLD",
                   "[EBX+ESI*1] display[3]=0x0000004C",
                   "[EBX+ESI*4] table[2]=0x33333333", "Memory ops done!"],
    "s12_minishell": ["80386 MiniShell", "> help", "> quit", "Bye!"],
    "s13_copybench": ["COPY OK CHECKSUM=1356"],
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
parser.add_argument("--qemu", default="qemu-system-i386")
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
    "-cpu", "486",
    "-no-reboot", "-no-shutdown",
]
dfilter_flags = shlex.split(args.dfilter) if args.dfilter else []
failed = False
images = tempfile.TemporaryDirectory(prefix="asm-x86_32-test-")
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
        reached = [int(m, 16) for m in re.findall(r"^EIP=([0-9a-fA-F]+)", text, re.M)]
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
