`timescale 1ns/1ps
module alu_signed_smoke_tb;
  logic [31:0] a, b, y;
  logic [4:0] op;
  alu_logic dut(.op1(a), .op2(b), .alu_op(op), .result(y));
  initial begin
    a=32'hffff_fff9; b=32'd3; op=5'd14; #1;
    $display("SIGNED_DIV_SMOKE a=%h b=%h y=%h", a,b,y);
    if (y !== 32'hffff_fffe) $fatal(1,"signed division mismatch");
    $finish;
  end
endmodule
