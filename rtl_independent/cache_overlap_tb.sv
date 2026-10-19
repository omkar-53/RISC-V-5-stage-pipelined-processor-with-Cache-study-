`timescale 1ns/1ps
`include "cache_overlap_config.svh"

module cache_overlap_tb;
    localparam bit CACHE_ON = `O_CACHE_ENABLE;
    localparam int LINES = `O_CACHE_LINES;
    localparam int VICTIM = `O_VICTIM_ENABLE;
    localparam int BYPASS_WAIT = `O_BYPASS_WAIT;
    localparam int MISS_PENALTY = `O_MISS_PENALTY;
    localparam logic [31:0] NOP = 32'h00000013;
    localparam logic [31:0] EBREAK = 32'h00100073;

    logic clk=0, reset=1;
    logic [31:0] alu_result_out, data_mem_out;
    logic MemRW, reg_write_en, trap, cache_hit, cache_miss, cache_stall;
    logic [31:0] debug_wb_value;
    logic [4:0] debug_wb_rd;
    logic debug_wb_commit;
    logic [31:0] debug_cycle_count, debug_load_count, debug_store_count;
    logic [31:0] debug_hit_count, debug_miss_count;
    logic [31:0] debug_cache_stall_count, debug_redirect_count;
    integer cycles=0, overlap_edges=0, redirects=0;
    integer cache_wait_edges=0, bypass_wait_edges=0;
    integer trace_fd, state_fd;
    bit done=0, overlap_seen=0, redirect_after_wait=0;

    top #(.CACHE_ENABLE(CACHE_ON), .CACHE_NUM_LINES(LINES),
          .CACHE_VICTIM_ENABLE(VICTIM), .CACHE_MISS_PENALTY(MISS_PENALTY),
          .BYPASS_LOAD_STALL_CYCLES(BYPASS_WAIT)) dut(.*);
    always #5 clk=~clk;

    function automatic logic [31:0] enc_i(input integer imm,
        input logic [4:0] rs1, input logic [2:0] f3,
        input logic [4:0] rd, input logic [6:0] op);
        enc_i={imm[11:0],rs1,f3,rd,op};
    endfunction
    function automatic logic [31:0] enc_b(input integer imm,
        input logic [4:0] rs2, input logic [4:0] rs1, input logic [2:0] f3);
        logic [12:0] bits;
        begin bits=imm; enc_b={bits[12],bits[10:5],rs2,rs1,f3,bits[4:1],bits[11],7'b1100011}; end
    endfunction

    always @(posedge clk) begin
        if (reset) begin
            cycles=0; overlap_edges=0; redirects=0;
            cache_wait_edges=0; bypass_wait_edges=0;
            overlap_seen=0; redirect_after_wait=0;
        end else if (!done) begin
            cycles++;
            if (dut.ex_mem_valid && dut.ex_mem_mem_read && dut.id_ex_valid &&
                dut.id_ex_instruction[6:0]==7'b1100011 && dut.branch_taken) begin
                if (dut.pipeline_hold) begin
                    overlap_seen=1;
                    overlap_edges++;
                    if (CACHE_ON) cache_wait_edges++;
                    else bypass_wait_edges++;
                end
            end
            if (dut.redirect && dut.id_ex_instruction[6:0]==7'b1100011) begin
                redirects++;
                if (overlap_seen) redirect_after_wait=1;
            end
            $fdisplay(trace_fd,
                "%0d,%08x,%08x,%08x,%08x,%08x,%08x,%0d,%0d,%0d,%0d,%0d,%0d",
                cycles,dut.pc_out,dut.if_id_pc,dut.id_ex_pc,dut.id_ex_instruction,
                dut.ex_mem_result,cache_hit,cache_miss,cache_stall,dut.pipeline_hold,
                dut.branch_taken,dut.redirect,overlap_seen);
        end
    end

    initial begin
        trace_fd=$fopen("overlap_cycles.csv","w");
        state_fd=$fopen("final_state.txt","w");
        if (!trace_fd || !state_fd) $fatal(1,"Could not open evidence output files");
        $fdisplay(trace_fd,"cycle,pc_if,pc_id,pc_ex,inst_ex,mem_address,cache_hit,cache_miss,cache_stall,pipeline_hold,branch_taken,redirect,overlap_seen");
        repeat(3) @(negedge clk);
        for (int k=0;k<256;k++) dut.imem.memory[k]=NOP;
        for (int k=0;k<32;k++) dut.rf.reg_file[k]=0;
        for (int k=0;k<512;k++) dut.dmem.memory[k]=32'h1000+k;
        dut.dmem.memory[0]=32'h00000005;
        // LW -> taken BEQ -> wrong-path write -> target write -> EBREAK.
        dut.imem.memory[0]=enc_i(0,0,3'b010,3,7'b0000011);
        dut.imem.memory[1]=enc_b(8,0,0,3'b000);
        dut.imem.memory[2]=enc_i(99,0,3'b000,2,7'b0010011);
        dut.imem.memory[3]=enc_i(7,0,3'b000,4,7'b0010011);
        dut.imem.memory[4]=EBREAK;
        reset=0;
        fork
            begin repeat(3000) @(posedge clk); $fatal(1,"overlap workload timeout"); end
            begin
                wait(trap===1'b1);
                repeat(8) @(negedge clk);
                #1;
                if (CACHE_ON && !overlap_seen) $fatal(1,"branch did not overlap a cache-miss wait");
                if (CACHE_ON && overlap_edges != MISS_PENALTY+1)
                    $fatal(1,"overlap wait edges=%0d expected=%0d",overlap_edges,MISS_PENALTY+1);
                if (!CACHE_ON && BYPASS_WAIT>0 && overlap_edges != BYPASS_WAIT)
                    $fatal(1,"bypass overlap edges=%0d expected=%0d",overlap_edges,BYPASS_WAIT);
                if (CACHE_ON && !redirect_after_wait) $fatal(1,"taken branch did not redirect after miss wait");
                if (redirects!=1) $fatal(1,"expected one taken-branch redirect, got %0d",redirects);
                if (dut.rf.reg_file[3]!==5 || dut.rf.reg_file[2]!==0 || dut.rf.reg_file[4]!==7)
                    $fatal(1,"architectural result or wrong-path suppression failed");
                for (int r=0;r<32;r++) $fdisplay(state_fd,"x%0d=%08x",r,dut.rf.reg_file[r]);
                for (int m=0;m<512;m++) $fdisplay(state_fd,"m%0d=%08x",m,dut.dmem.memory[m]);
                $fclose(state_fd); $fclose(trace_fd); done=1;
                $display("CACHE_OVERLAP_RESULT,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                    CACHE_ON,LINES,VICTIM,BYPASS_WAIT,MISS_PENALTY,cycles,
                    overlap_edges,redirects,overlap_seen);
                $display("CACHE_OVERLAP_PASS,load=5,wrong_path_x2=0,target_x4=7");
                $finish;
            end
        join
    end
endmodule
