#!/usr/bin/env bash
set -euo pipefail

elf_path=${1:?ACT4 ELF path is required}
if [[ ! -f "$elf_path" ]]; then
  printf 'ACT4 adapter: ELF not found: %s\n' "$elf_path" >&2
  exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_root=$(cd -- "$script_dir/.." && pwd)
elf_name=$(basename -- "$elf_path")
run_root="$project_root/build/act4_xsim_runs"
mkdir -p "$run_root"
run_dir=$(mktemp -d "$run_root/${elf_name%.*}.XXXXXX")

riscv64-unknown-elf-objcopy -O verilog \
  -j .text.init -j .text.rvtest -j .text.rvmodel -j .text \
  "$elf_path" "$run_dir/code.hex"
riscv64-unknown-elf-objcopy -O verilog \
  -j .rodata -j .data -j .sdata -j .bss -j .sbss \
  "$elf_path" "$run_dir/data.hex"
python3 "$script_dir/act4_pack_images.py" \
  --code-hex "$run_dir/code.hex" \
  --data-hex "$run_dir/data.hex" \
  --out-dir "$run_dir" \
  --instruction-words 65536 \
  --data-words 65536

powershell_path=$(wslpath -w "$script_dir/run_act4_elf.ps1")
run_dir_windows=$(wslpath -w "$run_dir")
powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$powershell_path" -BuildRoot "$run_dir_windows"
