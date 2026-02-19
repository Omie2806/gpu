`timescale 1ns/1ps

module tb_gpu_top;

logic clk;
logic reset;

gpu_top dut(
    .clk(clk),
    .reset(reset)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// ============================================================
// SCOREBOARD
// ============================================================
int pass_count;
int fail_count;

task automatic check(
    input string name,
    input int    got,
    input int    expected
);
    if (got !== expected) begin
        $display("  FAIL [%s] lane got=%0d expected=%0d", name, got, expected);
        fail_count++;
    end else begin
        $display("  PASS [%s] = %0d", name, got);
        pass_count++;
    end
endtask

// ============================================================
// CHECK ALL 16 LANES OF A REGISTER
// ============================================================
task automatic check_reg(
    input int    regnum,
    input string name,
    input int    expected_vals [0:15]
);
    $display("\n  Checking %s (R%0d)", name, regnum);
    for (int lane = 0; lane < 16; lane++) begin
        check($sformatf("%s_lane%0d", name, lane),
              int'(dut.debug_regs[lane][regnum]),
              expected_vals[lane]);
    end
endtask

// ============================================================
// WAIT FOR PC TO REACH A TARGET (with timeout)
// ============================================================
task automatic wait_for_pc(input logic [15:0] target);
    int timeout;
    timeout = 0;
    while (dut.pc !== target && timeout < 500) begin
        @(posedge clk);
        timeout++;
    end
    if (timeout >= 500)
        $display("  WARN: PC timeout waiting for %h", target);
    else
        repeat(3) @(posedge clk); // settle
endtask

// ============================================================
// TESTS
// ============================================================
initial begin
    int exp [0:15];

    $dumpfile("gpu.vcd");
    $dumpvars(0, tb_gpu_top);

    pass_count = 0;
    fail_count = 0;

    $display("\n====================================");
    $display("   GPU INTEGRATION TESTBENCH");
    $display("====================================");

    // --------------------------------------------------------
    // RESET
    // --------------------------------------------------------
    reset = 1;
    repeat(2)@(posedge clk);
    reset = 0;
    // ========================================================
    // TEST 1: R-TYPE ALU INSTRUCTIONS
    // Program:
    //   R1  = thread_idx        (ADD R1, R15, R0)
    //   R2  = thread_idx * 2    (ADD R2, R15, R15)
    //   R3  = R1 + R2
    //   R4  = R2 - R1
    //   R5  = R2 * R2
    //   R6  = R1 & R2
    //   R7  = R1 | R2
    //   R8  = R1 ^ R2
    // ========================================================
    $display("\n--- TEST 1: R-Type ALU ---");

    dut.instr_inst.instr_mem[0]  = 32'h0000_010F; // ADD R1, R15, R0
    dut.instr_inst.instr_mem[1]  = 32'h0000_02FF; // ADD R2, R15, R15
    dut.instr_inst.instr_mem[2]  = 32'h0000_0312; // ADD R3, R1,  R2
    dut.instr_inst.instr_mem[3]  = 32'h0000_1412; // SUB R4, R2,  R1
    dut.instr_inst.instr_mem[4]  = 32'h0000_2522; // MUL R5, R2,  R2
    dut.instr_inst.instr_mem[5]  = 32'h0000_3621; // AND R6, R1,  R2
    dut.instr_inst.instr_mem[6]  = 32'h0000_4721; // OR  R7, R1,  R2
    dut.instr_inst.instr_mem[7]  = 32'h0000_5821; // XOR R8, R1,  R2
    // NOP sled (opcode=F = undefined, will hit default, we=0)
    for (int i = 8; i < 64; i++)
        dut.instr_inst.instr_mem[i] = 32'hFFFF_FFFF;

    wait_for_pc(16'd8);

    for (int l = 0; l < 16; l++) exp[l] = l + l*2;
    check_reg(3, "ADD", exp);

    for (int l = 0; l < 16; l++) exp[l] = l*2 - l;
    check_reg(4, "SUB", exp);

    for (int l = 0; l < 16; l++) exp[l] = (l*2) * (l*2);
    check_reg(5, "MUL", exp);

    for (int l = 0; l < 16; l++) exp[l] = l & (l*2);
    check_reg(6, "AND", exp);

    for (int l = 0; l < 16; l++) exp[l] = l | (l*2);
    check_reg(7, "OR",  exp);

    for (int l = 0; l < 16; l++) exp[l] = l ^ (l*2);
    check_reg(8, "XOR", exp);

    // ========================================================
    // TEST 2: STORE then LOAD
    // Program:
    //   R1  = thread_idx
    //   SW  R1 -> mem[base + thread_idx]   (base via imm)
    //   LW  R9 <- mem[base + thread_idx]
    //   R9 should equal R1 per lane
    // ========================================================
    $display("\n--- TEST 2: Store + Load roundtrip ---");

    // reset to re-run
    reset = 1;
    repeat(1)@(posedge clk);
    reset = 0;

    // R1 = thread_idx
    dut.instr_inst.instr_mem[0] = 32'h0000_010F; // ADD R1, R15, R0
    // R2 = base address (imm = 0x0100, ADD R2 with imm)
    // addr = R0 + imm = 0x0100 + thread_idx
    // SW: opcode=0111, rd=don't care(0), rs2=R1(data), rs1=R0(base)
    // addr = RS1 + imm = R0 + 0x0100 = 0x0100..0x010F per lane
    dut.instr_inst.instr_mem[1] = 32'h0100_701F; // SW  R1, 0x0100(R0)
    // LW: opcode=0110, rd=R9, rs1=R0, imm=0x0100
    dut.instr_inst.instr_mem[2] = 32'h0100_690F; // LW  R9, 0x0100(R0)
    for (int i = 3; i < 64; i++)
        dut.instr_inst.instr_mem[i] = 32'hFFFF_FFFF;

    // SW takes 16*3 cycles + LW takes 16*3 cycles, give plenty of time
    wait_for_pc(16'd3);
    repeat(20) @(posedge clk); // let memory ops settle

    for (int l = 0; l < 16; l++) exp[l] = l; // R9 should = thread_idx
    check_reg(9, "LW_after_SW", exp);

    // ========================================================
    // TEST 3: STALL GATING - PC must not advance during stall
    // ========================================================
    $display("\n--- TEST 3: PC stall gating ---");

    reset = 1;
    repeat(2)@(posedge clk);
    reset = 0;

    dut.instr_inst.instr_mem[0] = 32'h0000_010F; // ADD R1 (1 cycle)
    dut.instr_inst.instr_mem[1] = 32'h0100_7001; // SW  (stalls 48+ cycles)
    for (int i = 2; i < 64; i++)
        dut.instr_inst.instr_mem[i] = 32'hFFFF_FFFF;

    // wait for SW to start stalling
    wait(dut.stall === 1'b1);

    begin
        logic [15:0] pc_snapshot;
        int          glitch;
        pc_snapshot = dut.pc;
        glitch      = 0;

        // sample every cycle while stall is high
        repeat(30) @(posedge clk) begin
            if (dut.stall && dut.pc !== pc_snapshot)
                glitch++;
        end

        if (glitch == 0)
            $display("  PASS [pc_stall_gating] PC held for 30 cycles");
        else
            $display("  FAIL [pc_stall_gating] PC moved %0d times during stall", glitch);
    end

    // ========================================================
    // SUMMARY
    // ========================================================
    $display("\n============================================");
    $display("  RESULTS: %0d PASS   %0d FAIL",
              pass_count, fail_count);
    if (fail_count == 0)
        $display("  ALL TESTS PASSED");
    else
        $display("  FAILURES DETECTED - check gpu.vcd");
    $display("============================================\n");

    $finish;
end

endmodule