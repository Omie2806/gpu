module alu (
    input logic[15:0] A,
    input logic[15:0] B,
    input logic[3:0] alu_control,
    output logic[15:0]  alu_result,
    output logic zero
);

always @(*) begin
    case(alu_control) 
        4'b0000: alu_result = A + B; 
        4'b0001: alu_result = A - B;
        4'b0010: alu_result = A * B;
        4'b0011: alu_result = A & B;
        4'b0100: alu_result = A | B;
        4'b0101: alu_result = A ^ B;
    endcase
end

assign zero = (alu_result == 16'h0000);
    
endmodule