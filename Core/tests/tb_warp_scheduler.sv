`timescale 1ns/1ps

module tb_mem_system;


logic clk;
logic reset;
logic [3:0] request;
logic [15:0] active_mask;

logic [15:0] addr_in [0:15];
logic [15:0] sw_out  [0:15];
logic [15:0] lw_out  [0:15];

logic stall;
logic mem_write;

logic [15:0] addr_out;
logic [15:0] sw_out_mem;
logic [15:0] lw_in;

logic mem_req;
logic mem_done;
logic[1 : 0] warp_id_from_ws;
logic[1 : 0] warp_id_to_ws;

//warp scheduler
logic halt;
logic[1 : 0] warp_id_to_ms;

logic[1 : 0] warp_id_from_ms;
// logic done;
logic[15 : 0] warp_ready;
logic[15 : 0] warp_ready_mask;

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

mem_scheduler ms_dut(
    .clk(clk),
    .reset(reset),
    .request(request), //standalone
    .active_mask(warp_ready_mask),
    .addr_in(addr_in), //standalone
    .sw_out(sw_out), //standalone
    .lw_out(lw_out), 
    .stall(stall),
    .mem_write(mem_write), 
    .lw_in(lw_in), //standalone
    .addr_out(addr_out),
    .sw_out_mem(sw_out_mem),

    //warp scheduler 
    .mem_req(mem_req), //standalone
    .mem_done(mem_done),
    .warp_id_from_ws(warp_id_to_ms),
    .warp_id_to_ws(warp_id_from_ms)
);

warp_scheduler ws_dut(
    .clk(clk),
    .reset(reset),
    .mem_req(mem_req), //standalone
    .mem_done(mem_done),
    .halt(halt), //standalone
    .warp_ready(warp_ready),
    .warp_ready_mask(warp_ready_mask),
    .warp_id_from_ms(warp_id_from_ms),
    .warp_id_to_ms(warp_id_to_ms)
);

initial begin
    $dumpfile("gpu_mem.vcd");
    $dumpvars(0,tb_mem_system);

    reset   = 1;
    request = 4'b0000;
    lw_in   = 16'h0000;
    mem_req = 0;
    halt    = 0;
    for(int i = 0; i < 16; i++) begin
        addr_in[i] = 16'h0100 + i; 
        sw_out[i]  = 16'h00FF + i;  
    end
    repeat(4)@(posedge clk);
    reset = 0;

    //test 1 - execute warp 0 as sw
    repeat(2)@(posedge clk);
    mem_req = 1;
    request = 4'b0111;
    @(posedge clk);
    mem_req = 0;
    request = 4'b0000;
    repeat(49)@(posedge clk);
    halt = 1;

    //finish execute warp 3
    @(posedge clk);
    halt = 0;
    repeat(16)@(posedge clk);
    halt = 1;

        //finish execute warp 0
    @(posedge clk);
    halt = 0;
    repeat(16)@(posedge clk);
    halt = 1;

        //finish execute warp 4
    @(posedge clk);
    halt = 0;
    repeat(20)@(posedge clk);
    halt = 1;

    //test 2
    reset   = 1;
    request = 4'b0000;
    lw_in   = 16'h0000;
    mem_req = 0;
    halt    = 0;
    for(int i = 0; i < 16; i++) begin
        addr_in[i] = 16'h0100 + i; 
        sw_out[i]  = 16'h00FF + i;  
    end
    repeat(4)@(posedge clk);
    reset = 0;

    //test 2 warp 0 and warp 1 have sw
    @(posedge clk);
    mem_req = 1;
    request = 4'b0111;
    @(posedge clk);
    mem_req = 0;
    request = 4'b0000;

    //warp 1 has sw
    @(posedge clk);
    mem_req = 1;
    request = 4'b0111;
    @(posedge clk);
    mem_req = 0;
    request = 4'b0000;

    //let them complete while warp 2 runs
    repeat(100)@(posedge clk);
    halt = 1; //warp 2 finsih
    @(posedge clk);
    halt = 0; //warp 0 resums
    repeat(17)@(posedge clk);
    //warp 0 ends
    halt = 1;

    @(posedge clk);
    halt = 0; //warp 1 resumes
    repeat(17)@(posedge clk);
    halt = 1; //warp 1 ends

    @(posedge clk);
    halt = 0;//warp 3 resumes
    repeat(17)@(posedge clk);
    halt = 1;//warp 3 ends

    repeat(3)@(posedge clk);

    reset   = 1;
    request = 4'b0000;
    lw_in   = 16'h0000;
    mem_req = 0;
    halt    = 0;
    for(int i = 0; i < 16; i++) begin
        addr_in[i] = 16'h0100 + i; 
        sw_out[i]  = 16'h00FF + i;  
    end
    repeat(4)@(posedge clk);
    reset = 0;

    //test 4 all warps stall
    @(posedge clk); //warp 0 stall
    mem_req = 1;
    request = 4'b0111;
    @(posedge clk);
    mem_req = 0;
    request = 4'b0000;

    repeat(2)@(posedge clk); //warp 2 stall
    mem_req = 1;
    request = 4'b0111;
    @(posedge clk);
    mem_req = 0;
    request = 4'b0000;

    @(posedge clk); //warp 2 stall
    mem_req = 1;
    request = 4'b0111;
    @(posedge clk);
    mem_req = 0;
    request = 4'b0000;

    repeat(5)@(posedge clk); //warp 3 stall
    mem_req = 1;
    request = 4'b0111;
    @(posedge clk);
    mem_req = 0;
    request = 4'b0000;

    repeat(64)@(posedge clk);
    halt = 1; //warp 0 finishes
    @(posedge clk);

    halt = 0; //warp 1 continues
    repeat(48)@(posedge clk);
    halt = 1; //warp 1 finish
    @(posedge clk);

    halt = 0; //warp 2 continues
    repeat(48)@(posedge clk);
    halt = 1; //warp 2 finish
    @(posedge clk);

    halt = 0; //warp 3 continues
    repeat(48)@(posedge clk);
    halt = 1; //warp 3 finish
    @(posedge clk);


    $finish;
end
endmodule
