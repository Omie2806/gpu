module gpu_top (
    input logic clk,
    input logic reset,
    output logic [15:0] debug_regs [0:3][0:15][0:15]
);


parameter NUMBER_OF_WARPS = 4;
logic mem_done;
logic[1 : 0] warp_id_from_ms;
logic[1 : 0] warp_id_to_ms;
logic[1 : 0] current_warp_id;
logic[15 : 0] warp_ready;
logic[15 : 0] warp_ready_mask;

warp_scheduler #(
    .NUMBER_OF_WARPS(NUMBER_OF_WARPS)
) warp_inst (
    .clk(clk),
    .reset(reset),
    .mem_req(mem_req),
    .mem_done(mem_done),
    .halt(halt),
    .warp_id_from_ms(warp_id_from_ms),
    .warp_id_to_ms(warp_id_to_ms),
    .warp_ready(warp_ready),
    .warp_ready_mask(warp_ready_mask),
    .current_warp_id(current_warp_id)
);


//instr mem
logic[31 : 0] instr;
instr_mem instr_inst(
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
logic[15 : 0] alu_source_mux [0 : 15];

//alu data path
logic [15 : 0] RS1 [0 : 15];
logic [15 : 0] RS2 [0 : 15];
logic [15 : 0] alu_result[0 : 15];
// control path
logic [3 : 0]  alu_control;
logic zero [0 : 15];

logic[15 : 0] result_source_mux [0 : 15];
logic[15 : 0] result_source_mux_warps [0 : NUMBER_OF_WARPS - 1][0 : 15];
logic result_source;

logic [15 : 0] RS1_warps [0 : NUMBER_OF_WARPS - 1][0 : 15];
logic [15 : 0] RS2_warps [0 : NUMBER_OF_WARPS - 1][0 : 15];

logic[3 : 0] lw_destination_out;
logic lw_ready;
logic[1 : 0] lw_warp_id;
genvar w,i;
generate

    for (w = 0; w < NUMBER_OF_WARPS; w++) begin: warp_array
        for(i = 0; i < 16; i++) begin: lane_array
        reg_file reg_inst(
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
        for(k = 0; k < 16; k++)begin
        alu alu_inst (
            .A(RS1[k]),
            .B(alu_source_mux[k]),
            .alu_result(alu_result[k]),
            .alu_control(alu_control),
            .zero(zero[k])
        );
        assign alu_source_mux[k]    = alu_source ? imm_out : RS2[k];
    end
    endgenerate

always @(*) begin
    for(integer k = 0; k < 16; k++) begin
        RS1[k] = RS1_warps[current_warp_id][k];
        RS2[k] = RS2_warps[current_warp_id][k];
    end
end

always @(*) begin
    for(integer w = 0; w < 4; w++)begin
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
    alu_control = 4'b0000;
    halt        = 0;
    mem_req_raw = 0;
    result_source = 0;
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
        4'b1000: begin
            halt = 1;
        end
    endcase
end
logic mem_req;
logic mem_req_raw;
logic mem_req_sent;

always_ff @(posedge clk) begin
    if(reset) begin
        mem_req_sent <= 0;
        mem_req_raw  <= 0;
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
