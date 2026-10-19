# test_rv32m.s
# Test hardware multiplication and division

li x1, 12
li x2, 5

# Multiply
mul x3, x1, x2    # x3 = 12 * 5 = 60 (0x3c)

# Divide
div x4, x1, x2    # x4 = 12 / 5 = 2

# Remainder
rem x5, x1, x2    # x5 = 12 % 5 = 2

# Negative divide
li x6, -12
div x7, x6, x2    # x7 = -12 / 5 = -2

# Division by zero
li x8, 0
div x9, x1, x8    # x9 = -1 (0xFFFFFFFF)

nop
nop
nop
nop
nop
