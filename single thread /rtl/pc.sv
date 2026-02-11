module pc (
    input logic          clk,
    input logic          reset,
    input logic[15 : 0]  pc_next,
    output logic[15 : 0]   pc
);

always @(posedge clk or posedge reset) begin
    if(reset) begin
        pc <= 16'h0000;
    end
    else begin
        pc <= pc_next;
    end
end
    
endmodule