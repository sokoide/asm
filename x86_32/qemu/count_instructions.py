#!/usr/bin/env python3
"""実行終了位置までの QEMU 命令数を記録する。"""
import argparse
import re
import shlex
import subprocess
import sys
import tempfile
import time
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--qemu', default='qemu-system-i386')
parser.add_argument('--scenario', required=True)
parser.add_argument('--timeout', type=float, default=5)
parser.add_argument('--qflags', default='',
                   help='QEMU 起動フラグ (Makefile の INSN_QFLAGS。空なら既定値)')
parser.add_argument('--dfilter', default='',
                   help='-dfilter の値 (Makefile の DFILTER。空なら既定値)')
args = parser.parse_args()
try:
    symbols = subprocess.check_output(['nm', '-n', f'{args.scenario}.elf'], text=True)
    matches = re.findall(r'^([0-9a-fA-F]+)\s+\w\s+scenario_halt$', symbols, re.M)
    if len(matches) != 1:
        raise ValueError('scenario_halt が一意に見つかりません')
    halt = int(matches[0], 16)
    with tempfile.TemporaryDirectory(prefix='asm-x86-icount-') as tmp:
        log = Path(tmp) / 'trace'
        image = Path(tmp) / 'disk.img'
        import shutil
        shutil.copyfile(f'{args.scenario}.img', image)
        # Makefile が真実の源: make icount は --qflags / --dfilter を渡す。
        # 空の場合 (直接実行) は既定値 (Makefile と同じ) を使う。
        cmd = [args.qemu,
               *(shlex.split(args.qflags) or ['-machine', 'pc', '-accel', 'tcg,one-insn-per-tb=on',
                 '-cpu', '486', '-no-reboot', '-no-shutdown']),
               *(shlex.split(args.dfilter) or ['-dfilter', '0x8000+0x7e00']),
               '-d', 'cpu', '-D', str(log), '-drive', f'file={image},format=raw,if=floppy',
               '-serial', 'stdio', '-display', 'none', '-monitor', 'none']
        data = {'s06_serial_in': b'q\n', 's12_minishell': b'help\nquit\n'}.get(args.scenario, b'')
        with tempfile.TemporaryFile() as inp, tempfile.TemporaryFile() as out:
            inp.write(data)
            inp.seek(0)
            process = subprocess.Popen(cmd, stdin=inp, stdout=out, stderr=out)
            deadline = time.monotonic() + args.timeout
            found = False
            count = 0
            try:
                while time.monotonic() < deadline:
                    if log.exists():
                        with log.open(errors='replace') as f:
                            count = 0
                            for line in f:
                                m = re.match(r'^EIP=([0-9a-fA-F]+)', line)
                                if m:
                                    if int(m.group(1), 16) == halt:
                                        found = True
                                        break
                                    count += 1
                    if found or process.poll() is not None:
                        break
                    time.sleep(0.1)
            finally:
                if process.poll() is None:
                    process.terminate()
                try:
                    process.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            if found:
                print(f'実行命令数: {count} (終了位置まで、cli/hlt を除外)')
            else:
                out.seek(0)
                detail = out.read().decode('utf-8', 'replace').strip()
                print(f'未完了: 終了位置未到達（{count} 命令を記録、終了コード {process.returncode}）', file=sys.stderr)
                if detail:
                    print(detail, file=sys.stderr)
                sys.exit(1)
except (OSError, subprocess.CalledProcessError, ValueError) as exc:
    print(f'計測失敗: {exc}', file=sys.stderr)
    sys.exit(1)
