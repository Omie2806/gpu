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

//instr mem
logic[15 : 0] instr;
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
    .thread_idx(thread_idx)

    //CONTRL
    .we(we),
    .reg_en(reg_en)
);

//control unit
logic [3 : 0] opcode;
assign opcode = instr[14 : 12];
always @(*) begin
    case (opcode)
        3'b: 
        default: 
    endcase
end

//alu data path
logic [15 : 0] RS1, RS2, alu_result;
// control path
logic [2 : 0]  alu_contrl;
logic zero;
alu alu_inst (
    .A(RS1),
    .B(RS2),
    .alu_result(alu_result),
    .alu_control(alu_control),
    .zero(zero)
);
    
endmodule