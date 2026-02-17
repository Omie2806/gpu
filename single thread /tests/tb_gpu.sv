`timescale 1ns/1ps

module tb_gpu_simple;

logic clk;
logic reset;

//////////////////////////////////////////////////
// DUT
//////////////////////////////////////////////////

gpu_top dut(
    .clk(clk),
    .reset(reset)
);

//////////////////////////////////////////////////
// CLOCK
//////////////////////////////////////////////////

initial begin
    clk = 0;
    forever #5 clk = ~clk;   // 100MHz
end

//////////////////////////////////////////////////
// HELPER TASK : CHECK REGISTER
//////////////////////////////////////////////////

task check_reg(
    input int regnum,
    input string name
);
    int expected;
    int got;

    $display("\nChecking %s (R%0d)", name, regnum);

    for (int lane = 0; lane < 16; lane++) begin

        case(regnum)
            3: expected = lane + lane*2;        // ADD
            4: expected = lane*2 - lane;        // SUB
            5: expected = (lane*2)*(lane*2);    // MUL
            6: expected = lane & (lane*2);      // AND
            7: expected = lane | (lane*2);      // OR
            8: expected = lane ^ (lane*2);      // XOR
        endcase

        got = dut.debug_regs[lane][regnum];

        if (got !== expected)
            $display("❌ Lane %0d FAIL : got=%0d expected=%0d",
                      lane, got, expected);
        else
            $display("✅ Lane %0d PASS : %0d",
                      lane, got);
    end
endtask

//////////////////////////////////////////////////
// TEST
//////////////////////////////////////////////////

initial begin

    $display("\n====================================");
    $display("   GPU 16-LANE R-TYPE TEST");
    $display("====================================\n");

    //////////////////////////////////////////////
    // PROGRAM LOAD
    //////////////////////////////////////////////
    // format: [opcode][rd][rs2][rs1]
// ---------- Operand setup ----------

// R1 = thread_id
dut.instr_inst.instr_mem[0] = 32'h0000_010F; // ADD R1,R15,R0

// R2 = thread_id * 2
dut.instr_inst.instr_mem[1] = 32'h0000_02FF; // ADD R2,R15,R15


// ---------- ALU TESTS ----------

dut.instr_inst.instr_mem[2] = 32'h0000_0312; // ADD R3,R1,R2
dut.instr_inst.instr_mem[3] = 32'h0000_1412; // SUB R4,R2,R1
dut.instr_inst.instr_mem[4] = 32'h0000_2522; // MUL R5,R2,R2
dut.instr_inst.instr_mem[5] = 32'h0000_3621; // AND R6,R1,R2
dut.instr_inst.instr_mem[6] = 32'h0000_4721; // OR  R7,R1,R2
dut.instr_inst.instr_mem[7] = 32'h0000_5821; // XOR R8,R1,R2


    //////////////////////////////////////////////
    // RESET
    //////////////////////////////////////////////
    reset = 1;
    #20
    reset = 0;

    $display("Lane5 R1=%0d R2=%0d",
                dut.debug_regs[5][1],
                dut.debug_regs[5][2]);


    //////////////////////////////////////////////
    // EXECUTE PROGRAM
    //////////////////////////////////////////////
    repeat(40) @(posedge clk);

        $display("Lane5 R1=%0d R2=%0d",
                dut.debug_regs[5][1],
                dut.debug_regs[5][2]);


    $display("\nExecution finished.\n");

    //////////////////////////////////////////////
    // VERIFY RESULTS
    //////////////////////////////////////////////
    check_reg(3,"ADD");
    check_reg(4,"SUB");
    check_reg(5,"MUL");
    check_reg(6,"AND");
    check_reg(7,"OR");
    check_reg(8,"XOR");

    $display("\n✅ TEST COMPLETE\n");

    $finish;
end

//////////////////////////////////////////////////
// WAVES
//////////////////////////////////////////////////

initial begin
    $dumpfile("gpu.vcd");
    $dumpvars(0, tb_gpu_simple);
end

endmodule
