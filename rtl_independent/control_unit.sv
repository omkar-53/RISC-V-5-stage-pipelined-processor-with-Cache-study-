`timescale 1ns/1ps

module control_unit(
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,
    input  logic       equal,
    input  logic       lessThan,
    output logic       alu_src,
    output logic       ASel,
    output logic [4:0] alu_op,
    output logic       reg_write_en,
    output logic       mem_write,
    output logic       mem_to_reg,
    output logic [1:0] pc_src
);
    always_comb begin
        alu_src = 1'b0;
        ASel = 1'b0;
        alu_op = 5'd0;
        reg_write_en = 1'b0;
        mem_write = 1'b0;
        mem_to_reg = 1'b0;
        pc_src = 2'b00;

        unique case (opcode)
            7'b0110011: begin
                reg_write_en = 1'b1;
                if (funct7 == 7'b0000001) alu_op = 5'd10 + {2'b00,funct3};
                else unique case (funct3)
                    3'b000: alu_op = funct7[5] ? 5'd1 : 5'd0;
                    3'b001: alu_op = 5'd2;
                    3'b010: alu_op = 5'd3;
                    3'b011: alu_op = 5'd4;
                    3'b100: alu_op = 5'd5;
                    3'b101: alu_op = funct7[5] ? 5'd7 : 5'd6;
                    3'b110: alu_op = 5'd8;
                    3'b111: alu_op = 5'd9;
                endcase
            end
            7'b0010011: begin
                reg_write_en = 1'b1;
                alu_src = 1'b1;
                unique case (funct3)
                    3'b000: alu_op = 5'd0;
                    3'b010: alu_op = 5'd3;
                    3'b011: alu_op = 5'd4;
                    3'b100: alu_op = 5'd5;
                    3'b110: alu_op = 5'd8;
                    3'b111: alu_op = 5'd9;
                    3'b001: alu_op = 5'd2;
                    3'b101: alu_op = funct7[5] ? 5'd7 : 5'd6;
                endcase
            end
            7'b0000011: begin reg_write_en=1'b1; alu_src=1'b1; mem_to_reg=1'b1; alu_op=5'd0; end
            7'b0100011: begin alu_src=1'b1; mem_write=1'b1; alu_op=5'd0; end
            7'b1100011: begin pc_src=2'b01; end
            7'b1101111: begin reg_write_en=1'b1; pc_src=2'b10; end
            7'b1100111: begin reg_write_en=1'b1; alu_src=1'b1; pc_src=2'b11; end
            7'b0110111: begin reg_write_en=1'b1; alu_src=1'b1; alu_op=5'd0; end
            7'b0010111: begin reg_write_en=1'b1; ASel=1'b1; alu_src=1'b1; alu_op=5'd0; end
            default: ;
        endcase
    end
endmodule
