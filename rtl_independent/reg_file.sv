`timescale 1ns/1ps

module reg_file #(parameter int REGF_WIDTH = 32) (
    input  logic                  clk,
    input  logic                  write_en,
    input  logic [4:0]            rs1,
    input  logic [4:0]            rs2,
    input  logic [4:0]            rsW,
    input  logic [REGF_WIDTH-1:0] write_data,
    output logic [REGF_WIDTH-1:0] read_data1,
    output logic [REGF_WIDTH-1:0] read_data2
);
    logic [REGF_WIDTH-1:0] reg_file [0:31];
    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1) reg_file[i] = '0;
`ifndef SYNTHESIS
        if ($test$plusargs("LOAD_REG_INIT")) $readmemh("reg_init.mem", reg_file);
`endif
        reg_file[0] = '0;
    end

    always_comb begin
        read_data1 = (rs1 == 0) ? '0 : reg_file[rs1];
        read_data2 = (rs2 == 0) ? '0 : reg_file[rs2];
    end

    always_ff @(negedge clk) begin
        if (write_en && (rsW != 0)) reg_file[rsW] <= write_data;
    end
endmodule
