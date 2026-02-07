module alu (
    input logic[15:0] A,
    input logic[15:0] B,
    input logic[2:0] alu_control,
    output logic[15:0]  alu_result,
    output logic zero
);

always @(*) begin
    case(alu_control) 
        3'b000: alu_result = A + B; 
        3'b001: alu_result = A - B;
        3'b010: alu_result = A * B;
        3'b011: alu_result = A & B;
        3'b100: alu_result = A | B;
        3'b101: alu_result = A ^ B;
        default: alu_result = 16'h0000;
    endcase
end

assign zero = (alu_result == 16'h0000);
    
endmodule