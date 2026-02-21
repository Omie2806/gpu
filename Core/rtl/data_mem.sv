module data_mem (
    input clk, reset,
    input logic[15 : 0] addr,
    input logic[15 : 0] WD1,
    //control
    input logic mem_write,

    output logic[15 : 0] result
);

logic [15 : 0] DATA_MEMORY [0 : 255];
always @(posedge clk) begin
    if(reset) begin
        for (integer i = 0; i < 256; i++) begin
            DATA_MEMORY[i] <= 0;
        end
    end
    else if(mem_write)begin
        DATA_MEMORY[addr[7 : 0]] <= WD1;
    end
end

always @(*) begin
    result = DATA_MEMORY[addr[7 : 0]];
end
    
endmodule