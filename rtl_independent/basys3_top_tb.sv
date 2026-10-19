`timescale 1ns/1ps

module basys3_top_tb;
    logic clk100 = 1'b0;
    logic btnC = 1'b1;
    logic [3:0] sw = 4'b0000;
    wire [15:0] led;
    wire [6:0] seg;
    wire dp;
    wire [3:0] an;

    basys3_top dut(.*);
    always #5 clk100 = ~clk100;

    initial begin
        repeat (5) @(negedge clk100);
        btnC = 1'b0;
        wait (led[15] === 1'b1 || dut.cpu.rf.reg_file[31] === 32'h00000bad);
        #1;
        if (dut.last_wb_value !== 32'h0000_05a5)
            $fatal(1, "Expected board marker 0x5A5, got %08h", dut.last_wb_value);
        if (led[7:0] !== 8'hA5 || led[14] !== 1'b0 || led[15] !== 1'b1)
            $fatal(1, "Unexpected board status LEDs: %04h", led);
        wait (dut.metrics_valid === 1'b1);
        if (dut.saved_cycles == 0 || dut.saved_loads == 0 ||
            dut.saved_misses == 0 || dut.saved_cache_stalls == 0 ||
            dut.saved_redirects == 0)
            $fatal(1, "Expected nonzero run counters: cycles=%0d loads=%0d misses=%0d stalls=%0d redirects=%0d",
                   dut.saved_cycles, dut.saved_loads, dut.saved_misses,
                   dut.saved_cache_stalls, dut.saved_redirects);
        if (dut.saved_cycles !== dut.cpu_cycles ||
            dut.saved_loads !== dut.cpu_loads ||
            dut.saved_stores !== dut.cpu_stores ||
            dut.saved_hits !== dut.cpu_hits ||
            dut.saved_misses !== dut.cpu_misses ||
            dut.saved_cache_stalls !== dut.cpu_cache_stalls ||
            dut.saved_redirects !== dut.cpu_redirects)
            $fatal(1, "Frozen metrics differ from core counters at EBREAK");
        for (int metric = 1; metric <= 7; metric++) begin
            sw = {metric[2:0], 1'b0};
            #1;
            case (metric)
                1: if (dut.display_value !== dut.saved_cycles) $fatal(1, "Cycle display mux failed");
                2: if (dut.display_value !== dut.saved_loads) $fatal(1, "Load display mux failed");
                3: if (dut.display_value !== dut.saved_hits) $fatal(1, "Hit display mux failed");
                4: if (dut.display_value !== dut.saved_misses) $fatal(1, "Miss display mux failed");
                5: if (dut.display_value !== dut.saved_cache_stalls) $fatal(1, "Stall display mux failed");
                6: if (dut.display_value !== dut.saved_stores) $fatal(1, "Store display mux failed");
                7: if (dut.display_value !== dut.saved_redirects) $fatal(1, "Redirect display mux failed");
            endcase
        end
        sw = 4'b0000;
        #1;
        $display("BASYS3_DEMO_PASS,marker=%08h,led=%04h", dut.last_wb_value, led);
        $display("BASYS3_METRICS_MUX_PASS,cycles=%0d,loads=%0d,hits=%0d,misses=%0d,stalls=%0d,stores=%0d,redirects=%0d",
                 dut.saved_cycles, dut.saved_loads, dut.saved_hits, dut.saved_misses,
                 dut.saved_cache_stalls, dut.saved_stores, dut.saved_redirects);
        $finish;
    end

    initial begin
        repeat (100_000) @(posedge clk100);
        $fatal(1, "Timed out waiting for board demo completion marker");
    end
endmodule
