"""Compile a freestanding RV32IM C program into Vivado memory images."""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parent.parent
TOOLCHAIN_PREFIXES = (
    "riscv-none-elf-",
    "riscv32-unknown-elf-",
    "riscv64-unknown-elf-",
)
ROM_BYTES = 256 * 4
RAM_WORDS = 512


def find_toolchain(toolchain_bin=None):
    for prefix in TOOLCHAIN_PREFIXES:
        if toolchain_bin:
            bin_path = Path(toolchain_bin)
            gcc = next((str(candidate) for candidate in (
                bin_path / (prefix + "gcc.exe"), bin_path / (prefix + "gcc")
            ) if candidate.is_file()), None)
            objcopy = next((str(candidate) for candidate in (
                bin_path / (prefix + "objcopy.exe"), bin_path / (prefix + "objcopy")
            ) if candidate.is_file()), None)
            if gcc and objcopy:
                return gcc, objcopy
        gcc = shutil.which(prefix + "gcc")
        objcopy = shutil.which(prefix + "objcopy")
        if gcc and objcopy:
            return gcc, objcopy
    names = ", ".join(prefix + "gcc" for prefix in TOOLCHAIN_PREFIXES)
    raise SystemExit(
        "RISC-V GCC and objcopy were not found on PATH. Install the xPack "
        "Windows toolchain and add its bin directory to PATH. Accepted GCC "
        f"names: {names}."
    )


def bytes_to_words(blob, capacity, section_name, fill_word="00000000"):
    if len(blob) > capacity * 4:
        raise SystemExit(
            f"{section_name} uses {len(blob)} bytes; capacity is {capacity * 4} bytes."
        )
    if len(blob) % 4:
        blob += b"\x00" * (4 - len(blob) % 4)
    words = [
        f"{int.from_bytes(blob[i:i + 4], 'little'):08x}"
        for i in range(0, len(blob), 4)
    ]
    # Emit the complete inferred-memory depth. Short $readmemh files leave the
    # remaining synthesized words unspecified; instruction ROM defaults to NOP.
    words.extend([fill_word] * (capacity - len(words)))
    return words


def compile_c(source, output_dir, toolchain_bin=None):
    gcc, objcopy = find_toolchain(toolchain_bin)
    source = source.resolve()
    if not source.is_file():
        raise SystemExit(f"C source file not found: {source}")

    output_dir.mkdir(parents=True, exist_ok=True)
    elf = output_dir / "program.elf"
    text_bin = output_dir / "text.bin"
    data_bin = output_dir / "data.bin"
    map_file = output_dir / "program.map"

    command = [
        gcc,
        "-march=rv32im", "-mabi=ilp32", "-mno-relax", "-msmall-data-limit=0",
        "-O1", "-ffreestanding", "-fno-builtin", "-fno-common", "-fno-pic",
        "-fno-pie", "-fno-asynchronous-unwind-tables", "-fno-unwind-tables",
        "-nostdlib", "-Wl,-Map=" + str(map_file),
        "-T", str(Path(__file__).with_name("link.ld")),
        str(Path(__file__).with_name("crt0.s")), str(source), "-o", str(elf),
    ]
    subprocess.run(command, check=True, cwd=PROJECT_DIR)

    subprocess.run(
        [objcopy, "-O", "binary", "-j", ".text", str(elf), str(text_bin)],
        check=True,
    )
    subprocess.run(
        [objcopy, "-O", "binary", "-j", ".data", str(elf), str(data_bin)],
        check=True,
    )

    instructions = bytes_to_words(
        text_bin.read_bytes(), ROM_BYTES // 4, "instruction ROM", fill_word="00000013"
    )
    data = bytes_to_words(data_bin.read_bytes(), RAM_WORDS, "data RAM")
    (output_dir / "instructions.mem").write_text("\n".join(instructions) + "\n", encoding="ascii")
    (output_dir / "data_mem.mem").write_text("\n".join(data) + "\n", encoding="ascii")
    shutil.copy2(
        PROJECT_DIR / "vendor" / "awais-rv32i" / "Source Code" / "Mem Files" / "reg_init.mem",
        output_dir / "reg_init.mem",
    )
    print(f"Built {elf}")
    print(f"Instruction ROM: {len(text_bin.read_bytes())} bytes / {ROM_BYTES} bytes")
    print(f"Data image: {len(data_bin.read_bytes())} initialized bytes; RAM image has {RAM_WORDS} words")
    print(f"Vivado memory images: {output_dir}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", nargs="?", type=Path, default=Path(__file__).with_name("main.c"))
    parser.add_argument(
        "--output-dir", type=Path,
        default=PROJECT_DIR / "build" / "c_program",
        help="folder for ELF, map, and Vivado memory images",
    )
    parser.add_argument("--toolchain-bin", type=Path, help="optional path to the toolchain bin folder")
    args = parser.parse_args()
    output_dir = args.output_dir if args.output_dir.is_absolute() else PROJECT_DIR / args.output_dir
    compile_c(args.source, output_dir.resolve(), args.toolchain_bin)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
