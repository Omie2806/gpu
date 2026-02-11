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
    
    // Monitor Execution
    always @(posedge clk) begin
        if (!reset) begin
            $display("[Cycle %0d] PC=%2d | Instr=0x%08h | Op=%3b | A1=%d A2=%d A3=%d | RS1=%3d RS2=%3d | ALU=%4d | WE=%b", 
                     ($time/10)-4,  // Adjusted
                     dut.pc, 
                     dut.instr, 
                     dut.opcode,
                     dut.A1, dut.A2, dut.A3,
                     dut.RS1, 
                     dut.RS2, 
                     dut.alu_result, 
                     dut.we);
        end
    end
    
    // Main Test
    initial begin
        $display("\n=====================================================");
        $display("           GPU Top Level Testbench");
        $display("           Single-Cycle Design Test");
        $display("=====================================================\n");
        
        // Load Program
        $display("Step 1: Loading test program...\n");
        
        dut.instr_inst.instr_mem[0] = 32'h0000_0312;  // ADD R3, R1, R2
        dut.instr_inst.instr_mem[1] = 32'h0000_1412;  // SUB R4, R2, R1
        dut.instr_inst.instr_mem[2] = 32'h0000_2522;  // MUL R5, R2, R2
        dut.instr_inst.instr_mem[3] = 32'h0000_3621;  // AND R6, R1, R2
        dut.instr_inst.instr_mem[4] = 32'h0000_4721;  // OR  R7, R1, R2
        dut.instr_inst.instr_mem[5] = 32'h0000_5821;  // XOR R8, R1, R2
        dut.instr_inst.instr_mem[6] = 32'h0000_0000;  // NOP
        
        // Reset
        $display("Step 2: Resetting GPU...\n");
        reset = 1;
        #10
        reset = 0;
        
        // Initialize Registers
        $display("Step 3: Initializing R1=5, R2=10\n");
        dut.reg_inst.REGISTER[1] = 16'd5;
        dut.reg_inst.REGISTER[2] = 16'd10;
        // ✅ CRITICAL FIX: Wait one cycle after releasing reset
        
        // Execute
        $display("Step 4: Starting execution...\n");
        $display("=====================================================");
        $display("                 EXECUTION TRACE");
        $display("=====================================================\n");
        
        repeat(10) @(posedge clk);
        
        $display("\n=====================================================");
        $display("              EXECUTION COMPLETE");
        $display("=====================================================\n");
        
        // Results
        print_registers(10);
        
        // Verify
        $display("=====================================================");
        $display("                 VERIFICATION");
        $display("=====================================================\n");
        
        if (dut.reg_inst.REGISTER[3] == 16'd15)
            $display("✅ PASS: R3 = %3d (expected 15)", dut.reg_inst.REGISTER[3]);
        else
            $display("❌ FAIL: R3 = %3d (expected 15)", dut.reg_inst.REGISTER[3]);
            
        if (dut.reg_inst.REGISTER[4] == 16'd5)
            $display("✅ PASS: R4 = %3d (expected 5)", dut.reg_inst.REGISTER[4]);
        else
            $display("❌ FAIL: R4 = %3d (expected 5)", dut.reg_inst.REGISTER[4]);
            
        if (dut.reg_inst.REGISTER[5] == 16'd100)
            $display("✅ PASS: R5 = %3d (expected 100)", dut.reg_inst.REGISTER[5]);
        else
            $display("❌ FAIL: R5 = %3d (expected 100)", dut.reg_inst.REGISTER[5]);
            
        if (dut.reg_inst.REGISTER[6] == 16'd0)
            $display("✅ PASS: R6 = %3d (expected 0)", dut.reg_inst.REGISTER[6]);
        else
            $display("❌ FAIL: R6 = %3d (expected 0)", dut.reg_inst.REGISTER[6]);
            
        if (dut.reg_inst.REGISTER[7] == 16'd15)
            $display("✅ PASS: R7 = %3d (expected 15)", dut.reg_inst.REGISTER[7]);
        else
            $display("❌ FAIL: R7 = %3d (expected 15)", dut.reg_inst.REGISTER[7]);
            
        if (dut.reg_inst.REGISTER[8] == 16'd15)
            $display("✅ PASS: R8 = %3d (expected 15)", dut.reg_inst.REGISTER[8]);
        else
            $display("❌ FAIL: R8 = %3d (expected 15)", dut.reg_inst.REGISTER[8]);
        
        $display("\n=====================================================\n");
        
        // Summary
        if (dut.reg_inst.REGISTER[3] == 16'd15 &&
            dut.reg_inst.REGISTER[4] == 16'd5 &&
            dut.reg_inst.REGISTER[5] == 16'd100 &&
            dut.reg_inst.REGISTER[6] == 16'd0 &&
            dut.reg_inst.REGISTER[7] == 16'd15 &&
            dut.reg_inst.REGISTER[8] == 16'd15) begin
            $display("✅✅✅ ALL TESTS PASSED! ✅✅✅");
            $display("Your single-cycle GPU works correctly!\n");
        end else begin
            $display("❌ SOME TESTS FAILED\n");
        end
        
        $finish;
    end
    
    // Timeout
    initial begin
        #10000000;
        $display("\n❌ TIMEOUT!\n");
        $finish;
    end

endmodule