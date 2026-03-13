module warp_scheduler #(
    parameter NUMBER_OF_WARPS = 4
) (
    input logic         clk, 
    input logic         reset,
    input logic[15 : 0] warp_mask,
    input logic[15 : 0] warp_pc,
    input logic         mem_req,
    input logic         mem_done,
    input logic[1 : 0]  warp_idx,
    input logic         halt,

    output logic[15 : 0] warp_ready, //pc of ready warp
    output logic[15 : 0] warp_ready_mask
);

logic        warp_stall;
logic[1 : 0] current_warp;
//warp table
reg[15 : 0] WARP_PC  [0 : NUMBER_OF_WARPS - 1];
reg[15 : 0] WARP_MASK[0 : NUMBER_OF_WARPS - 1];

reg        WARP_STALL [0 : NUMBER_OF_WARPS - 1];
reg[1 : 0] WARP_IDX   [0 : NUMBER_OF_WARPS - 1];

typedef enum logic [2 : 0] {
    IDLE            = 3'b000,
    REQUESTING      = 3'b001,
    MEMORY_REQ_DONE = 3'b010,
    WARP_DONE       = 3'b011
} state_t;

state_t state_curr;

always_ff @(posedge clk) begin
    if(reset) begin
        for(integer i = 0; i < NUMBER_OF_WARPS; i++) begin
            WARP_STALL[i] <= 0;
            WARP_PC[i]    <= warp_pc;
            WARP_MASK[i]  <= warp_mask;  
            WARP_IDX[i]   <= i;
        end
        current_warp  <= 2'b00;
    end
    else begin
        
    end
end
    
endmodule