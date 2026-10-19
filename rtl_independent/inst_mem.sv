`timescale 1ns/1ps

module inst_mem #(parameter int WORDS = 256) (
    input  logic [31:0] addr,
    output logic [31:0] inst
);
    logic [31:0] memory [0:WORDS-1];
    integer i;

    initial begin
`ifdef SYNTHESIS
        // Vivado synthesis reads the program image into the inferred ROM.
        // Keep the image file in the Vivado project and add it as a memory file.
        $readmemh("instructions.mem", memory);
`else
        for (i = 0; i < WORDS; i = i + 1) memory[i] = 32'h00000013;
        if ($test$plusargs("LOAD_INST_MEM")) $readmemh("instructions.mem", memory);
`endif
    end

    always_comb begin
        if (addr[1:0] == 2'b00 && (addr[31:2] < WORDS))
            inst = memory[addr[31:2]];
        else
            inst = 32'h00000013;
    end
endmodule
