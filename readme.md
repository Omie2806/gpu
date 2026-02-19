# 16-Lane SIMT GPU Core
**A Complete Parallel Processing Architecture in SystemVerilog**

![Status](https://img.shields.io/badge/status-fully_functional-brightgreen)
![Tests](https://img.shields.io/badge/tests-112%2F112_passing-success)
![Language](https://img.shields.io/badge/language-SystemVerilog-orange)
![Lines](https://img.shields.io/badge/code-~600_lines-blue)

---

## 🎯 Overview

A **fully functional 16-lane SIMT GPU** implementing parallel execution with memory scheduling, active lane masking, and multi-cycle memory operations. This design demonstrates production GPU concepts including divergence infrastructure and thread ID support.

-**16 parallel execution lanes** - True SIMT architecture
-**Memory scheduler** - Handles 16 independent memory requests with lane skipping
-**Active masking** - Per-lane enable/disable for divergence support
-**Multi-cycle operations** - PC stalling for memory access

---


## Execution Model
**Single Instruction, Multiple Threads (SIMT):**
- All 16 lanes execute the same instruction
- Each lane operates on different data
- Memory scheduler handles parallel memory access
- Active mask controls which lanes write results

---

## 📖 Instruction Set Architecture

### Instruction Format (32-bit)
```
┌─────────────────┬──────────┬─────────┬─────────┬─────────┐
│   Immediate     │  Opcode  │   Rd    │   Rs2   │   Rs1   │
│    [31:16]      │ [15:12]  │ [11:8]  │  [7:4]  │  [3:0]  │
└─────────────────┴──────────┴─────────┴─────────┴─────────┘
     16 bits         4 bits    4 bits    4 bits    4 bits
```

### Instruction Decoding
The instruction decoder extracts fields using simple bit slicing:
```systemverilog
assign A1     = instr[3:0];      // Rs1 - Source register 1
assign A2     = instr[7:4];      // Rs2 - Source register 2
assign A3     = instr[11:8];     // Rd  - Destination register
assign opcode = instr[15:12];    // 4-bit operation code
assign imm    = instr[31:16];    // 16-bit immediate value
```

### Complete Instruction Set

#### R-Type Instructions (Register-Register)
| Mnemonic | Opcode | Format | Operation | Example |
|----------|--------|--------|-----------|---------|
| ADD | 0000 | `ADD Rd, Rs1, Rs2` | Rd = Rs1 + Rs2 | `ADD R3, R1, R2` |
| SUB | 0001 | `SUB Rd, Rs1, Rs2` | Rd = Rs1 - Rs2 | `SUB R4, R3, R1` |
| MUL | 0010 | `MUL Rd, Rs1, Rs2` | Rd = Rs1 × Rs2 | `MUL R5, R2, R2` |
| AND | 0011 | `AND Rd, Rs1, Rs2` | Rd = Rs1 & Rs2 | `AND R6, R1, R2` |
| OR  | 0100 | `OR  Rd, Rs1, Rs2` | Rd = Rs1 \| Rs2 | `OR  R7, R1, R2` |
| XOR | 0101 | `XOR Rd, Rs1, Rs2` | Rd = Rs1 ^ Rs2 | `XOR R8, R1, R2` |

**Encoding Example:**
```
ADD R3, R1, R2 → 32'h0000_0312
  imm=0x0000, opcode=0x0, Rd=0x3, Rs2=0x1, Rs1=0x2
```

#### I-Type Instructions (Immediate-based Memory)
| Mnemonic | Opcode | Format | Operation | Cycles |
|----------|--------|--------|-----------|--------|
| LW  | 0110 | `LW  Rd, imm(Rs1)` | Rd = MEM[Rs1 + imm] | 48* |
| SW  | 0111 | `SW  Rs2, imm(Rs1)` | MEM[Rs1 + imm] = Rs2 | 48* |

*Cycles for all 16 lanes active; fewer if lanes masked

**Memory Addressing:**
```
Effective Address = Rs1 + sign_extend(immediate)

Example:
  LW R9, 0x0100(R0)  →  Load from address 0x0100 + R0
  SW R3, 0x0050(R1)  →  Store to address 0x0050 + R1
```
**Special Registers**
R13- block_dim
R14- block_idx
R15- thread_idx
---

## 🔧 Memory Scheduler

The memory scheduler is the core of multi-lane memory access.

### Operation Flow

**State Machine:**
```
IDLE → REQ → WAIT → CAPTURE → REQ (next lane) → ... → DONE → IDLE
         ↓                                                ↑
    inactive lane? ────── skip (1 cycle) ───────────────┘
```

**Per-Lane Timing:**
- **Active lane**: 3 cycles (REQ → WAIT → CAPTURE)
- **Inactive lane**: 1 cycle (immediate skip)

```


### Example Test Program
```systemverilog
// Initialize: Each lane gets unique data
// R1 = thread_id (lane 0→15)
instr_mem[0] = 32'h0000_010F;  // ADD R1, R15, R0

// R2 = thread_id × 2
instr_mem[1] = 32'h0000_02FF;  // ADD R2, R15, R15

// Compute: R3 = R1 + R2 = thread_id × 3
instr_mem[2] = 32'h0000_0312;  // ADD R3, R1, R2

// Store to memory: MEM[base + thread_id] = R3
instr_mem[3] = 32'h0100_7031;  // SW R3, 0x100(R1)

// Load back: R4 = MEM[base + thread_id]
instr_mem[4] = 32'h0100_6401;  // LW R4, 0x100(R1)

// Result: Each lane has independent data
//   Lane 0: R4 = 0
//   Lane 1: R4 = 3
//   Lane 5: R4 = 15
//   Lane 15: R4 = 45
```

### Running Tests
```bash
# Compile
iverilog -g2012 -o gpu_sim tb_gpu_top.sv gpu_top.sv *.sv

# Run
vvp gpu_sim

# View waveforms
gtkwave gpu.vcd
```

---


## 📊 Specifications

| Feature | Value |
|---------|-------|
| **Architecture** | 16-lane SIMT |
| **Data Width** | 16 bits |
| **Instruction Width** | 32 bits |
| **Registers per Lane** | 16 × 16-bit |
| **Total Registers** | 256 (16 lanes × 16 regs) |
| **ALU Operations** | 6 (ADD, SUB, MUL, AND, OR, XOR) |
| **Data Memory** | 256 × 16-bit words |
| **Instruction Memory** | Configurable (tested 256 words) |
| **Memory Scheduler** | 5-state FSM with lane skipping |
| **Thread ID Support** | R15 = lane index (0-15) |
| **Active Masking** | 16-bit mask per instruction |

### Performance Characteristics
- **R-Type instruction**: 1 cycle
- **Memory operation**: 3-48 cycles (depends on active lanes)
- **Lane skip penalty**: 1 cycle (inactive lanes)
- **PC stall**: Automatic during memory ops

---

##  Future Work

### Phase 1: Branch Divergence (Next Priority)
Add true divergence handling for conditional branches:

**Components:**
- **Branch instructions** (BEQ, BNE)
- **Divergence stack** (8 entries: PC + mask pairs)
- **Masker module** (detects when lanes take different paths)
- **Reconvergence logic** (merge lanes back together)


### Phase 2: Memory Coalescing
Optimize sequential memory access:
- Detect when lanes access consecutive addresses
- Combine into burst transactions
- Reduce cycles from 16×3 to 1×burst for sequential access

### Phase 3: FPGA Implementation
---


## 🔗 References

- **Tiny-GPU**
- **NVIDIA's SIMT Architecture**: GTC presentations and whitepapers
- **Programming Massively Parallel Processors by Hwu and Kiwi**
- **General Purpose Graphics Processor Architectures**
- **Nvidia Cuda Programming Guide**
---


## 📝 License

MIT License - Open for educational and research use

---

**Status:** 16-lane implementation complete  | Branch divergence next 
