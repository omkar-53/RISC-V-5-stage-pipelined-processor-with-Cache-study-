import re
import sys

ABI_REG_MAP = {
    'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
    't0': 5, 't1': 6, 't2': 7,
    's0': 8, 'fp': 8, 's1': 9,
    'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13, 'a4': 14, 'a5': 15, 'a6': 16, 'a7': 17,
    's2': 18, 's3': 19, 's4': 20, 's5': 21, 's6': 22, 's7': 23, 's8': 24, 's9': 25, 's10': 26, 's11': 27,
    't3': 28, 't4': 29, 't5': 30, 't6': 31
}

def parse_reg(reg_str):
    reg_str = reg_str.strip().replace(',', '').lower()
    if reg_str in ABI_REG_MAP:
        return ABI_REG_MAP[reg_str]
    if reg_str.startswith('x'):
        return int(reg_str[1:])
    return int(reg_str)

def assemble(code):
    lines = code.split('\n')
    instructions = []
    labels = {}
    
    # Pass 1: expand pseudo-ops and find labels
    addr = 0
    expanded_lines = []
    for line in lines:
        line = re.split(r'[#;]|//', line)[0].strip()
        if not line: continue
        if ':' in line:
            label, rest = line.split(':', 1)
            expanded_lines.append(('label', label.strip()))
            line = rest.strip()
        if not line: continue
        parts = re.split(r'[\s,]+', line.strip())
        mnem = parts[0].lower()
        if mnem == 'nop':
            expanded_lines.append(('inst', "addi x0, x0, 0"))
        elif mnem == 'j':
            expanded_lines.append(('inst', f"jal zero, {parts[1]}"))
        elif mnem == 'jr':
            expanded_lines.append(('inst', f"jalr zero, {parts[1]}, 0"))
        elif mnem == 'ret':
            expanded_lines.append(('inst', "jalr zero, ra, 0"))
        elif mnem == 'mv':
            expanded_lines.append(('inst', f"addi {parts[1]}, {parts[2]}, 0"))
        elif mnem == 'not':
            expanded_lines.append(('inst', f"xori {parts[1]}, {parts[2]}, -1"))
        elif mnem == 'neg':
            expanded_lines.append(('inst', f"sub {parts[1]}, zero, {parts[2]}"))
        elif mnem == 'li':
            rd = parts[1]
            imm = int(parts[2], 0)
            if -2048 <= imm <= 2047:
                expanded_lines.append(('inst', f"addi {rd}, zero, {imm}"))
            else:
                upper = ((imm + 0x800) >> 12) & 0xFFFFF
                lower = imm - (upper << 12)
                expanded_lines.append(('inst', f"lui {rd}, {upper}"))
                expanded_lines.append(('inst', f"addi {rd}, {rd}, {lower}"))
        elif mnem == 'beqz':
            expanded_lines.append(('inst', f"beq {parts[1]}, zero, {parts[2]}"))
        elif mnem == 'bnez':
            expanded_lines.append(('inst', f"bne {parts[1]}, zero, {parts[2]}"))
        elif mnem == 'bgez':
            expanded_lines.append(('inst', f"bge {parts[1]}, zero, {parts[2]}"))
        elif mnem == 'bltz':
            expanded_lines.append(('inst', f"blt {parts[1]}, zero, {parts[2]}"))
        elif mnem == 'bgt':
            expanded_lines.append(('inst', f"blt {parts[2]}, {parts[1]}, {parts[3]}"))
        elif mnem == 'ble':
            expanded_lines.append(('inst', f"bge {parts[2]}, {parts[1]}, {parts[3]}"))
        elif mnem == 'bgtu':
            expanded_lines.append(('inst', f"bltu {parts[2]}, {parts[1]}, {parts[3]}"))
        elif mnem == 'bleu':
            expanded_lines.append(('inst', f"bgeu {parts[2]}, {parts[1]}, {parts[3]}"))
        else:
            expanded_lines.append(('inst', line))

    for item_type, val in expanded_lines:
        if item_type == 'label':
            labels[val] = addr
        else:
            instructions.append((addr, val))
            addr += 4
            
    # Pass 2: emit hex
    hex_output = []
    for addr, line in instructions:
        parts = re.split(r'[\s,]+', line.strip())
        mnem = parts[0]
        
        val = 0
        try:
            if mnem in ['add', 'sub', 'and', 'or', 'sll', 'slt', 'sltu', 'xor', 'srl', 'sra', 'mul', 'mulh', 'mulhsu', 'mulhu', 'div', 'divu', 'rem', 'remu']:
                opcode = 0x33
                rd = parse_reg(parts[1])
                rs1 = parse_reg(parts[2])
                rs2 = parse_reg(parts[3])
                funct3 = {'add':0, 'sub':0, 'sll':1, 'slt':2, 'sltu':3, 'xor':4, 'srl':5, 'sra':5, 'or':6, 'and':7, 'mul':0, 'mulh':1, 'mulhsu':2, 'mulhu':3, 'div':4, 'divu':5, 'rem':6, 'remu':7}[mnem]
                if mnem in ['sub', 'sra']:
                    funct7 = 0x20
                elif mnem in ['mul', 'mulh', 'mulhsu', 'mulhu', 'div', 'divu', 'rem', 'remu']:
                    funct7 = 0x01
                else:
                    funct7 = 0x00
                val = (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode
                
            elif mnem in ['addi', 'slli', 'slti', 'sltiu', 'xori', 'srli', 'srai', 'ori', 'andi']:
                opcode = 0x13
                rd = parse_reg(parts[1])
                rs1 = parse_reg(parts[2])
                imm = int(parts[3], 0) & 0xFFF
                funct3 = {'addi':0, 'slli':1, 'slti':2, 'sltiu':3, 'xori':4, 'srli':5, 'srai':5, 'ori':6, 'andi':7}[mnem]
                val = (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode
                
            elif mnem in ['lw', 'lb', 'lh', 'lbu', 'lhu']:
                opcode = 0x03
                rd = parse_reg(parts[1])
                match = re.match(r'(-?\d+)\(([a-zA-Z0-9_]+)\)', parts[2])
                if not match: raise Exception("Invalid load format")
                imm = int(match.group(1), 0) & 0xFFF
                rs1 = parse_reg(match.group(2))
                funct3 = {'lb':0, 'lh':1, 'lw':2, 'lbu':4, 'lhu':5}[mnem]
                val = (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode
                
            elif mnem in ['sw', 'sb', 'sh']:
                opcode = 0x23
                rs2 = parse_reg(parts[1])
                match = re.match(r'(-?\d+)\(([a-zA-Z0-9_]+)\)', parts[2])
                if not match: raise Exception("Invalid store format")
                imm = int(match.group(1), 0)
                rs1 = parse_reg(match.group(2))
                funct3 = {'sb':0, 'sh':1, 'sw':2}[mnem]
                imm_lower = imm & 0x1F
                imm_upper = (imm >> 5) & 0x7F
                val = (imm_upper << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_lower << 7) | opcode
                
            elif mnem in ['beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu']:
                opcode = 0x63
                rs1 = parse_reg(parts[1])
                rs2 = parse_reg(parts[2])
                target = parts[3]
                if target in labels:
                    offset = labels[target] - addr
                else:
                    offset = int(target, 0)
                funct3 = {'beq':0, 'bne':1, 'blt':4, 'bge':5, 'bltu':6, 'bgeu':7}[mnem]
                imm_11 = (offset >> 11) & 1
                imm_4_1 = (offset >> 1) & 0xF
                imm_10_5 = (offset >> 5) & 0x3F
                imm_12 = (offset >> 12) & 1
                val = (imm_12 << 31) | (imm_10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_4_1 << 8) | (imm_11 << 7) | opcode
                
            elif mnem == 'jal':
                opcode = 0x6F
                rd = parse_reg(parts[1])
                target = parts[2]
                if target in labels:
                    offset = labels[target] - addr
                else:
                    offset = int(target, 0)
                imm_19_12 = (offset >> 12) & 0xFF
                imm_11 = (offset >> 11) & 1
                imm_10_1 = (offset >> 1) & 0x3FF
                imm_20 = (offset >> 20) & 1
                val = (imm_20 << 31) | (imm_10_1 << 21) | (imm_11 << 20) | (imm_19_12 << 12) | (rd << 7) | opcode
                
            elif mnem == 'jalr':
                opcode = 0x67
                rd = parse_reg(parts[1])
                match = re.match(r'(-?\d+)\(([a-zA-Z0-9_]+)\)', parts[2])
                if not match: raise Exception("Invalid jalr format")
                imm = int(match.group(1), 0) & 0xFFF
                rs1 = parse_reg(match.group(2))
                val = (imm << 20) | (rs1 << 15) | (0 << 12) | (rd << 7) | opcode
                
            elif mnem in ['lui', 'auipc']:
                opcode = 0x37 if mnem == 'lui' else 0x17
                rd = parse_reg(parts[1])
                imm = int(parts[2], 0) & 0xFFFFF
                val = (imm << 12) | (rd << 7) | opcode
            
            elif mnem == 'nop':
                val = 0x00000013 # addi x0, x0, 0
                
            else:
                raise Exception(f"Unsupported instruction: {mnem}")
                
            hex_str = f"{val:08x}"
            hex_output.append(hex_str)
        except Exception as e:
            raise Exception(f"Error assembling line '{line}': {e}")
            
    return "\n".join(hex_output) + "\n"

if __name__ == '__main__':
    if len(sys.argv) > 1:
        with open(sys.argv[1], 'r') as f:
            code = f.read()
        print(assemble(code))
