module instr_mem#(
    parameter NUMBER_OF_WARPS   = 4,
    parameter ADDR_WIDTH        = 16,
    parameter DATA_WIDTH        = 16,
    parameter NUMBER_OF_THREADS = 16    
) (
    input logic clk,
    input  logic [ADDR_WIDTH - 1 : 0] pc,
    output logic [31:0] instr
);
reg [31:0] instr_mem [0:255];

// initial $readmemh("program.mem", instr_mem);

always @(*) begin
    instr = instr_mem[pc[7:0]];
end

endmodule
