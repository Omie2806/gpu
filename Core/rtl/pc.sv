module pc (
    input logic          clk,
    input logic          reset,
    input logic[15 : 0]  pc_next,
    output logic[15 : 0]   pc
);
logic pc_en;

always @(posedge clk) begin
    if(reset) begin
        pc <= 16'h0000;
        pc_en <= 0;
    end
    else if(pc_en) begin
        pc <= pc_next;
    end else begin
        pc_en <= 1; 
    end
end
    
endmodule