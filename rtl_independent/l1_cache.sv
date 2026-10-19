`timescale 1ns/1ps

module l1_cache #(
    parameter int NUM_LINES = 16,
    parameter int MISS_PENALTY = 3,
    parameter bit CACHE_ENABLE = 1'b1,
    parameter bit VICTIM_ENABLE = 1'b0,
    // Number of total stalled rising edges for a cache-bypassed LW.
    parameter int BYPASS_WAIT_CYCLES = 0
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        request_valid,
    input  logic        request_write,
    input  logic [31:0] address,
    input  logic [31:0] store_value,
    input  logic [2:0]  access_size,
    input  logic [31:0] backing_value,
    output logic [31:0] read_value,
    output logic        cache_hit,
    output logic        cache_miss,
    output logic        cache_stall
);
    localparam int INDEX_BITS = $clog2(NUM_LINES);
    localparam int TAG_BITS = 30 - INDEX_BITS;
    logic [31:0] line_data [0:NUM_LINES-1];
    logic [TAG_BITS-1:0] line_tag [0:NUM_LINES-1];
    logic line_valid [0:NUM_LINES-1];
    logic victim_valid;
    logic [31:0] victim_address, victim_data;
    logic [INDEX_BITS-1:0] index;
    logic [TAG_BITS-1:0] tag;
    logic cacheable_read, main_hit, victim_hit, hit_now;
    logic waiting, bypass_wait_done, fill_response_pending;
    logic [7:0] delay_left;
    logic [31:0] miss_address;
    logic [TAG_BITS-1:0] miss_tag;
    logic [INDEX_BITS-1:0] miss_index;
    integer i;

    always_comb begin
        index = address[2 + INDEX_BITS - 1:2];
        tag = address[31:2 + INDEX_BITS];
        cacheable_read = request_valid && !request_write && (access_size == 3'b010) && (address[1:0] == 0);
        main_hit = line_valid[index] && (line_tag[index] == tag);
        victim_hit = VICTIM_ENABLE && victim_valid && (victim_address == {address[31:2], 2'b00});
        hit_now = CACHE_ENABLE && (main_hit || victim_hit);
        cache_hit = cacheable_read && hit_now && !waiting && !fill_response_pending;
        cache_miss = CACHE_ENABLE && cacheable_read && !hit_now && !waiting;
        cache_stall = cacheable_read && (waiting || (!hit_now &&
            (CACHE_ENABLE || (BYPASS_WAIT_CYCLES > 0 && !bypass_wait_done))));
        if (cacheable_read && hit_now)
            read_value = victim_hit ? victim_data : line_data[index];
        else read_value = backing_value;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            waiting <= 1'b0;
            bypass_wait_done <= 1'b0;
            fill_response_pending <= 1'b0;
            delay_left <= '0;
            victim_valid <= 1'b0;
            victim_address <= '0;
            victim_data <= '0;
            miss_address <= '0;
            miss_tag <= '0;
            miss_index <= '0;
            for (i = 0; i < NUM_LINES; i = i + 1) begin
                line_valid[i] <= 1'b0;
                line_tag[i] <= '0;
                line_data[i] <= '0;
            end
        end else begin
            if (request_valid && request_write) begin
                if (line_valid[index] && (line_tag[index] == tag))
                    line_valid[index] <= 1'b0;
                if (VICTIM_ENABLE && victim_valid &&
                    (victim_address == {address[31:2], 2'b00}))
                    victim_valid <= 1'b0;
            end

            if (waiting) begin
                if (delay_left <= 1) begin
                    if (CACHE_ENABLE) begin
                        if (VICTIM_ENABLE && line_valid[miss_index]) begin
                            victim_address <= {{line_tag[miss_index], miss_index}, 2'b00};
                            victim_data <= line_data[miss_index];
                            victim_valid <= 1'b1;
                        end
                        line_data[miss_index] <= backing_value;
                        line_tag[miss_index] <= miss_tag;
                        line_valid[miss_index] <= 1'b1;
                        fill_response_pending <= 1'b1;
                    end else bypass_wait_done <= 1'b1;
                    waiting <= 1'b0;
                    delay_left <= '0;
                end else delay_left <= delay_left - 1'b1;
            end else if (bypass_wait_done) begin
                // Permit exactly one pipeline-advance edge before a held
                // bypass request can begin its next access wait.
                bypass_wait_done <= 1'b0;
            end else if (fill_response_pending) begin
                // The just-filled miss is serviced now, not recounted as a
                // separate cache-hit request. Permit pipeline advance.
                fill_response_pending <= 1'b0;
            end else if (cacheable_read && !hit_now &&
                         (CACHE_ENABLE || (BYPASS_WAIT_CYCLES > 0))) begin
                waiting <= 1'b1;
                // The initiating request edge is included in the requested
                // total latency, so only the remaining edges are counted here.
                delay_left <= CACHE_ENABLE ? MISS_PENALTY : BYPASS_WAIT_CYCLES - 1;
                miss_address <= {address[31:2], 2'b00};
                miss_tag <= tag;
                miss_index <= index;
            end

            // A victim hit swaps the requested word with the direct-mapped
            // line. This is an optional experiment; the default is unchanged.
            if (CACHE_ENABLE && VICTIM_ENABLE && cacheable_read &&
                victim_hit && !waiting) begin
                victim_address <= {{line_tag[index], index}, 2'b00};
                victim_data <= line_data[index];
                victim_valid <= line_valid[index];
                line_tag[index] <= tag;
                line_data[index] <= victim_data;
                line_valid[index] <= 1'b1;
            end
        end
    end
endmodule
