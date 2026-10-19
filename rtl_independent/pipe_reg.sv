`timescale 1ns/1ps

module pipe_reg #(parameter int WIDTH = 32) (
    input  logic                 clk,
    input  logic                 rst,
    input  logic                 write_en,
    input  logic                 flush,
    input  logic [WIDTH-1:0]     d,
    output logic [WIDTH-1:0]     q
);
    always_ff @(posedge clk) begin
        if (rst)         q <= '0;
        else if (flush)  q <= '0;
        else if (write_en) q <= d;
    end
endmodule
