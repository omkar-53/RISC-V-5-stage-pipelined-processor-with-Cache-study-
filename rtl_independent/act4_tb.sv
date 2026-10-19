`timescale 1ns/1ps

// Experimental ACT4 execution harness for the independent RTL.
// The matching ACT4 RVMODEL_HALT_PASS/FAIL macros must write the sentinels
// below to the reserved final data-memory word before executing EBREAK.
module act4_tb;
    localparam logic [31:0] ACT4_PASS = 32'h4154_4350; // "ATCP"
    localparam logic [31:0] ACT4_FAIL = 32'h4154_4346; // "ATCF"
    localparam int ACT4_DATA_WORDS = 65536;
    localparam int SENTINEL_INDEX = ACT4_DATA_WORDS - 1;

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

    top #(.IMEM_WORDS(ACT4_DATA_WORDS), .DMEM_WORDS(ACT4_DATA_WORDS)) dut(.*);
    always #5 clk = ~clk;

    initial begin
        repeat (3) @(negedge clk);
        reset = 1'b0;

        fork
            begin
                repeat (2_000_000) @(posedge clk);
                $display("ACT4_DIAG: pc=%08h if_id=%08h id_ex=%08h marker=%08h trap=%b",
                         dut.pc_out, dut.if_id_instruction, dut.id_ex_instruction,
                         dut.dmem.memory[SENTINEL_INDEX], trap);
                $fatal(1, "ACT4_TIMEOUT: test did not reach its EBREAK terminator");
            end
            begin
                wait (trap === 1'b1);
                @(posedge clk);
                #1;
                if (dut.dmem.memory[SENTINEL_INDEX] !== ACT4_PASS) begin
                    $display("RVCP-SUMMARY: TEST FAILED - Test File \"rtl_independent ACT4 harness\"");
                    $display("ACT4_DIAG: pc=%08h if_id_pc=%08h id_ex_pc=%08h if_id=%08h id_ex=%08h x1=%08h x2=%08h x5=%08h x25=%08h",
                             dut.pc_out, dut.if_id_pc, dut.id_ex_pc,
                             dut.if_id_instruction, dut.id_ex_instruction,
                             dut.rf.reg_file[1], dut.rf.reg_file[2],
                             dut.rf.reg_file[5], dut.rf.reg_file[25]);
                    $fatal(1, "ACT4_FAIL: sentinel=%08h",
                           dut.dmem.memory[SENTINEL_INDEX]);
                end
                $display("RVCP-SUMMARY: TEST PASSED - Test File \"rtl_independent ACT4 harness\"");
                $finish;
            end
        join
    end
endmodule
