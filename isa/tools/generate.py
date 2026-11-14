#!/usr/bin/env python3
"""Generate the offline ISA reference (build/) from data/*.json.

Validates the JSON sources, then emits:
- build/index.tsv                arch, mnemonic, category, summary
- build/<arch>/<MNEMONIC>.txt    one instruction reference page (Japanese)

Usage: python3 tools/generate.py
"""
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
BUILD_DIR = ROOT / "build"

REQUIRED_FIELDS = ("mnemonic", "operands", "category", "summary", "flags")
FLAG_SYMBOLS = {"-", "1", "0", "‡", "U"}
ALLOWED_SRC = {"book", "note", "knowledge"}
ARCH_DISPLAY = {
    "6502": "6502",
    "z80": "Z80",
    "m68k": "68000",
    "x86_16": "8086",
    "i386": "80386",
    "x86_64": "x86-64",
    "riscv32": "RISC-V 32",
    "riscv64": "RISC-V 64",
    "arm64": "ARM64",
}
SEPARATOR = "─" * 14 + " 詳細 " + "─" * 14


class ValidationError(Exception):
    pass


def load_data_files():
    files = sorted(DATA_DIR.glob("*.json"))
    if not files:
        raise ValidationError("data/*.json が見つかりません")
    docs = []
    for path in files:
        try:
            doc = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise ValidationError(f"{path.name}: JSON パースエラー ({exc})")
        docs.append((path, doc))
    return docs


def validate(path, doc):
    name = path.name
    if doc.get("arch") != path.stem:
        raise ValidationError(f"{name}: arch ({doc.get('arch')!r}) がファイル名と一致しません")
    flag_names = doc.get("flagNames")
    if not isinstance(flag_names, list):
        raise ValidationError(f"{name}: flagNames が不正です（配列を指定。フラグなしアーキは []）")
    if len(set(flag_names)) != len(flag_names):
        raise ValidationError(f"{name}: flagNames に重複があります")
    for key in ("arch", "flagNames", "instructions"):
        if key not in doc:
            raise ValidationError(f"{name}: 必須キー {key} がありません")
    if not isinstance(doc["instructions"], list) or not doc["instructions"]:
        raise ValidationError(f"{name}: instructions が空です")

    seen = set()
    for i, inst in enumerate(doc["instructions"], start=1):
        where = f"{name}: instructions[{i}]"
        for key in REQUIRED_FIELDS:
            if key not in inst:
                raise ValidationError(f"{where}: 必須フィールド {key} がありません")
        mnem = inst["mnemonic"]
        if not isinstance(mnem, str) or not mnem or not re.fullmatch(r"[A-Z]+(\.cond|cc)?", mnem):
            raise ValidationError(f"{where}: mnemonic は大文字のみ（条件接尾 cc/.cond は可）({mnem!r})")
        if mnem in seen:
            raise ValidationError(f"{where}: mnemonic 重複 ({mnem})")
        seen.add(mnem)
        for key in ("mnemonic", "operands", "category", "summary"):
            value = inst[key]
            if not isinstance(value, str) or (key != "operands" and not value):
                raise ValidationError(f"{where}: {key} は非空の文字列で指定してください")
            if "\t" in value or "\n" in value:
                raise ValidationError(f"{where}: {key} にタブ/改行は使えません")
        flags = inst["flags"]
        if not isinstance(flags, list) or len(flags) != len(flag_names):
            raise ValidationError(f"{where}: flags の長さ ({len(flags)}) が flagNames ({len(flag_names)}) と一致しません")
        for sym in flags:
            if sym not in FLAG_SYMBOLS:
                raise ValidationError(f"{where}: 不正なフラグ記号 {sym!r}（許可: {sorted(FLAG_SYMBOLS)}）")
        if not isinstance(inst.get("addressing", []), list) or not inst.get("addressing"):
            raise ValidationError(f"{where}: addressing は非空の配列で指定してください")
        for addr in inst["addressing"]:
            if "\t" in str(addr) or "\n" in str(addr):
                raise ValidationError(f"{where}: addressing にタブ/改行は使えません")
        cycles = inst.get("cycles", [])
        if not cycles:
            raise ValidationError(f"{where}: cycles が空です")
        for entry in cycles:
            if not isinstance(entry, dict) or "cond" not in entry or "cycles" not in entry:
                raise ValidationError(f"{where}: cycles の各要素は cond と cycles を持つ必要があります")
        encodings = inst.get("encodings", [])
        for entry in encodings:
            if not isinstance(entry, dict) or "syntax" not in entry or "opcode" not in entry:
                raise ValidationError(f"{where}: encodings の各要素は syntax と opcode を持つ必要があります")
        src = inst.get("src", "")
        if src and src not in ALLOWED_SRC:
            raise ValidationError(f"{where}: src は {sorted(ALLOWED_SRC)} のいずれか ({src!r})")
        notes = inst.get("notes", "")
        if not isinstance(notes, str):
            raise ValidationError(f"{where}: notes は文字列で指定してください")
    return flag_names


