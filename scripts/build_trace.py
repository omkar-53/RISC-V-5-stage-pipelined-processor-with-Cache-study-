import json
import sys

def disassemble(hex_str):
    if not hex_str.strip(): return {"mnemonic":"NOP", "type":"Unknown"}
    val = int(hex_str, 16)
    opcode = val & 0x7F
    rd = (val >> 7) & 0x1F
    funct3 = (val >> 12) & 0x7
    rs1 = (val >> 15) & 0x1F
    rs2 = (val >> 20) & 0x1F
    funct7 = (val >> 25) & 0x7F
    
    imm_i = (val >> 20)
    if imm_i & 0x800: imm_i -= 4096
    
    imm_s = ((val >> 25) << 5) | ((val >> 7) & 0x1F)
    if imm_s & 0x800: imm_s -= 4096
    
    imm_b = ((val >> 31) << 12) | (((val >> 7) & 1) << 11) | (((val >> 25) & 0x3F) << 5) | (((val >> 8) & 0xF) << 1)
    if imm_b & 0x1000: imm_b -= 8192
    
    imm_u = (val & 0xFFFFF000)
    if imm_u & 0x80000000: imm_u -= 0x100000000
    
    imm_j = ((val >> 31) << 20) | (((val >> 12) & 0xFF) << 12) | (((val >> 20) & 1) << 11) | (((val >> 21) & 0x3FF) << 1)
    if imm_j & 0x100000: imm_j -= 0x200000
    
    ctrl = {"RegWrite":0, "ALUSrc":0, "MemRead":0, "MemWrite":0, "MemToReg":0, "Branch":0, "Jump":0, "ALUOp":"?", "type":"?"}
    mnem = "unknown"
    
    if opcode == 0x33: # R-type
        ctrl["RegWrite"]=1; ctrl["ALUOp"]="R"; ctrl["type"]="R-type (reg-reg)"
        if funct7 == 1:
            if funct3==0: mnem = f"mul x{rd}, x{rs1}, x{rs2}"
            elif funct3==1: mnem = f"mulh x{rd}, x{rs1}, x{rs2}"
            elif funct3==2: mnem = f"mulhsu x{rd}, x{rs1}, x{rs2}"
            elif funct3==3: mnem = f"mulhu x{rd}, x{rs1}, x{rs2}"
            elif funct3==4: mnem = f"div x{rd}, x{rs1}, x{rs2}"
            elif funct3==5: mnem = f"divu x{rd}, x{rs1}, x{rs2}"
            elif funct3==6: mnem = f"rem x{rd}, x{rs1}, x{rs2}"
            elif funct3==7: mnem = f"remu x{rd}, x{rs1}, x{rs2}"
        else:
            if funct3==0 and funct7==0: mnem = f"add x{rd}, x{rs1}, x{rs2}"
            elif funct3==0 and funct7==32: mnem = f"sub x{rd}, x{rs1}, x{rs2}"
            elif funct3==1: mnem = f"sll x{rd}, x{rs1}, x{rs2}"
            elif funct3==2: mnem = f"slt x{rd}, x{rs1}, x{rs2}"
            elif funct3==3: mnem = f"sltu x{rd}, x{rs1}, x{rs2}"
            elif funct3==4: mnem = f"xor x{rd}, x{rs1}, x{rs2}"
            elif funct3==5 and funct7==0: mnem = f"srl x{rd}, x{rs1}, x{rs2}"
            elif funct3==5 and funct7==32: mnem = f"sra x{rd}, x{rs1}, x{rs2}"
            elif funct3==6: mnem = f"or x{rd}, x{rs1}, x{rs2}"
            elif funct3==7: mnem = f"and x{rd}, x{rs1}, x{rs2}"
    elif opcode == 0x13: # I-type ALU
        ctrl["RegWrite"]=1; ctrl["ALUSrc"]=1; ctrl["ALUOp"]="I"; ctrl["type"]="I-type (imm ALU)"
        if funct3==0: mnem = f"addi x{rd}, x{rs1}, {imm_i}"
        elif funct3==1: mnem = f"slli x{rd}, x{rs1}, {rs2}"
        elif funct3==2: mnem = f"slti x{rd}, x{rs1}, {imm_i}"
        elif funct3==3: mnem = f"sltiu x{rd}, x{rs1}, {imm_i}"
        elif funct3==4: mnem = f"xori x{rd}, x{rs1}, {imm_i}"
        elif funct3==5 and funct7==0: mnem = f"srli x{rd}, x{rs1}, {rs2}"
        elif funct3==5 and funct7==32: mnem = f"srai x{rd}, x{rs1}, {rs2}"
        elif funct3==6: mnem = f"ori x{rd}, x{rs1}, {imm_i}"
        elif funct3==7: mnem = f"andi x{rd}, x{rs1}, {imm_i}"
    elif opcode == 0x3: # Load
        ctrl["RegWrite"]=1; ctrl["ALUSrc"]=1; ctrl["MemRead"]=1; ctrl["MemToReg"]=1; ctrl["ALUOp"]="ADD"; ctrl["type"]="Load"
        if funct3==0: mnem = f"lb x{rd}, {imm_i}(x{rs1})"
        elif funct3==1: mnem = f"lh x{rd}, {imm_i}(x{rs1})"
        elif funct3==2: mnem = f"lw x{rd}, {imm_i}(x{rs1})"
        elif funct3==4: mnem = f"lbu x{rd}, {imm_i}(x{rs1})"
        elif funct3==5: mnem = f"lhu x{rd}, {imm_i}(x{rs1})"
    elif opcode == 0x23: # Store
        ctrl["ALUSrc"]=1; ctrl["MemWrite"]=1; ctrl["ALUOp"]="ADD"; ctrl["type"]="Store"
        if funct3==0: mnem = f"sb x{rs2}, {imm_s}(x{rs1})"
        elif funct3==1: mnem = f"sh x{rs2}, {imm_s}(x{rs1})"
        elif funct3==2: mnem = f"sw x{rs2}, {imm_s}(x{rs1})"
    elif opcode == 0x63: # Branch
        ctrl["Branch"]=1; ctrl["ALUOp"]="SUB/CMP"; ctrl["type"]="Branch"
        sign = "+" if imm_b >= 0 else ""
        if funct3==0: mnem = f"beq x{rs1}, x{rs2}, {sign}{imm_b}"
        elif funct3==1: mnem = f"bne x{rs1}, x{rs2}, {sign}{imm_b}"
        elif funct3==4: mnem = f"blt x{rs1}, x{rs2}, {sign}{imm_b}"
        elif funct3==5: mnem = f"bge x{rs1}, x{rs2}, {sign}{imm_b}"
        elif funct3==6: mnem = f"bltu x{rs1}, x{rs2}, {sign}{imm_b}"
        elif funct3==7: mnem = f"bgeu x{rs1}, x{rs2}, {sign}{imm_b}"
    elif opcode == 0x6F: # JAL
        ctrl["RegWrite"]=1; ctrl["Jump"]=1; ctrl["ALUOp"]="ADD(PC)"; ctrl["type"]="JAL"
        sign = "+" if imm_j >= 0 else ""
        mnem = f"jal x{rd}, {sign}{imm_j}"
    elif opcode == 0x67: # JALR
        ctrl["RegWrite"]=1; ctrl["Jump"]=1; ctrl["ALUSrc"]=1; ctrl["ALUOp"]="ADD"; ctrl["type"]="JALR"
        mnem = f"jalr x{rd}, {imm_i}(x{rs1})"
    elif opcode == 0x37: # LUI
        ctrl["RegWrite"]=1; ctrl["ALUSrc"]=1; ctrl["ALUOp"]="LUI"; ctrl["type"]="LUI"
        mnem = f"lui x{rd}, 0x{imm_u>>12:X}"
    elif opcode == 0x17: # AUIPC
        ctrl["RegWrite"]=1; ctrl["ALUSrc"]=1; ctrl["ALUOp"]="ADD(PC)"; ctrl["type"]="AUIPC"
        mnem = f"auipc x{rd}, 0x{imm_u>>12:X}"
    
    return {
        "mnemonic": mnem,
        "opcode": opcode,
        "funct3": funct3,
        "funct7": funct7,
        "rd": rd,
        "rs1": rs1,
        "rs2": rs2,
        "control": ctrl
    }

