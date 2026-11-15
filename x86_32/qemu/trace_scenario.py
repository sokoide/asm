#!/usr/bin/env python3
"""QEMU の命令トレースを上限付きで記録する。"""
import argparse
import re
import selectors
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--qemu', default='qemu-system-i386')
parser.add_argument('--scenario', required=True)
parser.add_argument('--timeout', type=float, default=10)
parser.add_argument('--max-bytes', type=int, default=33554432)
args = parser.parse_args()
if args.timeout <= 0 or args.max_bytes <= 0:
    parser.error('timeout と max-bytes は正の値を指定してください')
trace = Path(f'{args.scenario}.trace')
try:
    symbols = subprocess.check_output(['nm', '-n', f'{args.scenario}.elf'], text=True)
    matches = re.findall(r'^([0-9a-fA-F]+)\s+\w\s+scenario_halt$', symbols, re.M)
    if len(matches) != 1:
        raise ValueError('scenario_halt が一意に見つかりません')
    halt = int(matches[0], 16)
    with tempfile.TemporaryDirectory(prefix='asm-x86-trace-') as tmp:
        disk = Path(tmp) / 'disk.img'
        shutil.copyfile(f'{args.scenario}.img', disk)
        cmd = [args.qemu, '-machine', 'pc', '-accel', 'tcg,one-insn-per-tb=on',
               '-cpu', '486', '-no-reboot', '-no-shutdown', '-dfilter', '0x8000+0x7e00',
               '-d', 'in_asm,cpu', '-drive', f'file={disk},format=raw,if=floppy',
               '-serial', 'stdio', '-display', 'none', '-monitor', 'none']
        data = {'s06_serial_in': b'q\n', 's12_minishell': b'help\nquit\n'}.get(args.scenario, b'')
        with tempfile.TemporaryFile() as inp, tempfile.TemporaryFile() as output, trace.open('wb') as log:
            inp.write(data)
            inp.seek(0)
            proc = subprocess.Popen(cmd, stdin=inp, stdout=output, stderr=subprocess.PIPE, bufsize=0)
            selector = selectors.DefaultSelector()
            selector.register(proc.stderr, selectors.EVENT_READ)
            deadline = time.monotonic() + args.timeout
            pending = b''
            written = 0
            outcome = None
            try:
                while outcome is None:
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        outcome = '時間上限に到達'
                        break
                    events = selector.select(min(remaining, 0.1))
                    if not events and proc.poll() is not None:
                        outcome = f'QEMU が終了（終了コード {proc.returncode}）'
                        break
                    for key, _ in events:
                        chunk = key.fileobj.read(65536)
                        if not chunk:
                            proc.wait()
                            outcome = f'QEMU が終了（終了コード {proc.returncode}）'
                            break
                        limit = args.max_bytes - written
                        part = chunk[:limit]
                        log.write(part)
                        written += len(part)
                        pending += part
                        lines = pending.split(b'\n')
                        pending = lines.pop()
                        for line in lines:
                            m = re.match(rb'^EIP=([0-9a-fA-F]+)', line)
                            if m and int(m.group(1), 16) == halt:
                                outcome = '終了位置に到達'
                                break
                        if outcome is None and written >= args.max_bytes:
                            outcome = 'ログ上限に到達'
            finally:
                selector.close()
                if proc.poll() is None:
                    proc.terminate()
                try:
                    proc.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait()
                proc.stderr.close()
            if outcome == '終了位置に到達':
                print(f'トレース完了: {trace}（{outcome}、{written} バイト）')
            else:
                print(f'トレース未完了: {outcome}。{trace} に {written} バイトを記録', file=sys.stderr)
                sys.exit(1)
except (OSError, subprocess.CalledProcessError, ValueError) as exc:
    print(f'トレース失敗: {exc}', file=sys.stderr)
    sys.exit(1)
