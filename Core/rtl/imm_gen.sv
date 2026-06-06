module imm_gen #(
    parameter NUMBER_OF_WARPS   = 4,
    parameter ADDR_WIDTH        = 16,
    parameter DATA_WIDTH        = 16,
    parameter NUMBER_OF_THREADS = 16    
) (
    input  logic [15 : 0] imm,   
    input  logic branch,
    input  logic jump,   
    output logic [15 : 0] imm_out,
    output logic [15 : 0] reconverge_pc
);
 always_comb begin
    if (branch || jump) begin
        reconverge_pc = {{8{imm[7]}}, imm[7 : 0]}; //ill sign extend so as to allow for negative offsets
        imm_out       = {{8{imm[15]}}, imm[15 : 8]};
    end else begin
        imm_out = imm;
    end

 end   

endmodule
