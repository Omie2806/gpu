`timescale 1ns/1ps

module tb_gpu_top;

    logic clk;
    logic reset;
    
    gpu_top dut (
        .clk(clk),
        .reset(reset)
    );
    
    // Clock generation (100MHz = 10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Helper Tasks
    task print_registers(input integer count);
        integer i;
        begin
            $display("\n========== Register File ==========");
            for (i = 0; i < count; i = i + 1) begin
                $display("  R%02d = %5d (0x%04h)", i, 
                         dut.reg_inst.REGISTER[i],
                         dut.reg_inst.REGISTER[i]);
            end
            $display("===================================\n");
        end
    endtask
    
    task print_memory(input integer start, input integer count);
        integer i;
        begin
            $display("\n========== Data Memory ==========");
            for (i = start; i < start + count; i = i + 1) begin
                $display("  MEM[%3d] = %5d (0x%04h)", i,
                         dut.data_mem_inst.DATA_MEMORY[i],
                         dut.data_mem_inst.DATA_MEMORY[i]);
            end
            $display("=================================\n");
        end
    endtask
    
    // Monitor Execution
    always @(posedge clk) begin
        if (!reset) begin
            $display("[PC=%2d] Op=%4b | RS1=%3d RS2=%3d | ALU=%4d | WE=%b", 
                     dut.pc, dut.opcode,
                     dut.RS1, dut.RS2, dut.alu_result, dut.we);
        end
    end

    always @(posedge clk) begin
    if (!reset) begin
        $display("[PC=%2d] Op=%4b | alu_ctrl=%4b | imm=%d | RS1=%3d RS2=%3d | ALU=%4d | WE=%b", 
                 dut.pc, dut.opcode, dut.alu_control, dut.imm_out,
                 dut.RS1, dut.RS2, dut.alu_result, dut.we);
    end
end
    
    // Main Test
    initial begin
        $display("\n=====================================================");
        $display("    GPU Single-Cycle Test with Load/Store");
        $display("=====================================================\n");
        
        // ==========================================
        // TEST 1: R-Type Instructions
        // ==========================================
        $display("TEST 1: R-Type Instructions\n");
        
        dut.instr_inst.instr_mem[0] = 32'h0000_0312;  // ADD R3, R1, R2  (R3 = 5+10 = 15)
        dut.instr_inst.instr_mem[1] = 32'h0000_1412;  // SUB R4, R2, R1  (R4 = 10-5 = 5)
        dut.instr_inst.instr_mem[2] = 32'h0000_2522;  // MUL R5, R2, R2  (R5 = 10*10 = 100)
        dut.instr_inst.instr_mem[3] = 32'h0000_3621;  // AND R6, R1, R2  (R6 = 5&10 = 0)
        dut.instr_inst.instr_mem[4] = 32'h0000_4721;  // OR  R7, R1, R2  (R7 = 5|10 = 15)
        dut.instr_inst.instr_mem[5] = 32'h0000_5821;  // XOR R8, R1, R2  (R8 = 5^10 = 15)
        
        // ==========================================
        // TEST 2: Store Instructions
        // ==========================================
        $display("TEST 2: Store Instructions\n");
        
        // SW R3, 0(R0)  → MEM[0] = R3 = 15
        dut.instr_inst.instr_mem[6] = 32'h0000_7030;  // imm=0, op=0111(SW), rs2=3, rs1=0
        
        // SW R5, 1(R0)  → MEM[1] = R5 = 100
        dut.instr_inst.instr_mem[7] = 32'h0001_7050;  // imm=1, op=0111(SW), rs2=5, rs1=0
        
        // SW R7, 2(R0)  → MEM[2] = R7 = 15
        dut.instr_inst.instr_mem[8] = 32'h0002_7070;  // imm=2, op=0111(SW), rs2=7, rs1=0
        
        // ==========================================
        // TEST 3: Load Instructions
        // ==========================================
        $display("TEST 3: Load Instructions\n");
        
        // LW R9, 0(R0)  → R9 = MEM[0] = 15
        dut.instr_inst.instr_mem[9] = 32'h0000_6900;  // imm=0, op=0110(LW), rd=9, rs1=0
        
        // LW R10, 1(R0) → R10 = MEM[1] = 100
        dut.instr_inst.instr_mem[10] = 32'h0001_6A00; // imm=1, op=0110(LW), rd=10, rs1=0
        
        // LW R11, 2(R0) → R11 = MEM[2] = 15
        dut.instr_inst.instr_mem[11] = 32'h0002_6B00; // imm=2, op=0110(LW), rd=11, rs1=0
        
        // ==========================================
        // Initialize and Run
        // ==========================================
        
        // Reset
        $display("Resetting GPU...\n");
        reset = 1;
        #20;
        reset = 0;
        
        // Initialize Registers
        $display("Initializing R1=5, R2=10\n");
        dut.reg_inst.REGISTER[1] = 16'd5;
        dut.reg_inst.REGISTER[2] = 16'd10;
        
        $display("Starting execution...\n");
        $display("=====================================================\n");
        
        // Execute all instructions
        repeat(15) @(posedge clk);
        
        $display("\n=====================================================");
        $display("              EXECUTION COMPLETE");
        $display("=====================================================\n");
        
        // Display Results
        print_registers(12);
        print_memory(0, 5);
        
        // ==========================================
        // Verification
        // ==========================================
        $display("=====================================================");
        $display("                 VERIFICATION");
        $display("=====================================================\n");
        
        $display("--- R-Type Tests ---");
        
        if (dut.reg_inst.REGISTER[3] == 16'd15)
            $display("✅ PASS: R3  = %3d (5+10 = 15)", dut.reg_inst.REGISTER[3]);
        else
            $display("❌ FAIL: R3  = %3d (expected 15)", dut.reg_inst.REGISTER[3]);
            
        if (dut.reg_inst.REGISTER[4] == 16'd5)
            $display("✅ PASS: R4  = %3d (10-5 = 5)", dut.reg_inst.REGISTER[4]);
        else
            $display("❌ FAIL: R4  = %3d (expected 5)", dut.reg_inst.REGISTER[4]);
            
        if (dut.reg_inst.REGISTER[5] == 16'd100)
            $display("✅ PASS: R5  = %3d (10*10 = 100)", dut.reg_inst.REGISTER[5]);
        else
            $display("❌ FAIL: R5  = %3d (expected 100)", dut.reg_inst.REGISTER[5]);
            
        if (dut.reg_inst.REGISTER[6] == 16'd0)
            $display("✅ PASS: R6  = %3d (5&10 = 0)", dut.reg_inst.REGISTER[6]);
        else
            $display("❌ FAIL: R6  = %3d (expected 0)", dut.reg_inst.REGISTER[6]);
            
        if (dut.reg_inst.REGISTER[7] == 16'd15)
            $display("✅ PASS: R7  = %3d (5|10 = 15)", dut.reg_inst.REGISTER[7]);
        else
            $display("❌ FAIL: R7  = %3d (expected 15)", dut.reg_inst.REGISTER[7]);
            
        if (dut.reg_inst.REGISTER[8] == 16'd15)
            $display("✅ PASS: R8  = %3d (5^10 = 15)", dut.reg_inst.REGISTER[8]);
        else
            $display("❌ FAIL: R8  = %3d (expected 15)", dut.reg_inst.REGISTER[8]);
        
        $display("\n--- Store Tests ---");
        
        if (dut.data_mem_inst.DATA_MEMORY[0] == 16'd15)
            $display("✅ PASS: MEM[0] = %3d (stored R3)", dut.data_mem_inst.DATA_MEMORY[0]);
        else
            $display("❌ FAIL: MEM[0] = %3d (expected 15)", dut.data_mem_inst.DATA_MEMORY[0]);
            
        if (dut.data_mem_inst.DATA_MEMORY[1] == 16'd100)
            $display("✅ PASS: MEM[1] = %3d (stored R5)", dut.data_mem_inst.DATA_MEMORY[1]);
        else
            $display("❌ FAIL: MEM[1] = %3d (expected 100)", dut.data_mem_inst.DATA_MEMORY[1]);
            
        if (dut.data_mem_inst.DATA_MEMORY[2] == 16'd15)
            $display("✅ PASS: MEM[2] = %3d (stored R7)", dut.data_mem_inst.DATA_MEMORY[2]);
        else
            $display("❌ FAIL: MEM[2] = %3d (expected 15)", dut.data_mem_inst.DATA_MEMORY[2]);
        
        $display("\n--- Load Tests ---");
        
        if (dut.reg_inst.REGISTER[9] == 16'd15)
            $display("✅ PASS: R9  = %3d (loaded from MEM[0])", dut.reg_inst.REGISTER[9]);
        else
            $display("❌ FAIL: R9  = %3d (expected 15)", dut.reg_inst.REGISTER[9]);
            
        if (dut.reg_inst.REGISTER[10] == 16'd100)
            $display("✅ PASS: R10 = %3d (loaded from MEM[1])", dut.reg_inst.REGISTER[10]);
        else
            $display("❌ FAIL: R10 = %3d (expected 100)", dut.reg_inst.REGISTER[10]);
            
        if (dut.reg_inst.REGISTER[11] == 16'd15)
            $display("✅ PASS: R11 = %3d (loaded from MEM[2])", dut.reg_inst.REGISTER[11]);
        else
            $display("❌ FAIL: R11 = %3d (expected 15)", dut.reg_inst.REGISTER[11]);
        
        $display("\n=====================================================\n");
        
        // Summary
        if (dut.reg_inst.REGISTER[3] == 16'd15 &&
            dut.reg_inst.REGISTER[4] == 16'd5 &&
            dut.reg_inst.REGISTER[5] == 16'd100 &&
            dut.reg_inst.REGISTER[6] == 16'd0 &&
            dut.reg_inst.REGISTER[7] == 16'd15 &&
            dut.reg_inst.REGISTER[8] == 16'd15 &&
            dut.data_mem_inst.DATA_MEMORY[0] == 16'd15 &&
            dut.data_mem_inst.DATA_MEMORY[1] == 16'd100 &&
            dut.data_mem_inst.DATA_MEMORY[2] == 16'd15 &&
            dut.reg_inst.REGISTER[9] == 16'd15 &&
            dut.reg_inst.REGISTER[10] == 16'd100 &&
            dut.reg_inst.REGISTER[11] == 16'd15) begin
            $display("✅✅✅ ALL TESTS PASSED! ✅✅✅");
            $display("R-Type, Store, and Load all work!\n");
        end else begin
            $display("❌ SOME TESTS FAILED\n");
        end
        
        $finish;
    end
    
    // Waveform dump
    initial begin
        $dumpfile("gpu_top.vcd");
        $dumpvars(0, tb_gpu_top);
    end

endmodule
