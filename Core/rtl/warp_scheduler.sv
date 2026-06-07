module warp_scheduler #(
    parameter NUMBER_OF_WARPS   = 4,
    parameter ADDR_WIDTH        = 16,
    parameter DATA_WIDTH        = 16,
    parameter NUMBER_OF_THREADS = 16
) (
    input logic                                    clk, 
    input logic                                    reset,
    input logic                                    branch_eq,//tell if there is a branch instruction comes from the contrl unit
    input logic                                    branch_lt,
    input logic[0 : NUMBER_OF_THREADS - 1]         zero, //for beq and comes from the alu
    input logic[0 : NUMBER_OF_THREADS - 1]         less_than,
    input logic                                    jump,
    input logic[15 : 0]                            imm_out,//immediate to add with the pc for branch instruction 
    input logic[15 : 0]                            reconverge_pc,
    input logic[NUMBER_OF_THREADS - 1 : 0]         warp_mask [0 : NUMBER_OF_WARPS - 1], //initialize 
    input logic[ADDR_WIDTH - 1 : 0]                warp_pc [0 : NUMBER_OF_WARPS - 1],  //initialize
    input logic                                    mem_req, //from top check from opcode
    input logic                                    mem_done, //from mem_scheduler
    input logic                                    halt, //from top
    input logic[$clog2(NUMBER_OF_WARPS) - 1 : 0]   warp_id_from_ms, //to memory_scheduler

    output logic[$clog2(NUMBER_OF_WARPS) - 1 : 0]  warp_id_to_ms, //from memory_scheduler
    output logic[ADDR_WIDTH - 1 : 0]               warp_ready, //pc of ready warp
    output logic[NUMBER_OF_THREADS - 1 : 0]        warp_ready_mask,
    // output logic         done
    output logic[$clog2(NUMBER_OF_WARPS) - 1 : 0]  current_warp_id
);

localparam STACK_DEPTH = 8; //per warp

reg[$clog2(NUMBER_OF_WARPS) - 1: 0] current_warp;

//warp table
reg[ADDR_WIDTH - 1 : 0]        WARP_PC     [0 : NUMBER_OF_WARPS - 1][0 : STACK_DEPTH - 1];
reg[ADDR_WIDTH - 1 : 0]        RECON_PC    [0 : NUMBER_OF_WARPS - 1][0 : STACK_DEPTH - 1];
reg[NUMBER_OF_THREADS - 1 : 0] WARP_MASK   [0 : NUMBER_OF_WARPS - 1][0 : STACK_DEPTH - 1];
reg                            BRANCH_VALID[0 : NUMBER_OF_WARPS - 1][0 : STACK_DEPTH - 1];

reg WARP_STALL    [0 : NUMBER_OF_WARPS - 1];
reg WARP_FINISHED [0 : NUMBER_OF_WARPS - 1];

logic[$clog2(STACK_DEPTH) - 1 : 0] stack_pointer[NUMBER_OF_WARPS - 1 : 0];
logic[$clog2(STACK_DEPTH) - 1 : 0] stack_pointer_internal;

typedef enum logic [2 : 0] {
    IDLE            = 3'b000,
    // FETCH           = 3'b001,
    REQUESTING      = 3'b001,
    WARP_DONE       = 3'b010
} state_t;

state_t state_curr;

logic pc_en;

