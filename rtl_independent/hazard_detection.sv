`timescale 1ns/1ps

module hazard_detection(
    input  logic       id_ex_mem_read,
    input  logic [4:0] id_ex_rd,
    input  logic [4:0] if_id_rs1,
    input  logic [4:0] if_id_rs2,
    output logic       PCWrite,
    output logic       IF_ID_Write,
    output logic       control_mux_sel
);
    logic dependency;
    always_comb begin
        dependency = id_ex_mem_read && (id_ex_rd != 0) &&
                     ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2));
        PCWrite = !dependency;
        IF_ID_Write = !dependency;
        control_mux_sel = dependency;
    end
endmodule
