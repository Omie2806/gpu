# Single-Cycle GPU Core
**A 16-bit Educational GPU Architecture in SystemVerilog**

![Status](https://img.shields.io/badge/status-working-brightgreen)
![Language](https://img.shields.io/badge/language-SystemVerilog-orange)

---

## 🎯 Overview

A fully functional single-cycle GPU core implementing fundamental SIMT (Single Instruction, Multiple Threads) architecture principles. Currently operates as a single-lane processor with plans to scale to 16-lane parallel execution.

**Current Features:**
- ✅ 16-bit data path, 32-bit instructions
- ✅ 16 general-purpose registers
- ✅ 6 ALU operations (ADD, SUB, MUL, AND, OR, XOR)
- ✅ Load/Store with immediate addressing
- ✅ 256-word data memory
- ✅ Synthesizable SystemVerilog

---

## 📐 Architecture
```
┌──────────┐    ┌─────────┐    ┌────────────┐
│    PC    │───→│ Instr   │───→│  Control   │
│          │    │ Memory  │    │   Unit     │
└──────────┘    └─────────┘    └────────────┘
                                      │
                          ┌───────────┴───────────┐
                          ▼                       ▼
                    ┌──────────┐           ┌──────────┐
                    │ Register │──→ ALU ──→│   LSU    │
                    │   File   │           │          │
                    └──────────┘           └──────────┘
                          ▲                       ▼
                          └────────────────┬──────────┘
                                          ▼
                                   ┌──────────────┐
                                   │ Data Memory  │
                                   └──────────────┘
```

**Design:** Single-cycle execution where each instruction completes in one clock cycle (Fetch → Decode → Execute → Memory → Writeback).

---

## 📖 Instruction Set

### Instruction Format (32-bit)
```
┌────────────┬─────────┬────────┬────────┬────────┐
│ Immediate  │ Opcode  │   Rd   │  Rs2   │  Rs1   │
│  [31:16]   │ [15:12] │ [11:8] │ [7:4]  │ [3:0]  │
└────────────┴─────────┴────────┴────────┴────────┘
```

### Instruction Decoding
```systemverilog
assign A1 = instr[3:0];      // Source register 1
assign A2 = instr[7:4];      // Source register 2
assign A3 = instr[11:8];     // Destination register
assign opcode = instr[15:12]; // Operation (4 bits)
assign imm = instr[31:16];   // Immediate value
```

The control unit decodes the 4-bit opcode and generates control signals for the datapath (ALU operation, register write enable, memory access, source muxing).

### Supported Instructions

| Type | Instruction | Opcode | Description |
|------|-------------|--------|-------------|
| R-Type | ADD Rd, Rs1, Rs2 | 0000 | Rd = Rs1 + Rs2 |
| R-Type | SUB Rd, Rs1, Rs2 | 0001 | Rd = Rs1 - Rs2 |
| R-Type | MUL Rd, Rs1, Rs2 | 0010 | Rd = Rs1 × Rs2 |
| R-Type | AND Rd, Rs1, Rs2 | 0011 | Rd = Rs1 & Rs2 |
| R-Type | OR  Rd, Rs1, Rs2 | 0100 | Rd = Rs1 \| Rs2 |
| R-Type | XOR Rd, Rs1, Rs2 | 0101 | Rd = Rs1 ^ Rs2 |
| I-Type | LW  Rd, imm(Rs1) | 0110 | Rd = MEM[Rs1 + imm] |
| I-Type | SW  Rs2, imm(Rs1) | 0111 | MEM[Rs1 + imm] = Rs2 |

### Load-Store Unit (LSU) Operation

**Load (LW):**
```
1. ALU computes address: addr = Rs1 + immediate
2. LSU routes addr to memory
3. Memory returns data
4. LSU forwards data to register file
5. Destination register updated
```

**Store (SW):**
```
1. ALU computes address: addr = Rs1 + immediate  
2. LSU routes address and data (from Rs2) to memory
3. Memory write occurs on clock edge
```

---


### Run Tests
```bash
# Compile
iverilog -g2012 -o gpu_sim *.sv

# Simulate
vvp gpu_sim

# View waveforms
gtkwave gpu_top.vcd
```

---

## 🚀 Current Work: Multi-Lane Implementation

**Status:** 🔄 In Progress

### Goal
Convert single-lane processor to **16-lane SIMT GPU** with parallel execution.

### Architecture After Multi-Lane
```
              Control Unit (Shared)
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
    Lane 0        Lane 1   ...  Lane 15
  ┌────────┐    ┌────────┐    ┌────────┐
  │16 REG  │    │16 REG  │    │16 REG  │
  │  ALU   │    │  ALU   │    │  ALU   │
  └────────┘    └────────┘    └────────┘
        │             │             │
        └─────────────┼─────────────┘
                      ▼
                  LSU (16-way)
                      ▼
                 Data Memory
```


## 🗺️ Future Roadmap

### Phase 2: Branch Divergence 
- Add branch instructions (BEQ, BNE)
- Implement divergence stack (8 entries)
- Add masker module for divergence detection
- Handle lane reconvergence

### Phase 3: Memory Coalescing
- Detect sequential memory access patterns
- Burst memory operations
- Bank conflict resolution



## 📊 Specifications

| Parameter | Current | Target (Multi-Lane) |
|-----------|---------|---------------------|
| Lanes | 1 | 16 |
| Data Width | 16 bits | 16 bits |
| Registers per Lane | 16 | 16 |
| ALU Operations | 6 | 6 |
| Memory | 256 words | 256 words |
| Divergence Support | ❌ | ✅ (Phase 2) |


---

## 📝 License

MIT License - Open for educational and research use

---

**Last Updated:** February 2025  
**Status:** Single-lane complete ✅ | Multi-lane in progress 🔄