def main():
    import argparse
    import os
    from pathlib import Path

    script_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--instruction-file", type=Path,
        default=script_dir.parent / "vendor" / "awais-rv32i" / "Source Code" / "Mem Files" / "instructions.mem",
    )
    args = parser.parse_args()
    mem_file = args.instruction_file.resolve()
    instructions = []
    addr = 0
    idx = 0
    
    addr_to_idx = {}
    
    if os.path.exists(mem_file):
        with open(mem_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line: continue
                dec = disassemble(line)
                dec["idx"] = idx
                dec["addr"] = addr
                dec["hex"] = line
                instructions.append(dec)
                addr_to_idx[addr] = idx
                addr += 4
                idx += 1
                
    trace_file = script_dir.parent / "build" / "pipeline_proof" / "raw_trace.json"
    cycles = []
    reg_history = []
    
    if os.path.exists(trace_file):
        with open(trace_file, 'r') as f:
            raw_data = json.loads(f.read())
            
            for item in raw_data:
                if not item: continue
                cycle_num = item["cycle"]
                reg_history.append(item["regs"])
                
                def get_idx(pc, inst, valid_sig=1):
                    if inst in [0, 0x13] or valid_sig == 0: return None
                    return addr_to_idx.get(pc, None)
                
                stages = {
                    "IF": get_idx(item["pc"], item["instruction"], 1) if not item["stall"] else None,
                    "ID": get_idx(item["pc_ID"], item["inst_ID"], 1) if item["pc_ID"] != 0 or item["inst_ID"] != 0 else None,
                    "EX": get_idx(item["pc_EX"], item["inst_EX"], 1) if item["pc_EX"] != 0 or item["inst_EX"] != 0 else None,
                    "MEM": get_idx(item["pc_MEM"], item["inst_MEM"], 1) if item["pc_MEM"] != 0 or item["inst_MEM"] != 0 else None,
                    "WB": get_idx(item["pc_WB"], item["inst_WB"], 1) if item["pc_WB"] != 0 or item["inst_WB"] != 0 else None
                }
                
                cycles.append({
                    "cycle": cycle_num,
                    "stages": stages,
                    "forwardA": item["forwardA"],
                    "forwardB": item["forwardB"],
                    "flush": item["IF_flush"],
                    "branch_taken": item["take_branch_EX"],
                    "stall": bool(item["stall"]),
                    "reg_write_en_WB": item["reg_write_en_WB"],
                    "wb_rd": item["rd_WB"],
                    "wb_data": item["write_data"],
                    "mem_write_MEM": item["mem_write_MEM"],
                    "redirect": item["redirect_EX"],
                    "cache_hit": item.get("cache_hit", 0),
                    "cache_miss": item.get("cache_miss", 0),
                    "cache_stall": item.get("cache_stall", 0),
                    "raw": item
                })
                
    # Trim trailing empty cycles (where no instruction is in any stage)
    while cycles:
        stages = cycles[-1]["stages"]
        if all(v is None for v in stages.values()):
            cycles.pop()
            reg_history.pop()
        else:
            # Keep one extra cycle after the pipeline is completely empty, 
            # or just break and use exact length. Breaking here is exact length.
            break

    final_data = {
        "instructions": instructions,
        "cycles": cycles,
        "reg_history": reg_history
    }
    
    out_file = script_dir.parent / "docs" / "trace_data.js"
    with open(out_file, 'w') as f:
        f.write("const DATA = " + json.dumps(final_data, separators=(',', ':')) + ";\n")
    print(f"Generated {out_file} with {len(cycles)} cycles.")

if __name__ == '__main__':
    main()
