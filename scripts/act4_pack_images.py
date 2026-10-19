#!/usr/bin/env python3
"""Pack GNU objcopy Verilog-format byte images into this RTL's word memories."""

from __future__ import annotations

import argparse
from pathlib import Path


def read_verilog_bytes(path: Path) -> dict[int, int]:
    """Read objcopy's @byte-address + byte-token Verilog hex format."""
    address = 0
    memory: dict[int, int] = {}
    for line_number, raw_line in enumerate(path.read_text(encoding="ascii").splitlines(), 1):
        line = raw_line.strip()
        if not line:
            continue
        for token in line.split():
            if token.startswith("@"):
                try:
                    address = int(token[1:], 16)
                except ValueError as exc:
                    raise ValueError(f"{path}:{line_number}: invalid address {token!r}") from exc
                continue
            try:
                value = int(token, 16)
            except ValueError as exc:
                raise ValueError(f"{path}:{line_number}: invalid byte {token!r}") from exc
            if not 0 <= value <= 0xFF:
                raise ValueError(f"{path}:{line_number}: token is not one byte: {token!r}")
            if address in memory:
                raise ValueError(f"{path}:{line_number}: duplicate byte address 0x{address:x}")
            memory[address] = value
            address += 1
    return memory


def pack_words(memory: dict[int, int], *, capacity: int, fill: int, label: str) -> list[int]:
    if any(address < 0 for address in memory):
        raise ValueError(f"{label}: negative byte address")
    highest_word = max((address // 4 for address in memory), default=-1)
    if highest_word >= capacity:
        raise ValueError(
            f"{label}: image needs {highest_word + 1} words, configured memory has {capacity}"
        )
    words = [fill] * (highest_word + 1)
    for address, byte in memory.items():
        index = address // 4
        shift = (address % 4) * 8
        words[index] = (words[index] & ~(0xFF << shift)) | (byte << shift)
    return words


def write_words(path: Path, words: list[int]) -> None:
    path.write_text("".join(f"{word:08x}\n" for word in words), encoding="ascii")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--code-hex", type=Path, required=True)
    parser.add_argument("--data-hex", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--instruction-words", type=int, default=16384)
    parser.add_argument("--data-words", type=int, default=16384)
    args = parser.parse_args()
    if args.instruction_words < 1 or args.data_words < 1:
        parser.error("memory sizes must be positive")

    code = read_verilog_bytes(args.code_hex)
    data = read_verilog_bytes(args.data_hex)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    write_words(
        args.out_dir / "instructions.mem",
        pack_words(code, capacity=args.instruction_words, fill=0x00000013, label="instruction image"),
    )
    write_words(
        args.out_dir / "data_mem.mem",
        pack_words(data, capacity=args.data_words, fill=0, label="data image"),
    )


if __name__ == "__main__":
    main()
