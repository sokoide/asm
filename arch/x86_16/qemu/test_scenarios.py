#!/usr/bin/env python3
"""QEMU のシリアル出力をシナリオ別の期待値と照合する。"""
import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

EXPECTED = {
    "s01_hello": ["Hello, 8086 World!"],
    "s02_registers": ["AX=1234", "0x001E", "0x0019", "Done!"],
    "s03_stack": ["1st POP = 0x5678", "2nd POP = 0x1234", "Saved/restored AX = 0x002A"],
    "s04_loops": ["5 4 3 2 1", "7 is odd", "Loops done!"],
    "s05_strings": ["Length of 'Hello': 5", "Copied: World", "String ops done!"],
    "s06_serial_in": ["Bye!"],
    "s07_subroutines": ["0xBEEF", "0xCAFE", "42+13=0x37", "Subroutines done!"],
    "s08_hardware": ["PIT Counter 0:", "Hardware access done!"],
    "s09_branching": ["42 == 42? Yes!", "-5 < 10?  Yes!", "30 > 10?  Yes!", "Done!"],
    "s10_bitwise": ["00001010 = 0A", "0xF0", "10100101", "Bitwise done!"],
    "s11_memory": ["Copy:  Hello", "Index: WORLD", "Memory ops done!"],
    "s12_minishell": ["8086 MiniShell", "Bye!"],
    "s13_copybench": ["COPY OK CHECKSUM=1356"],
    "s101_segments": ["0000:7C00 -> 07C00", "1002:0003 -> 10023", "Segment demo done"],
    "s102_vectors": ["Before INT 60h", "handler fired!", "Back after IRET"],
    "s103_multisector": ["Sector 2 loaded!", "Multi-sector loading works!"],
    "s104_protected": ["CR0.PE = 1", "32-bit protected mode active!"],
}

parser = argparse.ArgumentParser()
parser.add_argument("--qemu", default="qemu-system-i386")
parser.add_argument("--timeout", type=float, default=1)
args = parser.parse_args()
failed = False
images = tempfile.TemporaryDirectory(prefix="asm-x86-test-")
for name, expected in EXPECTED.items():
    image = Path(images.name) / f"{name}.img"
    shutil.copyfile(f"{name}.img", image)
    command = [args.qemu, "-drive", f"file={image},format=raw,if=floppy",
               "-serial", "stdio", "-display", "none", "-monitor", "none"]
    data = b"quit\n" if name == "s12_minishell" else b"q\n" if name == "s06_serial_in" else b""
    try:
        result = subprocess.run(command, input=data, stdout=subprocess.PIPE,
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
    missing = [item for item in expected if item not in output]
    if missing:
        print(f"FAIL {name}: missing {missing}; output={output!r}")
        failed = True
    else:
        print(f"PASS {name}")
images.cleanup()
sys.exit(1 if failed else 0)
