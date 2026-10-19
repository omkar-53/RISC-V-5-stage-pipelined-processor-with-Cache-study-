`timescale 1ns/1ps

module imm_gen(input logic [31:0] instruction, output logic [31:0] imm_out);
    always_comb begin
        unique case (instruction[6:0])
            7'b0010011, 7'b0000011, 7'b1100111:
                imm_out = {{20{instruction[31]}}, instruction[31:20]};
            7'b0100011:
                imm_out = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            7'b1100011:
                imm_out = {{19{instruction[31]}}, instruction[31], instruction[7],
                           instruction[30:25], instruction[11:8], 1'b0};
            7'b0110111, 7'b0010111:
                imm_out = {instruction[31:12], 12'b0};
            7'b1101111:
                imm_out = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                           instruction[20], instruction[30:21], 1'b0};
            default: imm_out = 32'b0;
        endcase
    end
endmodule
