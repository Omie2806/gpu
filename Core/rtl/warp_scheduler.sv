module warp_scheduler #(
    parameter NUMBER_OF_WARPS = 4
) (
    input logic         clk, 
    input logic         reset,
    // input logic[15 : 0] warp_mask, //initialize 
    // input logic[15 : 0] warp_pc,  //initialize
    input logic         mem_req, //from top check from opcode
    input logic         mem_done, //from mem_scheduler
    input logic         halt, //from top
    input logic[1 : 0]  warp_id_from_ms, //to memory_scheduler

    output logic[1 : 0]  warp_id_to_ms, //from memory_scheduler
    output logic[15 : 0] warp_ready, //pc of ready warp
    output logic[15 : 0] warp_ready_mask,
    // output logic         done
    output logic[1 : 0] current_warp_id
);

reg[1 : 0] current_warp;

//warp table
reg[15 : 0] WARP_PC  [0 : NUMBER_OF_WARPS - 1];
reg[15 : 0] WARP_MASK[0 : NUMBER_OF_WARPS - 1];

reg WARP_STALL    [0 : NUMBER_OF_WARPS - 1];
reg WARP_FINISHED [0 : NUMBER_OF_WARPS - 1];

typedef enum logic [2 : 0] {
    IDLE            = 3'b000,
    REQUESTING      = 3'b001,
    WARP_DONE       = 3'b010
} state_t;

state_t state_curr;

logic pc_en;


always_ff @(posedge clk) begin
    if(reset) begin
        for(integer i = 0; i < NUMBER_OF_WARPS; i++) begin
            WARP_STALL[i]    <= 0;
            WARP_FINISHED[i] <= 0;
            WARP_MASK[i]     <= 16'hFFFF;  
        end
        current_warp       <= 2'b00;
        state_curr         <= IDLE;
        warp_id_to_ms      <= 2'b00;
        pc_en              <= 0;

        WARP_PC[0] <= 16'h0000;  // starts at 0  runs until HALT
        WARP_PC[1] <= 16'h0010;  // starts at 16 runs until HALT
        WARP_PC[2] <= 16'h0020;  // starts at 32 runs until HALT
        WARP_PC[3] <= 16'h0030;  // starts at 48 runs until HALT
    end
    else begin
        case (state_curr)
            IDLE: begin
                if(mem_req) begin
                    WARP_STALL[current_warp]   <= 1;
                    state_curr                 <= REQUESTING;
                end
                else if(mem_done) begin
                    WARP_STALL[warp_id_from_ms] <= 0;
                end
                else if(halt) begin
                    WARP_FINISHED[current_warp]    <= 1;
                    state_curr                     <= WARP_DONE;
                end
                else if(pc_en)begin
                    //update the pc
                    WARP_PC[current_warp] <= WARP_PC[current_warp] + 1;
                end
                else begin
                    pc_en <= 1;
                end
            end 
            REQUESTING: begin
                logic found = 0;
                for(integer i = 0; i < NUMBER_OF_WARPS; i++) begin
                    if(WARP_STALL[i] == 0 && found == 0 && WARP_FINISHED[i] == 0 && i != current_warp) begin // and dont increment i after getting a ready warp
                        current_warp <= i;
                        state_curr   <= IDLE;
                        found        = 1;
                    end
                end
                if(mem_done) begin   //if all stalled then wait for mem_done 
                    WARP_STALL[warp_id_from_ms] <= 0;
                end
            end
            WARP_DONE: begin
                logic found = 0;
                for(integer i = 0; i < NUMBER_OF_WARPS; i++) begin
                    if(WARP_STALL[i] == 0 && found == 0 && WARP_FINISHED[i] == 0 && i != current_warp) begin // and dont increment i after getting a ready warp
                        current_warp <= i;
                        state_curr   <= IDLE;
                        found        = 1;
                    end
                end
                if(mem_done) begin
                    WARP_STALL[warp_id_from_ms] <= 0;
                    WARP_PC[warp_id_from_ms] <= WARP_PC[warp_id_from_ms] + 1;
                end
            end
            default: state_curr <= IDLE;
        endcase
    end
end

    assign warp_id_to_ms   = current_warp;
    assign current_warp_id = current_warp;
    assign warp_ready      = WARP_PC[current_warp];
    assign warp_ready_mask = WARP_MASK[current_warp];
endmodule
