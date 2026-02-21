module gpu_top (
    input logic clk,
    input logic reset
);

// DEBUG REGISTER MATRIX
logic [15:0] debug_regs [0:15][0:15];

//pc 
logic [15 : 0] pc, pc_next;
pc pc_inst (
    .clk(clk),
    .reset(reset),
    .pc_next(pc_next),
    .pc(pc)
);
assign pc_next = (stall ? pc : pc + 16'd1);

//instr mem
logic[31 : 0] instr;
instr_mem instr_inst(
    .pc(pc),
    .instr(instr)
);

//active mask
logic[15 : 0] active_mask;
initial active_mask = 16'hFFFF;

//register file
logic[3 : 0] A1, A2, A3;
logic[15 : 0] thread_idx;
//contrl
logic we, reg_en;

//addr decoder
assign A1 = instr[3 : 0];
assign A2 = instr[7 : 4];
assign A3 = instr[11 : 8];

//alu_source mux
logic[15 : 0] alu_source_mux [0 : 15];

//alu data path
logic [15 : 0] RS1 [0 : 15];
logic [15 : 0] RS2 [0 : 15];
logic [15 : 0] alu_result[0 : 15];
// control path
logic [3 : 0]  alu_control;
logic zero [0 : 15];

logic[15 : 0] result_source_mux [0 : 15];
logic result_source;

genvar i;
generate
    for (i = 0; i < 16; i++) begin: lane_array

        assign alu_source_mux[i]    = alu_source ? imm_out : RS2[i];
        assign result_source_mux[i] = result_source ? lw_out[i] : alu_result[i];

        reg_file reg_inst(
            .clk(clk),
            .reset(reset),
            .A1(A1),
            .A2(A2),
            .A3(A3),
            .RS1(RS1[i]),
            .RS2(RS2[i]),
            .block_idx(16'd0),
            .block_dim(16'd16),
            .thread_idx(16'(i)),
            .WD(result_source_mux[i]),

            //CONTRL
            .we(we && active_mask[i]),
            .reg_en(reg_en && active_mask[i])
        );

        alu alu_inst (
            .A(RS1[i]),
            .B(alu_source_mux[i]),
            .alu_result(alu_result[i]),
            .alu_control(alu_control),
            .zero(zero[i])
        );

        genvar r;
        for (r = 0; r < 16; r++) begin: debug_copy
            assign debug_regs[i][r] = reg_inst.REGISTER[r];
        end

    end
endgenerate

//mem_scheduler
logic[15 : 0] lw_out [0 : 15];
logic[15 : 0] addr_out, lw_in, sw_out_mem;
logic stall;

mem_scheduler scheduler_inst (
    //datapath
    .clk(clk),
    .reset(reset),
    .addr_in(alu_result),
    .sw_out(RS2),
    .lw_out(lw_out),
    .lw_in(lw_in),
    .addr_out(addr_out),
    .sw_out_mem(sw_out_mem),
    
    //control
    .mem_write(mem_write),
    .stall(stall),
    .request(opcode),
    .active_mask(active_mask)
);


// //datapath
// lsu lsu_inst (
//     .lw_or_sw(lw_or_sw),
//     .lsu_en(lsu_en),
//     .addr_in(alu_result[0]),
//     .addr_out(addr_out),
//     .lw_in(lw_in),
//     .sw_in(RS2[0]),
//     .sw_out(sw_out),
//     .lw_out(lw_out)
// );

//control unit
logic [3 : 0] opcode;
logic alu_source;
assign opcode = instr[15 : 12];
always @(*) begin
    alu_source = 0;
    we = 0;
    reg_en = 0;
    // lsu_en = 0;
    result_source = 0;
    // lw_or_sw = 0;
    alu_control = 4'b0000;
    case (opcode)
        4'b0000: begin //add
            alu_source = 0;
            alu_control = 4'b0000;
            we = 1;
            reg_en = 1;
            result_source = 0;
        end
        4'b0001: begin //sub
            alu_source = 0;
            alu_control = 4'b0001;
            we = 1;
            reg_en = 1;
            result_source = 0;
        end
        4'b0010: begin //mul
            alu_source = 0;
            alu_control = 4'b0010;
            we = 1;
            reg_en = 1;
            result_source = 0;
        end
        4'b0011: begin //and
            alu_source = 0;
            alu_control = 4'b0011;
            we = 1;
            reg_en = 1;
            result_source = 0;
        end
        4'b0100: begin //or
            alu_source = 0;
            alu_control = 4'b0100;
            we = 1;
            reg_en = 1;
            result_source = 0;
        end
        4'b0101: begin //xor
            alu_source = 0;
            alu_control = 4'b0101;
            we = 1;
            reg_en = 1;
            result_source = 0;
        end
        4'b0110: begin//lw
            alu_source = 1;
            alu_control = 4'b0000;
            we = 1;
            reg_en = 1;
            result_source = 1;
        end
        4'b0111: begin //sw
           alu_source = 1;
           alu_control = 4'b0000; 
           reg_en = 1;
//           mem_write = 1;
        end
    endcase
end

//imm_gen
logic[15 : 0] imm;
logic[15 : 0] imm_out;

assign imm = instr[31 : 16];

imm_gen imm_inst (
    .imm(imm),
    .imm_out(imm_out)
);

//data_mem 
//control
logic mem_write;

data_mem data_mem_inst (
    .clk(clk),
    .reset(reset),
    .WD1(sw_out_mem),
    .addr(addr_out),
    .result(lw_in),
    .mem_write(mem_write)
);
    
endmodule