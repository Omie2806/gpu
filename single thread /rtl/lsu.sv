module lsu (
    input logic clk,
    input logic reset,
    input logic [15 : 0] lw_in,
    input logic [15 : 0]  addr_in,
    input logic [15 : 0]  sw_in,
    //control
    input logic lw_or_sw,//lw = 1 and sw = 0
    input logic lsu_en,

    output logic[15 : 0] lw_out,
    output logic[15 : 0] sw_out,
    output logic[15 : 0] addr_out
);


always @(*) begin
    if (lw_or_sw && lsu_en)  begin //lw
        lw_out   = lw_in;
        addr_out = addr_in;
    end
    else if(!lw_or_sw && lsu_en)begin //sw
        sw_out   = sw_in;
        addr_out = addr_in;
    end
end
    
endmodule