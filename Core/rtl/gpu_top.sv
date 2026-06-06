module gpu_top (
    input logic clk,
    input logic reset,
    input logic [3:0] lane_select,
    input logic[15 : 0] warp_mask [0 : 3], 
    input logic[15 : 0] warp_pc [0 : 3],
    output logic [15:0] debug_pc,     // preserves warp scheduler PC
    output logic [15:0] debug_regs [0:3][0:15][0:15],  // exposes register file
    output logic [15:0] debug_lw_out,    // exposes lw_out path  // preserves mem_req signal
    output logic [15:0] debug_alu_result
);

parameter NUMBER_OF_WARPS   = 4;
parameter ADDR_WIDTH        = 16;
parameter DATA_WIDTH        = 16;
parameter NUMBER_OF_THREADS = 16;

logic mem_done;
logic[$clog2(NUMBER_OF_WARPS) - 1 : 0] warp_id_from_ms;
logic[$clog2(NUMBER_OF_WARPS) - 1 : 0] warp_id_to_ms;
logic[$clog2(NUMBER_OF_WARPS) - 1 : 0] current_warp_id;
logic[ADDR_WIDTH - 1 : 0] warp_ready;
logic[NUMBER_OF_THREADS - 1 : 0] warp_ready_mask;
logic branch_eq; //for branch equal instruction
logic branch_lt; //for branch less than instruction
logic jump; //unconditional jump
logic[15 : 0] reconverge_pc;

warp_scheduler #(
    .NUMBER_OF_THREADS(NUMBER_OF_THREADS),
    .NUMBER_OF_WARPS(NUMBER_OF_WARPS),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) warp_inst (
    .clk(clk),
    .reset(reset),
    .mem_req(mem_req),
    .mem_done(mem_done),
    .zero(zero), //for now no divergence (im using this for testing only will get all alu results as 0)
    .less_than(less_than), //same for now i assume no divergence
    .branch_eq(branch_eq),
    .branch_lt(branch_lt),
    .jump(jump), //all active threads will jump no conditions 
    .imm_out(imm_out),
    .reconverge_pc(reconverge_pc),
    .halt(halt),
    .warp_id_from_ms(warp_id_from_ms),
    .warp_pc(warp_pc),
    .warp_mask(warp_mask),
    .warp_id_to_ms(warp_id_to_ms),
    .warp_ready(warp_ready),
    .warp_ready_mask(warp_ready_mask),
    .current_warp_id(current_warp_id)
);

//instr mem
logic[31 : 0] instr;
instr_mem #(
    .NUMBER_OF_THREADS(NUMBER_OF_THREADS),
    .NUMBER_OF_WARPS(NUMBER_OF_WARPS),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)    
) instr_inst (
    .clk(clk),
    .pc(warp_ready),
    .instr(instr)
);


//register file
logic[3 : 0] A1, A2, A3;
logic[15 : 0] thread_idx;
//contrl
logic reg_we, reg_en;

//addr decoder
assign A1 = instr[3 : 0];
assign A2 = instr[7 : 4];
assign A3 = instr[11 : 8];

//alu_source mux
logic[DATA_WIDTH - 1 : 0] alu_source_mux [0 : NUMBER_OF_THREADS - 1];

//alu data path
logic [DATA_WIDTH - 1 : 0] RS1 [0 : NUMBER_OF_THREADS - 1];
logic [DATA_WIDTH - 1 : 0] RS2 [0 : NUMBER_OF_THREADS - 1];
logic [DATA_WIDTH - 1 : 0] alu_result[0 : NUMBER_OF_THREADS - 1];
// control path
logic [3 : 0]  alu_control;
logic[0 : NUMBER_OF_THREADS - 1] zero;
logic[0 : NUMBER_OF_THREADS - 1] less_than;

logic[DATA_WIDTH - 1 : 0] result_source_mux [0 : NUMBER_OF_THREADS - 1];
logic[DATA_WIDTH - 1 : 0] result_source_mux_warps [0 : NUMBER_OF_WARPS - 1][0 : NUMBER_OF_THREADS - 1];
logic result_source;

