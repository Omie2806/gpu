module gpu_top (
    input logic clk,
    input logic reset
);
//pc 
logic [15 : 0] pc, pc_next;
pc pc_inst (
    .clk(clk),
    .reset(reset),
    .pc_next(pc_next),
    .pc(pc)
);

assign pc_next = pc + 16'd1;

//instr mem
logic[31 : 0] instr;
instr_mem instr_inst(
    .pc(pc),
    .instr(instr)
);

//register file
logic[3 : 0] A1, A2, A3;
logic[15 : 0] WD;
logic[15 : 0] block_idx, block_dim, thread_idx;
//contrl
logic we, reg_en;

//addr decoder
assign A1 = instr[3 : 0];
assign A2 = instr[7 : 4];
assign A3 = instr[11 : 8];

reg_file reg_inst(
    .clk(clk),
    .reset(reset),
    .A1(A1),
    .A2(A2),
    .A3(A3),
    .RS1(RS1),
    .RS2(RS2),
    .block_idx(block_idx),
    .block_dim(block_dim),
    .thread_idx(thread_idx),
    .WD(result_source_mux),

    //CONTRL
    .we(we),
    .reg_en(reg_en)
);

//control unit
logic [3 : 0] opcode;
logic alu_source = 0;
assign opcode = instr[15 : 12];
always @(*) begin
    alu_source = 0;
    we = 0;
    reg_en = 0;
    lsu_en = 0;
    result_source = 0;
    mem_write = 0;
    lw_or_sw = 0;
    alu_control = 4'b0000;
    case (opcode)
        4'b0000: begin //add
            alu_source = 0;
            alu_control = 4'b0000;
            we = 1;
            reg_en = 1;
            lsu_en = 0;
            result_source = 0;
        end
        4'b0001: begin //sub
            alu_source = 0;
            alu_control = 4'b0001;
            we = 1;
            reg_en = 1;
            lsu_en = 0;
            result_source = 0;
        end
        4'b0010: begin //mul
            alu_source = 0;
            alu_control = 4'b0010;
            we = 1;
            reg_en = 1;
            lsu_en = 0;
            result_source = 0;
        end
        4'b0011: begin //and
            alu_source = 0;
            alu_control = 4'b0011;
            we = 1;
            reg_en = 1;
            lsu_en = 0;
            result_source = 0;
        end
        4'b0100: begin //or
            alu_source = 0;
            alu_control = 4'b0100;
            we = 1;
            reg_en = 1;
            lsu_en = 0;
            result_source = 0;
        end
        4'b0101: begin //xor
            alu_source = 0;
            alu_control = 4'b0101;
            we = 1;
            reg_en = 1;
            lsu_en = 0;
            result_source = 0;
        end
        4'b0110: begin//lw
            alu_source = 1;
            alu_control = 4'b0000;
            we = 1;
            reg_en = 1;
            result_source = 1;
            lw_or_sw = 1;
            lsu_en = 1;
        end
        4'b0111: begin //sw
           alu_source = 1;
           alu_control = 4'b0000; 
           mem_write = 1;
           reg_en = 1;
           lw_or_sw = 0;
           lsu_en = 1;
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

//alu_source mux
logic[15 : 0] alu_source_mux;
assign alu_source_mux = alu_source ? imm_out : RS2;

//alu data path
logic [15 : 0] RS1, RS2, alu_result;
// control path
logic [3 : 0]  alu_control;
logic zero;
alu alu_inst (
    .A(RS1),
    .B(alu_source_mux),
    .alu_result(alu_result),
    .alu_control(alu_control),
    .zero(zero)
);

//lsu
//control
logic lw_or_sw, lsu_en;
logic[15 : 0] lw_out, sw_out, addr_out, lw_in;
//datapath
lsu lsu_inst (
    .lw_or_sw(lw_or_sw),
    .lsu_en(lsu_en),
    .addr_in(alu_result),
    .addr_out(addr_out),
    .lw_in(lw_in),
    .sw_in(RS2),
    .sw_out(sw_out),
    .lw_out(lw_out)
);

logic[15 : 0] result_source_mux;
logic result_source;
assign result_source_mux = result_source ? lw_out : alu_result;

//data_mem datapath
logic[15 : 0] addr;
logic[15 : 0] WD1;
logic[15 : 0] result;
//control
logic mem_write;

data_mem data_mem_inst (
    .clk(clk),
    .reset(reset),
    .WD1(sw_out),
    .addr(addr_out),
    .result(lw_in),
    .mem_write(mem_write)
);
    
endmodule
