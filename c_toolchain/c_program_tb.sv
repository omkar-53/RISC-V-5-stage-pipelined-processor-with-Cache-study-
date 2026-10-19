`timescale 1ns/1ps

`include "cache_c_config.svh"
`ifndef C_CACHE_ENABLE
`define C_CACHE_ENABLE 1
`endif
`ifndef C_CACHE_LINES
`define C_CACHE_LINES 16
`endif
`ifndef C_CACHE_VICTIM_ENABLE
`define C_CACHE_VICTIM_ENABLE 0
`endif

module c_program_tb;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic [31:0] alu_result_out, data_mem_out;
    logic MemRW, reg_write_en, trap;
    logic cache_hit, cache_miss, cache_stall;
    logic [31:0] debug_wb_value;
    logic [4:0] debug_wb_rd;
    logic debug_wb_commit;
    localparam bit CACHE_ENABLE = `C_CACHE_ENABLE;
    localparam int CACHE_LINES = `C_CACHE_LINES;
    localparam bit VICTIM_ENABLE = `C_CACHE_VICTIM_ENABLE;
    integer checks = 0;
    integer cycles = 0, loads = 0, stores = 0;
    integer hits = 0, misses = 0, cache_stalls = 0, load_use_stalls = 0;
    integer cycle_trace_fd;
    bit done = 1'b0;

    top #(.CACHE_ENABLE(CACHE_ENABLE), .CACHE_NUM_LINES(CACHE_LINES),
          .CACHE_VICTIM_ENABLE(VICTIM_ENABLE)) dut(.*);
    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset) begin
            cycles = 0; loads = 0; stores = 0;
            hits = 0; misses = 0; cache_stalls = 0; load_use_stalls = 0;
        end else if (!done) begin
            cycles++;
            if (cache_hit) hits++;
            if (cache_miss) misses++;
            if (cache_stall) cache_stalls++;
            if (dut.control_mux_sel && !dut.pipeline_stall) load_use_stalls++;
            if (!dut.pipeline_stall) begin
                if (dut.mem_to_reg_MEM) loads++;
                if (dut.mem_write_MEM) stores++;
            end
            $fdisplay(cycle_trace_fd,
                "%0d,%08x,%08x,%08x,%08x,%08x,%08x,%08x,%08x,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                cycles, dut.pc_IF, dut.pc_ID, dut.pc_EX,
                dut.inst_IF, dut.inst_ID, dut.inst_EX, dut.inst_MEM,
                dut.inst_WB, cache_hit, cache_miss, cache_stall,
                dut.pipeline_stall,
                (dut.control_mux_sel && !dut.pipeline_stall),
                dut.mem_to_reg_MEM, dut.mem_write_MEM);
        end
    end

    task automatic expect_word(input integer index, input [31:0] expected);
        checks++;
        if (dut.dmem.memory[index] !== expected)
            $fatal(1, "RAM[%0d] expected %08h, got %08h", index, expected, dut.dmem.memory[index]);
    endtask

    initial begin
        cycle_trace_fd = $fopen("c_cycle_attribution.csv", "w");
        if (cycle_trace_fd == 0) $fatal(1, "Cannot create C cycle trace");
        $fdisplay(cycle_trace_fd,
            "cycle,pc_if,pc_id,pc_ex,inst_if,inst_id,inst_ex,inst_mem,inst_wb,cache_hit,cache_miss,cache_stall,pipeline_stall,load_use_stall,load_in_mem,store_in_mem");
        repeat (3) @(negedge clk);
        reset = 1'b0;

        fork
            begin
                repeat (2000) @(posedge clk);
                $fatal(1, "C program did not reach EBREAK within 2000 cycles");
            end
            begin
                wait (trap === 1'b1);
                @(posedge clk);
                #1;
                expect_word(0, 7);                // initialized .data
                expect_word(64, 17);              // add
                expect_word(65, 60);              // mul
                expect_word(66, 2);               // div
                expect_word(67, 2);               // rem
                expect_word(68, 6);               // loop
                expect_word(69, 1);               // branch result
                expect_word(70, 19);              // initialized data read
                expect_word(71, 0);               // .bss global
                done = 1'b1;
                $fclose(cycle_trace_fd);
                $display("RV32IM_C_CACHE_RESULT,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                         CACHE_ENABLE, CACHE_LINES, VICTIM_ENABLE, cycles,
                         loads, stores, hits, misses, cache_stalls, load_use_stalls);
                $display("RV32IM_C_PROGRAM_PASS: %0d RAM checks", checks);
                $finish;
            end
        join
    end
endmodule
