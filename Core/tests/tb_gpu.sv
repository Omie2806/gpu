`timescale 1ns/1ps

module tb_gpu_top;

logic clk;
logic reset;
logic [15:0] debug_regs [0:3][0:15][0:15];

int pass_count;
int fail_count;

gpu_top dut(
    .clk(clk),
    .reset(reset),
    .debug_regs(debug_regs)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin

    $dumpfile("gpu.vcd");
    $dumpvars(0, tb_gpu_top);

    pass_count = 0;
    fail_count = 0;

    reset = 1;
    repeat(2) @(posedge clk);
    reset = 0;

//warp 0
    dut.instr_inst.instr_mem[0]  = 32'h0000_010F; // ADD R1, R15, R0
    dut.instr_inst.instr_mem[1]  = 32'h0000_02FF; // ADD R2, R15, R15
    dut.instr_inst.instr_mem[2]  = 32'h0000_0312; // ADD R3, R1,  R2
    dut.instr_inst.instr_mem[3]  = 32'h0000_0413; // ADD R4, R3,  R1
    dut.instr_inst.instr_mem[4]  = 32'h0000_2522; // MUL R5, R2,  R2
    dut.instr_inst.instr_mem[5]  = 32'h0000_3621; // AND R6, R1,  R2
    dut.instr_inst.instr_mem[6]  = 32'h0000_4721; // OR  R7, R1,  R2
    dut.instr_inst.instr_mem[7]  = 32'h0000_5821; // XOR R8, R1,  R2
    dut.instr_inst.instr_mem[8]  = 32'h0000_8000; // HALT

//warp 1
    dut.instr_inst.instr_mem[16] = 32'h0000_010F; // ADD R1, R15, R0
    dut.instr_inst.instr_mem[17] = 32'h0100_701F; // SW  R1, 0x0100(R0)
    dut.instr_inst.instr_mem[18] = 32'h0100_690F; // LW  R9, 0x0100(R0)
    dut.instr_inst.instr_mem[19] = 32'h0000_2522; // MUL R5, R2, R2
    dut.instr_inst.instr_mem[20] = 32'h0000_3621; // AND R6, R1, R2
    dut.instr_inst.instr_mem[21] = 32'h0000_8000; // HALT

//warp 2
    dut.instr_inst.instr_mem[32] = 32'h0000_010F; // ADD R1, R15, R0
    dut.instr_inst.instr_mem[33] = 32'h0110_701F; // SW R1, 0x0100(R0)
    dut.instr_inst.instr_mem[34] = 32'h0000_8000; // HALT

//warp 3
    dut.instr_inst.instr_mem[48] = 32'h0000_8000; // HALT

    repeat(1200) @(posedge clk);

//scoreboard to verify
    $display("\n--- Checking Warp 0 ALU Results ---");
    for(int lane = 0; lane < 16; lane++) begin
        // R1 = thread_idx
        if(debug_regs[0][lane][1] === 16'(lane))
            $display("  PASS [W0_L%0d_R1] = %0d", lane, lane);
        else begin
            $display("  FAIL [W0_L%0d_R1] got=%0d expected=%0d",
                      lane, debug_regs[0][lane][1], lane);
            fail_count++;
        end

        // R2 = thread_idx * 2
        if(debug_regs[0][lane][2] === 16'(lane*2))
            $display("  PASS [W0_L%0d_R2] = %0d", lane, lane*2);
        else begin
            $display("  FAIL [W0_L%0d_R2] got=%0d expected=%0d",
                      lane, debug_regs[0][lane][2], lane*2);
            fail_count++;
        end

        // R3 = R1 + R2 = lane*3
        if(debug_regs[0][lane][3] === 16'(lane*3))
            $display("  PASS [W0_L%0d_R3] = %0d", lane, lane*3);
        else begin
            $display("  FAIL [W0_L%0d_R3] got=%0d expected=%0d",
                      lane, debug_regs[0][lane][3], lane*3);
            fail_count++;
        end

        // R5 = R2*R2 = (lane*2)^2
        if(debug_regs[0][lane][5] === 16'((lane*2)*(lane*2)))
            $display("  PASS [W0_L%0d_R5] = %0d", lane, (lane*2)*(lane*2));
        else begin
            $display("  FAIL [W0_L%0d_R5] got=%0d expected=%0d",
                      lane, debug_regs[0][lane][5], (lane*2)*(lane*2));
            fail_count++;
        end

        // R6 = R1 & R2
        if(debug_regs[0][lane][6] === 16'(lane & (lane*2)))
            $display("  PASS [W0_L%0d_R6] = %0d", lane, lane & (lane*2));
        else begin
            $display("  FAIL [W0_L%0d_R6] got=%0d expected=%0d",
                      lane, debug_regs[0][lane][6], lane & (lane*2));
            fail_count++;
        end

        // R7 = R1 | R2
        if(debug_regs[0][lane][7] === 16'(lane | (lane*2)))
            $display("  PASS [W0_L%0d_R7] = %0d", lane, lane | (lane*2));
        else begin
            $display("  FAIL [W0_L%0d_R7] got=%0d expected=%0d",
                      lane, debug_regs[0][lane][7], lane | (lane*2));
            fail_count++;
        end

        // R8 = R1 ^ R2
        if(debug_regs[0][lane][8] === 16'(lane ^ (lane*2)))
            $display("  PASS [W0_L%0d_R8] = %0d", lane, lane ^ (lane*2));
        else begin
            $display("  FAIL [W0_L%0d_R8] got=%0d expected=%0d",
                      lane, debug_regs[0][lane][8], lane ^ (lane*2));
            fail_count++;
        end
    end


    $display("\n--- Checking Warp 1 SW+LW Results ---");
    for(int lane = 0; lane < 16; lane++) begin
        // R1 = thread_idx
        if(debug_regs[1][lane][1] === 16'(lane))
            $display("  PASS [W1_L%0d_R1] = %0d", lane, lane);
        else begin
            $display("  FAIL [W1_L%0d_R1] got=%0d expected=%0d",
                      lane, debug_regs[1][lane][1], lane);
            fail_count++;
        end

        // R9 = LW result = thread_idx
        if(debug_regs[1][lane][9] === 16'(lane))
            $display("  PASS [W1_L%0d_R9] = %0d", lane, lane);
        else begin
            $display("  FAIL [W1_L%0d_R9] got=%0d expected=%0d",
                      lane, debug_regs[1][lane][9], lane);
            fail_count++;
        end
    end


    $display("\n--- Checking Warp 2 Results ---");
    for(int lane = 0; lane < 16; lane++) begin
        // R1 = thread_idx
        if(debug_regs[2][lane][1] === 16'(lane))
            $display("  PASS [W2_L%0d_R1] = %0d", lane, lane);
        else begin
            $display("  FAIL [W2_L%0d_R1] got=%0d expected=%0d",
                      lane, debug_regs[2][lane][1], lane);
            fail_count++;
        end
    end


    $display("\n============================================");
    $display("  RESULTS: %0d PASS   %0d FAIL", pass_count, fail_count);
    if(fail_count == 0)
        $display("  ALL TESTS PASSED");
    else
        $display("  FAILURES DETECTED — check gpu.vcd");
    $display("============================================\n");

    $finish;
end

endmodule
