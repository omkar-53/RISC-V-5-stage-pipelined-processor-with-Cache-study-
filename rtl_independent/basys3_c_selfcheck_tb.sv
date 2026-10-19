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

module basys3_c_selfcheck_tb;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic [31:0] alu_result_out, data_mem_out;
    logic MemRW, reg_write_en, trap;
    logic cache_hit, cache_miss, cache_stall;
    logic [31:0] debug_wb_value;
    logic [4:0] debug_wb_rd;
    logic debug_wb_commit;
    logic [31:0] debug_cycle_count, debug_load_count, debug_store_count;
    logic [31:0] debug_hit_count, debug_miss_count;
    logic [31:0] debug_cache_stall_count, debug_redirect_count;
    integer checks = 0;
    integer forwarding_events = 0;
    integer loaduse_events = 0;
    integer flush_events = 0;

    top #(.CACHE_ENABLE(`C_CACHE_ENABLE), .CACHE_NUM_LINES(`C_CACHE_LINES),
          .CACHE_VICTIM_ENABLE(`C_CACHE_VICTIM_ENABLE)) dut(.*);
    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset) begin
            forwarding_events = 0;
            loaduse_events = 0;
            flush_events = 0;
        end else begin
            if (dut.forwardA != 0 || dut.forwardB != 0) forwarding_events++;
            if (dut.load_dependency) loaduse_events++;
            if (dut.IF_flush) flush_events++;
        end
    end

    task automatic expect_word(input integer index, input [31:0] expected);
        checks++;
        if (dut.dmem.memory[index] !== expected)
            $fatal(1, "RAM[%0d] expected %08h, got %08h", index, expected, dut.dmem.memory[index]);
    endtask

    initial begin
        repeat (3) @(negedge clk);
        reset = 1'b0;

        fork
            begin
                repeat (20000) @(posedge clk);
                $fatal(1, "Self-checking RV32IM test timed out");
            end
            begin
                wait (trap === 1'b1);
                wait (dut.rf.reg_file[31] === 32'h000005a5 ||
                      dut.rf.reg_file[31] === 32'h00000bad);
                @(negedge clk);
                if (dut.rf.reg_file[31] !== 32'h000005a5)
                    $fatal(1, "Program reported FAIL marker %08h", dut.rf.reg_file[31]);

                expect_word(0, 7);                // initialized .data
                expect_word(64, 17);              // ADD
                expect_word(65, 60);              // MUL
                expect_word(66, 2);               // DIV
                expect_word(67, 2);               // REM
                expect_word(68, 6);               // loop/branch
                expect_word(69, 1);               // compare result
                expect_word(70, 19);              // initialized-data read
                expect_word(71, 0);               // global data read/write
                expect_word(72, 25);              // EX forwarding chain
                expect_word(73, 26);              // load-use interlock/resume
                expect_word(74, 0);               // wrong-path store was flushed
                expect_word(75, 85);              // taken-branch target executed
                if (forwarding_events == 0 || loaduse_events == 0 || flush_events == 0)
                    $fatal(1, "Directed event missing: forward=%0d loaduse=%0d flush=%0d",
                           forwarding_events, loaduse_events, flush_events);

                $display("BASYS3_RV32IM_SELFCHECK_PASS: %0d RAM checks, x31=%08h, forward=%0d, loaduse=%0d, flush=%0d",
                         checks, dut.rf.reg_file[31], forwarding_events, loaduse_events, flush_events);
                $finish;
            end
        join
    end
endmodule
