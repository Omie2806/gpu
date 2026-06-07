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
    warp_pc[0] = 16'h0000;
    warp_mask[0] = 16'hFFFF;
    warp_pc[1] = 16'h0032;
    warp_mask[1] = 16'hFFFF;
    warp_pc[2] = 16'h0064;
    warp_mask[2] = 16'hFFFF;
    warp_pc[3] = 16'h0096;
    warp_mask[3] = 16'hFFFF;
    repeat(10) @(posedge clk);
    reset = 0;
    lane_select = 0;

//warp 0(tests beq, blt and jump for simple programs (sw within a divergent block))
   dut.instr_inst.instr_mem[0]  = 32'h0000_010F; // ADD R1, R15, R0
   dut.instr_inst.instr_mem[1]  = 32'h0105_820F; // ADDI R2, imm = 105, R15
   dut.instr_inst.instr_mem[2]  = 32'h0001_830F; // ADDI R3, imm = 1,  R15
   dut.instr_inst.instr_mem[3]  = 32'h0000_243F; // MUL R4, R15, R3
   dut.instr_inst.instr_mem[4]  = 32'h0004_850F; // ADDI R5, imm = 2,  R0
   dut.instr_inst.instr_mem[5]  = 32'h0407_A054; // BEQ R4,  R5 (reconv at [11])
   dut.instr_inst.instr_mem[6]  = 32'h0000_4721; // OR  R7, R1,  R2
   dut.instr_inst.instr_mem[7]  = 32'h0000_5821; // XOR R8, R1,  R2
   dut.instr_inst.instr_mem[8]  = 32'h0400_C000; // JUMP 0x0004 + pc(jump to reconv)

   dut.instr_inst.instr_mem[9]   = 32'h0000_090F; // ADD R9, R15, R0 (warp 1 will continue from here)
   dut.instr_inst.instr_mem[10]  = 32'h0120_701F; // SW  R9, 0x0120(R15) (2nd thread shouldnt store)
   dut.instr_inst.instr_mem[11]  = 32'h0001_8500; // ADDI R5, imm = 1, R0
   dut.instr_inst.instr_mem[12]  = 32'h0002_8600; // ADDI R6, imm = 2, R0
   dut.instr_inst.instr_mem[13]  = 32'h0203_B056; // BLT R6, R5
   dut.instr_inst.instr_mem[14]  = 32'h0202_C000; // JUMP 0x0002 + pc
   dut.instr_inst.instr_mem[15]  = 32'h0000_470F; // 0R R7, R15, R0
   dut.instr_inst.instr_mem[16]  = 32'h0000_F000; // HALT                
   dut.instr_inst.instr_mem[17]  = 32'h0000_F000; // HALT

//warp 1(tests lw inside a divergent block)
   dut.instr_inst.instr_mem[50] = 32'h0006_810F; // ADDI R1, R15, R0
   dut.instr_inst.instr_mem[51] = 32'h0100_701F; // SW  R1, 0x0100(R15)
   dut.instr_inst.instr_mem[52] = 32'h0002_8200; // ADDI R2, IMM = 2, R0
   dut.instr_inst.instr_mem[53] = 32'h0000_232F; // MUL R3, R15, R2
   dut.instr_inst.instr_mem[54] = 32'h0303_B031; // BLT R1, R3
   dut.instr_inst.instr_mem[55] = 32'h0100_690F; // LW  R9, 0x0100(R15)(should load first 7 threads)
   dut.instr_inst.instr_mem[56] = 32'h0000_2522; // MUL R5, R2, R2
   dut.instr_inst.instr_mem[57] = 32'h0000_3621; // AND R6, R1, R2
   dut.instr_inst.instr_mem[58] = 32'h0000_F000; // HALT

//warp 2(tests nested control flow)
   dut.instr_inst.instr_mem[100] = 32'h0000_010F; // ADD R1, R15, R0
   dut.instr_inst.instr_mem[101] = 32'h0006_8200; // ADDI R2, imm = 6, R0 
   dut.instr_inst.instr_mem[102] = 32'h0B0E_B021; // BLT R1, R2 (recon = pc + 16, imm = 9)
   dut.instr_inst.instr_mem[103] = 32'h0007_8300; // ADDI R3, IMM = 5, R0
   dut.instr_inst.instr_mem[104] = 32'h0000_040F; // ADD R4, R15, R0
   dut.instr_inst.instr_mem[105] = 32'h0406_B043; // BLT R3, R4 (recon = pc + 6, imm = 3)
   dut.instr_inst.instr_mem[106] = 32'h0000_050F; // ADD R5, R15, R0
   dut.instr_inst.instr_mem[107] = 32'h0000_060F; // ADD R6, R15, R0 
   dut.instr_inst.instr_mem[108] = 32'h0300_C000; // JUMP R7, R15, R0 (imm 1st nest) 
   dut.instr_inst.instr_mem[109] = 32'h0000_080F; // ADD R8, R15, R0 
   dut.instr_inst.instr_mem[110] = 32'h0000_090F; // ADD R9, R15, R0 
   dut.instr_inst.instr_mem[111] = 32'h0000_0A0F; // ADD R10, R15, R0 (recon 1st nest)
   dut.instr_inst.instr_mem[112] = 32'h0400_C000; // JUMP 0x05 
   dut.instr_inst.instr_mem[113] = 32'h0000_0C0F; // ADD R12, R15, R0 
   dut.instr_inst.instr_mem[114] = 32'h0000_010F; // ADD R1, R15, R0 
   dut.instr_inst.instr_mem[115] = 32'h0000_020F; // ADD R2, R15, R0  
   dut.instr_inst.instr_mem[116] = 32'h0110_030F; // ADD R3, R15, R0
   dut.instr_inst.instr_mem[117] = 32'h0000_F000; // HALT

//warp 3
   dut.instr_inst.instr_mem[150] = 32'h0200_C000; // JUMP 0x002(R0) (ie current pc + 0002)
   dut.instr_inst.instr_mem[151] = 32'h0000_F000; // HALT (shouldnt be executed)
   dut.instr_inst.instr_mem[152] = 32'h0900_810F; // ADDI R1, imm = 900, R15 (jumps here)
   dut.instr_inst.instr_mem[153] = 32'h0130_701F; // SW R1, 0x130(R15)
   dut.instr_inst.instr_mem[154] = 32'h0000_F000; // HALT  
   dut.instr_inst.instr_mem[155] = 32'h0000_F000; // HALT          

    repeat(1200) @(posedge clk);

    $finish;
end

endmodule
