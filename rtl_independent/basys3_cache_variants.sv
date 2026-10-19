`timescale 1ns/1ps

// Select one of these modules as the Vivado design top for each physical run.
// Every variant keeps the same Basys 3 pins and metric display; only the
// compile-time cache/backing-wait parameters change.

module basys3_cache4_top (
    input logic clk100, input logic btnC, input logic [3:0] sw,
    output logic [15:0] led, output logic [6:0] seg,
    output logic dp, output logic [3:0] an
);
    basys3_top #(.CACHE_ENABLE(1'b1), .CACHE_NUM_LINES(4),
        .CACHE_MISS_PENALTY(3), .CACHE_VICTIM_ENABLE(1'b0)) impl(.*);
endmodule

module basys3_cache16_top (
    input logic clk100, input logic btnC, input logic [3:0] sw,
    output logic [15:0] led, output logic [6:0] seg,
    output logic dp, output logic [3:0] an
);
    basys3_top #(.CACHE_ENABLE(1'b1), .CACHE_NUM_LINES(16),
        .CACHE_MISS_PENALTY(3), .CACHE_VICTIM_ENABLE(1'b0)) impl(.*);
endmodule

module basys3_cache32_top (
    input logic clk100, input logic btnC, input logic [3:0] sw,
    output logic [15:0] led, output logic [6:0] seg,
    output logic dp, output logic [3:0] an
);
    basys3_top #(.CACHE_ENABLE(1'b1), .CACHE_NUM_LINES(32),
        .CACHE_MISS_PENALTY(3), .CACHE_VICTIM_ENABLE(1'b0)) impl(.*);
endmodule

module basys3_cache16_victim_top (
    input logic clk100, input logic btnC, input logic [3:0] sw,
    output logic [15:0] led, output logic [6:0] seg,
    output logic dp, output logic [3:0] an
);
    basys3_top #(.CACHE_ENABLE(1'b1), .CACHE_NUM_LINES(16),
        .CACHE_MISS_PENALTY(3), .CACHE_VICTIM_ENABLE(1'b1)) impl(.*);
endmodule

module basys3_bypass_top (
    input logic clk100, input logic btnC, input logic [3:0] sw,
    output logic [15:0] led, output logic [6:0] seg,
    output logic dp, output logic [3:0] an
);
    basys3_top #(.CACHE_ENABLE(1'b0), .CACHE_NUM_LINES(16),
        .CACHE_VICTIM_ENABLE(1'b0), .BYPASS_LOAD_STALL_CYCLES(0)) impl(.*);
endmodule

// Emulates a four-cycle backing-memory wait for latency-matched comparison.
// This is a controlled wait model, not a measurement of external RAM latency.
module basys3_bypass_wait4_top (
    input logic clk100, input logic btnC, input logic [3:0] sw,
    output logic [15:0] led, output logic [6:0] seg,
    output logic dp, output logic [3:0] an
);
    basys3_top #(.CACHE_ENABLE(1'b0), .CACHE_NUM_LINES(16),
        .CACHE_VICTIM_ENABLE(1'b0), .BYPASS_LOAD_STALL_CYCLES(4)) impl(.*);
endmodule
