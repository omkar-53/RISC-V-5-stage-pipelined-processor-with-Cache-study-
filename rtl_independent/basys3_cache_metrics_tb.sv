`timescale 1ns/1ps
`ifndef BC_CACHE_ENABLE
`define BC_CACHE_ENABLE 1
`endif
`ifndef BC_CACHE_LINES
`define BC_CACHE_LINES 16
`endif
`ifndef BC_VICTIM_ENABLE
`define BC_VICTIM_ENABLE 0
`endif
`ifndef BC_BYPASS_WAIT
`define BC_BYPASS_WAIT 0
`endif
`ifndef BC_EXPECTED_RESULT
`define BC_EXPECTED_RESULT 416
`endif
`ifndef BC_PROFILE_NAME
`define BC_PROFILE_NAME "reuse4_cache16"
`endif

module basys3_cache_metrics_tb;
    logic clk100 = 1'b0;
    logic btnC = 1'b1;
    logic [3:0] sw = 4'b0000;
    wire [15:0] led;
    wire [6:0] seg;
    wire dp;
    wire [3:0] an;

    basys3_top #(
        .CACHE_ENABLE(`BC_CACHE_ENABLE),
        .CACHE_NUM_LINES(`BC_CACHE_LINES),
        .CACHE_MISS_PENALTY(3),
        .CACHE_VICTIM_ENABLE(`BC_VICTIM_ENABLE),
        .BYPASS_LOAD_STALL_CYCLES(`BC_BYPASS_WAIT)
    ) dut(.*);
    always #5 clk100 = ~clk100;

    initial begin
        repeat (5) @(negedge clk100);
        btnC = 1'b0;
        fork
            begin
                repeat (2_000_000) @(posedge clk100);
                $fatal(1, "Cache profile timeout: %s", `BC_PROFILE_NAME);
            end
            begin
                wait (dut.metrics_valid === 1'b1);
                #1;
                if (!dut.pass_seen)
                    $fatal(1, "Workload did not commit its PASS marker: %s, last WB=%08h x31=%08h",
                           `BC_PROFILE_NAME, dut.last_wb_value, dut.cpu.rf.reg_file[31]);
                if (dut.cpu.dmem.memory[64] !== `BC_EXPECTED_RESULT)
                    $fatal(1, "Result RAM[64] expected %08h, got %08h",
                           `BC_EXPECTED_RESULT, dut.cpu.dmem.memory[64]);
                if (dut.saved_cycles == 0 || dut.saved_loads == 0 || dut.saved_stores == 0)
                    $fatal(1, "Profile counters unexpectedly zero: %s", `BC_PROFILE_NAME);
                if (dut.saved_cycles !== dut.cpu_cycles ||
                    dut.saved_loads !== dut.cpu_loads ||
                    dut.saved_stores !== dut.cpu_stores ||
                    dut.saved_hits !== dut.cpu_hits ||
                    dut.saved_misses !== dut.cpu_misses ||
                    dut.saved_cache_stalls !== dut.cpu_cache_stalls ||
                    dut.saved_redirects !== dut.cpu_redirects)
                    $fatal(1, "Frozen counters mismatch: %s", `BC_PROFILE_NAME);
                if (`BC_CACHE_ENABLE && dut.saved_hits + dut.saved_misses != dut.saved_loads)
                    $fatal(1, "Cache accounting mismatch: %s", `BC_PROFILE_NAME);
                if (!`BC_CACHE_ENABLE && dut.saved_hits != 0)
                    $fatal(1, "Bypass unexpectedly counted cache hits: %s", `BC_PROFILE_NAME);

                $display("BASYS3_CACHE_PROFILE_PASS,%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%08h",
                    `BC_PROFILE_NAME, `BC_CACHE_ENABLE, `BC_CACHE_LINES,
                    `BC_VICTIM_ENABLE, dut.saved_cycles, dut.saved_loads,
                    dut.saved_stores, dut.saved_hits, dut.saved_misses,
                    dut.saved_cache_stalls, dut.cpu.dmem.memory[64]);
                $finish;
            end
        join
    end
endmodule
