`timescale 1ns/1ps

module tb_gpu_top;

logic clk;
logic reset;
logic[3 : 0] lane_select;
logic[15 : 0] warp_mask [0 : 3]; 
logic[15 : 0] warp_pc [0 : 3];
logic [15:0] debug_pc;
logic [15:0] debug_regs [0:3][0:15][0:15];
logic[15 : 0] debug_lw_out;
logic[15 : 0] debug_alu_result;


gpu_top dut(
    .clk(clk),
    .reset(reset),
    .lane_select(lane_select),
    .warp_mask(warp_mask),
    .warp_pc(warp_pc),
    .debug_pc(debug_pc),
    .debug_regs(debug_regs),
    .debug_lw_out(debug_lw_out),
    .debug_alu_result(debug_alu_result)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin

    $dumpfile("gpu.vcd");
    $dumpvars(0, tb_gpu_top);


    reset = 1;
    warp_pc[0] = 16'h0;
    warp_mask[0] = 16'hFFFF;
    warp_pc[1] = 16'h000A;
    warp_mask[1] = 16'hFFFF;
    warp_pc[2] = 16'h0020;
    warp_mask[2] = 16'hFFFF;
    warp_pc[3] = 16'h0030;
    warp_mask[3] = 16'hFFFF;
    repeat(10) @(posedge clk);
    reset = 0;
    lane_select = 0;
//warp 0
   dut.instr_inst.instr_mem[0]  = 32'h0000_010F; // ADD R1, R15, R0
   dut.instr_inst.instr_mem[1]  = 32'h0105_820F; // ADDI R2, imm = 105, R15
   dut.instr_inst.instr_mem[2]  = 32'h0020_9302; // SUBI R3, imm = 20,  R2
   dut.instr_inst.instr_mem[3]  = 32'h0001_8401; // ADDI R4, imm = 1,  R1
   dut.instr_inst.instr_mem[4]  = 32'h0001_8501; // ADDI R5, imm = 1,  R1
   dut.instr_inst.instr_mem[5]  = 32'h0030_A054; // BEQ R4,  R5 (it will diverge to 53 and the below ones will not be executed)
   dut.instr_inst.instr_mem[6]  = 32'h0000_4721; // OR  R7, R1,  R2
   dut.instr_inst.instr_mem[7]  = 32'h0000_5821; // XOR R8, R1,  R2
   dut.instr_inst.instr_mem[8]  = 32'h0000_F000; // HALT

   dut.instr_inst.instr_mem[53]  = 32'h0000_090F; // ADD R9, R15, R0 (warp 1 will continue from here)
   dut.instr_inst.instr_mem[54]  = 32'h0120_701F; // SW  R9, 0x0120(R15)
   dut.instr_inst.instr_mem[55]  = 32'h0001_8500; // ADDI R5, imm = 1, R0
   dut.instr_inst.instr_mem[56]  = 32'h0002_8600; // ADDI R6, imm = 2, R0
   dut.instr_inst.instr_mem[57]  = 32'h0002_B056; // BLT R6, R5 (shouldnt be taken (interchange 5 and 6 positions and itll be taken))
   dut.instr_inst.instr_mem[58]  = 32'h0000_F000; // HALT
   dut.instr_inst.instr_mem[59]  = 32'h0000_470F; // 0R R7, R15, R0
   dut.instr_inst.instr_mem[60]  = 32'h0000_F000; // HALT                
   dut.instr_inst.instr_mem[61]  = 32'h0000_F000; // HALT

//warp 1
   dut.instr_inst.instr_mem[10] = 32'h0103_810F; // ADDI R1, R15, R0
   dut.instr_inst.instr_mem[11] = 32'h0100_701F; // SW  R1, 0x0100(R15)
   dut.instr_inst.instr_mem[12] = 32'h0000_3626; // AND R6, R6, R2
   dut.instr_inst.instr_mem[13] = 32'h0100_690F; // LW  R9, 0x0100(R15)
   dut.instr_inst.instr_mem[14] = 32'h0000_2522; // MUL R5, R2, R2
   dut.instr_inst.instr_mem[15] = 32'h0000_3621; // AND R6, R1, R2
   dut.instr_inst.instr_mem[16] = 32'h0000_F000; // HALT

//warp 2
   dut.instr_inst.instr_mem[32] = 32'h0000_010F; // ADD R1, R15, R0
   dut.instr_inst.instr_mem[33] = 32'h0110_701F; // SW R1, 0x0110(R15)
   dut.instr_inst.instr_mem[34] = 32'h0000_F000; // HALT

//warp 3
   dut.instr_inst.instr_mem[48] = 32'h0002_C000; // JUMP 0x002(R0) (ie current pc + 0002)
   dut.instr_inst.instr_mem[49] = 32'h0000_F000; // HALT (shouldnt be executed)
   dut.instr_inst.instr_mem[50] = 32'h0900_810F; // ADDI R1, imm = 900, R15 (jumps here)
   dut.instr_inst.instr_mem[51] = 32'h0130_701F; // SW R1, 0x130(R15)
   dut.instr_inst.instr_mem[52] = 32'h0000_F000; // HALT            

    repeat(1200) @(posedge clk);

    $finish;
end

endmodule