always_ff @(posedge clk) begin
    if(reset) begin
        for(integer i = 0; i < NUMBER_OF_WARPS; i++) begin
            for(integer j = 1; j < STACK_DEPTH; j++) begin
                WARP_STALL[i]       <= 0;
                WARP_FINISHED[i]    <= 0;
                WARP_MASK[i][j]     <= 0; //set mask and pc for stack > 0 as 0 in reset
                WARP_PC[i][j]       <= 0;  
                RECON_PC[i][j]      <= 0;
                BRANCH_VALID[i][j]  <= 0;    
            end
            WARP_PC[i][0]      <= warp_pc[i];
            WARP_MASK[i][0]    <= warp_mask[i];
            RECON_PC[i][0]     <= 16'hFFFF;
            BRANCH_VALID[i][0] <= 0;
            stack_pointer[i]   <= 0;
        end
        current_warp           <= 2'b00;
        state_curr             <= IDLE;
        pc_en                  <= 0;
        stack_pointer_internal <= 0;
        //ill now have to extend each warps instruction storage size due to branch instructions 
        //also ill make each warp instr buffer size dynamic(receive it from the compiler)
        //and the mask too
        // WARP_PC[0] <= 16'h0000;  // starts at 0  runs until HALT
        // WARP_PC[1] <= 16'h0010;  // starts at 16 runs until HALT
        // WARP_PC[2] <= 16'h0020;  // starts at 32 runs until HALT
        // WARP_PC[3] <= 16'h0030;  // starts at 48 runs until HALT
    end
    else begin
        case (state_curr)
            IDLE: begin
                if(mem_req) begin
                    WARP_STALL[current_warp]   <= 1;
                    state_curr                 <= REQUESTING;
                    WARP_PC[warp_id_from_ms][stack_pointer[current_warp]] <= WARP_PC[warp_id_from_ms][stack_pointer[current_warp]] + 1;
                end
                else if(mem_done) begin
                    WARP_STALL[warp_id_from_ms] <= 0;
                end
                else if(halt) begin
                    WARP_FINISHED[current_warp]    <= 1;
                    state_curr                     <= WARP_DONE;
                end
                else if(pc_en && branch_eq && (&zero == 0)) begin
                    if(BRANCH_VALID[current_warp][stack_pointer[current_warp] + 1] == 0) begin
                        //taken branch
                        WARP_PC[current_warp][stack_pointer[current_warp] + 1] <= WARP_PC[current_warp][stack_pointer[current_warp]] + imm_out;
                        RECON_PC[current_warp][stack_pointer[current_warp] + 1] <= WARP_PC[current_warp][stack_pointer[current_warp]] + reconverge_pc;
                        BRANCH_VALID[current_warp][stack_pointer[current_warp] + 1] <= 1; 
                        WARP_PC[current_warp][stack_pointer[current_warp]] <= WARP_PC[current_warp][stack_pointer[current_warp]] + reconverge_pc + 1;                   
                    end

                    if(BRANCH_VALID[current_warp][stack_pointer[current_warp] + 2] == 0) begin
                        //not taken branch
                        WARP_PC[current_warp][stack_pointer[current_warp] + 2] <= WARP_PC[current_warp][stack_pointer[current_warp]] + 1;
                        RECON_PC[current_warp][stack_pointer[current_warp] + 2] <= WARP_PC[current_warp][stack_pointer[current_warp]] + reconverge_pc;
                        BRANCH_VALID[current_warp][stack_pointer[current_warp] + 2] <= 1;
                    end
                    for(integer i = 0; i < NUMBER_OF_THREADS; i++) begin
                        WARP_MASK[current_warp][stack_pointer[current_warp] + 1][i] <= (zero[i] & (WARP_MASK[current_warp][stack_pointer[current_warp]][i]));
                    end
                    for(integer i = 0; i < NUMBER_OF_THREADS; i++) begin
                        WARP_MASK[current_warp][stack_pointer[current_warp] + 2][i] <= (!zero[i] & (WARP_MASK[current_warp][stack_pointer[current_warp]][i]));
                    end

                    stack_pointer[current_warp] <= stack_pointer[current_warp] + 2;
                end
                else if(pc_en && branch_lt && (&less_than == 0)) begin
                    if(BRANCH_VALID[current_warp][stack_pointer[current_warp] + 1] == 0) begin
                        //taken branch
                        WARP_PC[current_warp][stack_pointer[current_warp] + 1] <= WARP_PC[current_warp][stack_pointer[current_warp]] + imm_out;
                        RECON_PC[current_warp][stack_pointer[current_warp] + 1] <= WARP_PC[current_warp][stack_pointer[current_warp]] + reconverge_pc;
                        BRANCH_VALID[current_warp][stack_pointer[current_warp] + 1] <= 1; 
                        WARP_PC[current_warp][stack_pointer[current_warp]] <= WARP_PC[current_warp][stack_pointer[current_warp]] + reconverge_pc + 1;                   
                    end

                    if(BRANCH_VALID[current_warp][stack_pointer[current_warp] + 2] == 0) begin
                        //not taken branch
                        WARP_PC[current_warp][stack_pointer[current_warp] + 2] <= WARP_PC[current_warp][stack_pointer[current_warp]] + 1;
                        RECON_PC[current_warp][stack_pointer[current_warp] + 2] <= WARP_PC[current_warp][stack_pointer[current_warp]] + reconverge_pc;
                        BRANCH_VALID[current_warp][stack_pointer[current_warp] + 2] <= 1;
                    end

                    for(integer i = 0; i < NUMBER_OF_THREADS; i++) begin
                        WARP_MASK[current_warp][stack_pointer[current_warp] + 1][i] <= less_than[i] & (WARP_MASK[current_warp][stack_pointer[current_warp]][i]);
                    end
                    for(integer i = 0; i < NUMBER_OF_THREADS; i++) begin
                        WARP_MASK[current_warp][stack_pointer[current_warp] + 2][i] <= !less_than[i] & (WARP_MASK[current_warp][stack_pointer[current_warp]][i]);
                    end

                    stack_pointer[current_warp] <= stack_pointer[current_warp] + 2;                    
                end
                else if (jump && pc_en) begin
                    WARP_PC[current_warp][stack_pointer[current_warp]] <= WARP_PC[current_warp][stack_pointer[current_warp]] + imm_out;
                end
                else if(WARP_PC[current_warp][stack_pointer[current_warp]] == RECON_PC[current_warp][stack_pointer[current_warp]] && pc_en) begin
                    BRANCH_VALID[current_warp][stack_pointer[current_warp]] <= 0;
                    stack_pointer[current_warp] <= stack_pointer[current_warp] - 1;
                end
                else if(pc_en) begin
                    //update the pc
                    WARP_PC[current_warp][stack_pointer[current_warp]] <= WARP_PC[current_warp][stack_pointer[current_warp]] + 1;                  
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
                    WARP_PC[warp_id_from_ms][stack_pointer[current_warp]] <= WARP_PC[warp_id_from_ms][stack_pointer[current_warp]] + 1;
                end
            end
            default: state_curr <= IDLE;
        endcase
    end
end

    assign warp_id_to_ms   = current_warp;
    assign current_warp_id = current_warp;
    assign warp_ready      = WARP_PC[current_warp][stack_pointer[current_warp]];
    assign warp_ready_mask = WARP_MASK[current_warp][stack_pointer[current_warp]];
endmodule
