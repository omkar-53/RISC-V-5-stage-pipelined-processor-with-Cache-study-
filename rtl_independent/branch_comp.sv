`timescale 1ns/1ps

module branch_comp(
    input logic [31:0] a,
    input logic [31:0] b,
    input logic        BrUn,
    output logic       BrEq,
    output logic       BrLt
);
    always_comb begin
        BrEq = (a == b);
        if (BrUn) BrLt = (a < b);
        else      BrLt = ($signed(a) < $signed(b));
    end
endmodule
