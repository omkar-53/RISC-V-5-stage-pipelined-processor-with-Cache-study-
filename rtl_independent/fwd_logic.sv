`timescale 1ns/1ps

module fwd_logic(
    input  logic       ex_mem_reg_write,
    input  logic [4:0] ex_mem_rd,
    input  logic       mem_wb_reg_write,
    input  logic [4:0] mem_wb_rd,
    input  logic [4:0] id_ex_rs1,
    input  logic [4:0] id_ex_rs2,
    output logic [1:0] forwardA,
    output logic [1:0] forwardB
);
    always_comb begin
        forwardA = 2'b00;
        forwardB = 2'b00;
        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1))
            forwardA = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs1))
            forwardA = 2'b01;
        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2))
            forwardB = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs2))
            forwardB = 2'b01;
    end
endmodule
