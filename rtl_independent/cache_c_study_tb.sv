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
`ifndef C_BYPASS_WAIT
`define C_BYPASS_WAIT 0
`endif
`ifndef C_MISS_PENALTY
`define C_MISS_PENALTY 3
`endif
`ifndef C_EXPECTED_RESULT
`define C_EXPECTED_RESULT 0
`endif
`ifndef C_WORKING_SET_WORDS
`define C_WORKING_SET_WORDS 0
`endif

module cache_c_study_tb;
    localparam bit CACHE_ON = `C_CACHE_ENABLE;
    localparam int CACHE_LINES = `C_CACHE_LINES;
    localparam bit VICTIM_ON = `C_CACHE_VICTIM_ENABLE;
    localparam int BYPASS_WAIT = `C_BYPASS_WAIT;
    localparam int CACHE_MISS_PENALTY = `C_MISS_PENALTY;
    localparam logic [31:0] EXPECTED_RESULT = `C_EXPECTED_RESULT;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic [31:0] alu_result_out, data_mem_out;
    logic MemRW, reg_write_en, trap, cache_hit, cache_miss, cache_stall;
    logic [31:0] debug_wb_value;
    logic [4:0] debug_wb_rd;
    logic debug_wb_commit;
    logic [31:0] debug_cycle_count, debug_load_count, debug_store_count;
    logic [31:0] debug_hit_count, debug_miss_count;
    logic [31:0] debug_cache_stall_count, debug_redirect_count;
    integer cycles = 0, loads = 0, stores = 0, hits = 0, misses = 0;
    integer cache_wait_edges = 0, bypass_wait_edges = 0, load_use_stalls = 0;
    integer serialized_wait_requests = 0;
    logic held_load = 1'b0;
    logic [31:0] held_load_address = '0;
    integer trace_fd, state_fd;
    bit done = 1'b0;

    top #(.CACHE_ENABLE(CACHE_ON), .CACHE_NUM_LINES(CACHE_LINES),
          .CACHE_VICTIM_ENABLE(VICTIM_ON), .CACHE_MISS_PENALTY(CACHE_MISS_PENALTY),
          .BYPASS_LOAD_STALL_CYCLES(BYPASS_WAIT)) dut(.*);
    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset) begin
            cycles = 0; loads = 0; stores = 0; hits = 0; misses = 0;
            cache_wait_edges = 0; bypass_wait_edges = 0; load_use_stalls = 0;
            serialized_wait_requests = 0; held_load = 1'b0; held_load_address = '0;
        end else if (!done) begin
            cycles++;
            // The blocking memory interface must keep the same EX/MEM load
            // in place until its wait finishes; a second request cannot issue.
            if (held_load && (!dut.pipeline_hold || !dut.ex_mem_valid ||
                              !dut.ex_mem_mem_read)) held_load = 1'b0;
            if (dut.pipeline_hold && dut.ex_mem_valid && dut.ex_mem_mem_read) begin
                if (!held_load) begin
                    held_load = 1'b1;
                    held_load_address = dut.ex_mem_result;
                    serialized_wait_requests++;
                end else if (dut.ex_mem_result !== held_load_address) begin
                    $fatal(1, "memory request changed while outstanding: %08h -> %08h",
                           held_load_address, dut.ex_mem_result);
                end
            end
            if (cache_hit) hits++;
            if (cache_miss) misses++;
            if (dut.pipeline_hold && dut.ex_mem_valid && dut.ex_mem_mem_read) begin
                if (CACHE_ON) cache_wait_edges++;
                else bypass_wait_edges++;
            end
            if (dut.control_mux_sel && !dut.pipeline_hold) load_use_stalls++;
            if (!dut.pipeline_hold) begin
                if (dut.ex_mem_valid && dut.ex_mem_mem_read) loads++;
                if (dut.ex_mem_valid && dut.ex_mem_mem_write) stores++;
            end
            $fdisplay(trace_fd,
                "%0d,%08x,%08x,%08x,%08x,%08x,%08x,%08x,%08x,%0d,%0d,%0d,%0d",
                cycles, dut.pc_out, dut.if_id_pc, dut.id_ex_pc,
                dut.instruction, dut.if_id_instruction, dut.id_ex_instruction,
                dut.ex_mem_result, dut.mem_wb_result, cache_hit, cache_miss,
                cache_stall, dut.pipeline_hold);
        end
    end

    initial begin
        trace_fd = $fopen("cycle_attribution.csv", "w");
        if (!trace_fd) $fatal(1, "Cannot create cycle_attribution.csv");
        $fdisplay(trace_fd,
            "cycle,pc_if,pc_id,pc_ex,inst_if,inst_id,inst_ex,mem_address,wb_result,cache_hit,cache_miss,cache_stall,pipeline_hold");
        state_fd = $fopen("final_state.txt", "w");
        if (!state_fd) $fatal(1, "Cannot create final_state.txt");
        repeat (3) @(negedge clk);
        reset = 1'b0;

        fork
            begin
                repeat (12000) @(posedge clk);
                $fatal(1, "C workload did not reach EBREAK within 12000 cycles");
            end
            begin
                wait (trap === 1'b1);
                repeat (8) @(negedge clk);
                #1;
                if (dut.dmem.memory[64] !== EXPECTED_RESULT)
                    $fatal(1, "result RAM[64]: expected %08h, got %08h",
                           EXPECTED_RESULT, dut.dmem.memory[64]);
                if (dut.rf.reg_file[0] !== 32'b0)
                    $fatal(1, "architectural x0 changed");
                for (int r = 0; r < 32; r++)
                    $fdisplay(state_fd, "x%0d=%08x", r, dut.rf.reg_file[r]);
                for (int m = 0; m < 512; m++)
                    $fdisplay(state_fd, "m%0d=%08x", m, dut.dmem.memory[m]);
                $fclose(state_fd);
                $fclose(trace_fd);
                done = 1'b1;
                if (CACHE_ON && cache_wait_edges != misses * (CACHE_MISS_PENALTY + 1))
                    $fatal(1, "cache wait accounting mismatch: %0d edges for %0d misses",
                           cache_wait_edges, misses);
                if (!CACHE_ON && BYPASS_WAIT > 0 && bypass_wait_edges != loads * BYPASS_WAIT)
                    $fatal(1, "bypass wait accounting mismatch: %0d edges for %0d loads",
                           bypass_wait_edges, loads);
                if (!CACHE_ON && BYPASS_WAIT == 0 && bypass_wait_edges != 0)
                    $fatal(1, "immediate bypass unexpectedly stalled");
                if (CACHE_ON && hits + misses != loads)
                    $fatal(1, "cache request accounting mismatch: hits=%0d misses=%0d loads=%0d",
                           hits, misses, loads);
                if (CACHE_ON && serialized_wait_requests != misses)
                    $fatal(1, "cache serialization mismatch: waits=%0d misses=%0d",
                           serialized_wait_requests, misses);
                if (!CACHE_ON && BYPASS_WAIT > 0 && serialized_wait_requests != loads)
                    $fatal(1, "bypass serialization mismatch: waits=%0d loads=%0d",
                           serialized_wait_requests, loads);
                $display("CACHE_C_RESULT,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                    CACHE_ON, CACHE_LINES, VICTIM_ON, BYPASS_WAIT,
                    CACHE_MISS_PENALTY, cycles,
                    loads, stores, hits, misses,
                    CACHE_ON ? cache_wait_edges : bypass_wait_edges, load_use_stalls);
                $display("CACHE_C_PASS,result=%08h,working_set_words=%0d",
                    dut.dmem.memory[64], `C_WORKING_SET_WORDS);
                $display("CACHE_C_SERIALIZATION_PASS,max_outstanding=1,wait_requests=%0d",
                    serialized_wait_requests);
                $finish;
            end
        join
    end
endmodule
