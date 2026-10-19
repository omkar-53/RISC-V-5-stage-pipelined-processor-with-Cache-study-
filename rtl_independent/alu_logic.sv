`timescale 1ns/1ps

module alu_logic #(parameter int ALU_WIDTH = 32) (
    input  logic [ALU_WIDTH-1:0] op1,
    input  logic [ALU_WIDTH-1:0] op2,
    input  logic [4:0]           alu_op,
    output logic [ALU_WIDTH-1:0] result
);
    always_comb begin
        result = '0;
        unique case (alu_op)
            5'd0:  result = op1 + op2;
            5'd1:  result = op1 - op2;
            5'd2:  result = op1 << op2[4:0];
            5'd3:  result = ($signed(op1) < $signed(op2));
            5'd4:  result = (op1 < op2);
            5'd5:  result = op1 ^ op2;
            5'd6:  result = op1 >> op2[4:0];
            5'd7:  result = $signed(op1) >>> op2[4:0];
            5'd8:  result = op1 | op2;
            5'd9:  result = op1 & op2;
            5'd10: result = op1 * op2;
            5'd11: result = ($signed({{32{op1[31]}}, op1}) *
                             $signed({{32{op2[31]}}, op2})) >> 32;
            5'd12: result = ($signed({{32{op1[31]}}, op1}) *
                             $signed({32'b0, op2})) >> 32;
            5'd13: result = ({32'b0, op1} * {32'b0, op2}) >> 32;
            // RISC-V M-extension specifies quotient=-1 and remainder=rs1
            // for division by zero; signed overflow returns rs1 and zero.
            5'd14: begin
                if (op2 == '0) result = '1;
                else if (op1 == {1'b1, {(ALU_WIDTH-1){1'b0}}} && op2 == '1)
                    result = op1;
                else result = $signed(op1) / $signed(op2);
            end
            5'd15: result = (op2 == '0) ? '1 : op1 / op2;
            5'd16: begin
                if (op2 == '0) result = op1;
                else if (op1 == {1'b1, {(ALU_WIDTH-1){1'b0}}} && op2 == '1)
                    result = '0;
                else result = $signed(op1) % $signed(op2);
            end
            5'd17: result = (op2 == '0) ? op1 : op1 % op2;
            default: result = '0;
        endcase
    end
endmodule
