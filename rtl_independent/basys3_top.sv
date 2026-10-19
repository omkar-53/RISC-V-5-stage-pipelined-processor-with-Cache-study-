`timescale 1ns/1ps

// Physical-board wrapper for the independent RV32IM core.
// SW[3:1] selects the displayed run metric; SW0 selects its low/high 16 bits.
// btnC resets the processor and clears the frozen metric snapshot.
module basys3_top #(
    parameter bit CACHE_ENABLE = 1'b1,
    parameter int CACHE_NUM_LINES = 16,
    parameter int CACHE_MISS_PENALTY = 3,
    parameter bit CACHE_VICTIM_ENABLE = 1'b0,
    parameter int BYPASS_LOAD_STALL_CYCLES = 0
) (
    input  logic       clk100,
    input  logic       btnC,
    input  logic [3:0] sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic        dp,
    output logic [3:0]  an
);
    logic [1:0] reset_sync = 2'b11;
    logic core_reset;
    logic [31:0] alu_result, memory_value;
    logic [31:0] wb_value, last_wb_value;
    logic [31:0] cpu_cycles, cpu_loads, cpu_stores, cpu_hits, cpu_misses;
    logic [31:0] cpu_cache_stalls, cpu_redirects;
    logic [31:0] saved_cycles, saved_loads, saved_stores, saved_hits, saved_misses;
    logic [31:0] saved_cache_stalls, saved_redirects;
    logic [4:0] wb_rd, last_wb_rd;
    logic mem_write, reg_write, trap, cache_hit, cache_miss, cache_stall;
    logic wb_commit, write_seen, commit_seen, complete_seen, pass_seen;
    logic metrics_valid;
    logic [5:0] divider_count = '0;
    logic core_clk_div = 1'b0;
    logic core_clk;
    logic [17:0] refresh_count = '0;
    logic [31:0] display_value;
    logic [15:0] display_half;
    logic [3:0] digit_value;
    logic [1:0] digit_select;

    // The independent RV32IM core has a long combinational path. Run the
    // board demonstration at 1 MHz (not 100 MHz); XDC constrains this clock.
    always_ff @(posedge clk100 or posedge btnC) begin
        if (btnC) begin
            divider_count <= '0;
            core_clk_div <= 1'b0;
        end else if (divider_count == 6'd49) begin
            divider_count <= '0;
            core_clk_div <= ~core_clk_div;
        end else begin
            divider_count <= divider_count + 1'b1;
        end
    end
`ifdef SYNTHESIS
    BUFG core_clock_buf (.I(core_clk_div), .O(core_clk));