logic [DATA_WIDTH - 1 : 0] RS1_warps [0 : NUMBER_OF_WARPS - 1][0 : NUMBER_OF_THREADS - 1];
logic [DATA_WIDTH - 1 : 0] RS2_warps [0 : NUMBER_OF_WARPS - 1][0 : NUMBER_OF_THREADS - 1];

logic[3 : 0] lw_destination_out;
logic lw_ready;
logic[$clog2(NUMBER_OF_WARPS) - 1 : 0] lw_warp_id;
genvar w,i;
generate

    for (w = 0; w < NUMBER_OF_WARPS; w++) begin: warp_array
        for(i = 0; i < NUMBER_OF_THREADS; i++) begin: lane_array
        reg_file #(
            .NUMBER_OF_THREADS(NUMBER_OF_THREADS),
            .NUMBER_OF_WARPS(NUMBER_OF_WARPS),
            .ADDR_WIDTH(ADDR_WIDTH),
            .DATA_WIDTH(DATA_WIDTH)    
        ) reg_inst(
            .clk(clk),
            .reset(reset),
            .A1(A1),
            .A2(A2),
            .A3((lw_ready && (w == lw_warp_id)) ? lw_destination_out : A3),
            .RS1(RS1_warps[w][i]),
            .RS2(RS2_warps[w][i]),
            .block_idx(16'd0),
            .block_dim(16'd16),
            .thread_idx(16'(i)),
            .WD(result_source_mux_warps[w][i]),

            //CONTRL
            .we((reg_we && warp_ready_mask[i] && !mem_req && (w == current_warp_id))
                 || (lw_ready && warp_ready_mask[i] && (w == lw_warp_id))),
            .reg_en(reg_en && warp_ready_mask[i] && (w == current_warp_id))
        );
        genvar r;
        for(r = 0; r < 16; r++) begin: debug_copy
            assign debug_regs[w][i][r] = reg_inst.REGISTER[r];
            end
        end
    end
endgenerate

    genvar k;
    generate
        for(k = 0; k < NUMBER_OF_THREADS; k++)begin
        alu #(
            .NUMBER_OF_THREADS(NUMBER_OF_THREADS),
            .NUMBER_OF_WARPS(NUMBER_OF_WARPS),
            .ADDR_WIDTH(ADDR_WIDTH),
            .DATA_WIDTH(DATA_WIDTH)
        ) alu_inst (
            .A(RS1[k]),
            .B(alu_source_mux[k]),
            .alu_result(alu_result[k]),
            .alu_control(alu_control),
            .zero(zero[k]),
            .less_than(less_than[k])
        );
        assign alu_source_mux[k]    = alu_source ? imm_out : RS2[k];
    end
    endgenerate

always @(*) begin
    for(integer k = 0; k < NUMBER_OF_THREADS; k++) begin
        RS1[k] = RS1_warps[current_warp_id][k];
        RS2[k] = RS2_warps[current_warp_id][k];
    end
end

always @(*) begin
    for(integer w = 0; w < NUMBER_OF_WARPS; w++)begin
        for(integer i = 0; i < 16; i++)begin
            if(lw_ready) begin
            result_source_mux_warps[w][i] = lw_out[i];
            end else begin
            result_source_mux_warps[w][i] = alu_result[i];
            end
        end
    end
end

//mem_scheduler
logic[DATA_WIDTH - 1 : 0] lw_out [0 : NUMBER_OF_THREADS - 1];
logic[DATA_WIDTH - 1 : 0] addr_out, lw_in, sw_out_mem;
logic stall;


mem_scheduler #(
    .NUMBER_OF_THREADS(NUMBER_OF_THREADS),
    .NUMBER_OF_WARPS(NUMBER_OF_WARPS),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) scheduler_inst (
    //datapath
    .clk(clk),
    .reset(reset),
    .addr_in(alu_result),
    .sw_out(RS2),
    .lw_out(lw_out),
    .lw_in(lw_in),
    .addr_out(addr_out),
    .sw_out_mem(sw_out_mem),
    .active_mask(warp_ready_mask),
    
    //control
    .mem_write(mem_write),
    // .stall(stall),
    .request(opcode),
    .mem_req(mem_req),
    .mem_done(mem_done),

    //warp scheduler
    .warp_id_from_ws(warp_id_to_ms),
    .warp_id_to_ws(warp_id_from_ms),
    // .current_warp_id(current_warp_id)

    //lw
    .lw_warp_id(lw_warp_id),
    .lw_ready(lw_ready),
    .lw_destination(A3),
    .lw_destination_out(lw_destination_out)
);


//control unit
logic [3 : 0] opcode;
logic alu_source;
assign opcode = instr[15 : 12];

logic halt;
always @(*) begin
    alu_source = 0;
    reg_we = 0;
    reg_en = 0;
    // lsu_en = 0;
    // lw_or_sw = 0;
    mem_req_raw = 0;
    alu_control = 4'b0000;
    halt        = 0;
    result_source = 0;
    branch_eq = 0;
    branch_lt = 0;
    jump = 0;
    case (opcode)
        4'b0000: begin //add
            alu_source = 0;
            alu_control = 4'b0000;
            reg_we = 1;
            reg_en = 1;
        end
        4'b0001: begin //sub
            alu_source = 0;
            alu_control = 4'b0001;
            reg_we = 1;
            reg_en = 1;
        end
        4'b0010: begin //mul
            alu_source = 0;
            alu_control = 4'b0010;
            reg_we = 1;
            reg_en = 1;
        end
        4'b0011: begin //and
            alu_source = 0;
            alu_control = 4'b0011;
            reg_we = 1;
            reg_en = 1;
        end
        4'b0100: begin //or
            alu_source = 0;
            alu_control = 4'b0100;
            reg_we = 1;
            reg_en = 1;
        end
        4'b0101: begin //xor
            alu_source = 0;
            alu_control = 4'b0101;
            reg_we = 1;
            reg_en = 1;
        end
        4'b0110: begin//lw
            alu_source = 1;
            alu_control = 4'b0000;
            // reg_we = 1;
            reg_en = 1;
            mem_req_raw = 1;
            result_source = 1;
        end
        4'b0111: begin //sw
           alu_source = 1;
           alu_control = 4'b0000; 
           reg_en = 1;
//           mem_write = 1;
            mem_req_raw = 1;
        end
        4'b1000: begin //addi
            alu_source = 1;
            alu_control = 4'b0000;
            reg_we = 1;
            reg_en = 1;            
        end
        4'b1001: begin //subi
            alu_source = 1;
            alu_control = 4'b0001;
            reg_we = 1;
            reg_en = 1;
        end
        4'b1010: begin //beq
            alu_source = 0;
            alu_control = 4'b0001;
            branch_eq = 1;
            reg_en = 1;
        end
        4'b1011: begin //blt
            alu_source = 0;
            alu_control = 4'b0001;
            branch_lt = 1;
            reg_en = 1;
        end
        4'b1100: begin //jump
            alu_source = 1;
            alu_control = 4'b0000;
            jump = 1;
            reg_en = 1;
        end
        4'b1111: begin
            halt = 1;
        end
    endcase
end
logic mem_req;
logic mem_req_raw;
logic mem_req_sent;

always_ff @(posedge clk) begin
    if(reset) begin
        mem_req_sent  <= 0;
    end
    else begin
        if(mem_req_raw && !mem_req_sent) begin
            mem_req_sent <= 1;
        end
        else if(!mem_req_raw) begin
            mem_req_sent <= 0;
        end
    end
end

assign mem_req = mem_req_raw && !mem_req_sent;

//imm_gen
logic[15 : 0] imm;
logic[15 : 0] imm_out;

assign imm = instr[31 : 16];

imm_gen imm_inst (
    .imm(imm),
    .branch(branch_eq || branch_lt),
    .jump(jump),
    .reconverge_pc(reconverge_pc),
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

assign debug_pc = warp_ready[lane_select];
assign debug_lw_out = lw_out[lane_select];
assign debug_alu_result = alu_result[lane_select];

    
endmodule
