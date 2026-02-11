module imm_gen (
    input  logic [15:0] imm,      
    output logic [15:0] imm_out
);

    assign imm_out = {{15{imm[16]}}, imm[0]};  // Sign extend 

endmodule