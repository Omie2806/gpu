`timescale 1ns/1ps

module tb_warp_scheduler;

    parameter NUMBER_OF_WARPS   = 4;
    parameter ADDR_WIDTH        = 16;
    parameter DATA_WIDTH        = 16;
    parameter NUMBER_OF_THREADS = 16;

     logic                                    clk; 
     logic                                    reset;
     logic                                    branch_eq;//tell if there is a branch instruction comes from the contrl unit
     logic                                    branch_lt;
     logic                                    zero[0 : NUMBER_OF_THREADS - 1]; //for beq and comes from the alu
     logic                                    less_than[0 : NUMBER_OF_THREADS - 1];
     logic                                    jump;
     logic[15 : 0]                            imm_out;//immediate to add with the pc for branch instruction 
     logic[ADDR_WIDTH - 1 : 0]                reconverge_pc;
     logic[NUMBER_OF_THREADS - 1 : 0]         warp_mask [0 : NUMBER_OF_WARPS - 1]; //initialize 
     logic[ADDR_WIDTH - 1 : 0]                warp_pc [0 : NUMBER_OF_WARPS - 1];  //initialize
     logic                                    mem_req; //from top check from opcode
     logic                                    mem_done; //from mem_scheduler
     logic                                    halt; //from top
     logic[$clog2(NUMBER_OF_WARPS) - 1 : 0]   warp_id_from_ms; //to memory_scheduler

     logic[$clog2(NUMBER_OF_WARPS) - 1 : 0]  warp_id_to_ms; //from memory_scheduler
     logic[ADDR_WIDTH - 1 : 0]               warp_ready; //pc of ready warp
     logic[NUMBER_OF_THREADS - 1 : 0]        warp_ready_mask;
    //  logic         done
     logic[$clog2(NUMBER_OF_WARPS) - 1 : 0]  current_warp_id;

warp_scheduler #(
    .NUMBER_OF_THREADS(NUMBER_OF_THREADS),
    .NUMBER_OF_WARPS(NUMBER_OF_WARPS),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) dut(
    .*
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin

    $dumpfile("warp_scheduler.vcd");
    $dumpvars(0, tb_warp_scheduler);

    reset    = 1;
    mem_req  = 0;
    mem_done = 0;
    halt     = 0;
    
    warp_pc[0] = 16'h0000;
    warp_mask[0] = 16'hFFFF;
    warp_pc[1] = 16'h0032;
    warp_mask[1] = 16'hFFFF;    
    warp_pc[2] = 16'h0064;
    warp_mask[2] = 16'hFFFF;    
    warp_pc[3] = 16'h0096;
    warp_mask[3] = 16'hFFFF;    

    repeat(3)@(posedge clk);
    reset = 0;

    @(posedge clk);
    branch_eq = 1;
    zero[0] = 1;
    zero[1] = 1; 
    zero[2] = 1;
    zero[3] = 1;
    zero[4] = 1;
    zero[5] = 1;
    zero[6] = 1;
    zero[7] = 1;

    zero[8] = 1;
    zero[9] = 1;
    zero[10] = 0;
    zero[11] = 0;
    zero[12] = 0;
    zero[13] = 0;
    zero[14] = 0;
    zero[15] = 0; 
    imm_out = 16'h0000_0008;
    reconverge_pc = 16'h0000_000F;
    @(posedge clk); 
    branch_eq = 0;
    repeat(3)@(posedge clk); 

    @(posedge clk);
    branch_eq = 1;
    zero[0] = 1;
    zero[1] = 1; 
    zero[2] = 1;
    zero[3] = 1;
    zero[4] = 1;
    zero[5] = 1;
    zero[6] = 1;
    zero[7] = 1;

    zero[8] = 0;
    zero[9] = 0;
    zero[10] = 0;
    zero[11] = 0;
    zero[12] = 0;
    zero[13] = 0;
    zero[14] = 0;
    zero[15] = 0; 
    imm_out = 16'h0000_0008;
    reconverge_pc = 16'h0000_000F;
    @(posedge clk); 
    branch_eq = 0;
    repeat(50)@(posedge clk);     

    @(posedge clk);
    branch_lt = 1;
    less_than[0] = 1;
    less_than[1] = 1; 
    less_than[2] = 1;
    less_than[3] = 1;
    less_than[4] = 0;
    less_than[5] = 0;
    less_than[6] = 0;
    less_than[7] = 0;

    less_than[8] = 0;
    less_than[9] = 0;
    less_than[10] = 0;
    less_than[11] = 0;
    less_than[12] = 0;
    less_than[13] = 0;
    less_than[14] = 0;
    less_than[15] = 0; 
    imm_out = 16'h0000_0004;
    reconverge_pc = 16'h0000_000B;
    @(posedge clk); 
    branch_lt = 0;   
    repeat(50)@(posedge clk); 

    $finish;

    
end

endmodule
