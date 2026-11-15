#!/usr/bin/env python3
"""ビルド・QEMU 起動失敗が成功として扱われないことを検証する。"""
import socket
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARCHES = ("arm64", "ppc", "m68k", "riscv32", "riscv64")


def make(*args):
    return subprocess.run(["make", "--no-print-directory", *map(str, args)],
                          cwd=ROOT, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, timeout=20)


class ExecutionFailureTests(unittest.TestCase):
    def test_qemu_failure_propagates(self):
        for arch in ARCHES:
            with self.subTest(arch=arch):
                directory = ROOT / "arch" / arch / "qemu"
                for target, skip in (("run", "build"), ("runall", "all")):
                    result = make("-C", directory, "-o", skip, target,
                                  "S=s01_hello", "SOURCES=s01_hello", "QEMU=false")
                    self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_timeout_is_only_accepted_for_halt_loop_platforms(self):
        with tempfile.TemporaryDirectory() as tmp:
            qemu = Path(tmp) / "timeout-qemu"
            qemu.write_text("#!/bin/sh\nexit 124\n")
            qemu.chmod(0o755)
            for arch in ARCHES:
                with self.subTest(arch=arch):
                    directory = ROOT / "arch" / arch / "qemu"
                    result = make("-C", directory, "-o", "all", "runall",
                                  "SOURCES=s01_hello", f"QEMU={qemu}")
                    self.assertEqual(result.returncode == 0, arch in ("ppc", "m68k"),
                                     result.stdout)

    def test_debug_rejects_occupied_port_and_start_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            marker = Path(tmp) / "gdb-called"
            gdb = Path(tmp) / "fake-gdb"
            gdb.write_text(f"#!/bin/sh\ntouch '{marker}'\n")
            gdb.chmod(0o755)
            for arch in ARCHES:
                with self.subTest(arch=arch):
                    directory = ROOT / "arch" / arch / "qemu"
                    with socket.socket() as listener:
                        listener.bind(("127.0.0.1", 0))
                        listener.listen()
                        port = listener.getsockname()[1]
                        result = make("-C", directory, "-o", "build", "debug",
                                      "S=s01_hello", f"GDB_PORT={port}", f"GDB={gdb}")
                        self.assertNotEqual(result.returncode, 0, result.stdout)
                        self.assertFalse(marker.exists(), result.stdout)
                    result = make("-C", directory, "-o", "build", "debug",
                                  "S=s01_hello", f"GDB_PORT={port}",
                                  f"GDB={gdb}", "QEMU=false")
                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertFalse(marker.exists(), result.stdout)

    def test_root_propagates_failure(self):
        for target, variable in (("all", "ALL_DIRS=missing"),
                                 ("runall", "CORE_DIRS=missing")):
            with self.subTest(target=target):
                result = make(target, variable)
                self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_z80_failed_assembly_removes_stale_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)
            (path / "Makefile").write_bytes((ROOT / "arch/z80/sim/Makefile").read_bytes())
            (path / "s01_hello.com").write_bytes(b"stale")
            result = make("-C", path, "-o", "simz80", "all", "AS=false",
                          "SOURCES=s01_hello", "CSOURCES=")
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertFalse((path / "s01_hello.com").exists())


if __name__ == "__main__":
    unittest.main()