def format_flags(flag_names, flags):
    return "  ".join(f"{n}{v}" for n, v in zip(flag_names, flags))


def render(inst, arch, flag_names):
    operands = inst["operands"]
    head = inst["mnemonic"] + (f" {operands}" if operands else "")
    lines = [
        f"{head} — {ARCH_DISPLAY[arch]}（{inst['category']}）",
        "",
        inst["summary"],
        "",
        f"アドレッシング: {'、'.join(inst['addressing'])}",
    ]
    if flag_names:
        lines.append(f"フラグ: {format_flags(flag_names, inst['flags'])}")

    detail = [SEPARATOR, ""]
    if inst["cycles"]:
        detail += ["消費クロック:"]
        for entry in inst["cycles"]:
            detail.append(f"  {entry['cond']}: {entry['cycles']}")

    encodings = inst.get("encodings", [])
    if encodings:
        detail += ["", "オペコード:"]
        for entry in encodings:
            bytes_part = f"  ({entry['bytes']} バイト)" if "bytes" in entry else ""
            detail.append(f"  {entry['syntax']}: {entry['opcode']}{bytes_part}")

    notes = inst.get("notes", "")
    src = inst.get("src", "")
    if notes:
        detail += ["", "備考:"] + [f"  {line}" for line in notes.splitlines()]
    if src:
        detail += ["", f"（根拠: {src}）"]

    return "\n".join(lines + [""] + detail) + "\n"


def main():
    errors = []
    try:
        docs = load_data_files()
    except ValidationError as exc:
        print(f"エラー: {exc}", file=sys.stderr)
        return 1

    per_arch = {}
    for path, doc in docs:
        try:
            flag_names = validate(path, doc)
            per_arch[doc["arch"]] = (doc, flag_names)
        except ValidationError as exc:
            errors.append(str(exc))

    if errors:
        for message in errors:
            print(f"エラー: {message}", file=sys.stderr)
        return 1

    if BUILD_DIR.exists():
        shutil.rmtree(BUILD_DIR)
    BUILD_DIR.mkdir(parents=True)

    total = 0
    index_lines = []
    for arch, (doc, flag_names) in per_arch.items():
        arch_dir = BUILD_DIR / arch
        arch_dir.mkdir()
        for inst in doc["instructions"]:
            page = render(inst, arch, flag_names)
            (arch_dir / f"{inst['mnemonic'].upper()}.txt").write_text(page, encoding="utf-8")
            index_lines.append(f"{arch}\t{inst['mnemonic']}\t{inst['category']}\t{inst['summary']}")
            total += 1

    index_lines.sort()
    (BUILD_DIR / "index.tsv").write_text("\n".join(index_lines) + "\n", encoding="utf-8")
    print(f"生成完了: {total} 命令 / {len(per_arch)} アーキ → {BUILD_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
