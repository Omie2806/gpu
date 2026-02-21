module reg_file (
    input logic clk, reset,
    input logic[3 : 0] A1, A2, A3,
    input logic[15 : 0] WD,
    input logic[15 : 0] block_idx, block_dim, thread_idx,

    output logic [15 : 0] RS1, RS2,

    input logic reg_en,
    input logic we
);
    reg [15 : 0] REGISTER [0 : 15];
    //0 - 12 normal registers, 13 - 15 special registers
    //write
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            for (int i = 0; i < 13 ; i++) begin
                REGISTER[i] <= 16'h0000;
            end
            REGISTER[13] <= block_dim;
            REGISTER[14] <= block_idx;
            REGISTER[15] <= thread_idx;
        end
        else if((we && reg_en) && (A3 < 13)) begin
            REGISTER[A3] <= WD;
        end
    end
    //read
    always @(*) begin
        RS1 = REGISTER[A1];
        RS2 = REGISTER[A2];
    end

endmodule