`else
    assign core_clk = core_clk_div;
`endif

    // Assert reset immediately; release it synchronously to the 100 MHz clock.
    always_ff @(posedge core_clk or posedge btnC) begin
        if (btnC) reset_sync <= 2'b11;
        else      reset_sync <= {reset_sync[0], 1'b0};
    end
    // Include the button directly so reset asserts immediately, even before
    // the reset synchronizer is clocked, and can be visibly verified on-board.
    assign core_reset = btnC | reset_sync[1];

    top #(.CACHE_ENABLE(CACHE_ENABLE), .CACHE_NUM_LINES(CACHE_NUM_LINES),
          .CACHE_MISS_PENALTY(CACHE_MISS_PENALTY),
          .CACHE_VICTIM_ENABLE(CACHE_VICTIM_ENABLE),
          .BYPASS_LOAD_STALL_CYCLES(BYPASS_LOAD_STALL_CYCLES)) cpu (
        .clk(core_clk), .reset(core_reset), .alu_result_out(alu_result),
        .MemRW(mem_write), .reg_write_en(reg_write), .trap(trap),
        .data_mem_out(memory_value), .cache_hit(cache_hit),
        .cache_miss(cache_miss), .cache_stall(cache_stall),
        .debug_cycle_count(cpu_cycles), .debug_load_count(cpu_loads),
        .debug_store_count(cpu_stores), .debug_hit_count(cpu_hits),
        .debug_miss_count(cpu_misses), .debug_cache_stall_count(cpu_cache_stalls),
        .debug_redirect_count(cpu_redirects),
        .debug_wb_value(wb_value), .debug_wb_rd(wb_rd),
        .debug_wb_commit(wb_commit)
    );

    // Snapshot counters at the first EBREAK/trap. The cycle metric includes
    // the edge on which trap is sampled; counters then hold until reset.
    always_ff @(posedge core_clk or posedge btnC) begin
        if (btnC) begin
            metrics_valid <= 1'b0;
            saved_cycles <= '0; saved_loads <= '0; saved_stores <= '0;
            saved_hits <= '0; saved_misses <= '0; saved_cache_stalls <= '0;
            saved_redirects <= '0;
        end else if (core_reset) begin
            metrics_valid <= 1'b0;
            saved_cycles <= '0; saved_loads <= '0; saved_stores <= '0;
            saved_hits <= '0; saved_misses <= '0; saved_cache_stalls <= '0;
            saved_redirects <= '0;
        end else if (trap && !metrics_valid) begin
            metrics_valid <= 1'b1;
            saved_cycles <= cpu_cycles + 1'b1;
            saved_loads <= cpu_loads; saved_stores <= cpu_stores;
            saved_hits <= cpu_hits; saved_misses <= cpu_misses;
            saved_cache_stalls <= cpu_cache_stalls;
            saved_redirects <= cpu_redirects;
        end
    end

    always_ff @(posedge clk100) begin
        refresh_count <= refresh_count + 1'b1;
        if (core_reset) begin
            last_wb_value <= '0;
            last_wb_rd <= '0;
            write_seen <= 1'b0;
            commit_seen <= 1'b0;
            complete_seen <= 1'b0;
            pass_seen <= 1'b0;
        end else begin
            if (wb_commit) begin
                last_wb_value <= wb_value;
                last_wb_rd <= wb_rd;
                commit_seen <= 1'b1;
                if (wb_rd == 5'd31 && wb_value == 32'h000005a5)
                    pass_seen <= 1'b1;
            end
            if (mem_write) write_seen <= 1'b1;
            if (trap) complete_seen <= 1'b1;
        end
    end

    always_comb begin
        case (sw[3:1])
            3'd1: display_value = metrics_valid ? saved_cycles : cpu_cycles;
            3'd2: display_value = metrics_valid ? saved_loads : cpu_loads;
            3'd3: display_value = metrics_valid ? saved_hits : cpu_hits;
            3'd4: display_value = metrics_valid ? saved_misses : cpu_misses;
            3'd5: display_value = metrics_valid ? saved_cache_stalls : cpu_cache_stalls;
            3'd6: display_value = metrics_valid ? saved_stores : cpu_stores;
            3'd7: display_value = metrics_valid ? saved_redirects : cpu_redirects;
            default: display_value = pass_seen ? 32'h000005a5 : last_wb_value;
        endcase
        display_half = sw[0] ? display_value[31:16] : display_value[15:0];
    end
    assign digit_select = refresh_count[17:16];

    always_comb begin
        an = 4'b1111;
        case (digit_select)
            2'd0: begin an = 4'b1110; digit_value = display_half[3:0];   end
            2'd1: begin an = 4'b1101; digit_value = display_half[7:4];   end
            2'd2: begin an = 4'b1011; digit_value = display_half[11:8];  end
            default: begin an = 4'b0111; digit_value = display_half[15:12]; end
        endcase

        // seg[0:6] map to a,b,c,d,e,f,g; cathodes are active-low.
        case (digit_value)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            default: seg = 7'b0001110;
        endcase
    end

    assign dp = 1'b1;
    assign led[7:0]  = last_wb_value[7:0];
    assign led[8]    = write_seen;
    assign led[9]    = commit_seen;
    assign led[10]   = complete_seen;
    assign led[11]   = cache_hit;
    assign led[12]   = cache_miss;
    assign led[13]   = cache_stall;
    assign led[14]   = btnC;
    assign led[15]   = pass_seen;
endmodule
