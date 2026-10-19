`timescale 1ns/1ps

module data_mem #(parameter int WORDS = 512) (
    input  logic        clk,
    input  logic [31:0] addr,
    input  logic [31:0] dataW,
    input  logic [2:0]  funct3,
    input  logic        MemRW,
    output logic [31:0] dataR
);
    logic [31:0] memory [0:WORDS-1];
    logic [31:0] word_value;
    logic [29:0] word_index;
    integer i;

    initial begin
`ifdef SYNTHESIS
        // Initialize FPGA data memory from the same image used by the demo.
        $readmemh("data_mem.mem", memory);
`else
        for (i = 0; i < WORDS; i = i + 1) memory[i] = 32'b0;
        if ($test$plusargs("LOAD_DATA_MEM")) $readmemh("data_mem.mem", memory);
`endif
    end

    always_comb begin
        word_index = addr[31:2];
        word_value = (word_index < WORDS) ? memory[word_index] : 32'b0;
        unique case (funct3)
            3'b000: begin
                case (addr[1:0])
                    2'd0: dataR = {{24{word_value[7]}}, word_value[7:0]};
                    2'd1: dataR = {{24{word_value[15]}}, word_value[15:8]};
                    2'd2: dataR = {{24{word_value[23]}}, word_value[23:16]};
                    default: dataR = {{24{word_value[31]}}, word_value[31:24]};
                endcase
            end
            3'b001: dataR = addr[1] ? {{16{word_value[31]}}, word_value[31:16]} : {{16{word_value[15]}}, word_value[15:0]};
            3'b010: dataR = word_value;
            3'b100: begin
                case (addr[1:0])
                    2'd0: dataR = {24'b0, word_value[7:0]};
                    2'd1: dataR = {24'b0, word_value[15:8]};
                    2'd2: dataR = {24'b0, word_value[23:16]};
                    default: dataR = {24'b0, word_value[31:24]};
                endcase
            end
            3'b101: dataR = addr[1] ? {16'b0, word_value[31:16]} : {16'b0, word_value[15:0]};
            default: dataR = 32'b0;
        endcase
    end

    always_ff @(posedge clk) begin
        if (MemRW && (word_index < WORDS)) begin
            unique case (funct3)
                3'b000: begin
                    case (addr[1:0])
                        2'd0: memory[word_index][7:0]   <= dataW[7:0];
                        2'd1: memory[word_index][15:8]  <= dataW[7:0];
                        2'd2: memory[word_index][23:16] <= dataW[7:0];
                        2'd3: memory[word_index][31:24] <= dataW[7:0];
                    endcase
                end
                3'b001: if (!addr[1]) memory[word_index][15:0] <= dataW[15:0];
                        else          memory[word_index][31:16] <= dataW[15:0];
                3'b010: if (addr[1:0] == 0) memory[word_index] <= dataW;
                default: ;
            endcase
        end
    end
endmodule
