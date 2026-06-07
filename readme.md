# A multi-warp SIMT GPU core with branch divergence handling 

**A Multi-Warp Parallel Processing Architecture in SystemVerilog**

---

## Overview

A fully functional **4-warp, 16-lane SIMT GPU** implementing parallel warp execution with branch divergence stack(IPDOM), a queue-based memory scheduler, per-warp context switching, and independent register files per warp.

**Key capabilities:**
- 4 independent warps executing concurrently with round-robin LIKE scheduling
- 8 stack registers per warp for divergent branches with masking
- 16 parallel execution lanes per warp
- Queue-based memory request scheduler supporting up to 4 simultaneous outstanding memory transactions
- Per-warp register files full context isolation between warps
- LW writeback routed to the correct warp's register file regardless of which warp is currently executing

---

## Architecture Overview

<img width="1167" height="731" alt="image" src="https://github.com/user-attachments/assets/940607cc-7d75-46d9-af11-16f6512dfcd4" />




### Warp Scheduling

Each warp has its own PC and register file. The warp scheduler runs one warp at a time, switching warps when the active warp encounters a memory instruction or executes HALT.
```
For example:

Cycle 1-2:  Warp 0 executes ADD, ADD
Cycle 3:    Warp 0 hits SW → stall, switch to Warp 1
Cycle 4-5:  Warp 1 executes ADD, ADD
Cycle 6:    Warp 1 hits SW → stall, switch to Warp 2
Cycle 7-N:  Warp 2 executes while Warp 0 and 1 memory runs in background
Cycle N+1:  Warp 0 memory done → Warp 0 marked ready
Cycle N+2:  Warp 2 hits HALT → switch to next ready warp (Warp 0)
```

Warps that are stalled waiting for memory are marked `WARP_STALL=1`. When `mem_done` returns with the completing `warp_id`, that warp is marked ready and will be scheduled again.

### Divergence Stack(IPDOM for branch divergence)
The divergence stack supports 8 registers per warp for branching PCs. Pushes the 'taken' branch and then the 'not taken' branch at the top.
Reconvergence PC(Immediate Post Dominator offset) is given in the branch instruction. A jump instruction 'jumps' to the reconvergent pc ones that block is executed. From that point onwards, all threads run parallely again or with the parent's mask(nested control flow)

<img width="1364" height="579" alt="image" src="https://github.com/user-attachments/assets/23b035e7-9ab8-4f6b-aff3-a46ebd9e36ba" />

**Example:
```
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
   dut.instr_inst.instr_mem[112] = 32'h0400_C000; // JUMP 0x04 
   dut.instr_inst.instr_mem[113] = 32'h0000_0C0F; // ADD R12, R15, R0 
   dut.instr_inst.instr_mem[114] = 32'h0000_010F; // ADD R1, R15, R0 
   dut.instr_inst.instr_mem[115] = 32'h0000_020F; // ADD R2, R15, R0  
   dut.instr_inst.instr_mem[116] = 32'h0110_030F; // ADD R3, R15, R0
```
Two BLT instructions are nested, the outer branch at PC=102 splits all 16 threads based on whether thread_idx < 6, sending threads 0-5 to the reconverge point directly while threads 6-15 continue into a second BLT at PC=105 that further splits them based on thread_idx > 7. This creates two active divergence levels on the stack simultaneously, with the inner masks correctly ANDed against the outer active mask so threads 0-5 can never be reactivated by the inner branch. Both levels reconverge in order inner first at PC=111, outer at PC=116 and then restoring the full 16-thread active mask.

**Mask example
<img width="1334" height="176" alt="image" src="https://github.com/user-attachments/assets/c7cb648b-886b-42fd-a0a7-985040a84563" />


### Memory Request Queue

The memory scheduler maintains a 4-slot queue. Each slot stores everything needed to serve the request independently — the warp ID, request type (LW/SW), all 16 lane addresses, and all 16 lane store data. This allows multiple warps to have outstanding memory requests simultaneously.

**Queue admission:**
When any warp issues LW or SW, `mem_req` pulses for one cycle. At that exact moment while the issuing warp is still active the addresses (`alu_result`) and store data (`RS2`) are captured into the queue slot indexed by `warp_id`.

**Queue service (FIFO by slot index):**
The memory scheduler scans slots 0 - 3 and serves the first pending slot. This means lower indexed warp IDs get priority when multiple requests are pending. After completing a transaction, the slot is marked unoccupied and `mem_done` pulses with the completed `warp_id` so the warp scheduler can unstall that warp.

