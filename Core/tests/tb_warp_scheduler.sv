`timescale 1ns/1ps

module tb_warp_scheduler;

logic clk;
logic reset;
logic mem_req;
logic mem_done;
logic halt;
logic[1 : 0] warp_id_to_ms;

logic[1 : 0] warp_id_from_ms;
logic done;
logic[15 : 0] warp_ready;
logic[15 : 0] warp_ready_mask;

warp_scheduler dut(
    .clk(clk),
    .reset(reset),
    .mem_req(mem_req),
    .mem_done(mem_done),
    .halt(halt),
    .warp_id_from_ms(warp_id_from_ms),

    .warp_id_to_ms(warp_id_to_ms),
    .warp_ready(warp_ready),
    .warp_ready_mask(warp_ready_mask)
    // .done(done)
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
    
    repeat(3)@(posedge clk);
    reset = 0;

    //make mem_req high for 16 clk cycles
    //warp 0
    @(posedge clk);
    mem_req = 1;
    @(posedge clk);
    mem_req = 0;
    //then mem_done
    repeat(16)@(posedge clk);
    warp_id_from_ms = 0;
    mem_done = 1;
    @(posedge clk);
    mem_done = 0;
    //wait for warp to complete
    repeat(8)@(posedge clk);
    halt = 1;
    @(posedge clk); //warp 1 finished

    halt = 0; //picks up the next warp (warp 0 again)
    repeat(2)@(posedge clk);
    mem_req = 1; //warp 0 stall
    @(posedge clk);
    mem_req = 0; //selects another warp (warp 2)
    repeat(16)@(posedge clk);
    warp_id_from_ms = 0;
    mem_done = 1; //warp 0 unstalled
    @(posedge clk);
    mem_done = 0;
    repeat(2)@(posedge clk);
    halt = 1; //warp 2 completed
    @(posedge clk);

    
    halt = 0; //picks the next warp (warp 0 again)
    repeat(2)@(posedge clk);
    mem_req = 1; //warp 0 stalled
    @(posedge clk);
    mem_req = 0; //selects another warp (warp 3)
    repeat(16)@(posedge clk);
    warp_id_from_ms = 0; 
    mem_done = 1; //warp 0 unstalled
    @(posedge clk);
    mem_done = 0; 
    repeat(2)@(posedge clk);
    halt = 1; //warp 3 done


    @(posedge clk);
    halt = 0; //picks the next warp
    repeat(16)@(posedge clk);
    halt = 1;
    @(posedge clk); //warp 0 done

    //test 2 stall all warps and then unstall 
    reset = 1;
    mem_req  = 0;
    mem_done = 0;
    halt     = 0;

    repeat(3)@(posedge clk);
    reset = 0;
    
    @(posedge clk);
    mem_req = 1; //warp 0;
    @(posedge clk);
    mem_req = 0; 

    @(posedge clk);
    mem_req = 1; //warp 1;
    @(posedge clk);
    mem_req = 0; 

    @(posedge clk);
    mem_req = 1; //warp 2;
    @(posedge clk);
    mem_req = 0; 

    @(posedge clk);
    mem_req = 1; //warp 3;
    @(posedge clk);
    mem_req = 0;
    @(posedge clk); 

    //unstall warp 0
    @(posedge clk);
    mem_done = 1;
    warp_id_from_ms = 0;
    @(posedge clk);
    mem_done = 0;
    @(posedge clk);

    //unstall warp 1
    @(posedge clk);
    mem_done = 1;
    warp_id_from_ms = 1;
    @(posedge clk);
    mem_done = 0;
    @(posedge clk);
    //unstall warp 2
    @(posedge clk);
    mem_done = 1;
    warp_id_from_ms = 2;
    @(posedge clk);
    mem_done = 0;
    @(posedge clk);
    //unstall warp 3
    @(posedge clk);
    warp_id_from_ms = 3;
    mem_done = 1;
    @(posedge clk);
    mem_done = 0;
    @(posedge clk);

    //finish warp 0
    repeat(16)@(posedge clk);
    halt = 1;
    @(posedge clk);
    halt = 0;
    @(posedge clk);

        //finish warp 1
    repeat(16)@(posedge clk);
    halt = 1;
    @(posedge clk);
    halt = 0;
    @(posedge clk);

        //finish warp 2
    repeat(16)@(posedge clk);
    halt = 1;
    @(posedge clk);
    halt = 0;
    @(posedge clk);

        //finish warp 3
    repeat(16)@(posedge clk);
    halt = 1;
    @(posedge clk);
    halt = 0;
    @(posedge clk);

    $finish;
    
end

endmodule