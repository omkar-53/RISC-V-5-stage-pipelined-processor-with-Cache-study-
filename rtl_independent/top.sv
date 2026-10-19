`timescale 1ns/1ps

module top #(
    parameter int IMEM_WORDS = 256,
    parameter int DMEM_WORDS = 512,
    parameter bit CACHE_ENABLE = 1'b1,
    parameter int CACHE_NUM_LINES = 16,
    parameter int CACHE_MISS_PENALTY = 3,
    parameter bit CACHE_VICTIM_ENABLE = 1'b0,
    parameter int BYPASS_LOAD_STALL_CYCLES = 0
)(
    input  logic        clk,
    input  logic        reset,
    output logic [31:0]  alu_result_out,
    output logic        MemRW,
    output logic        reg_write_en,
    output logic        trap,
    output logic [31:0] data_mem_out,
    output logic        cache_hit,
    output logic        cache_miss,
    output logic        cache_stall,
    output logic [31:0] debug_cycle_count,
    output logic [31:0] debug_load_count,
    output logic [31:0] debug_store_count,
    output logic [31:0] debug_hit_count,
    output logic [31:0] debug_miss_count,
    output logic [31:0] debug_cache_stall_count,
    output logic [31:0] debug_redirect_count,
    output logic [31:0] debug_wb_value,
    output logic [4:0]  debug_wb_rd,
    output logic        debug_wb_commit
);
    localparam logic [31:0] NOP = 32'h00000013;

    logic [31:0] pc_out, pc_next, pc_plus4, instruction;
    logic [31:0] if_id_pc, if_id_instruction;
    logic if_id_valid;

    logic [6:0] opcode_ID, funct7_ID;
    logic [2:0] funct3_ID;
    logic [4:0] rs1_ID, rs2_ID, rd_ID, alu_op_ID;
    logic [31:0] rs1_value_ID, rs2_value_ID, immediate_ID;
    logic alu_src_ID, ASel_ID, reg_write_ID, mem_write_ID, mem_to_reg_ID;
    logic [1:0] pc_src_ID;
    logic unused_equal, unused_less;

    logic id_ex_valid;
    logic [31:0] id_ex_pc, id_ex_instruction, id_ex_rs1_value, id_ex_rs2_value, id_ex_imm;
    logic [4:0] id_ex_rs1, id_ex_rs2, id_ex_rd, id_ex_alu_op;
    logic [2:0] id_ex_funct3;
    logic id_ex_alu_src, id_ex_ASel, id_ex_reg_write, id_ex_mem_write, id_ex_mem_read;
    logic id_ex_mem_to_reg, id_ex_pc4_write, id_ex_trap;
    logic [1:0] id_ex_pc_src;

    logic [1:0] forwardA, forwardB;
    logic [31:0] forwardedA, forwardedB, ex_operandA, ex_operandB, ex_result;
    logic [31:0] ex_pc_target, ex_jalr_target;
    logic branch_equal, branch_less, branch_taken, redirect;
    logic [31:0] redirect_target;

    logic ex_mem_valid;
    logic [31:0] ex_mem_result, ex_mem_store_data, ex_mem_pc4;
    logic [4:0] ex_mem_rd;
    logic [2:0] ex_mem_funct3;
    logic ex_mem_reg_write, ex_mem_mem_write, ex_mem_mem_read, ex_mem_mem_to_reg;
    logic ex_mem_pc4_write, ex_mem_trap;

    logic [31:0] backing_read, cache_read, mem_read_value;
    logic mem_wb_valid;
    logic [31:0] mem_wb_result, mem_wb_load_value, mem_wb_pc4;
    logic [4:0] mem_wb_rd;
    logic mem_wb_reg_write, mem_wb_mem_to_reg, mem_wb_pc4_write;
    logic [31:0] writeback_value;
    logic wb_hold_committed;

    logic PCWrite, IF_ID_Write, control_mux_sel, IF_flush, pipeline_hold;
    logic load_dependency;
    logic [31:0] cycles, forward_cycles, loaduse_cycles, flush_cycles;
    logic [31:0] hit_cycles, miss_cycles, cache_stall_cycles;
    logic [31:0] load_count, store_count;
    logic load_completed, store_completed;

    program_counter pc_inst(.clk(clk), .rst(reset), .PCWrite(PCWrite), .pc_next(pc_next), .pc_out(pc_out));
    inst_mem #(.WORDS(IMEM_WORDS)) imem(.addr(pc_out), .inst(instruction));
    reg_file rf(.clk(clk), .write_en(reg_write_en), .rs1(rs1_ID), .rs2(rs2_ID), .rsW(mem_wb_rd),
                .write_data(writeback_value), .read_data1(rs1_value_ID), .read_data2(rs2_value_ID));
    imm_gen immediate_decode(.instruction(if_id_instruction), .imm_out(immediate_ID));
    control_unit decode_control(.opcode(opcode_ID), .funct3(funct3_ID), .funct7(funct7_ID),
                .equal(unused_equal), .lessThan(unused_less), .alu_src(alu_src_ID), .ASel(ASel_ID),
                .alu_op(alu_op_ID), .reg_write_en(reg_write_ID), .mem_write(mem_write_ID),
                .mem_to_reg(mem_to_reg_ID), .pc_src(pc_src_ID));
    fwd_logic forwarding(.ex_mem_reg_write(ex_mem_valid && ex_mem_reg_write), .ex_mem_rd(ex_mem_rd),
                .mem_wb_reg_write(mem_wb_valid && mem_wb_reg_write), .mem_wb_rd(mem_wb_rd),
                .id_ex_rs1(id_ex_rs1), .id_ex_rs2(id_ex_rs2), .forwardA(forwardA), .forwardB(forwardB));
    alu_logic execute_alu(.op1(ex_operandA), .op2(ex_operandB), .alu_op(id_ex_alu_op), .result(ex_result));
    branch_comp branch_compare(.a(forwardedA), .b(forwardedB), .BrUn(id_ex_funct3[1]),
                .BrEq(branch_equal), .BrLt(branch_less));
    data_mem #(.WORDS(DMEM_WORDS)) dmem(.clk(clk), .addr(ex_mem_result), .dataW(ex_mem_store_data), .funct3(ex_mem_funct3),
                .MemRW(ex_mem_valid && ex_mem_mem_write), .dataR(backing_read));
    l1_cache #(.NUM_LINES(CACHE_NUM_LINES), .MISS_PENALTY(CACHE_MISS_PENALTY),
                .CACHE_ENABLE(CACHE_ENABLE), .VICTIM_ENABLE(CACHE_VICTIM_ENABLE),
                .BYPASS_WAIT_CYCLES(BYPASS_LOAD_STALL_CYCLES)) cache(.clk(clk), .reset(reset),
                .request_valid(ex_mem_valid && (ex_mem_mem_read || ex_mem_mem_write)),
                .request_write(ex_mem_valid && ex_mem_mem_write), .address(ex_mem_result),
                .store_value(ex_mem_store_data), .access_size(ex_mem_funct3), .backing_value(backing_read),
                .read_value(cache_read), .cache_hit(cache_hit), .cache_miss(cache_miss), .cache_stall(cache_stall));

    always_comb begin
        opcode_ID = if_id_instruction[6:0];
        funct3_ID = if_id_instruction[14:12];
        funct7_ID = if_id_instruction[31:25];
        rs1_ID = if_id_instruction[19:15];
        rs2_ID = if_id_instruction[24:20];
        rd_ID = if_id_instruction[11:7];
        unused_equal = 1'b0;
        unused_less = 1'b0;

        unique case (forwardA)
            2'b10: forwardedA = ex_mem_pc4_write ? ex_mem_pc4 :
                                  (ex_mem_mem_to_reg ? mem_read_value : ex_mem_result);
            2'b01: forwardedA = writeback_value;
            default: forwardedA = id_ex_rs1_value;
        endcase
        unique case (forwardB)
            2'b10: forwardedB = ex_mem_pc4_write ? ex_mem_pc4 :
                                  (ex_mem_mem_to_reg ? mem_read_value : ex_mem_result);
            2'b01: forwardedB = writeback_value;
            default: forwardedB = id_ex_rs2_value;
        endcase

        // LUI adds its U-immediate to architectural zero; AUIPC selects PC.
        ex_operandA = (id_ex_instruction[6:0] == 7'b0110111) ? 32'b0 :
                      (id_ex_ASel ? id_ex_pc : forwardedA);
        ex_operandB = id_ex_alu_src ? id_ex_imm : forwardedB;
        ex_pc_target = id_ex_pc + id_ex_imm;
        ex_jalr_target = (forwardedA + id_ex_imm) & 32'hffff_fffe;

        branch_taken = 1'b0;
        if (id_ex_instruction[6:0] == 7'b1100011) begin
            unique case (id_ex_funct3)
                3'b000: branch_taken = branch_equal;
                3'b001: branch_taken = !branch_equal;
                3'b100: branch_taken = branch_less;
                3'b101: branch_taken = !branch_less;
                3'b110: branch_taken = branch_less;
                3'b111: branch_taken = !branch_less;
                default: branch_taken = 1'b0;
            endcase
        end
        redirect = id_ex_valid && !cache_stall &&
                   ((id_ex_instruction[6:0] == 7'b1100011 && branch_taken) ||
                    id_ex_instruction[6:0] == 7'b1101111 || id_ex_instruction[6:0] == 7'b1100111);
        redirect_target = (id_ex_instruction[6:0] == 7'b1100111) ? ex_jalr_target : ex_pc_target;
        pc_plus4 = pc_out + 32'd4;
        pc_next = redirect ? redirect_target : pc_plus4;

        load_dependency = id_ex_valid && id_ex_mem_read && (id_ex_rd != 0) && if_id_valid &&
                          ((id_ex_rd == rs1_ID) || (id_ex_rd == rs2_ID));
        // Count a load/store once when the request can leave EX/MEM. A held
        // request during a miss is not counted repeatedly.
        load_completed = ex_mem_valid && ex_mem_mem_read && !cache_stall;
        store_completed = ex_mem_valid && ex_mem_mem_write && !cache_stall;
        control_mux_sel = load_dependency;
        pipeline_hold = cache_stall;
        PCWrite = !pipeline_hold && !load_dependency;
        IF_ID_Write = !pipeline_hold && !load_dependency;
        IF_flush = redirect;

        mem_read_value = (ex_mem_mem_read && ex_mem_funct3 == 3'b010 && ex_mem_result[1:0] == 0)
                         ? cache_read : backing_read;
        writeback_value = mem_wb_pc4_write ? mem_wb_pc4 :
                          (mem_wb_mem_to_reg ? mem_wb_load_value : mem_wb_result);
        alu_result_out = ex_result;
        MemRW = ex_mem_valid && ex_mem_mem_write;
        // During a blocking-cache miss, hold the WB payload for forwarding to
        // the stalled EX instruction. Commit it once, not once per miss cycle.
        reg_write_en = mem_wb_valid && mem_wb_reg_write && !reset && !wb_hold_committed;
        data_mem_out = mem_read_value;
        trap = id_ex_valid && id_ex_trap;
        debug_wb_value = writeback_value;
        debug_wb_rd = mem_wb_rd;
        debug_wb_commit = reg_write_en;
        debug_cycle_count = cycles;
        debug_load_count = load_count;
        debug_store_count = store_count;
        debug_hit_count = hit_cycles;
        debug_miss_count = miss_cycles;
        debug_cache_stall_count = cache_stall_cycles;
        debug_redirect_count = flush_cycles;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            if_id_valid <= 1'b0;
            if_id_pc <= '0;
            if_id_instruction <= NOP;
            id_ex_valid <= 1'b0;
            id_ex_pc <= '0; id_ex_instruction <= NOP; id_ex_rs1_value <= '0; id_ex_rs2_value <= '0; id_ex_imm <= '0;
            id_ex_rs1 <= '0; id_ex_rs2 <= '0; id_ex_rd <= '0; id_ex_alu_op <= '0; id_ex_funct3 <= '0;
            id_ex_alu_src <= 1'b0; id_ex_ASel <= 1'b0; id_ex_reg_write <= 1'b0;
            id_ex_mem_write <= 1'b0; id_ex_mem_read <= 1'b0; id_ex_mem_to_reg <= 1'b0;
            id_ex_pc_src <= '0; id_ex_pc4_write <= 1'b0; id_ex_trap <= 1'b0;
            ex_mem_valid <= 1'b0; ex_mem_result <= '0; ex_mem_store_data <= '0; ex_mem_pc4 <= '0;
            ex_mem_rd <= '0; ex_mem_funct3 <= '0; ex_mem_reg_write <= 1'b0; ex_mem_mem_write <= 1'b0;
            ex_mem_mem_read <= 1'b0; ex_mem_mem_to_reg <= 1'b0; ex_mem_pc4_write <= 1'b0; ex_mem_trap <= 1'b0;
            mem_wb_valid <= 1'b0; mem_wb_result <= '0; mem_wb_load_value <= '0; mem_wb_pc4 <= '0;
            mem_wb_rd <= '0; mem_wb_reg_write <= 1'b0; mem_wb_mem_to_reg <= 1'b0; mem_wb_pc4_write <= 1'b0;
            wb_hold_committed <= 1'b0;
            cycles <= '0; forward_cycles <= '0; loaduse_cycles <= '0; flush_cycles <= '0;
            hit_cycles <= '0; miss_cycles <= '0; cache_stall_cycles <= '0;
            load_count <= '0; store_count <= '0;
        end else begin
            cycles <= cycles + 1'b1;
            if (forwardA != 0 || forwardB != 0) forward_cycles <= forward_cycles + 1'b1;
            if (control_mux_sel) loaduse_cycles <= loaduse_cycles + 1'b1;
            if (IF_flush) flush_cycles <= flush_cycles + 1'b1;
            if (cache_hit) hit_cycles <= hit_cycles + 1'b1;
            if (cache_miss) miss_cycles <= miss_cycles + 1'b1;
            if (cache_stall) cache_stall_cycles <= cache_stall_cycles + 1'b1;
            if (load_completed) load_count <= load_count + 1'b1;
            if (store_completed) store_count <= store_count + 1'b1;

            if (cache_stall) begin
                if (reg_write_en) wb_hold_committed <= 1'b1;
            end else begin
                wb_hold_committed <= 1'b0;
                mem_wb_valid <= ex_mem_valid;
                mem_wb_result <= ex_mem_result;
                mem_wb_load_value <= mem_read_value;
                mem_wb_pc4 <= ex_mem_pc4;
                mem_wb_rd <= ex_mem_rd;
                mem_wb_reg_write <= ex_mem_reg_write;
                mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
                mem_wb_pc4_write <= ex_mem_pc4_write;

                // The redirecting control-transfer instruction still retires;
                // only younger instructions are flushed from IF/ID and ID/EX.
                ex_mem_valid <= id_ex_valid;
                ex_mem_result <= ex_result;
                ex_mem_store_data <= forwardedB;
                ex_mem_pc4 <= id_ex_pc + 32'd4;
                ex_mem_rd <= id_ex_rd;
                ex_mem_funct3 <= id_ex_funct3;
                ex_mem_reg_write <= id_ex_reg_write;
                ex_mem_mem_write <= id_ex_mem_write;
                ex_mem_mem_read <= id_ex_mem_read;
                ex_mem_mem_to_reg <= id_ex_mem_to_reg;
                ex_mem_pc4_write <= id_ex_pc4_write;
                ex_mem_trap <= id_ex_trap;

                if (redirect) begin
                    if_id_valid <= 1'b0;
                    if_id_instruction <= NOP;
                    id_ex_valid <= 1'b0;
                    id_ex_instruction <= NOP;
                    id_ex_reg_write <= 1'b0; id_ex_mem_write <= 1'b0; id_ex_mem_read <= 1'b0;
                    id_ex_mem_to_reg <= 1'b0; id_ex_pc4_write <= 1'b0; id_ex_trap <= 1'b0;
                end else if (load_dependency) begin
                    id_ex_valid <= 1'b0;
                    id_ex_instruction <= NOP;
                    id_ex_reg_write <= 1'b0; id_ex_mem_write <= 1'b0; id_ex_mem_read <= 1'b0;
                    id_ex_mem_to_reg <= 1'b0; id_ex_pc4_write <= 1'b0; id_ex_trap <= 1'b0;
                end else begin
                    if_id_valid <= 1'b1;
                    if_id_pc <= pc_out;
                    if_id_instruction <= instruction;
                    id_ex_valid <= if_id_valid;
                    id_ex_pc <= if_id_pc;
                    id_ex_instruction <= if_id_instruction;
                    id_ex_rs1_value <= rs1_value_ID;
                    id_ex_rs2_value <= rs2_value_ID;
                    id_ex_imm <= immediate_ID;
                    id_ex_rs1 <= rs1_ID; id_ex_rs2 <= rs2_ID; id_ex_rd <= rd_ID;
                    id_ex_alu_op <= alu_op_ID; id_ex_funct3 <= funct3_ID;
                    id_ex_alu_src <= alu_src_ID; id_ex_ASel <= ASel_ID;
                    id_ex_reg_write <= reg_write_ID && if_id_valid;
                    id_ex_mem_write <= mem_write_ID && if_id_valid;
                    id_ex_mem_read <= (opcode_ID == 7'b0000011) && if_id_valid;
                    id_ex_mem_to_reg <= mem_to_reg_ID && if_id_valid;
                    id_ex_pc_src <= pc_src_ID;
                    id_ex_pc4_write <= (opcode_ID == 7'b1101111 || opcode_ID == 7'b1100111) && if_id_valid;
                    id_ex_trap <= (opcode_ID == 7'b1110011) && if_id_valid;
                end
            end
        end
    end
endmodule