**Example with two stalled warps:**
```
Warp 1 issues SW → queued in slot 1, warp switches to Warp 2
Warp 2 issues SW → queued in slot 2, warp switches to Warp 3
Mem scheduler: finds slot 1 first → serves Warp 1's SW 
mem_done=1, warp_id=1 → Warp 1 unstalled, marked ready
Mem scheduler: finds slot 2 → serves Warp 2's SW 
mem_done=1, warp_id=2 → Warp 2 unstalled, marked ready
```
<img width="1555" height="257" alt="image" src="https://github.com/user-attachments/assets/e681dc34-8091-40d1-9533-4e636100c981" />
state transition after finishing warp 1's store and setting req_type = 1 for load instruction in warp 1 

<img width="1597" height="256" alt="image" src="https://github.com/user-attachments/assets/8930c43d-8095-4c25-ac64-910b3d54ca21" />
serving warp 2's store instruction while warp 1 is queued for load

If Warp 1 issues another memory instruction while Warp 2 is being served, it re-enters the queue at slot 1 (now free) and will be served after Warp 2 completes.

Warp 0 and 1 test load/store with masking for divergent branches.

### LW Writeback

For load instructions, the data arrives (around 60 cycles) after the instruction was issued long after the warp scheduler has moved to other warps. The mem_scheduler tracks the destination register (`lw_destination`) per queue slot and signals `lw_ready` + `lw_warp_id` + `lw_destination_out` when load data is ready. This overrides the current instruction's write address (`A3`) and routes `lw_out` to the correct warp's register file regardless of which warp is currently executing.

<img width="1487" height="641" alt="image" src="https://github.com/user-attachments/assets/c13f1471-c7c9-4d83-8a1c-760ab06056ae" />

Values being stored to 9th register of warp 1 after finishing its load service (lw_ready = 1) 
---

## Instruction Set Architecture

### Instruction Format (32-bit)
```
┌─────────────────┬──────────┬─────────┬─────────┬─────────┐
│   Immediate     │  Opcode  │   Rd    │   Rs2   │   Rs1   │
│    [31:16]      │ [15:12]  │ [11:8]  │  [7:4]  │  [3:0]  │
└─────────────────┴──────────┴─────────┴─────────┴─────────┘
     16 bits         4 bits    4 bits    4 bits    4 bits
```
For jump, blt and beq instructions, immediate is from [31 : 24] and reconvergence pc(not for jump) is from [23 : 16]

### Instruction Set

| Mnemonic | Opcode | Operation |
|----------|--------|-----------|
| ADD | 0000 | Rd = Rs1 + Rs2 |
| ADDI | 1000 | Rd = Rs1 + Rs2 |
| SUBI | 1001 | Rd = Rs1 - Rs2 |
| SUB | 0001 | Rd = Rs1 - Rs2 |
| MUL | 0010 | Rd = Rs1 × Rs2 |
| AND | 0011 | Rd = Rs1 & Rs2 |
| OR  | 0100 | Rd = Rs1 \| Rs2 |
| XOR | 0101 | Rd = Rs1 ^ Rs2 |
| LW  | 0110 | Rd = MEM[Rs1 + imm] |
| SW  | 0111 | MEM[Rs1 + imm] = Rs2 |
| BEQ  | 1010 | pc + imm,  Rs1 - Rs2 |
| BLT  | 1011 | pc + imm,  Rs1 - Rs2 |
| JUMP | 1100 | pc + imm |
| HALT| 1111 | End warp execution |

### Special Registers

| Register | Purpose |
|----------|---------|
| R13 | block_dim |
| R14 | block_idx |
| R15 | thread_idx (lane index 0-15) |

---


---

## Specifications

| Feature | Value |
|---------|-------|
| Warps | 4 |
| Lanes per warp | 16 |
| Data width | 16 bits |
| Instruction width | 32 bits |
| Registers per lane | 16 |
| Total register storage | 4 warps × 16 lanes × 16 regs × 16 bits = 16,384 bits |
| Memory request queue depth | 4 slots |
| Data memory | 256 × 16-bit words |
| Instruction memory | 256 × 32-bit words (64 per warp) |
| ALU operations | 6 |



---

## Running Simulation
```bash
# Vivado (recommended)
# Add all .sv files as design sources
# Add tb_gpu_top.sv as simulation source
# Run Behavioral Simulation

```

---

## Future Work


**Memory Coalescing**
Detect when consecutive lanes access consecutive addresses and merge into a single burst transaction — reducing approx 60 cycles to 1 burst for sequential access patterns.

**Round-Robin Fairness**
Current queue always serves lowest-index slot first. True round-robin would give equal priority to all warps regardless of their ID.

**FPGA Implementation**
Deploy and verify on physical hardware. 

---

## References

- Tiny-GPU (architectural reference)
- NVIDIA SIMT Architecture — GTC whitepapers
- Programming Massively Parallel Processors — Hwu and Kirk
- General Purpose Graphics Processor Architectures — Aamodt, Fung, Rogers
- W.W.L. Fung, I. Sham, G. Yuan, T. Aamodt — Dynamic Warp Formation and Scheduling for Efficient GPU Control Flow, MICRO 2007

---

