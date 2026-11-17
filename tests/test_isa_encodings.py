#!/usr/bin/env python3
"""Cross-check selected dictionary encodings against an independent assembler."""

import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("ca65") and shutil.which("ld65"), "cc65 tools are not installed")
class Mos6502EncodingTests(unittest.TestCase):
    def test_all_documented_addressing_forms(self):
        data = json.loads((ROOT / "bin/isa/data/6502.json").read_text())
        source = ['.setcpu "6502"', '.segment "CODE"']
        expected, opcodes = bytearray(), set()
        for inst in data["instructions"]:
            for entry in inst["encodings"]:
                syntax = entry["syntax"]
                opcode = int(entry["opcode"], 16)
                self.assertNotIn(opcode, opcodes, syntax)
                opcodes.add(opcode)
                source.append(syntax.lower().replace("#n", "#$42").replace("zp", "$12")
                              .replace("abs", "$1234").replace(" d", " *+7"))
                expected.append(opcode)
                if entry["bytes"] == 2:
                    expected.append(0x42 if "#n" in syntax else 0x05 if syntax.endswith(" d") else 0x12)
                elif entry["bytes"] == 3:
                    expected.extend((0x34, 0x12))
                else:
                    self.assertEqual(entry["bytes"], 1, syntax)
        self.assertEqual(len(opcodes), 151)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text("\n".join(source) + "\n")
            subprocess.run(["ca65", "-o", str(path / "test.o"), str(path / "test.s")], check=True)
            subprocess.run(["ld65", "-t", "none", "-o", str(path / "test.bin"), str(path / "test.o")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)


@unittest.skipUnless(shutil.which("z80asm"), "z80asm is not installed")
class Z80EncodingTests(unittest.TestCase):
    def test_indexed_bit_and_word_forms(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/z80.json").read_text())["instructions"]}
        source, expected = [], bytearray()
        def append(syntax, assembly, substitutions=None):
            mnemonic = syntax.split()[0]
            entry = next(e for e in instructions[mnemonic]["encodings"] if e["syntax"] == syntax)
            source.append(assembly)
            for word in entry["opcode"].split():
                for key, value in (substitutions or {}).items():
                    word = word.replace(key, value)
                expected.append(5 if word == "d" else int(word, 2 if len(word) == 8 else 16))
        for name in ("RLC", "RRC", "RL", "RR", "SLA", "SRA", "SRL"):
            for index in ("IX", "IY"):
                append(f"{name} ({index}+d)", f"{name.lower()} ({index.lower()}+5)")
        for name in ("BIT", "RES", "SET"):
            for index in ("IX", "IY"):
                for bit in range(8):
                    append(f"{name} b,({index}+d)", f"{name.lower()} {bit},({index.lower()}+5)",
                           {"BBB": f"{bit:03b}"})
        for name in ("INC", "DEC"):
            for index in ("IX", "IY"):
                append(f"{name} {index}", f"{name.lower()} {index.lower()}")
                append(f"{name} ({index}+d)", f"{name.lower()} ({index.lower()}+5)")
        for index, field in (("IX", "pp"), ("IY", "rr")):
            for n, reg in enumerate(("BC", "DE", index, "SP")):
                append(f"ADD {index},{field}", f"add {index.lower()},{reg.lower()}",
                       {field: f"{n:02b}"})
        for name, syntax, code in (("EX", "EX (SP),IY", "ex (sp),iy"),
                                   ("PUSH", "PUSH IY", "push iy"),
                                   ("POP", "POP IY", "pop iy")):
            append(syntax, code)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.asm").write_text("\n".join(source) + "\n")
            subprocess.run(["z80asm", "-o", str(path / "test.bin"), str(path / "test.asm")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_load_additional_addressing_forms(self):
        data = json.loads((ROOT / "bin/isa/data/z80.json").read_text())
        encodings = {e["syntax"]: e for e in next(
            x for x in data["instructions"] if x["mnemonic"] == "LD")["encodings"]}
        forms = {
            "LD r,(IX+d)": "ld b,(ix+5)", "LD r,(IY+d)": "ld b,(iy+5)",
            "LD (IX+d),r": "ld (ix+5),b", "LD (IY+d),r": "ld (iy+5),b",
            "LD (IY+d),n": "ld (iy+5),0x34", "LD (BC),A": "ld (bc),a",
            "LD (DE),A": "ld (de),a", "LD (nn),A": "ld (0x1234),a",
            "LD A,I": "ld a,i", "LD A,R": "ld a,r", "LD I,A": "ld i,a",
            "LD R,A": "ld r,a", "LD IX,nn": "ld ix,0x1234", "LD IY,nn": "ld iy,0x1234",
            "LD HL,(nn)": "ld hl,(0x1234)", "LD (nn),HL": "ld (0x1234),hl",
            "LD dd,(nn)": "ld bc,(0x1234)", "LD (nn),dd": "ld (0x1234),bc",
            "LD IX,(nn)": "ld ix,(0x1234)", "LD IY,(nn)": "ld iy,(0x1234)",
            "LD (nn),IX": "ld (0x1234),ix", "LD (nn),IY": "ld (0x1234),iy",
            "LD SP,HL": "ld sp,hl", "LD SP,IX": "ld sp,ix", "LD SP,IY": "ld sp,iy",
        }
        expected = bytearray()
        for syntax in forms:
            for word in encodings[syntax]["opcode"].split():
                word = word.replace("DDD", "000").replace("SSS", "000").replace("ss", "00")
                if word == "nn":
                    expected.append(0x34)
                elif word == "d":
                    expected.append(5)
                elif word == "n":
                    expected.append(0x34)
                else:
                    expected.append(int(word, 2 if len(word) == 8 else 16))
            if "nn nn" in encodings[syntax]["opcode"]:
                expected[-1] = 0x12
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.asm").write_text("\n".join(forms.values()) + "\n")
            subprocess.run(["z80asm", "-o", str(path / "test.bin"), str(path / "test.asm")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_indexed_alu_encodings(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/z80.json").read_text())["instructions"]}
        source, expected = [], bytearray()
        for mnemonic in ("ADD", "ADC", "SUB", "SBC", "AND", "XOR", "OR", "CP"):
            first = f"{mnemonic} A," if mnemonic in ("ADD", "ADC", "SBC") else f"{mnemonic} "
            for register in ("HL", "IX", "IY"):
                operand = "(HL)" if register == "HL" else f"({register}+d)"
                entry = next(e for e in instructions[mnemonic]["encodings"]
                             if e["syntax"] == first + operand)
                source.append((first + operand.replace("+d", "+5")).lower())
                expected.extend(5 if word == "d" else int(word, 16)
                                for word in entry["opcode"].split())
            self.assertTrue(any(c["cycles"] == 19 and "IX/IY" in c["cond"]
                                for c in instructions[mnemonic]["cycles"]))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.asm").write_text("\n".join(source) + "\n")
            subprocess.run(["z80asm", "-o", str(path / "test.bin"), str(path / "test.asm")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_register_and_immediate_encodings(self):
        data = json.loads((ROOT / "bin/isa/data/z80.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        registers = {"b": 0, "c": 1, "d": 2, "e": 3, "h": 4, "l": 5, "a": 7}
        pairs = {"bc": 0, "de": 1, "hl": 2, "sp": 3}
        source = []
        expected = bytearray()

        entry = next(e for e in instructions["LD"]["encodings"] if e["syntax"] == "LD dd,nn")
        pattern = entry["opcode"].split()[0]
        for register, value in pairs.items():
            source.append(f"ld {register},0x1234")
            expected.extend((int(pattern.replace("ss", f"{value:02b}"), 2), 0x34, 0x12))

        for mnemonic in ("RLC", "RRC", "RL", "RR", "SLA", "SRA", "SRL"):
            entry = next(e for e in instructions[mnemonic]["encodings"] if e["syntax"] == f"{mnemonic} r")
            prefix, pattern = entry["opcode"].split()
            for register, value in registers.items():
                source.append(f"{mnemonic.lower()} {register}")
                expected.extend((int(prefix, 16), int(pattern.replace("DDD", f"{value:03b}"), 2)))

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.asm").write_text("\n".join(source) + "\n")
            subprocess.run(["z80asm", "-o", str(path / "test.bin"), str(path / "test.asm")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_first_encoding_of_every_z80_mnemonic(self):
        data = json.loads((ROOT / "bin/isa/data/z80.json").read_text())
        special = {
            "LD r,r'": ("ld b,c", {"DDD": "000", "SSS": "001"}),
            "PUSH qq": ("push bc", {}), "POP qq": ("pop bc", {}),
            "JP nn": ("jp 0x1234", {}), "CALL nn": ("call 0x1234", {}),
            "JR d": ("jr $+7", {}), "DJNZ d": ("djnz $+7", {}),
            "RST p": ("rst 0x18", {"PPP": "011"}),
            "IN A,(n)": ("in a,(0x24)", {}), "OUT (n),A": ("out (0x24),a", {}),
            "AND A,r": ("and c", {"SSS": "001"}), "OR A,r": ("or c", {"SSS": "001"}),
            "XOR A,r": ("xor c", {"SSS": "001"}), "CP A,r": ("cp c", {"SSS": "001"}),
        }
        source, expected = [], bytearray()
        for inst in data["instructions"]:
            entry = inst["encodings"][0]
            syntax, pattern = entry["syntax"], entry["opcode"]
            if syntax in special:
                instruction, fields = special[syntax]
            elif syntax.endswith(" b,r"):
                instruction, fields = syntax.replace("b,r", "3,c").lower(), {"BBB": "011", "SSS": "001"}
            elif syntax.endswith(",r"):
                instruction, fields = syntax[:-1].lower() + "c", {"SSS": "001"}
            elif syntax.endswith(" r"):
                instruction, fields = syntax[:-1].lower() + "c", {"DDD": "001"}
            else:
                instruction, fields = syntax.lower(), {}
            source.append(instruction)
            for field, bits in fields.items():
                pattern = pattern.replace(field, bits)
            pattern = pattern.replace("nn(下位) nn(上位)", "34 12").replace(" nn nn", " 34 12")
            pattern = pattern.replace(" dd", " 05").replace(" n", " 24")
            for token in pattern.split():
                token = token.split("/")[0]
                base = 2 if re.fullmatch(r"[01]{8}", token) else 16
                expected.append(int(token, base))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.asm").write_text("\n".join(source) + "\n")
            subprocess.run(["z80asm", "-o", str(path / "test.bin"), str(path / "test.asm")], check=True)
            actual = (path / "test.bin").read_bytes()
            self.assertEqual(actual, expected, f"first difference: {next(((i, a, b) for i, (a, b) in enumerate(zip(actual, expected)) if a != b), None)}, lengths {len(actual)}/{len(expected)}")


@unittest.skipUnless(shutil.which("clang") and shutil.which("llvm-objcopy"), "LLVM tools are not installed")
class Riscv64EncodingTests(unittest.TestCase):
    def test_only_variable_expansion_pseudoinstructions_omit_encodings(self):
        # These pseudo-instructions expand to multiple instructions or depend on
        # immediates, symbols, PIC mode, or assembler/linker relaxation.
        allowed = set("LI LA CALL TAIL".split())
        allowed.update("CSRR CSRW CSRS CSRC CSRWI CSRSI CSRCI".split())
        allowed.update("MV NEG NOT SEQZ SNEZ BEQZ BNEZ J JR RET NOP".split())
        allowed.update("SLTZ SGTZ SGT SGTU BLEZ BGEZ BLTZ BGTZ BGT BLE BGTU BLEU".split())
        allowed.update("SEXT.B SEXT.H ZEXT.B ZEXT.H".split())
        allowed.update("NEGW SEXT.W ZEXT.W".split())
        for bits in (32, 64):
            data = json.loads((ROOT / f"bin/isa/data/riscv{bits}.json").read_text())
            missing = {item["mnemonic"] for item in data["instructions"]
                       if not item.get("encodings")}
            expected = allowed if bits == 64 else allowed - {"NEGW", "SEXT.W", "ZEXT.W"}
            self.assertEqual(missing, expected)

    def test_base_and_selected_extension_coverage(self):
        # RV32I/RV64I, M, Zicsr, Zifencei, Zicntr, and selected privileged instructions.
        base = set("LUI AUIPC JAL JALR BEQ BNE BLT BGE BLTU BGEU LB LH LW LBU LHU "
                   "SB SH SW ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI ADD SUB "
                   "SLL SLT SLTU XOR SRL SRA OR AND FENCE FENCE.TSO ECALL EBREAK".split())
        base.update(("RDCYCLE", "RDTIME", "RDINSTRET"))
        multiply = set("MUL MULH MULHSU MULHU DIV DIVU REM REMU".split())
        csr = set("CSRRW CSRRS CSRRC CSRRWI CSRRSI CSRRCI FENCE.I".split())
        rv64 = set("LWU LD SD ADDIW SLLIW SRLIW SRAIW ADDW SUBW SLLW SRLW SRAW "
                   "MULW DIVW DIVUW REMW REMUW".split())
        for bits in (32, 64):
            data = json.loads((ROOT / f"bin/isa/data/riscv{bits}.json").read_text())
            names = {item["mnemonic"] for item in data["instructions"]}
            required = base | multiply | csr | {"MRET", "SRET", "WFI", "SFENCE.VMA"} | (rv64 if bits == 64 else set())
            self.assertEqual(required - names, set(), f"RV{bits} missing instructions")
            if bits == 32:
                self.assertEqual(names & rv64, set(), "RV64-only instructions in RV32")

    def test_comparison_and_branch_pseudoinstructions(self):
        pairs = (("sltz x5,x6", "slt x5,x6,x0"),
                 ("sgtz x5,x6", "slt x5,x0,x6"),
                 ("sgt x5,x6,x7", "slt x5,x7,x6"),
                 ("sgtu x5,x6,x7", "sltu x5,x7,x6"),
                 ("blez x6,.+8", "bge x0,x6,.+8"),
                 ("bgez x6,.+8", "bge x6,x0,.+8"),
                 ("bltz x6,.+8", "blt x6,x0,.+8"),
                 ("bgtz x6,.+8", "blt x0,x6,.+8"),
                 ("bgt x6,x7,.+8", "blt x7,x6,.+8"),
                 ("ble x6,x7,.+8", "bge x7,x6,.+8"),
                 ("bgtu x6,x7,.+8", "bltu x7,x6,.+8"),
                 ("bleu x6,x7,.+8", "bgeu x7,x6,.+8"))
        for bits in (32, 64):
            data = json.loads((ROOT / f"bin/isa/data/riscv{bits}.json").read_text())
            names = {item["mnemonic"] for item in data["instructions"]}
            self.assertTrue({alias.split()[0].upper() for alias, _ in pairs} <= names)
            source = ".text\n.option norvc\n" + "\n".join(x for pair in pairs for x in pair) + "\n"
            with self.subTest(bits=bits), tempfile.TemporaryDirectory() as directory:
                path = Path(directory)
                (path / "test.s").write_text(source)
                subprocess.run(["clang", f"--target=riscv{bits}-unknown-elf",
                                f"-march=rv{bits}im", "-c", str(path / "test.s"),
                                "-o", str(path / "test.o")], check=True)
                subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                                str(path / "test.o"), str(path / "test.bin")], check=True)
                raw = (path / "test.bin").read_bytes()
            self.assertEqual(len(raw), len(pairs) * 8)
            for index, (alias, _) in enumerate(pairs):
                self.assertEqual(raw[index * 8:index * 8 + 4],
                                 raw[index * 8 + 4:index * 8 + 8], alias)

    def test_integer_extension_pseudoinstructions(self):
        for bits in (32, 64):
            names = {x["mnemonic"] for x in json.loads(
                (ROOT / f"bin/isa/data/riscv{bits}.json").read_text())["instructions"]}
            pairs = [
                ("sext.b x5,x6", f"slli x5,x6,{bits - 8}\nsrai x5,x5,{bits - 8}"),
                ("sext.h x5,x6", f"slli x5,x6,{bits - 16}\nsrai x5,x5,{bits - 16}"),
                ("zext.b x5,x6", "andi x5,x6,255"),
                ("zext.h x5,x6", f"slli x5,x6,{bits - 16}\nsrli x5,x5,{bits - 16}"),
            ]
            if bits == 64:
                pairs += [("negw x5,x6", "subw x5,x0,x6"),
                          ("sext.w x5,x6", "addiw x5,x6,0"),
                          ("zext.w x5,x6", "slli x5,x6,32\nsrli x5,x5,32")]
            self.assertTrue({a.split()[0].upper() for a, _ in pairs} <= names)
            with self.subTest(bits=bits), tempfile.TemporaryDirectory() as directory:
                path = Path(directory)
                for index, (alias, expanded) in enumerate(pairs):
                    binaries = []
                    for code in (alias, expanded):
                        (path / "test.s").write_text(".text\n.option norvc\n" + code + "\n")
                        subprocess.run(["clang", f"--target=riscv{bits}-unknown-elf",
                                        f"-march=rv{bits}im", "-c", str(path / "test.s"),
                                        "-o", str(path / "test.o")], check=True)
                        subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                                        str(path / "test.o"), str(path / "test.bin")], check=True)
                        binaries.append((path / "test.bin").read_bytes())
                    self.assertEqual(binaries[0], binaries[1], alias)

    @unittest.skipUnless(shutil.which("ld.lld"), "LLD is not installed")
    def test_call_and_tail_linker_relaxation(self):
        source = ".text\n.option norvc\n.globl _start\n_start:\ncall target\ncall x5,target\ntail target\ntarget: nop\n"
        for bits in (32, 64):
            with self.subTest(bits=bits), tempfile.TemporaryDirectory() as directory:
                path = Path(directory)
                (path / "test.s").write_text(source)
                subprocess.run(["clang", f"--target=riscv{bits}-unknown-elf",
                                f"-march=rv{bits}im", "-c", str(path / "test.s"),
                                "-o", str(path / "test.o")], check=True)
                subprocess.run(["ld.lld", "--relax", "-e", "_start", str(path / "test.o"),
                                "-o", str(path / "test.elf")], check=True)
                subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                                str(path / "test.elf"), str(path / "test.bin")], check=True)
                raw = (path / "test.bin").read_bytes()
            self.assertEqual(len(raw), 16)
            for index, rd in enumerate((1, 5, 0)):
                word = int.from_bytes(raw[index * 4:index * 4 + 4], "little")
                self.assertEqual(word & 0x7f, 0x6f)
                self.assertEqual((word >> 7) & 31, rd)
                offset = (((word >> 31) & 1) << 20 | ((word >> 21) & 0x3ff) << 1 |
                          ((word >> 20) & 1) << 11 | ((word >> 12) & 0xff) << 12)
                self.assertEqual(offset, 12 - index * 4)

    def test_call_and_tail_registers(self):
        source = ".text\n.option norvc\ncall target\ncall x5,target\ntail target\ntarget: nop\n"
        for bits in (32, 64):
            with self.subTest(bits=bits), tempfile.TemporaryDirectory() as directory:
                path = Path(directory)
                (path / "test.s").write_text(source)
                subprocess.run(["clang", f"--target=riscv{bits}-unknown-elf",
                                f"-march=rv{bits}im", "-c", str(path / "test.s"),
                                "-o", str(path / "test.o")], check=True)
                subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                                str(path / "test.o"), str(path / "test.bin")], check=True)
                raw = (path / "test.bin").read_bytes()
            self.assertEqual(len(raw), 28)
            words = [int.from_bytes(raw[i:i + 4], "little") for i in range(0, 24, 4)]
            for index, temporary, destination in ((0, 1, 1), (2, 5, 5), (4, 6, 0)):
                auipc, jalr = words[index:index + 2]
                self.assertEqual(auipc & 0x7f, 0x17)
                self.assertEqual((auipc >> 7) & 31, temporary)
                self.assertEqual(jalr & 0x707f, 0x67)
                self.assertEqual((jalr >> 15) & 31, temporary)
                self.assertEqual((jalr >> 7) & 31, destination)

    def test_csr_pseudoinstructions(self):
        pairs = (
            ("csrr x5, 0x300", "csrrs x5, 0x300, x0"),
            ("csrw 0x300, x6", "csrrw x0, 0x300, x6"),
            ("csrs 0x300, x6", "csrrs x0, 0x300, x6"),
            ("csrc 0x300, x6", "csrrc x0, 0x300, x6"),
            ("csrwi 0x300, 17", "csrrwi x0, 0x300, 17"),
            ("csrsi 0x300, 17", "csrrsi x0, 0x300, 17"),
            ("csrci 0x300, 17", "csrrci x0, 0x300, 17"),
        )
        for bits in (32, 64):
            data = json.loads((ROOT / f"bin/isa/data/riscv{bits}.json").read_text())
            instructions = {inst["mnemonic"]: inst for inst in data["instructions"]}
            source = [".text", ".option norvc"]
            for alias, base in pairs:
                name = alias.split()[0].upper()
                self.assertIn(name, instructions)
                self.assertIn(base.split()[0].upper(), instructions[name]["notes"])
                source.extend((alias, base))
            with tempfile.TemporaryDirectory() as directory:
                path = Path(directory)
                (path / "test.s").write_text("\n".join(source) + "\n")
                subprocess.run(["clang", f"--target=riscv{bits}-unknown-elf", f"-march=rv{bits}im_zicsr",
                                "-c", str(path / "test.s"), "-o", str(path / "test.o")], check=True)
                subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                                str(path / "test.o"), str(path / "test.bin")], check=True)
                actual = (path / "test.bin").read_bytes()
                self.assertEqual(len(actual), 8 * len(pairs))
                for index, (alias, _) in enumerate(pairs):
                    pair = actual[index * 8:index * 8 + 8]
                    self.assertEqual(pair[:4], pair[4:], alias)

    def test_all_listed_rv32_and_rv64_encodings(self):
        for bits in (32, 64):
            with self.subTest(bits=bits):
                data = json.loads((ROOT / f"bin/isa/data/riscv{bits}.json").read_text())
                source = [".text", ".option norvc"]
                expected, names = bytearray(), []
                for inst in data["instructions"]:
                    for entry in inst.get("encodings", []):
                        mnemonic = inst["mnemonic"]
                        immediate = (0x54321 << 12 if mnemonic in ("LUI", "AUIPC") else
                                     0x6DA if mnemonic.startswith("B") else
                                     0x64532 if mnemonic == "JAL" else 0x354)
                        values = {"rd": 5, "rs1": 6, "rs2": 7, "imm": immediate,
                                  "shamt": 17, "csr": 0x300, "zimm": 17,
                                  "fm": 0, "pred": 15, "succ": 15}
                        syntax = entry["syntax"].lower()
                        replacements = {"rd": "x5", "rs1": "x6", "rs2": "x7",
                                        "offset": str(immediate), "imm": "0x54321" if mnemonic in ("LUI", "AUIPC") else str(immediate),
                                        "shamt": "17", "csr": "0x300", "zimm": "17",
                                        "pred": "iorw", "succ": "iorw"}
                        for name in sorted(replacements, key=len, reverse=True):
                            syntax = re.sub(r"\b" + name + r"\b", replacements[name], syntax)
                        source.append(syntax)
                        word = 0
                        total_width = 0
                        for field in entry["opcode"].split():
                            fixed = re.fullmatch(r"(\w+)=(\d+)", field)
                            sliced = re.fullmatch(r"(\w+)\[([\d:|]+)\]", field)
                            if fixed:
                                name, value = fixed.groups()
                                width = {"rs1": 5, "rd": 5, "imm": 12}.get(name, len(value))
                                value = int(value, 2)
                            elif sliced:
                                name, groups = sliced.groups()
                                value, width = 0, 0
                                for group in groups.split("|"):
                                    limits = [int(part) for part in group.split(":")]
                                    high, low = (limits[0], limits[-1])
                                    count = high - low + 1
                                    value = (value << count) | ((values[name] >> low) & ((1 << count) - 1))
                                    width += count
                            elif field in values:
                                width = {"rd": 5, "rs1": 5, "rs2": 5, "csr": 12}[field]
                                value = values[field]
                            else:
                                self.assertRegex(field, r"^[01]+$")
                                value, width = int(field, 2), len(field)
                            word = (word << width) | value
                            total_width += width
                        self.assertEqual(total_width, 32, mnemonic)
                        self.assertEqual(entry["bytes"], 4, mnemonic)
                        names.append(mnemonic)
                        expected.extend(word.to_bytes(4, "little"))
                with tempfile.TemporaryDirectory() as directory:
                    path = Path(directory)
                    (path / "test.s").write_text("\n".join(source) + "\n")
                    subprocess.run(["clang", f"--target=riscv{bits}-unknown-elf", f"-march=rv{bits}im_zicsr_zifencei_zicntr",
                                    "-c", str(path / "test.s"), "-o", str(path / "test.o")], check=True)
                    subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                                    str(path / "test.o"), str(path / "test.bin")], check=True)
                    actual = (path / "test.bin").read_bytes()
                    self.assertEqual(len(actual), len(expected))
                    for index, name in enumerate(names):
                        self.assertEqual(actual[index * 4:index * 4 + 4], expected[index * 4:index * 4 + 4], name)

    def test_rv64_specific_base_and_m_encodings(self):
        data = json.loads((ROOT / "bin/isa/data/riscv64.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        mnemonics = (
            "LD", "LWU", "SD", "ADDW", "SUBW", "ADDIW", "MULW", "DIVW", "DIVUW", "REMW", "REMUW",
            "SLLW", "SLLIW", "SRLW", "SRLIW", "SRAW", "SRAIW",
        )
        source = [".text", ".option norvc"]
        expected = bytearray()
        values = {"rd": (5, 5), "rs1": (6, 5), "rs2": (7, 5),
                  "imm[11:0]": (8, 12), "imm[11:5]": (0, 7),
                  "imm[4:0]": (8, 5), "shamt[4:0]": (8, 5)}
        for mnemonic in mnemonics:
            entry = instructions[mnemonic]["encodings"][0]
            syntax = entry["syntax"].lower()
            syntax = re.sub(r"\brd\b", "x5", syntax)
            syntax = re.sub(r"\brs1\b", "x6", syntax)
            syntax = re.sub(r"\brs2\b", "x7", syntax)
            syntax = re.sub(r"\b(?:offset|imm|shamt)\b", "8", syntax)
            source.append(syntax)
            word = 0
            width = 0
            for field in entry["opcode"].split():
                if field in values:
                    value, bits = values[field]
                else:
                    binary = field.split("=")[-1]
                    self.assertRegex(binary, r"^[01]+$")
                    value, bits = int(binary, 2), len(binary)
                word = (word << bits) | value
                width += bits
            self.assertEqual(width, 32, mnemonic)
            expected.extend(word.to_bytes(4, "little"))

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text("\n".join(source) + "\n")
            subprocess.run(["clang", "--target=riscv64-unknown-elf", "-march=rv64im", "-c",
                            str(path / "test.s"), "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            actual = (path / "test.bin").read_bytes()
            self.assertEqual(actual, expected, f"first difference: {next(((i, a, b) for i, (a, b) in enumerate(zip(actual, expected)) if a != b), None)}, lengths {len(actual)}/{len(expected)}")


@unittest.skipUnless(shutil.which("clang") and shutil.which("llvm-objcopy"), "LLVM tools are not installed")
class Aarch64EncodingTests(unittest.TestCase):
    def test_remaining_alias_and_system_register_encodings(self):
        data = json.loads((ROOT / "bin/isa/data/arm64.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        for name in ("ASR", "LSL", "LSR", "ROR", "SXTB", "SXTW", "SXTH",
                     "UXTB", "UXTH", "UXTW", "MSR", "MRS"):
            self.assertTrue(instructions[name]["encodings"], name)

        # 別名が基底命令と同じ命令語になることを、両方の幅で確かめる。
        source = """.text
.arch armv8-a
asr w0,w1,#7
sbfm w0,w1,#7,#31
asr x0,x1,#7
sbfm x0,x1,#7,#63
lsl w0,w1,#7
ubfm w0,w1,#25,#24
lsl x0,x1,#7
ubfm x0,x1,#57,#56
lsr w0,w1,#7
ubfm w0,w1,#7,#31
lsr x0,x1,#7
ubfm x0,x1,#7,#63
ror w0,w1,#7
extr w0,w1,w1,#7
ror x0,x1,#7
extr x0,x1,x1,#7
sxtb w0,w1
sbfm w0,w1,#0,#7
sxtb x0,w1
sbfm x0,x1,#0,#7
sxth w0,w1
sbfm w0,w1,#0,#15
sxth x0,w1
sbfm x0,x1,#0,#15
sxtw x0,w1
sbfm x0,x1,#0,#31
uxtb w0,w1
ubfm w0,w1,#0,#7
uxth w0,w1
ubfm w0,w1,#0,#15
uxtw x0,w1
ubfm x0,x1,#0,#31
lslv w0,w1,w2
lsl w0,w1,w2
lsrv x0,x1,x2
lsr x0,x1,x2
asrv w0,w1,w2
asr w0,w1,w2
rorv x0,x1,x2
ror x0,x1,x2
mrs x3,nzcv
msr nzcv,x3
msr daifset,#2
msr daifclr,#4
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(source)
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            code = (path / "test.bin").read_bytes()
        words = [code[i:i + 4] for i in range(0, len(code), 4)]
        for i in range(0, 32, 2):
            self.assertEqual(words[i], words[i + 1], source.splitlines()[2 + i])
        for i in range(32, 40, 2):
            self.assertEqual(words[i], words[i + 1], source.splitlines()[2 + i])

        # NZCV の汎用システムレジスタ形式と PSTATE 即値形式をフィールド照合。
        expected_system = (
            "11010101001" + "11" + "011" + "0100" + "0010" + "000" + "00011",
            "11010101000" + "11" + "011" + "0100" + "0010" + "000" + "00011",
            "1101010100000" + "011" + "0100" + "0010" + "110" + "11111",
            "1101010100000" + "011" + "0100" + "0100" + "111" + "11111",
        )
        for actual, bits in zip(words[-4:], expected_system):
            self.assertEqual(actual, int(bits, 2).to_bytes(4, "little"))

    def test_pair_load_store_encodings(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/arm64.json").read_text())["instructions"]}
        cases, expected = [], bytearray()
        for name in ("LDP", "STP"):
            for entry in instructions[name]["encodings"]:
                syntax = entry["syntax"]
                width = "x" if "Xt" in syntax else "w"
                scale = 8 if width == "x" else 4
                for displacement in (-64, -1, 0, 63):
                    offset = displacement * scale
                    address = f"[x5],#{offset}" if "],#simm" in syntax else f"[x5,#{offset}]" + ("!" if syntax.endswith("!") else "")
                    cases.append(f"{name.lower()} {width}3,{width}4,{address}")
                    opcode = entry["opcode"]
                    for field, value in (("imm7", f"{displacement & 127:07b}"), ("Rt2", "00100"),
                                         ("Rn", "00101"), ("Rt", "00011")):
                        opcode = opcode.replace(field, value)
                    expected.extend(int(opcode.replace(" ", ""), 2).to_bytes(4, "little"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n.arch armv8-a\n" + "\n".join(cases) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_general_load_store_encodings(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/arm64.json").read_text())["instructions"]}
        scales = {"LDRB": 0, "STRB": 0, "LDRSB": 0, "LDRH": 1, "STRH": 1,
                  "LDRSH": 1, "LDRSW": 2}
        cases, expected = [], bytearray()
        for name in ("LDR", "STR", "LDRB", "STRB", "LDRH", "STRH", "LDRSB", "LDRSH", "LDRSW"):
            for entry in instructions[name]["encodings"]:
                syntax = entry["syntax"]
                width = "x" if "Xt" in syntax else "w"
                scale = scales.get(name, 3 if width == "x" else 2)
                fields = {"Rn": "00101", "Rt": "00011"}
                if "label" in syntax:
                    operands = f"{width}3,#8"
                    fields["imm19"] = f"{2:019b}"
                elif "#uimm" in syntax:
                    operands = f"{width}3,[x5,#{3 << scale}]"
                    fields["imm12"] = f"{3:012b}"
                elif "#simm9" in syntax:
                    operands = f"{width}3,[x5,#-7]!" if syntax.endswith("!") else f"{width}3,[x5],#-7"
                    fields["imm9"] = f"{(-7) & 0x1ff:09b}"
                else:
                    operands = f"{width}3,[x5,x7,lsl #{scale}]"
                    fields.update({"Rm": "00111", "option": "011", "S": "1"})
                cases.append(f"{name.lower()} {operands}")
                opcode = entry["opcode"]
                for field, value in fields.items():
                    opcode = opcode.replace(field, value)
                expected.extend(int(opcode.replace(" ", ""), 2).to_bytes(4, "little"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n.arch armv8-a\n" + "\n".join(cases) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_exclusive_and_ordered_access_encodings(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/arm64.json").read_text())["instructions"]}
        names = ("LDXR", "LDXRB", "LDXRH", "LDAXR", "LDAXRB", "LDAXRH",
                 "STXR", "STXRB", "STXRH", "STLXR", "STLXRB", "STLXRH",
                 "LDAR", "LDARB", "LDARH", "STLR", "STLRB", "STLRH",
                 "LDXP", "LDAXP", "STXP", "STLXP")
        cases, expected = [], bytearray()
        for name in names:
            pair = name in ("LDXP", "LDAXP", "STXP", "STLXP")
            load = name.startswith("LD")
            ordered = name.startswith(("LDAR", "STLR"))
            for entry in instructions[name]["encodings"]:
                width = "x" if "Xt" in entry["syntax"] else "w"
                args = (f"{width}3,{width}4,[x5]" if load else f"w7,{width}3,{width}4,[x5]") if pair else (
                    f"{width}3,[x5]" if load or ordered else f"w7,{width}3,[x5]")
                cases.append(f"{name.lower()} {args}")
                opcode = entry["opcode"]
                for field, value in (("Rs", "00111"), ("Rt2", "00100"), ("Rn", "00101"), ("Rt", "00011")):
                    opcode = opcode.replace(field, value)
                expected.extend(int(opcode.replace(" ", ""), 2).to_bytes(4, "little"))
        for imm in (0, 3, 15):
            cases.append(f"clrex #{imm}")
            opcode = instructions["CLREX"]["encodings"][0]["opcode"].replace("imm4", f"{imm:04b}")
            expected.extend(int(opcode.replace(" ", ""), 2).to_bytes(4, "little"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n.arch armv8-a\n" + "\n".join(cases) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_unscaled_load_store_encodings(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/arm64.json").read_text())["instructions"]}
        forms = {"LDUR": ("w", "x"), "STUR": ("w", "x"), "LDURB": ("w",),
                 "LDURH": ("w",), "LDURSB": ("w", "x"), "LDURSH": ("w", "x"),
                 "LDURSW": ("x",), "STURB": ("w",), "STURH": ("w",)}
        cases, expected = [], bytearray()
        for name, widths in forms.items():
            for width in widths:
                syntax = f"{name} {width.upper()}t,[Xn{{,#simm9}}]"
                entry = next(e for e in instructions[name]["encodings"] if e["syntax"] == syntax)
                for offset in (-256, -7, 0, 255):
                    cases.append(f"{name.lower()} {width}3,[x5,#{offset}]")
                    opcode = entry["opcode"].replace("imm9", f"{offset & 0x1ff:09b}")
                    opcode = opcode.replace("Rn", "00101").replace("Rt", "00011")
                    expected.extend(int(opcode.replace(" ", ""), 2).to_bytes(4, "little"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n.arch armv8-a\n" + "\n".join(cases) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_variable_shift_and_conditional_compare_encodings(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/arm64.json").read_text())["instructions"]}
        cases = []
        for width, sf in (("w", "0"), ("x", "1")):
            for name in ("LSLV", "LSRV", "ASRV", "RORV"):
                cases.append((name, 0, f"{name.lower()} {width}3,{width}5,{width}7",
                              {"sf": sf, "Rm": "00111", "Rn": "00101", "Rd": "00011"}))
            for name in ("CCMP", "CCMN"):
                for cond, code in (("eq", "0000"), ("ne", "0001"), ("lt", "1011")):
                    common = {"sf": sf, "cond": code, "Rn": "00101", "nzcv": "1010"}
                    cases += [(name, 0, f"{name.lower()} {width}5,{width}7,#10,{cond}",
                               {**common, "Rm": "00111"}),
                              (name, 1, f"{name.lower()} {width}5,#7,#10,{cond}",
                               {**common, "imm5": "00111"})]
        expected = bytearray()
        for name, index, _, fields in cases:
            opcode = instructions[name]["encodings"][index]["opcode"]
            for field, value in fields.items():
                opcode = opcode.replace(field, value)
            expected.extend(int(opcode.replace(" ", ""), 2).to_bytes(4, "little"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n.arch armv8-a\n" + "\n".join(c[2] for c in cases) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_bitfield_extract_and_conditional_select_encodings(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/arm64.json").read_text())["instructions"]}
        cases = []
        for width, sf in (("w", "0"), ("x", "1")):
            for name in ("UBFM", "SBFM", "BFM"):
                for rotate, end in ((7, 12), (12, 7)):
                    cases.append((name, f"{name.lower()} {width}3,{width}5,#{rotate},#{end}",
                                  {"sf": sf, "N": sf, "immr": f"{rotate:06b}", "imms": f"{end:06b}"}))
            for amount in (0, 7, 31):
                cases.append(("EXTR", f"extr {width}3,{width}5,{width}7,#{amount}",
                              {"sf": sf, "N": sf, "Rm": "00111", "imms": f"{amount:06b}"}))
            for name in ("CSEL", "CSINC", "CSINV", "CSNEG"):
                for cond, code in (("eq", "0000"), ("ne", "0001"), ("lt", "1011")):
                    cases.append((name, f"{name.lower()} {width}3,{width}5,{width}7,{cond}",
                                  {"sf": sf, "Rm": "00111", "cond": code}))
        expected = bytearray()
        for name, _, fields in cases:
            opcode = instructions[name]["encodings"][0]["opcode"]
            for field, value in {"Rn": "00101", "Rd": "00011", **fields}.items():
                opcode = opcode.replace(field, value)
            expected.extend(int(opcode.replace(" ", ""), 2).to_bytes(4, "little"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n.arch armv8-a\n" + "\n".join(c[1] for c in cases) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_logical_instruction_encodings(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/arm64.json").read_text())["instructions"]}
        cases = []
        for name in ("AND", "BIC", "ORR", "ORN", "EOR", "EON", "ANDS", "BICS"):
            for width, sf in (("w", "0"), ("x", "1")):
                for shift, bits in (("lsl", "00"), ("lsr", "01"), ("asr", "10"), ("ror", "11")):
                    cases.append((name, 0, f"{name.lower()} {width}3,{width}5,{width}7,{shift} #4",
                                  {"sf": sf, "shift": bits, "Rm": "00111", "imm6": "000100"}))
                if name in ("AND", "ORR", "EOR", "ANDS"):
                    cases.append((name, 1, f"{name.lower()} {width}3,{width}5,#0xff",
                                  {"sf": sf, "N": sf, "immr": "000000", "imms": "000111"}))
        expected = bytearray()
        for name, index, _, fields in cases:
            opcode = instructions[name]["encodings"][index]["opcode"]
            for field, value in {"Rn": "00101", "Rd": "00011", **fields}.items():
                opcode = opcode.replace(field, value)
            expected.extend(int(opcode.replace(" ", ""), 2).to_bytes(4, "little"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n.arch armv8-a\n" + "\n".join(c[2] for c in cases) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_add_sub_and_carry_instruction_encodings(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/arm64.json").read_text())["instructions"]}
        cases = []
        for name in ("ADD", "ADDS", "SUB", "SUBS"):
            for width, sf in (("w", "0"), ("x", "1")):
                prefix = f"{name.lower()} {width}3,{width}5,"
                cases += [(name, 0, prefix + "#0x123,lsl #12",
                           {"sf": sf, "sh": "1", "imm12": f"{0x123:012b}"}),
                          (name, 1, prefix + f"{width}7,asr #4",
                           {"sf": sf, "shift": "10", "Rm": "00111", "imm6": "000100"}),
                          (name, 2, prefix + "w7,sxtw #2",
                           {"sf": sf, "Rm": "00111", "option": "110", "imm3": "010"})]
        for name in ("ADC", "ADCS", "SBC", "SBCS"):
            for width, sf in (("w", "0"), ("x", "1")):
                cases.append((name, 0, f"{name.lower()} {width}3,{width}5,{width}7", {"sf": sf, "Rm": "00111"}))
        expected = bytearray()
        for name, index, _, fields in cases:
            opcode = instructions[name]["encodings"][index]["opcode"]
            for field, value in {"Rn": "00101", "Rd": "00011", **fields}.items():
                opcode = opcode.replace(field, value)
            expected.extend(int(opcode.replace(" ", ""), 2).to_bytes(4, "little"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n.arch armv8-a\n" + "\n".join(c[2] for c in cases) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_multiply_divide_and_accumulate_encodings(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/arm64.json").read_text())["instructions"]}
        cases = []
        for name in ("MADD", "MSUB", "SDIV", "UDIV"):
            for width, sf in (("w", "0"), ("x", "1")):
                args = f"{width}3,{width}5,{width}7" + (f",{width}9" if name in ("MADD", "MSUB") else "")
                cases.append((name, f"{name.lower()} {args}", {"sf": sf}))
        for name in ("SMULH", "UMULH"):
            cases.append((name, f"{name.lower()} x3,x5,x7", {}))
        for name in ("SMADDL", "SMSUBL", "UMADDL", "UMSUBL"):
            cases.append((name, f"{name.lower()} x3,w5,w7,x9", {}))
        expected = bytearray()
        for name, _, fields in cases:
            opcode = instructions[name]["encodings"][0]["opcode"]
            for field, value in {"Rm": "00111", "Ra": "01001", "Rn": "00101", "Rd": "00011", **fields}.items():
                opcode = opcode.replace(field, value)
            expected.extend(int(opcode.replace(" ", ""), 2).to_bytes(4, "little"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n.arch armv8-a\n" + "\n".join(c[1] for c in cases) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_bit_and_byte_reversal_encodings(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/arm64.json").read_text())["instructions"]}
        cases = []
        for name in ("RBIT", "REV16", "CLZ", "CLS"):
            for width, sf in (("w", "0"), ("x", "1")):
                cases.append((name, 0, f"{name.lower()} {width}3,{width}7", sf))
        cases += [("REV", 0, "rev w3,w7", "0"), ("REV", 1, "rev x3,x7", "1"),
                  ("REV32", 0, "rev32 x3,x7", "1")]
        expected = bytearray()
        for name, index, _, sf in cases:
            opcode = instructions[name]["encodings"][index]["opcode"]
            opcode = opcode.replace("sf", sf).replace("Rn", "00111").replace("Rd", "00011")
            expected.extend(int(opcode.replace(" ", ""), 2).to_bytes(4, "little"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n.arch armv8-a\n" + "\n".join(c[2] for c in cases) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_conditional_branch_aliases_and_all_condition_codes(self):
        data = json.loads((ROOT / "bin/isa/data/arm64.json").read_text())
        aliases = {item["mnemonic"].upper(): item for item in data["aliases"]}
        conditions = ("eq", "ne", "cs", "cc", "mi", "pl", "vs", "vc",
                      "hi", "ls", "ge", "lt", "gt", "le", "al", "nv")
        codes = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15)
        source = [".text", ".arch armv8-a"]
        expected = bytearray()
        for condition, code in zip(conditions, codes):
            name = "B." + condition.upper()
            self.assertIn(name, aliases)
            alias = aliases[name]
            self.assertIn(f"cond={code:04b}", alias["equivalent"])
            source.append(f"b.{condition} #8")
            word = 0x54000000 | (2 << 5) | code
            expected.extend(word.to_bytes(4, "little"))
        for condition in ("hs", "lo"):
            self.assertIn("B." + condition.upper(), aliases)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text("\n".join(source) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_pc_relative_instruction_encodings(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/arm64.json").read_text())["instructions"]}
        cases = []
        for name in ("ADR", "ADRP"):
            for offset in (-8, 8):
                value = offset & ((1 << 21) - 1)
                operand = offset * 4096 if name == "ADRP" else offset
                cases.append((name, f"{name.lower()} x3,#{operand}",
                              {"immlo": f"{value & 3:02b}", "immhi": f"{value >> 2:019b}", "Rd": "00011"}))
        for name in ("CBZ", "CBNZ"):
            for register, sf in (("w3", "0"), ("x3", "1")):
                for offset in (-8, 8):
                    cases.append((name, f"{name.lower()} {register},#{offset}",
                                  {"sf": sf, "imm19": f"{(offset // 4) & ((1 << 19) - 1):019b}", "Rt": "00011"}))
        for name in ("TBZ", "TBNZ"):
            for register, bit in (("w3", 0), ("w3", 31), ("x3", 32), ("x3", 63)):
                for offset in (-8, 8):
                    cases.append((name, f"{name.lower()} {register},#{bit},#{offset}",
                                  {"b5": str(bit >> 5), "b40": f"{bit & 31:05b}",
                                   "imm14": f"{(offset // 4) & ((1 << 14) - 1):014b}", "Rt": "00011"}))
        conditions = ("eq", "ne", "cs", "cc", "mi", "pl", "vs", "vc",
                      "hi", "ls", "ge", "lt", "gt", "le", "al", "nv")
        for value, condition in enumerate(conditions):
            cases.append(("B.COND", f"b.{condition} #8",
                          {"imm19": f"{2:019b}", "cond": f"{value:04b}"}))
        expected = bytearray()
        for name, _, fields in cases:
            opcode = instructions[name]["encodings"][0]["opcode"]
            for field, value in fields.items():
                opcode = opcode.replace(field, value)
            expected.extend(int(opcode.replace(" ", ""), 2).to_bytes(4, "little"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n.arch armv8-a\n" + "\n".join(c[1] for c in cases) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_move_wide_and_branch_encodings(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/arm64.json").read_text())["instructions"]}
        cases = []
        for name in ("MOVZ", "MOVN", "MOVK"):
            for reg, sf, shifts in (("w3", "0", (0, 16)), ("x3", "1", (0, 16, 32, 48))):
                for shift in shifts:
                    cases.append((name, f"{name.lower()} {reg},#0x1234,lsl #{shift}",
                                  {"sf": sf, "hw": f"{shift // 16:02b}",
                                   "imm16": f"{0x1234:016b}", "Rd": "00011"}))
        cases += [("BR", "br x3", {"Rn": "00011"}), ("BLR", "blr x7", {"Rn": "00111"}),
                  ("B", "b #8", {"imm26": f"{2:026b}"}),
                  ("BL", "bl #-8", {"imm26": f"{(1 << 26) - 2:026b}"}),
                  ("SVC", "svc #0x1234", {"imm16": f"{0x1234:016b}"}), ("NOP", "nop", {})]
        expected = bytearray()
        for name, _, fields in cases:
            entry = instructions[name]["encodings"][0]
            opcode = entry["opcode"]
            for field, value in fields.items():
                opcode = opcode.replace(field, value)
            opcode = opcode.replace(" ", "")
            expected.extend(int(opcode, 16 if name == "NOP" else 2).to_bytes(4, "little"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n.arch armv8-a\n" + "\n".join(c[1] for c in cases) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_exclusive_and_ordered_access_forms(self):
        data = json.loads((ROOT / "bin/isa/data/arm64.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        source = [".text", ".arch armv8-a"]
        for prefix in ("ldxr", "ldaxr", "stxr", "stlxr", "ldar", "stlr"):
            for suffix in ("", "b", "h"):
                name = prefix + suffix
                self.assertIn(name.upper(), instructions)
                source.append(f"{name} " + ("w0,w1,[x2]" if prefix in ("stxr", "stlxr") else "w1,[x2]"))
        for name in ("ldxp", "ldaxp", "stxp", "stlxp"):
            self.assertIn(name.upper(), instructions)
            source.append(f"{name} " + ("w0,w1,w2,[x3]" if name.startswith("st") else "w1,w2,[x3]"))
        self.assertIn("CLREX", instructions)
        source.append("clrex")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text("\n".join(source) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual(len((path / "test.bin").read_bytes()), (len(source) - 2) * 4)

    def test_system_instruction_examples(self):
        data = json.loads((ROOT / "bin/isa/data/arm64.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        names = ("HVC", "SMC", "BRK", "HLT", "ERET", "DMB", "DSB", "ISB",
                 "WFE", "WFI", "SEV", "SEVL", "YIELD")
        source, expected = [".text", ".arch armv8-a"], bytearray()
        for name in names:
            entry = instructions[name]["encodings"][0]
            source.append(entry["syntax"].lower())
            expected.extend(int(entry["opcode"], 16).to_bytes(4, "little"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text("\n".join(source) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_variable_shift_mnemonics(self):
        data = json.loads((ROOT / "bin/isa/data/arm64.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        pairs = []
        for name in ("lsl", "lsr", "asr", "ror"):
            self.assertIn(name.upper() + "V", instructions)
            for width in ("w", "x"):
                pairs.append((f"{name}v {width}0,{width}1,{width}2", f"{name} {width}0,{width}1,{width}2"))
        pairs.append(("mvn x0,x1", "orn x0,xzr,x1"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(s for pair in pairs for s in pair) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            actual = (path / "test.bin").read_bytes()
            self.assertEqual(len(actual), len(pairs) * 8)
            for index, (alias, _) in enumerate(pairs):
                self.assertEqual(actual[index * 8:index * 8 + 4], actual[index * 8 + 4:index * 8 + 8], alias)

    def test_return_and_condition_aliases(self):
        data = json.loads((ROOT / "bin/isa/data/arm64.json").read_text())
        ret = next(item for item in data["instructions"] if item["mnemonic"] == "RET")
        self.assertEqual(ret["operands"], "{Xn}")
        source = ".text\nret\nret x30\nret x1\nb.ne .\nbne .\n"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(source)
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            actual = (path / "test.bin").read_bytes()
            self.assertEqual(len(actual), 20)
            self.assertEqual(actual[:4], actual[4:8])
            self.assertNotEqual(actual[:4], actual[8:12])
            self.assertEqual(actual[12:16], actual[16:20])

    def test_unscaled_load_store_forms(self):
        data = json.loads((ROOT / "bin/isa/data/arm64.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        pairs = (("ldurb w0,[x1,#-1]", "ldrb w0,[x1,#-1]"),
                 ("ldurh w0,[x1,#-1]", "ldrh w0,[x1,#-1]"),
                 ("ldursb x0,[x1,#-1]", "ldrsb x0,[x1,#-1]"),
                 ("ldursh x0,[x1,#-1]", "ldrsh x0,[x1,#-1]"),
                 ("ldursw x0,[x1,#-1]", "ldrsw x0,[x1,#-1]"),
                 ("sturb w0,[x1,#-1]", "strb w0,[x1,#-1]"),
                 ("sturh w0,[x1,#-1]", "strh w0,[x1,#-1]"))
        for alias, _ in pairs:
            self.assertIn(alias.split()[0].upper(), instructions)
        source = ".text\n" + "\n".join(s for pair in pairs for s in pair) + "\n"
        source += "ldp w0,w1,[x2,#-256]\nldp w0,w1,[x2,#252]\n"
        source += "stp x0,x1,[x2,#-512]\nstp x0,x1,[x2,#504]\n"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(source)
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            actual = (path / "test.bin").read_bytes()
            self.assertEqual(len(actual), len(pairs) * 8 + 16)
            for index, (alias, _) in enumerate(pairs):
                self.assertEqual(actual[index * 8:index * 8 + 4], actual[index * 8 + 4:index * 8 + 8], alias)

    def test_negate_with_carry_aliases(self):
        data = json.loads((ROOT / "bin/isa/data/arm64.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        pairs = (("ngc w0,w1", "sbc w0,wzr,w1"), ("ngc x0,x1", "sbc x0,xzr,x1"),
                 ("ngcs w0,w1", "sbcs w0,wzr,w1"), ("ngcs x0,x1", "sbcs x0,xzr,x1"))
        for name in ("NGC", "NGCS"):
            self.assertEqual(len(instructions[name]["encodings"]), 2)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(s for pair in pairs for s in pair) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            actual = (path / "test.bin").read_bytes()
            self.assertEqual(len(actual), len(pairs) * 8)
            for index, (alias, _) in enumerate(pairs):
                self.assertEqual(actual[index * 8:index * 8 + 4], actual[index * 8 + 4:index * 8 + 8], alias)

    def test_bitfield_formulas_from_dictionary(self):
        data = json.loads((ROOT / "bin/isa/data/arm64.json").read_text())
        instructions = {inst["mnemonic"]: inst for inst in data["instructions"]}
        names = ("UBFX", "UBFIZ", "SBFX", "SBFIZ", "BFI", "BFXIL")
        values = {"Xd": "x0", "Xn": "x1", "lsb": "8", "width": "8",
                  "posn": "8", "len": "8", "Rsize": "64"}
        source = [".text", ".arch armv8-a"]
        for name in names:
            entry = instructions[name]["encodings"][0]
            for syntax in (entry["syntax"], entry["opcode"].removesuffix(" と等価")):
                for key in sorted(values, key=len, reverse=True):
                    syntax = re.sub(r"\b" + key + r"\b", values[key], syntax)
                source.append(syntax)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text("\n".join(source) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            actual = (path / "test.bin").read_bytes()
            self.assertEqual(len(actual), 8 * len(names))
            for index, name in enumerate(names):
                pair = actual[index * 8:index * 8 + 8]
                self.assertEqual(pair[:4], pair[4:], name)

    def test_documented_aliases_match_base_instruction(self):
        pairs = (
            ("mov w0,#0x00ff00ff", "orr w0,wzr,#0x00ff00ff"),
            ("neg x0,x1", "sub x0,xzr,x1"), ("negs x0,x1", "subs x0,xzr,x1"),
            ("lsl x0,x1,#8", "ubfm x0,x1,#56,#55"), ("lsr x0,x1,#8", "ubfm x0,x1,#8,#63"),
            ("ror x0,x1,#8", "extr x0,x1,x1,#8"),
            ("ubfx x0,x1,#8,#8", "ubfm x0,x1,#8,#15"),
            ("ubfiz x0,x1,#8,#8", "ubfm x0,x1,#56,#7"),
            ("sbfx x0,x1,#8,#8", "sbfm x0,x1,#8,#15"),
            ("sbfiz x0,x1,#8,#8", "sbfm x0,x1,#56,#7"),
            ("bfi x0,x1,#8,#8", "bfm x0,x1,#56,#7"),
            ("bfc x0,#8,#8", "bfi x0,xzr,#8,#8"),
            ("bfxil x0,x1,#8,#8", "bfm x0,x1,#8,#15"),
            ("cmp x1,x2", "subs xzr,x1,x2"), ("cmn x1,x2", "adds xzr,x1,x2"),
            ("tst x1,x2", "ands xzr,x1,x2"),
            ("cset x0,eq", "csinc x0,xzr,xzr,ne"),
            ("csetm x0,eq", "csinv x0,xzr,xzr,ne"),
            ("cinc x0,x1,eq", "csinc x0,x1,x1,ne"),
            ("cinv x0,x1,eq", "csinv x0,x1,x1,ne"),
            ("cneg x0,x1,eq", "csneg x0,x1,x1,ne"),
            ("mul w0,w1,w2", "madd w0,w1,w2,wzr"),
            ("mul x0,x1,x2", "madd x0,x1,x2,xzr"),
            ("mneg w0,w1,w2", "msub w0,w1,w2,wzr"),
            ("mneg x0,x1,x2", "msub x0,x1,x2,xzr"),
            ("smull x0,w1,w2", "smaddl x0,w1,w2,xzr"),
            ("umull x0,w1,w2", "umaddl x0,w1,w2,xzr"),
            ("smnegl x0,w1,w2", "smsubl x0,w1,w2,xzr"),
            ("umnegl x0,w1,w2", "umsubl x0,w1,w2,xzr"),
        )
        data = json.loads((ROOT / "bin/isa/data/arm64.json").read_text())
        instructions = {inst["mnemonic"]: inst for inst in data["instructions"]}
        source = [".text", ".arch armv8-a"]
        for alias, base in pairs:
            name, target = alias.split()[0].upper(), base.split()[0].upper()
            self.assertTrue(any(target in entry["opcode"] for entry in instructions[name]["encodings"]), name)
            source.extend((alias, base))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text("\n".join(source) + "\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            actual = (path / "test.bin").read_bytes()
            self.assertEqual(len(actual), 8 * len(pairs))
            for index, (alias, _) in enumerate(pairs):
                pair = actual[index * 8:index * 8 + 8]
                self.assertEqual(pair[:4], pair[4:], alias)

    def test_armv8a_aliases_and_register_widths(self):
        source = """.text
.arch armv8-a
bfc x0, #8, #8
bfi x0, xzr, #8, #8
rev w0, w1
rev x0, x1
mov w0, #0xff00ff00
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(source)
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            words = (path / "test.bin").read_bytes()
            self.assertEqual(len(words), 20)
            self.assertEqual(words[:4], words[4:8], "BFC must encode the BFI alias")
            self.assertNotEqual(words[8:12], words[12:16], "REV W and X must both assemble")

    def test_uxtw_alias_and_destination_width(self):
        data = json.loads((ROOT / "bin/isa/data/arm64.json").read_text())
        item = next(x for x in data["instructions"] if x["mnemonic"] == "UXTW")
        self.assertEqual(item["operands"], "dst64, srcw")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\nuxtw x0, w1\nubfm x0, x1, #0, #31\n")
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            code = (path / "test.bin").read_bytes()
            self.assertEqual(len(code), 8)
            self.assertEqual(code[:4], code[4:])

    def test_uxtb_and_uxth_use_word_encoding(self):
        source = ".text\nuxtb w0,w1\nubfm w0,w1,#0,#7\nuxth w2,w3\nubfm w2,w3,#0,#15\n"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(source)
            subprocess.run(["clang", "--target=aarch64-none-elf", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            code = (path / "test.bin").read_bytes()
            self.assertEqual(len(code), 16)
            self.assertEqual(code[:4], code[4:8])
            self.assertEqual(code[8:12], code[12:])


@unittest.skipUnless(shutil.which("nasm"), "nasm is not installed")
class X86EncodingTests(unittest.TestCase):
    def test_x86_64_system_instruction_encodings(self):
        data = json.loads((ROOT / "bin/isa/data/x86_64.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        names = ("IRETQ", "HLT", "CPUID", "RDTSC", "RDMSR", "WRMSR", "SYSENTER", "SYSEXIT")
        source = "BITS 64\n" + "\n".join(names) + "\n"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.asm").write_text(source)
            subprocess.run(["nasm", "-f", "bin", str(path / "test.asm"), "-o",
                            str(path / "test.bin")], check=True)
            actual = (path / "test.bin").read_bytes()
        expected = bytes.fromhex("".join(
            instructions[name]["encodings"][0]["opcode"].replace(" ", "") for name in names))
        self.assertEqual(actual, expected)
        for name in ("RDMSR", "WRMSR"):
            self.assertIn("CPL=0", instructions[name]["notes"], name)
        rdtsc = instructions["RDTSC"]
        self.assertIn("CR4.TSD=0", rdtsc["notes"])
        self.assertIn("CPL 0", rdtsc["notes"])
        self.assertEqual(rdtsc["flags"], ["-"] * 8)
        sysenter = instructions["SYSENTER"]
        self.assertIn("CPL 3", sysenter["notes"])
        self.assertEqual(sysenter["flags"], ["-", "-", "0", "-", "-", "-", "-", "-"])
        sysexit = instructions["SYSEXIT"]
        self.assertIn("CPL 0", sysexit["notes"])
        self.assertEqual(sysexit["flags"], ["-"] * 8)
        self.assertIn("SYSENTERが保存した戻り先から復帰する命令ではない", sysexit["notes"])

    def test_i386_stack_memory_forms(self):
        data = json.loads((ROOT / "bin/isa/data/i386.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        cases = (("PUSH", "FF /6", "push dword [ebx]", "ff33"),
                 ("POP", "8F /0", "pop dword [ebx]", "8f03"))
        for name, opcode, _, _ in cases:
            entry = next(item for item in instructions[name]["encodings"] if item["syntax"] == f"{name} r/m16/32")
            self.assertEqual(entry["opcode"], opcode)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.asm").write_text("BITS 32\nCPU 386\n" + "\n".join(x[2] for x in cases) + "\n")
            subprocess.run(["nasm", "-f", "bin", "-o", str(path / "test.bin"),
                            str(path / "test.asm")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), bytes.fromhex(" ".join(x[3] for x in cases)))

    def test_i386_string_timings_and_encodings(self):
        data = json.loads((ROOT / "bin/isa/data/i386.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        for suffix in "BWD":
            for name, condition, value in (
                ("MOVS", "REP n 回、合計", "5+4n"),
                ("STOS", "REP n 回、合計", "5+5n"),
                ("INS", "REP n 回、リアルモード", "13+6n"),
                ("OUTS", "REP n 回、リアルモード", "5+12n"),
                ("CMPS", "REPE/REPNE n 回、合計", "5+9n"),
                ("SCAS", "REPE/REPNE n 回、合計", "5+8n"),
            ):
                clocks = {item["cond"]: item["cycles"] for item in instructions[name + suffix]["cycles"]}
                self.assertEqual(clocks[condition], value, name + suffix)
        cases = (("rep movsb", "f3a4"), ("rep movsw", "66f3a5"),
                 ("rep movsd", "f3a5"), ("rep insb", "f36c"),
                 ("rep outsd", "f36f"), ("repe cmpsb", "f3a6"),
                 ("repne scasb", "f2ae"), ("a16 rep movsb", "67f3a4"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.asm").write_text("BITS 32\nCPU 386\n" + "\n".join(x for x, _ in cases) + "\n")
            subprocess.run(["nasm", "-f", "bin", "-o", str(path / "test.bin"),
                            str(path / "test.asm")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), bytes.fromhex(" ".join(x for _, x in cases)))

    def test_i386_shift_and_rotate_operand_forms(self):
        data = json.loads((ROOT / "bin/isa/data/i386.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        source, expected = ["BITS 32", "CPU 386"], bytearray()
        for name, group in (("ROL", 0), ("ROR", 1), ("RCL", 2), ("RCR", 3),
                            ("SHL", 4), ("SHR", 5), ("SAR", 7)):
            entries = {entry["syntax"]: entry["opcode"] for entry in instructions[name]["encodings"]}
            for width, size, count, opcode in ((8, "byte", "1", 0xD0), (32, "dword", "1", 0xD1),
                                                (8, "byte", "cl", 0xD2), (32, "dword", "cl", 0xD3),
                                                (8, "byte", "3", 0xC0), (32, "dword", "3", 0xC1)):
                operand = "r/m8" if width == 8 else "r/m16/32"
                suffix = "1" if count == "1" else "CL" if count == "cl" else "imm8"
                expected_opcode = f"{opcode:02X} /{group}" + (" ib" if suffix == "imm8" else "")
                self.assertEqual(entries[f"{name} {operand}, {suffix}"], expected_opcode)
                source.append(f"{name.lower()} {size} [ebx],{count}")
                expected.extend((opcode, group * 8 + 3))
                if suffix == "imm8":
                    expected.append(3)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.asm").write_text("\n".join(source) + "\n")
            subprocess.run(["nasm", "-f", "bin", "-o", str(path / "test.bin"),
                            str(path / "test.asm")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_i386_alu_operand_forms(self):
        data = json.loads((ROOT / "bin/isa/data/i386.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        source, expected = ["BITS 32", "CPU 386"], bytearray()
        for group, name in enumerate(("ADD", "OR", "ADC", "SBB", "AND", "SUB", "XOR", "CMP")):
            entries = {entry["syntax"]: entry["opcode"] for entry in instructions[name]["encodings"]}
            forms = (
                (f"{name} r/m, r", f"{name.lower()} [ebx],eax", bytes((int(entries[f"{name} r/m, r"][:2], 16), 3))),
                (f"{name} r, r/m", f"{name.lower()} eax,[ebx]", bytes((int(entries[f"{name} r, r/m"][:2], 16), 3))),
                (f"{name} r/m8, imm8", f"{name.lower()} byte [ebx],0x12", bytes((0x80, group * 8 + 3, 0x12))),
                (f"{name} r/m16/32, imm8（符号拡張）", f"{name.lower()} dword [ebx],byte 0x12", bytes((0x83, group * 8 + 3, 0x12))),
                (f"{name} AL, imm8", f"{name.lower()} al,0x12", bytes((group * 8 + 4, 0x12))),
            )
            self.assertEqual(entries[f"{name} r/m8, imm8"], f"80 /{group} ib")
            self.assertEqual(entries[f"{name} r/m16/32, imm8（符号拡張）"], f"83 /{group} ib")
            self.assertEqual(entries[f"{name} AL, imm8"], f"{group * 8 + 4:02X} ib")
            for _, assembly, encoded in forms:
                source.append(assembly)
                expected.extend(encoded)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.asm").write_text("\n".join(source) + "\n")
            subprocess.run(["nasm", "-f", "bin", "-o", str(path / "test.bin"),
                            str(path / "test.asm")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_i386_explicit_operand_size_mnemonics(self):
        data = json.loads((ROOT / "bin/isa/data/i386.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        names = ("PUSHAD", "POPAD", "PUSHF", "POPF", "IRETD")
        source = ["BITS 32", "CPU 386"]
        expected = bytearray()
        for name in names:
            entry = instructions[name]["encodings"][0]
            encoded = bytes.fromhex(entry["opcode"])
            self.assertEqual(entry["bytes"], len(encoded))
            # NASM の PUSHF/POPF は既定幅を使い、Intel の 16 ビット形は W 接尾辞で指定する。
            source.append({"PUSHF": "pushfw", "POPF": "popfw"}.get(name, name.lower()))
            expected.extend(encoded)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.asm").write_text("\n".join(source) + "\n")
            subprocess.run(["nasm", "-f", "bin", "-o", str(path / "test.bin"),
                            str(path / "test.asm")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_8086_added_encoding_forms(self):
        data = json.loads((ROOT / "bin/isa/data/x86_16.json").read_text())
        instructions = {inst["mnemonic"]: inst for inst in data["instructions"]}
        cases = (
            ("MOV", "MOV reg,reg/mem", "1000101w /r", "mov ax,[bx]", "8b07"),
            ("MOV", "MOV reg/mem,reg", "1000100w /r", "mov [bx],ax", "8907"),
            ("MOV", "MOV reg/mem,imm", "1100011w /0 ib/iw", "mov word [bx],0x1234", "c7073412"),
            ("MOV", "MOV reg/mem16,Sreg", "8C /r", "mov ax,ds", "8cd8"),
            ("MOV", "MOV Sreg,reg/mem16", "8E /r", "mov ds,ax", "8ed8"),
            ("MOV", "MOV AL/AX,[moffs16]", "A0/A1 off16", "mov al,[0x1234]", "a03412"),
            ("MOV", "MOV AL/AX,[moffs16]", "A0/A1 off16", "mov ax,[0x1234]", "a13412"),
            ("MOV", "MOV [moffs16],AL/AX", "A2/A3 off16", "mov [0x1234],al", "a23412"),
            ("MOV", "MOV [moffs16],AL/AX", "A2/A3 off16", "mov [0x1234],ax", "a33412"),
            ("XCHG", "XCHG reg/mem,reg", "1000011w /r", "xchg [bx],ax", "8707"),
            ("JMP", "JMP r/m16（near 間接）", "FF /4", "jmp ax", "ffe0"),
            ("JMP", "JMP m16:16（far 間接）", "FF /5", "jmp far [bx]", "ff2f"),
            ("CALL", "CALL r/m16（near 間接）", "FF /2", "call ax", "ffd0"),
            ("CALL", "CALL m16:16（far 間接）", "FF /3", "call far [bx]", "ff1f"),
            ("IN", "IN AX,imm8", "E5 ib", "in ax,0x20", "e520"),
            ("IN", "IN AX,DX", "ED", "in ax,dx", "ed"),
            ("OUT", "OUT imm8,AX", "E7 ib", "out 0x20,ax", "e720"),
            ("OUT", "OUT DX,AX", "EF", "out dx,ax", "ef"),
        )
        source, expected = ["BITS 16", "CPU 8086"], bytearray()
        for mnemonic, syntax, opcode, assembly, encoded in cases:
            entry = next(item for item in instructions[mnemonic]["encodings"] if item["syntax"] == syntax)
            self.assertEqual(entry["opcode"], opcode, syntax)
            source.append(assembly)
            expected.extend(bytes.fromhex(encoded))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.asm").write_text("\n".join(source) + "\n")
            subprocess.run(["nasm", "-f", "bin", "-o", str(path / "test.bin"),
                            str(path / "test.asm")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_variable_lengths_and_address_size_branches(self):
        for arch, mnemonic, syntax in (("x86_16", "MOV", "MOV reg,reg/mem"),
                                       ("i386", "MOV", "MOV r, r/m"),
                                       ("x86_64", "MOV", "MOV r64, r/m64")):
            data = json.loads((ROOT / f"bin/isa/data/{arch}.json").read_text())
            inst = next(item for item in data["instructions"] if item["mnemonic"] == mnemonic)
            entry = next(item for item in inst["encodings"] if item["syntax"] == syntax)
            self.assertEqual(entry.get("length"), "可変", arch)
            self.assertNotIn("bytes", entry, arch)

        cases = (
            ("BITS 16\nCPU 8086\nmov ax,[bx]\nmov ax,[bx+0x1234]\n", "8b07 8b873412"),
            ("BITS 32\nCPU 386\njcxz $+3\njecxz $+2\n", "67e300 e300"),
            ("BITS 64\njrcxz $+2\njecxz $+3\n", "e300 67e300"),
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            for source, encoding in cases:
                (path / "test.asm").write_text(source)
                subprocess.run(["nasm", "-f", "bin", "-o", str(path / "test.bin"),
                                str(path / "test.asm")], check=True)
                self.assertEqual((path / "test.bin").read_bytes(), bytes.fromhex(encoding))

    def test_x86_64_string_sizes(self):
        data = json.loads((ROOT / "bin/isa/data/x86_64.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        source = ["BITS 64"]
        expected = bytearray()
        for mnemonic in ("SCASB", "SCASW", "SCASD", "SCASQ", "CMPSB", "CMPSW", "CMPSD", "CMPSQ"):
            entry = next(e for e in instructions[mnemonic]["encodings"] if e["syntax"] == mnemonic)
            source.append(mnemonic.lower())
            for token in entry["opcode"].split():
                expected.append(0x48 if token == "REX.W" else int(token, 16))
            self.assertEqual(entry["bytes"], len(entry["opcode"].split()))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.asm").write_text("\n".join(source) + "\n")
            subprocess.run(["nasm", "-f", "bin", "-o", str(path / "test.bin"),
                            str(path / "test.asm")], check=True)
            actual = (path / "test.bin").read_bytes()
            self.assertEqual(actual, expected, f"first difference: {next(((i, a, b) for i, (a, b) in enumerate(zip(actual, expected)) if a != b), None)}, lengths {len(actual)}/{len(expected)}")


@unittest.skipUnless(shutil.which("m68k-elf-as") and shutil.which("m68k-elf-objcopy"), "m68k binutils are not installed")
class M68kEncodingTests(unittest.TestCase):
    def test_movea_bcd_and_logic_formats(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/m68k.json").read_text())["instructions"]}
        cases = []
        for size in ("W", "L"):
            cases.append(("MOVEA", f"MOVEA.{size} ea,An", f"movea.{size.lower()} (%a3),%a2",
                          {"AAA": "010", "MMM": "010", "RRR": "011"}, b""))
        for name in ("ABCD", "SBCD"):
            for syntax, operands in ((f"{name} Dn,Dm", "%d3,%d2"),
                                     (f"{name} -(An),-(Am)", "-(%a3),-(%a2)")):
                cases.append((name, syntax, f"{name.lower()} {operands}",
                              {"DDD": "010", "RRR": "011"}, b""))
        for name in ("AND", "OR", "EOR"):
            for size, bits in (("b", "00"), ("w", "01"), ("l", "10")):
                if name != "EOR":
                    cases.append((name, f"{name} ea,Dn", f"{name.lower()}.{size} (%a3),%d2",
                                  {"DDD": "010", "ss": bits, "MMM": "010", "RRR": "011"}, b""))
                cases.append((name, f"{name} Dn,ea", f"{name.lower()}.{size} %d2,(%a3)",
                              {"DDD": "010", "ss": bits, "MMM": "010", "RRR": "011"}, b""))
                imm = name + "I"
                extra = bytes.fromhex("00000012" if size == "l" else "0012")
                cases.append((imm, f"{imm} #imm,ea", f"{imm.lower()}.{size} #0x12,(%a3)",
                              {"ss": bits, "MMM": "010", "RRR": "011"}, extra))
        expected = bytearray()
        for name, syntax, _, fields, extra in cases:
            opcode = next(e["opcode"] for e in instructions[name]["encodings"] if e["syntax"] == syntax)
            for field, value in fields.items():
                opcode = opcode.replace(field, value)
            expected.extend(int(opcode.replace("imm", "").replace(" ", ""), 2).to_bytes(2, "big") + extra)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(c[2] for c in cases) + "\n")
            subprocess.run(["m68k-elf-as", "-m68000", "-o", str(path / "test.o"), str(path / "test.s")], check=True)
            subprocess.run(["m68k-elf-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_add_sub_and_compare_formats(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/m68k.json").read_text())["instructions"]}
        cases = []
        for name in ("ADD", "SUB", "CMP"):
            for size, bits in (("b", "00"), ("w", "01"), ("l", "10")):
                cases.append((name, f"{name} ea,Dn", f"{name.lower()}.{size} (%a3),%d2",
                              {"DDD": "010", "ss": bits, "MMM": "010", "RRR": "011"}, b""))
                if name != "CMP":
                    cases.append((name, f"{name} Dn,ea", f"{name.lower()}.{size} %d2,(%a3)",
                                  {"DDD": "010", "ss": bits, "MMM": "010", "RRR": "011"}, b""))
            address_name = name + "A"
            for size in ("W", "L"):
                cases.append((address_name, f"{address_name}.{size} ea,An",
                              f"{address_name.lower()}.{size.lower()} (%a3),%a2",
                              {"AAA": "010", "MMM": "010", "RRR": "011"}, b""))
            immediate_name = name + "I"
            for size, bits in (("b", "00"), ("w", "01"), ("l", "10")):
                extra = bytes.fromhex("00000012" if size == "l" else "0012")
                cases.append((immediate_name, f"{immediate_name} #imm,ea",
                              f"{immediate_name.lower()}.{size} #0x12,(%a3)",
                              {"ss": bits, "MMM": "010", "RRR": "011"}, extra))
            if name != "CMP":
                for size, bits in (("b", "00"), ("w", "01"), ("l", "10")):
                    cases.append((name + "Q", f"{name}Q #count,ea", f"{name.lower()}q.{size} #8,(%a3)",
                                  {"QQQ": "000", "ss": bits, "MMM": "010", "RRR": "011"}, b""))
                    for syntax, operands in ((f"{name}X Dn,Dm", "%d3,%d2"),
                                             (f"{name}X -(An),-(Am)", "-(%a3),-(%a2)")):
                        cases.append((name + "X", syntax, f"{name.lower()}x.{size} {operands}",
                                      {"DDD": "010", "ss": bits, "RRR": "011"}, b""))
        for size, bits in (("b", "00"), ("w", "01"), ("l", "10")):
            cases.append(("CMPM", "CMPM (An)+,(Am)+", f"cmpm.{size} (%a3)+,(%a2)+",
                          {"DDD": "010", "ss": bits, "RRR": "011"}, b""))
        expected = bytearray()
        for name, syntax, _, fields, extra in cases:
            opcode = next(e["opcode"] for e in instructions[name]["encodings"] if e["syntax"] == syntax)
            for field, value in fields.items():
                opcode = opcode.replace(field, value)
            expected.extend(int(opcode.replace("imm", "").replace(" ", ""), 2).to_bytes(2, "big") + extra)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(c[2] for c in cases) + "\n")
            subprocess.run(["m68k-elf-as", "-m68000", "-o", str(path / "test.o"), str(path / "test.s")], check=True)
            subprocess.run(["m68k-elf-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_shift_and_bit_instruction_encodings(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/m68k.json").read_text())["instructions"]}
        cases = []
        for name in ("ASL", "ASR", "LSL", "LSR", "ROL", "ROR", "ROXL", "ROXR"):
            for size, bits in (("b", "00"), ("w", "01"), ("l", "10")):
                cases += [(name, f"{name} #count,Dn", f"{name.lower()}.{size} #8,%d3",
                           {"CCC": "000", "ss": bits, "RRR": "011"}, b""),
                          (name, f"{name} Dm,Dn", f"{name.lower()}.{size} %d2,%d3",
                           {"CCC": "010", "ss": bits, "RRR": "011"}, b"")]
            cases.append((name, f"{name}.W ea", f"{name.lower()}.w (%a3)",
                          {"MMM": "010", "RRR": "011"}, b""))
        for name in ("BTST", "BCHG", "BCLR", "BSET"):
            for operand, mode in (("%d3", "000"), ("(%a3)", "010")):
                cases += [(name, f"{name} Dn,ea", f"{name.lower()} %d2,{operand}",
                           {"NNN": "010", "MMM": mode, "RRR": "011"}, b""),
                          (name, f"{name} #imm,ea", f"{name.lower()} #5,{operand}",
                           {"MMM": mode, "RRR": "011"}, b"\x00\x05")]
        expected = bytearray()
        for name, syntax, _, fields, extra in cases:
            opcode = next(e["opcode"] for e in instructions[name]["encodings"] if e["syntax"] == syntax)
            for field, value in fields.items():
                opcode = opcode.replace(field, value)
            opcode = opcode.replace("imm16", "").replace(" ", "")
            expected.extend(int(opcode, 2).to_bytes(2, "big") + extra)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(c[2] for c in cases) + "\n")
            subprocess.run(["m68k-elf-as", "-m68000", "-o", str(path / "test.o"), str(path / "test.s")], check=True)
            subprocess.run(["m68k-elf-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_unary_and_multiply_divide_formats(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/m68k.json").read_text())["instructions"]}
        cases = []
        for name in ("CLR", "NEG", "NEGX", "NOT", "TST"):
            for size, bits in (("b", "00"), ("w", "01"), ("l", "10")):
                for operand, mode in (("%d3", "000"), ("(%a3)", "010")):
                    cases.append((name, f"{name} size,ea", f"{name.lower()}.{size} {operand}",
                                  {"ss": bits, "MMM": mode, "RRR": "011"}))
        for name in ("MULU", "MULS", "DIVU", "DIVS"):
            for operand, mode in (("%d3", "000"), ("(%a3)", "010")):
                cases.append((name, f"{name}.W ea,Dn", f"{name.lower()}.w {operand},%d2",
                              {"DDD": "010", "MMM": mode, "RRR": "011"}))
        for size, mode in (("w", "W"), ("l", "L")):
            cases.append(("EXT", f"EXT.{mode} Dn", f"ext.{size} %d3", {"RRR": "011"}))
        cases.append(("NBCD", "NBCD ea", "nbcd (%a3)", {"MMM": "010", "RRR": "011"}))
        expected = bytearray()
        for name, syntax, _, fields in cases:
            opcode = next(e["opcode"] for e in instructions[name]["encodings"] if e["syntax"] == syntax)
            for field, value in fields.items():
                opcode = opcode.replace(field, value)
            expected.extend(int(opcode.replace(" ", ""), 2).to_bytes(2, "big"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(c[2] for c in cases) + "\n")
            subprocess.run(["m68k-elf-as", "-m68000", "-o", str(path / "test.o"), str(path / "test.s")], check=True)
            subprocess.run(["m68k-elf-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_branch_and_system_instruction_formats(self):
        instructions = {x["mnemonic"]: x for x in json.loads(
            (ROOT / "bin/isa/data/m68k.json").read_text())["instructions"]}
        cases = [
            ("RTS", "RTS", "rts", {}, b""), ("RTR", "RTR", "rtr", {}, b""),
            ("TRAP", "TRAP #vector", "trap #7", {"VVVV": "0111"}, b""),
            ("TRAPV", "TRAPV", "trapv", {}, b""), ("RTE", "RTE", "rte", {}, b""),
            ("STOP", "STOP #imm16", "stop #0x2700", {}, bytes.fromhex("2700")),
            ("NOP", "NOP", "nop", {}, b""), ("ILLEGAL", "ILLEGAL", "illegal", {}, b""),
            ("BRA", "BRA.S disp8", "bra.s .+6", {"disp8": "00000100"}, b""),
            ("BSR", "BSR.S disp8", "bsr.s .+6", {"disp8": "00000100"}, b""),
            ("Bcc", "Bcc.S disp8", "bne.s .+6", {"cccc": "0110", "disp8": "00000100"}, b""),
            ("BRA", "BRA.W disp16", "bra.w .+10", {}, bytes.fromhex("0008")),
            ("BSR", "BSR.W disp16", "bsr.w .+10", {}, bytes.fromhex("0008")),
            ("Bcc", "Bcc.W disp16", "beq.w .+10", {"cccc": "0111"}, bytes.fromhex("0008")),
            ("DBcc", "DBcc Dn,disp16", "dbne %d3,.+10", {"cccc": "0110", "RRR": "011"}, bytes.fromhex("0008")),
            ("Scc", "Scc ea", "seq %d3", {"cccc": "0111", "MMM": "000", "RRR": "011"}, b""),
        ]
        expected = bytearray()
        for mnemonic, syntax, _, fields, extra in cases:
            entry = next(e for e in instructions[mnemonic]["encodings"] if e["syntax"] == syntax)
            pattern = entry["opcode"].replace("disp16", "").replace("imm16", "").replace(" ", "")
            for key, value in fields.items():
                pattern = pattern.replace(key, value)
            expected.extend((int(pattern, 2) if len(pattern) == 16 else int(pattern, 16)).to_bytes(2, "big"))
            expected.extend(extra)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(x[2] for x in cases) + "\n")
            subprocess.run(["m68k-elf-as", "-m68000", "-o", str(path / "test.o"), str(path / "test.s")], check=True)
            subprocess.run(["m68k-elf-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_control_address_and_register_transfer_encodings(self):
        data = json.loads((ROOT / "bin/isa/data/m68k.json").read_text())
        instructions = {x["mnemonic"]: x for x in data["instructions"]}
        cases = [
            ("PEA", "PEA ea", "pea (%a3)", {"MMM": "010", "RRR": "011"}, b""),
            ("LEA", "LEA ea,An", "lea (%a3),%a5", {"AAA": "101", "MMM": "010", "RRR": "011"}, b""),
            ("LINK", "LINK An,#disp16", "link %a3,#-8", {"RRR": "011"}, bytes.fromhex("fff8")),
            ("UNLK", "UNLK An", "unlk %a3", {"RRR": "011"}, b""),
            ("SWAP", "SWAP Dn", "swap %d3", {"RRR": "011"}, b""),
            ("EXG", "EXG Dn,Dm", "exg %d2,%d3", {"NNN": "010", "MMM": "011"}, b""),
            ("EXG", "EXG An,Am", "exg %a2,%a3", {"NNN": "010", "MMM": "011"}, b""),
            ("EXG", "EXG Dn,Am", "exg %d2,%a3", {"NNN": "010", "MMM": "011"}, b""),
            ("MOVEP", "MOVEP.W d16(An),Dn", "movep.w 16(%a3),%d2", {"DDD": "010", "AAA": "011"}, b"\x00\x10"),
            ("MOVEP", "MOVEP.L d16(An),Dn", "movep.l 16(%a3),%d2", {"DDD": "010", "AAA": "011"}, b"\x00\x10"),
            ("MOVEP", "MOVEP.W Dn,d16(An)", "movep.w %d2,16(%a3)", {"DDD": "010", "AAA": "011"}, b"\x00\x10"),
            ("MOVEP", "MOVEP.L Dn,d16(An)", "movep.l %d2,16(%a3)", {"DDD": "010", "AAA": "011"}, b"\x00\x10"),
        ]
        expected = bytearray()
        for mnemonic, syntax, _, fields, extension in cases:
            entry = next(e for e in instructions[mnemonic]["encodings"] if e["syntax"] == syntax)
            pattern = entry["opcode"].replace("disp16", "").replace(" ", "")
            for field, value in fields.items():
                pattern = pattern.replace(field, value)
            expected.extend(int(pattern, 2).to_bytes(2, "big") + extension)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(x[2] for x in cases) + "\n")
            subprocess.run(["m68k-elf-as", "-m68000", "-o", str(path / "test.o"), str(path / "test.s")], check=True)
            subprocess.run(["m68k-elf-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(), expected)

    def test_status_and_stack_pointer_encodings(self):
        data = json.loads((ROOT / "bin/isa/data/m68k.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        cases = [
            ("MOVETOCCR", "move.w %d0,%ccr", 2),
            ("MOVETOSR", "move.w (%a1),%sr", 2),
            ("MOVEFROMSR", "move.w %sr,%d2", 2),
            ("MOVEFROMUSP", "move.l %usp,%a3", 2),
            ("MOVETOUSP", "move.l %a4,%usp", 2),
            ("ANDITOSR", "andi.w #0x2700,%sr", 4),
            ("ORITOSR", "ori.w #0x2000,%sr", 4),
            ("EORITOSR", "eori.w #0x100,%sr", 4),
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(c[1] for c in cases) + "\n")
            subprocess.run(["m68k-elf-as", "-m68000", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["m68k-elf-objcopy", "-O", "binary", "-j", ".text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            actual = (path / "test.bin").read_bytes()
        offset = 0
        for name, _, size in cases:
            pattern = instructions[name]["encodings"][0]["opcode"].replace(" ", "")
            bits = f"{int.from_bytes(actual[offset:offset + size], 'big'):0{size * 8}b}"
            self.assertEqual(len(pattern), len(bits), name)
            for expected, observed in zip(pattern, bits):
                if expected in "01":
                    self.assertEqual(expected, observed, name)
            offset += size
        self.assertEqual(offset, len(actual))

    def test_jump_and_dbra_encodings(self):
        data = json.loads((ROOT / "bin/isa/data/m68k.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        source = ".text\njsr (%a0)\njmp 4(%a1)\ndbra %d3,.\n"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(source)
            subprocess.run(["m68k-elf-as", "-m68000", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["m68k-elf-objcopy", "-O", "binary", "-j", ".text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            actual = (path / "test.bin").read_bytes()
        for name, offset in (("JSR", 0), ("JMP", 2)):
            pattern = instructions[name]["encodings"][0]["opcode"].split()[0]
            self.assertEqual(int.from_bytes(actual[offset:offset + 2], "big") >> 6,
                             int(pattern, 2))
        pattern = instructions["DBRA"]["encodings"][0]["opcode"]
        fixed = "".join(pattern.split()[:3])
        self.assertEqual(int.from_bytes(actual[6:8], "big") >> 3, int(fixed, 2))
        self.assertEqual(actual, bytes.fromhex("4e90 4ee9 0004 51cb fffe"))

    def test_immediate_logic_to_ccr(self):
        data = json.loads((ROOT / "bin/isa/data/m68k.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        for name in ("ANDITOCCR", "ORITOCCR", "EORITOCCR"):
            self.assertEqual(instructions[name]["flags"], ["‡"] * 5)
            self.assertEqual(instructions[name]["cycles"][0]["cycles"], 20)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(
                ".text\nandi.b #0x1f,%ccr\nori.b #1,%ccr\neori.b #4,%ccr\n")
            subprocess.run(["m68k-elf-as", "-m68000", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["m68k-elf-objcopy", "-O", "binary", "-j", ".text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            self.assertEqual((path / "test.bin").read_bytes(),
                             bytes.fromhex("023c001f 003c0001 0a3c0004"))

    def test_multiply_divide_data_modes(self):
        data = json.loads((ROOT / "bin/isa/data/m68k.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        for name in ("MULU", "MULS", "DIVU", "DIVS"):
            self.assertIn("PC 相対", instructions[name]["addressing"][0])
        source = (".text\nmulu.w target(%pc),%d0\nmuls.w #2,%d0\n"
                  "divu.w (%a0),%d0\ndivs.w #2,%d0\ntarget: .word 1\n")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(source)
            subprocess.run(["m68k-elf-as", "-m68000", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)

    def test_dbra_alias(self):
        data = json.loads((ROOT / "bin/isa/data/m68k.json").read_text())
        self.assertIn("DBRA", {item["mnemonic"] for item in data["instructions"]})
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\ndbra %d0,.\ndbf %d0,.\n")
            subprocess.run(["m68k-elf-as", "-m68000", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["m68k-elf-objcopy", "-O", "binary", "-j", ".text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            actual = (path / "test.bin").read_bytes()
            self.assertEqual(len(actual), 8)
            self.assertEqual(actual[:4], actual[4:])

    def test_bit_and_logical_addressing(self):
        data = json.loads((ROOT / "bin/isa/data/m68k.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        self.assertIn("PC 相対（読み出し専用）", instructions["BTST"]["addressing"])
        self.assertIn("Dn → データ可変（Dn またはメモリ）", instructions["EOR"]["addressing"])
        source = (".text\nand.w target(%pc),%d0\nor.w target(%pc),%d0\n"
                  "eor.w %d0,%d1\nbtst #2,target(%pc)\nbset %d0,(%a0)\ntarget: .word 0\n")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(source)
            subprocess.run(["m68k-elf-as", "-m68000", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)

    def test_shift_operand_modes(self):
        data = json.loads((ROOT / "bin/isa/data/m68k.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        names = ("ASL", "ASR", "LSL", "LSR", "ROL", "ROR", "ROXL", "ROXR")
        source = [".text"]
        for name in names:
            self.assertIn("Dm 指定回数 0〜63、Dn", instructions[name]["addressing"])
            source.extend((f"{name.lower()}.w #8,%d0", f"{name.lower()}.l %d1,%d0",
                           f"{name.lower()}.w (%a0)"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text("\n".join(source) + "\n")
            subprocess.run(["m68k-elf-as", "-m68000", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            (path / "invalid.s").write_text(".text\nasl.b (%a0)\n")
            result = subprocess.run(["m68k-elf-as", "-m68000", str(path / "invalid.s"),
                                     "-o", str(path / "invalid.o")], capture_output=True)
            self.assertNotEqual(result.returncode, 0)

    def test_arithmetic_source_and_predecrement_modes(self):
        data = json.loads((ROOT / "bin/isa/data/m68k.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        self.assertIn("プリデクリメント -(Ay),-(Ax)", instructions["ADDX"]["addressing"])
        source = (".text\nadd.w %a0,%d0\nsub.l %a0,%d0\ncmp.w %a0,%d0\n"
                  "add.w target(%pc),%d0\naddx.w -(%a0),-(%a1)\n"
                  "subx.l -(%a0),-(%a1)\ntarget: .word 0\n")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(source)
            subprocess.run(["m68k-elf-as", "-m68000", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)

    def test_effective_address_control_modes(self):
        data = json.loads((ROOT / "bin/isa/data/m68k.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        self.assertNotIn("即値", instructions["LEA"]["addressing"])
        self.assertEqual(instructions["PEA"]["cycles"][0]["cycles"], 18)
        source = ".text\nlea (%a0),%a1\npea 4(%a0)\nmovep.w 4(%a0),%d0\nmovep.w %d0,4(%a0)\n"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(source)
            subprocess.run(["m68k-elf-as", "-m68000", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            (path / "invalid.s").write_text(".text\nlea #1,%a0\n")
            result = subprocess.run(["m68k-elf-as", "-m68000", str(path / "invalid.s"),
                                     "-o", str(path / "invalid.o")], capture_output=True)
            self.assertNotEqual(result.returncode, 0)

    def test_movem_predecrement_encoding(self):
        data = json.loads((ROOT / "bin/isa/data/m68k.json").read_text())
        inst = next(item for item in data["instructions"] if item["mnemonic"] == "MOVEM")
        entry = inst["encodings"][0]
        first_word = int(entry["opcode"].split()[0], 2).to_bytes(2, "big")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\nmovem.l %d0-%d2/%a4-%a6,-(%a7)\n")
            subprocess.run(["m68k-elf-as", "-m68000", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["m68k-elf-objcopy", "-O", "binary", "-j", ".text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            actual = (path / "test.bin").read_bytes()
            self.assertEqual(actual[:2], first_word)
            self.assertEqual(len(actual), entry["bytes"])
            self.assertEqual(actual[2:], bytes.fromhex("e0 0e"))


@unittest.skipUnless(shutil.which("clang") and shutil.which("llvm-objcopy"), "LLVM tools are not installed")
class PowerPC440EncodingTests(unittest.TestCase):
    def test_mcrxr_encoding_from_booke_x_form(self):
        data = json.loads((ROOT / "bin/isa/data/ppc.json").read_text())
        item = next(item for item in data["instructions"] if item["mnemonic"] == "MCRXR")
        self.assertEqual(item["operands"], "crfT")
        pattern = item["encodings"][0]["opcode"].replace("crfT", "010").replace(" ", "")
        self.assertEqual(len(pattern), 32)
        self.assertEqual(int(pattern, 2).to_bytes(4, "big"), bytes.fromhex("7d000400"))

    def test_branch_condition_register_and_system_opcode_fields(self):
        data = json.loads((ROOT / "bin/isa/data/ppc.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        cases = [("BC", "bc 12,2,8", {"BO": "01100", "BI": "00010", "BD": f"{2:014b}",
                                        "AA": "0", "LK": "0"}),
                 ("BCLR", "bclr 20,0", {"BO": "10100", "BI": "00000", "LK": "0"}),
                 ("BCCTR", "bcctr 20,0", {"BO": "10100", "BI": "00000", "LK": "0"})]
        for name, asm in (("CRAND", "crand"), ("CRANDC", "crandc"), ("CROR", "cror"),
                          ("CRXOR", "crxor"), ("CREQV", "creqv"), ("CRNAND", "crnand"),
                          ("CRNOR", "crnor"), ("CRORC", "crorc")):
            cases.append((name, f"{asm} 3,4,5", {"BT": "00011", "BA": "00100", "BB": "00101"}))
        cases.extend((
            ("MCRF", "mcrf 2,3", {"BF": "010", "BFA": "011"}),
            ("MFCR", "mfcr 3", {"rT": "00011"}),
            ("MTCRF", "mtcrf 255,3", {"rS": "00011", "FM": "11111111"}),
            ("MFSPR", "mfspr 3,8", {"rT": "00011", "SPR[0:4]": "01000", "SPR[5:9]": "00000"}),
            ("MTSPR", "mtspr 8,3", {"rS": "00011", "SPR[0:4]": "01000", "SPR[5:9]": "00000"}),
            ("MFMSR", "mfmsr 3", {"rT": "00011"}),
            ("MTMSR", "mtmsr 3", {"rS": "00011"}),
            ("SC", "sc", {}),
            ("TW", "tw 31,3,4", {"TO": "11111", "rA": "00011", "rB": "00100"}),
            ("TWI", "twi 31,3,-1", {"TO": "11111", "rA": "00011", "s16": "1111111111111111"}),
            ("ICBT", "icbt 3,4,5", {"CT": "00011", "rA": "00100", "rB": "00101"}),
        ))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(c[1] for c in cases) + "\n")
            subprocess.run(["clang", "--target=powerpc-none-elf", "-mcpu=440", "-c",
                            str(path / "test.s"), "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            raw = (path / "test.bin").read_bytes()
        self.assertEqual(len(raw), 4 * len(cases))
        for index, (name, _, fields) in enumerate(cases):
            pattern = instructions[name]["encodings"][0]["opcode"]
            for field, value in sorted(fields.items(), key=lambda item: -len(item[0])):
                pattern = pattern.replace(field, value)
            pattern = pattern.replace(" ", "")
            bits = f"{int.from_bytes(raw[index * 4:index * 4 + 4], 'big'):032b}"
            self.assertEqual(len(pattern), 32, name)
            for expected, observed in zip(pattern, bits):
                if expected in "01":
                    self.assertEqual(expected, observed, name)

    def test_standard_cache_barrier_and_return_opcodes(self):
        data = json.loads((ROOT / "bin/isa/data/ppc.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        cases = (("DCBF", "dcbf 3,4"), ("DCBI", "dcbi 3,4"),
                 ("DCBST", "dcbst 3,4"), ("DCBTST", "dcbtst 3,4"),
                 ("DCBT", "dcbt 3,4"), ("DCBZ", "dcbz 3,4"),
                 ("ICBI", "icbi 3,4"), ("SYNC", "sync"), ("MSYNC", "sync"),
                 ("EIEIO", "eieio"), ("ISYNC", "isync"), ("RFI", "rfi"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(c[1] for c in cases) + "\n")
            subprocess.run(["clang", "--target=powerpc-none-elf", "-mcpu=440", "-c",
                            str(path / "test.s"), "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            raw = (path / "test.bin").read_bytes()
        self.assertEqual(len(raw), 4 * len(cases))
        for index, (name, _) in enumerate(cases):
            pattern = instructions[name]["encodings"][0]["opcode"]
            pattern = pattern.replace("rA", "00011").replace("rB", "00100").replace(" ", "")
            bits = f"{int.from_bytes(raw[index * 4:index * 4 + 4], 'big'):032b}"
            self.assertEqual(len(pattern), 32, name)
            for expected, observed in zip(pattern, bits):
                if expected in "01":
                    self.assertEqual(expected, observed, name)

    def test_compare_rotate_and_shift_opcode_fields(self):
        data = json.loads((ROOT / "bin/isa/data/ppc.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        cases = (
            ("CNTLZW", "cntlzw 4,3", {"rS": "00011", "rA": "00100"}),
            ("EXTSB", "extsb 4,3", {"rS": "00011", "rA": "00100"}),
            ("EXTSH", "extsh 4,3", {"rS": "00011", "rA": "00100"}),
            ("SLW", "slw 4,3,5", {"rS": "00011", "rA": "00100", "rB": "00101"}),
            ("SRW", "srw 4,3,5", {"rS": "00011", "rA": "00100", "rB": "00101"}),
            ("SRAW", "sraw 4,3,5", {"rS": "00011", "rA": "00100", "rB": "00101"}),
            ("SRAWI", "srawi 4,3,5", {"rS": "00011", "rA": "00100", "SH": "00101"}),
            ("CMPL", "cmplw 2,3,4", {"BF": "010", "L": "0", "rA": "00011", "rB": "00100"}),
            ("CMPI", "cmpwi 2,3,-1", {"BF": "010", "L": "0", "rA": "00011",
                                      "s16": "1111111111111111"}),
            ("CMPLI", "cmplwi 2,3,255", {"BF": "010", "L": "0", "rA": "00011",
                                          "u16": f"{255:016b}"}),
            ("RLWIMI", "rlwimi 4,3,5,6,7", {"rS": "00011", "rA": "00100", "SH": "00101",
                                             "MB": "00110", "ME": "00111", "Rc": "0"}),
            ("RLWNM", "rlwnm 4,3,5,6,7", {"rS": "00011", "rA": "00100", "rB": "00101",
                                           "MB": "00110", "ME": "00111", "Rc": "0"}),
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(c[1] for c in cases) + "\n")
            subprocess.run(["clang", "--target=powerpc-none-elf", "-mcpu=440", "-c",
                            str(path / "test.s"), "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            raw = (path / "test.bin").read_bytes()
        self.assertEqual(len(raw), 4 * len(cases))
        for index, (name, _, fields) in enumerate(cases):
            pattern = instructions[name]["encodings"][0]["opcode"]
            for field, value in fields.items():
                pattern = pattern.replace(field, value)
            pattern = pattern.replace(" ", "")
            bits = f"{int.from_bytes(raw[index * 4:index * 4 + 4], 'big'):032b}"
            self.assertEqual(len(pattern), 32, name)
            for expected, observed in zip(pattern, bits):
                if expected in "01":
                    self.assertEqual(expected, observed, name)

    def test_integer_arithmetic_and_logical_opcode_fields(self):
        data = json.loads((ROOT / "bin/isa/data/ppc.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        cases = []
        for name in ("ADDC", "ADDE", "ADDME", "ADDZE", "SUBF", "SUBFC", "SUBFE",
                     "SUBFZE", "SUBFME", "NEG", "MULHW", "MULHWU", "DIVW", "DIVWU"):
            no_rb = name in ("ADDME", "ADDZE", "SUBFZE", "SUBFME", "NEG")
            asm = f"{name.lower()} 3,4" + ("" if no_rb else ",5")
            cases.append((name, asm, {"rT": "00011", "rA": "00100", "rB": "00101",
                                      "OE": "0", "Rc": "0"}))
        for name, asm in (("ADDIC", "addic 3,4,8"), ("ADDIS", "addis 3,4,8"),
                          ("SUBFIC", "subfic 3,4,8"), ("MULLI", "mulli 3,4,8")):
            cases.append((name, asm, {"rT": "00011", "rA": "00100", "s16": f"{8:016b}"}))
        for name in ("AND", "ANDC", "OR", "ORC", "XOR", "NOR", "NAND", "EQV"):
            cases.append((name, f"{name.lower()} 4,3,5", {"rS": "00011", "rA": "00100",
                                                            "rB": "00101", "Rc": "0"}))
        for name in ("ORI", "ORIS", "XORI", "XORIS", "ANDI.", "ANDIS."):
            cases.append((name, f"{name.lower()} 4,3,8", {"rS": "00011", "rA": "00100",
                                                            "u16": f"{8:016b}"}))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(c[1] for c in cases) + "\n")
            subprocess.run(["clang", "--target=powerpc-none-elf", "-mcpu=440", "-c",
                            str(path / "test.s"), "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            raw = (path / "test.bin").read_bytes()
        self.assertEqual(len(raw), 4 * len(cases))
        for index, (name, _, fields) in enumerate(cases):
            pattern = instructions[name]["encodings"][0]["opcode"]
            for field, value in fields.items():
                pattern = pattern.replace(field, value)
            pattern = pattern.replace(" ", "")
            bits = f"{int.from_bytes(raw[index * 4:index * 4 + 4], 'big'):032b}"
            self.assertEqual(len(pattern), 32, name)
            for expected, observed in zip(pattern, bits):
                if expected in "01":
                    self.assertEqual(expected, observed, name)

    def test_load_store_update_and_indexed_opcode_fields(self):
        data = json.loads((ROOT / "bin/isa/data/ppc.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        cases = []
        for name, asm in (("LBZU", "lbzu 3,8(4)"), ("LHZU", "lhzu 3,8(4)"),
                          ("LHAU", "lhau 3,8(4)"), ("LWZU", "lwzu 3,8(4)"),
                          ("STBU", "stbu 3,8(4)"), ("STHU", "sthu 3,8(4)"),
                          ("STWU", "stwu 3,8(4)")):
            cases.append((name, asm, {"rT": "00011", "rS": "00011", "rA": "00100",
                                      "D": f"{8:016b}"}))
        indexed = (("LBZX", "lbzx"), ("LBZUX", "lbzux"), ("LHZX", "lhzx"),
                   ("LHZUX", "lhzux"), ("LHAX", "lhax"), ("LHAUX", "lhaux"),
                   ("LWZX", "lwzx"), ("LWZUX", "lwzux"), ("LHBRX", "lhbrx"),
                   ("LWBRX", "lwbrx"), ("LWARX", "lwarx"), ("STWX", "stwx"),
                   ("STBX", "stbx"), ("STBUX", "stbux"), ("STHX", "sthx"),
                   ("STHUX", "sthux"), ("STWUX", "stwux"), ("STHBRX", "sthbrx"),
                   ("STWBRX", "stwbrx"), ("STWCX.", "stwcx."))
        for name, mnemonic in indexed:
            cases.append((name, f"{mnemonic} 3,4,5", {"rT": "00011", "rS": "00011",
                                                         "rA": "00100", "rB": "00101"}))
        for name, asm, field in (("LSWI", "lswi 3,4,4", "NB"),
                                 ("STSWI", "stswi 3,4,4", "NB")):
            cases.append((name, asm, {"rT": "00011", "rS": "00011", "rA": "00100",
                                      field: "00100"}))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(c[1] for c in cases) + "\n")
            subprocess.run(["clang", "--target=powerpc-none-elf", "-mcpu=440", "-c",
                            str(path / "test.s"), "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            raw = (path / "test.bin").read_bytes()
        self.assertEqual(len(raw), 4 * len(cases))
        for index, (name, _, fields) in enumerate(cases):
            pattern = instructions[name]["encodings"][0]["opcode"]
            for field, value in fields.items():
                pattern = pattern.replace(field, value)
            pattern = pattern.replace(" ", "")
            bits = f"{int.from_bytes(raw[index * 4:index * 4 + 4], 'big'):032b}"
            self.assertEqual(len(pattern), 32, name)
            for expected, observed in zip(pattern, bits):
                if expected in "01":
                    self.assertEqual(expected, observed, name)

    def test_cache_invalidate_opcodes(self):
        data = json.loads((ROOT / "bin/isa/data/ppc.json").read_text())
        entries = {item["mnemonic"]: item for item in data["instructions"]}
        cases = (("DCCCI", "dccci 4,5"), ("ICCCI", "iccci 4,5"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(x[1] for x in cases) + "\n")
            subprocess.run(["clang", "--target=powerpc-none-elf", "-mcpu=440", "-c",
                            str(path / "test.s"), "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            raw = (path / "test.bin").read_bytes()
        self.assertEqual(len(raw), 8)
        for index, (name, _) in enumerate(cases):
            pattern = entries[name]["encodings"][0]["opcode"].replace(" ", "")
            pattern = pattern.replace("rA", "x" * 5).replace("rB", "x" * 5)
            bits = f"{int.from_bytes(raw[index * 4:index * 4 + 4], 'big'):032b}"
            self.assertEqual(len(pattern), 32, name)
            for expected, observed in zip(pattern, bits):
                if expected in "01":
                    self.assertEqual(expected, observed, name)

    def test_tlb_management_opcodes(self):
        data = json.loads((ROOT / "bin/isa/data/ppc.json").read_text())
        entries = {item["mnemonic"]: item for item in data["instructions"]}
        cases = (("TLBRE", "tlbre 3,4,1"), ("TLBWE", "tlbwe 3,4,2"),
                 ("TLBSX", "tlbsx. 3,4,5"), ("TLBSYNC", "tlbsync"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(x[1] for x in cases) + "\n")
            subprocess.run(["clang", "--target=powerpc-none-elf", "-mcpu=440", "-c",
                            str(path / "test.s"), "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            raw = (path / "test.bin").read_bytes()
        self.assertEqual(len(raw), 16)
        for index, (name, _) in enumerate(cases):
            pattern = entries[name]["encodings"][0]["opcode"].replace(" ", "")
            for field in ("rT", "rS", "rA", "rB", "WS"):
                pattern = pattern.replace(field, "x" * 5)
            pattern = pattern.replace("Rc", "x")
            bits = f"{int.from_bytes(raw[index * 4:index * 4 + 4], 'big'):032b}"
            self.assertEqual(len(pattern), 32, name)
            for expected, observed in zip(pattern, bits):
                if expected in "01":
                    self.assertEqual(expected, observed, name)
        self.assertEqual(raw, bytes.fromhex("7c640f64 7c6407a4 7c642f25 7c00046c"))

    def test_dcr_and_external_interrupt_control(self):
        data = json.loads((ROOT / "bin/isa/data/ppc.json").read_text())
        entries = {item["mnemonic"]: item for item in data["instructions"]}
        cases = (("MFDCR", "mfdcr 3,42"), ("MTDCR", "mtdcr 42,3"),
                 ("WRTEE", "wrtee 3"), ("WRTEEI", "wrteei 1"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(x[1] for x in cases) + "\n")
            subprocess.run(["clang", "--target=powerpc-none-elf", "-mcpu=440", "-c",
                            str(path / "test.s"), "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            raw = (path / "test.bin").read_bytes()
        self.assertEqual(len(raw), 16)
        for index, (name, _) in enumerate(cases):
            pattern = entries[name]["encodings"][0]["opcode"].replace(" ", "")
            pattern = pattern.replace("DCRF", "x" * 10).replace("rT", "x" * 5)
            pattern = pattern.replace("rS", "x" * 5).replace("E", "x")
            bits = f"{int.from_bytes(raw[index * 4:index * 4 + 4], 'big'):032b}"
            self.assertEqual(len(pattern), 32, name)
            for expected, observed in zip(pattern, bits):
                if expected in "01":
                    self.assertEqual(expected, observed, name)

    def test_barrier_and_interrupt_return_opcodes(self):
        data = json.loads((ROOT / "bin/isa/data/ppc.json").read_text())
        entries = {item["mnemonic"]: item for item in data["instructions"]}
        cases = (("MBAR", "mbar 0"), ("RFCI", "rfci"), ("RFMCI", "rfmci"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(c[1] for c in cases) + "\n")
            subprocess.run(["clang", "--target=powerpc-none-elf", "-mcpu=440", "-c",
                            str(path / "test.s"), "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            raw = (path / "test.bin").read_bytes()
        self.assertEqual(len(raw), 12)
        for index, (name, _) in enumerate(cases):
            pattern = entries[name]["encodings"][0]["opcode"].replace(" ", "")
            bits = f"{int.from_bytes(raw[index * 4:index * 4 + 4], 'big'):032b}"
            # MO is a five-bit field, represented as two characters in the dictionary.
            pattern = pattern.replace("MO", "xxxxx")
            self.assertEqual(len(pattern), 32, name)
            for expected, observed in zip(pattern, bits):
                if expected in "01":
                    self.assertEqual(expected, observed, name)

    def test_halfword_multiply_opcode_fields(self):
        # IBM PPC440x5 manual and GNU binutils ppc-opc.c list these XO fields.
        expected = {
            "MACCHW": 172, "MACCHWS": 236, "MACCHWSU": 204, "MACCHWU": 140,
            "NMACCHW": 174, "NMACCHWS": 238, "MULCHW": 168, "MULCHWU": 136,
            "MACHHW": 44, "MACHHWS": 108, "MACHHWSU": 76, "MACHHWU": 12,
            "NMACHHW": 46, "NMACHHWS": 110, "MULHHW": 40, "MULHHWU": 8,
            "MACLHW": 428, "MACLHWS": 492, "MACLHWSU": 460, "MACLHWU": 396,
            "NMACLHW": 430, "NMACLHWS": 494, "MULLHW": 424, "MULLHWU": 392,
        }
        data = json.loads((ROOT / "bin/isa/data/ppc.json").read_text())
        actual = {item["mnemonic"]: item for item in data["instructions"]
                  if item["category"] == "MAC(440)"}
        self.assertEqual(set(actual), set(expected))
        for name, extended_opcode in expected.items():
            entry = actual[name]["encodings"][0]
            parts = entry["opcode"].split()
            self.assertEqual(parts[:4], ["000100", "rT", "rA", "rB"], name)
            self.assertEqual(parts[-1], "Rc", name)
            self.assertEqual(int(parts[-2], 2), extended_opcode, name)
            self.assertEqual(parts[4:-2], [] if name.startswith("MUL") else ["OE"], name)
            self.assertEqual(len(parts[-2]), 10 if name.startswith("MUL") else 9, name)
            self.assertEqual(entry["bytes"], 4, name)


@unittest.skipUnless(shutil.which("clang") and shutil.which("llvm-objcopy"), "LLVM tools are not installed")
class PowerPCAliasTests(unittest.TestCase):
    def test_branch_link_and_absolute_variants(self):
        data = json.loads((ROOT / "bin/isa/data/ppc.json").read_text())
        aliases = {item["mnemonic"]: item for item in data["aliases"]}
        self.assertTrue({"ba", "bl", "bla", "bctrl"} <= aliases.keys())
        cases = (("ba", "ba 8", 1, 0), ("bl", "bl .+8", 0, 1),
                 ("bla", "bla 8", 1, 1))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(c[1] for c in cases) +
                                         "\nbctrl\n")
            subprocess.run(["clang", "--target=powerpc-none-elf", "-mcpu=440", "-c",
                            str(path / "test.s"), "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            raw = (path / "test.bin").read_bytes()
        self.assertEqual(len(raw), 16)
        b_primary = next(item for item in data["instructions"] if item["mnemonic"] == "B")
        for index, (name, _, aa, lk) in enumerate(cases):
            expected = (int(b_primary["encodings"][0]["opcode"]) << 26) | 8
            expected |= aa << 1 | lk
            self.assertEqual(raw[index * 4:index * 4 + 4], expected.to_bytes(4, "big"), name)
        pattern = next(item for item in data["instructions"]
                       if item["mnemonic"] == "BCCTR")["encodings"][0]["opcode"]
        for field, value in (("BO", "10100"), ("BI", "00000"), ("LK", "1")):
            pattern = pattern.replace(field, value)
        expected = int(pattern.replace(" ", ""), 2).to_bytes(4, "big")
        self.assertEqual(raw[12:16], expected, "bctrl must set BCCTR.LK")

    def test_listed_primary_and_extended_opcodes(self):
        data = json.loads((ROOT / "bin/isa/data/ppc.json").read_text())
        instructions = {item["mnemonic"]: item for item in data["instructions"]}
        cases = (("LBZ", "lbz 3,16(4)", None), ("LHZ", "lhz 3,16(4)", None),
                 ("LHA", "lha 3,16(4)", None), ("LWZ", "lwz 3,16(4)", None),
                 ("LMW", "lmw 3,16(2)", None), ("STMW", "stmw 3,16(4)", None),
                 ("STB", "stb 3,16(4)", None), ("STH", "sth 3,16(4)", None),
                 ("STW", "stw 3,16(4)", None), ("ADD", "add 3,4,5", 266),
                 ("ADDI", "addi 3,4,16", None), ("MULLW", "mullw 3,4,5", 235),
                 ("CMP", "cmp 0,0,4,5", 0), ("RLWINM", "rlwinm 3,4,5,6,7", None),
                 ("B", "b .", None))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text(".text\n" + "\n".join(x[1] for x in cases) + "\n")
            subprocess.run(["clang", "--target=powerpc-none-elf", "-mcpu=440", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            actual = (path / "test.bin").read_bytes()
            self.assertEqual(len(actual), 4 * len(cases))
            for index, (name, _, extended) in enumerate(cases):
                word = int.from_bytes(actual[index * 4:index * 4 + 4], "big")
                opcode = instructions[name]["encodings"][0]["opcode"].split()[0].split("（")[0]
                self.assertEqual(word >> 26, int(opcode, 0), name)
                if extended is not None:
                    self.assertEqual((word >> 1) & 0x1ff, extended, name)

    def test_aliases_match_their_base_encodings(self):
        data = json.loads((ROOT / "bin/isa/data/ppc.json").read_text())
        values = {"rT": 3, "rA": 4, "rB": 6, "rS": 5, "r0": 0,
                  "crT": 2, "crbT": 7, "crbA": 8, "s16": 17, "u16": 17,
                  "nBits": 5, "start": 3, "shift": 2, "end": 8, "d": 17}

        def expand(text):
            text = text.replace("[crT,]", "crT,").replace("[crT]", "crT").replace("addr", ".+16")
            for name in sorted(values, key=len, reverse=True):
                text = re.sub(r"\b" + name + r"\b", str(values[name]), text)
            text = re.sub(r"\((\d+)\*4\)\+(\d+)", lambda m: str(int(m[1]) * 4 + int(m[2])), text)
            text = re.sub(r"\((\d+)\+(\d+)\)-1", lambda m: str(int(m[1]) + int(m[2]) - 1), text)
            return re.sub(r"(?<![\w.])(\d+)\s*([-+])\s*(\d+)",
                          lambda m: str(int(m[1]) + int(m[3]) * (1 if m[2] == "+" else -1)), text)

        source = [".text"]
        for alias in data["aliases"]:
            if alias["mnemonic"] in {"ba", "bl", "bla", "bctrl"}:
                continue  # AA/LK variants are checked against their explicit format fields above.
            source.append(expand(alias["mnemonic"] + " " + alias.get("operands", "")))
            source.append(expand(alias["equivalent"]))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text("\n".join(source) + "\n")
            subprocess.run(["clang", "--target=powerpc-none-elf", "-mcpu=440", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            result = (path / "test.bin").read_bytes()
            self.assertEqual(len(result), 8 * (len(data["aliases"]) - 4))
            for index, alias in enumerate(data["aliases"]):
                pair = result[8 * index:8 * index + 8]
                self.assertEqual(pair[:4], pair[4:], alias["mnemonic"])

    def test_rotate_alias_boundary_values(self):
        data = json.loads((ROOT / "bin/isa/data/ppc.json").read_text())
        aliases = {alias["mnemonic"]: alias for alias in data["aliases"]}
        cases = [("rotrwi", 0, 0), ("srwi", 0, 0), ("inslwi", 5, 0),
                 ("extrwi", 5, 27), ("insrwi", 5, 27)]
        source = [".text"]
        for name, count, start in cases:
            alias = aliases[name]
            values = {"rA": 4, "rS": 5, "nBits": count, "start": start, "end": start + count}
            for text in (name + " " + alias["operands"], alias["equivalent"]):
                for key in sorted(values, key=len, reverse=True):
                    text = re.sub(r"\b" + key + r"\b", str(values[key]), text)
                source.append(text)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "test.s").write_text("\n".join(source) + "\n")
            subprocess.run(["clang", "--target=powerpc-none-elf", "-mcpu=440", "-c", str(path / "test.s"),
                            "-o", str(path / "test.o")], check=True)
            subprocess.run(["llvm-objcopy", "-O", "binary", "--only-section=.text",
                            str(path / "test.o"), str(path / "test.bin")], check=True)
            result = (path / "test.bin").read_bytes()
            self.assertEqual(len(result), 8 * len(cases))
            for index, (name, _, _) in enumerate(cases):
                pair = result[8 * index:8 * index + 8]
                self.assertEqual(pair[:4], pair[4:], name)


if __name__ == "__main__":
    unittest.main()
