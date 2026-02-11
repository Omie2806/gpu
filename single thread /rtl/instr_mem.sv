module instr_mem (
    input logic[15 : 0] pc,
    output logic[31 : 0] instr
);

reg[31 : 0] instr_mem [0 : 255];
//input program directly here or through the test bench
always @(*) begin
    instr = instr_mem[pc];
end

endmodule