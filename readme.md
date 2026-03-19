# 16-Lane SIMT GPU Core

**A Multi-Warp Parallel Processing Architecture in SystemVerilog**

---

## Overview

A fully functional **4-warp, 16-lane SIMT GPU** implementing parallel warp execution with a queue-based memory scheduler, per-warp context switching, and independent register files per warp.

**Key capabilities:**
- 4 independent warps executing concurrently with round-robin LIKE scheduling
- 16 parallel execution lanes per warp
- Queue-based memory request scheduler supporting up to 4 simultaneous outstanding memory transactions
- Per-warp register files full context isolation between warps
- LW writeback routed to the correct warp's register file regardless of which warp is currently executing
- Active lane masking for divergence infrastructure

---

## Architecture Overview

<img width="1475" height="713" alt="image" src="https://github.com/user-attachments/assets/bed8d92e-e0ef-482b-8b48-8f2ddfb44416" />


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

### Instruction Set

| Mnemonic | Opcode | Operation |
|----------|--------|-----------|
| ADD | 0000 | Rd = Rs1 + Rs2 |
| SUB | 0001 | Rd = Rs1 - Rs2 |
| MUL | 0010 | Rd = Rs1 × Rs2 |
| AND | 0011 | Rd = Rs1 & Rs2 |
| OR  | 0100 | Rd = Rs1 \| Rs2 |
| XOR | 0101 | Rd = Rs1 ^ Rs2 |
| LW  | 0110 | Rd = MEM[Rs1 + imm] |
| SW  | 0111 | MEM[Rs1 + imm] = Rs2 |
| HALT| 1000 | End warp execution |

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

### Warp Memory Map

| Warp | PC Start | PC End |
|------|----------|--------|
| 0 | 0x0000 | 0x000F |
| 1 | 0x0010 | 0x001F |
| 2 | 0x0020 | 0x002F |
| 3 | 0x0030 | 0x003F |

---

## Example Programs

### Vector Add (single warp)
```systemverilog
// Each lane computes A[i] + B[i] = C[i]
// R15 = thread_idx (lane index)
instr_mem[0] = 32'h0100_610F; // LW R1, 0x0100(R15)  load A[i]
instr_mem[1] = 32'h0200_620F; // LW R2, 0x0200(R15)  load B[i]
instr_mem[2] = 32'h0000_0312; // ADD R3, R1, R2       C[i] = A[i]+B[i]
instr_mem[3] = 32'h0300_730F; // SW R3, 0x0300(R15)  store C[i]
instr_mem[4] = 32'h0000_8000; // HALT
```

### Multi-warp store-load roundtrip (verified)
```systemverilog
// Warp 0: ALU operations across all lanes
instr_mem[0]  = 32'h0000_010F; // R1 = thread_idx
instr_mem[1]  = 32'h0000_02FF; // R2 = thread_idx * 2
instr_mem[2]  = 32'h0000_0312; // R3 = R1 + R2
instr_mem[8]  = 32'h0000_8000; // HALT

// Warp 1: Store then load roundtrip
instr_mem[16] = 32'h0000_010F; // R1 = thread_idx
instr_mem[17] = 32'h0100_701F; // SW R1, 0x0100(R15)
instr_mem[18] = 32'h0100_690F; // LW R9, 0x0100(R15)  R9 should = R1
instr_mem[21] = 32'h0000_8000; // HALT
```

---

## Running Simulation
```bash
# Vivado (recommended)
# Add all .sv files as design sources
# Add tb_gpu_top.sv as simulation source
# Run Behavioral Simulation

# Icarus Verilog
iverilog -g2012 -o gpu_sim tb_gpu_top.sv gpu_top.sv mem_scheduler.sv \
         warp_scheduler.sv reg_file.sv alu.sv instr_mem.sv data_mem.sv imm_gen.sv
vvp gpu_sim
gtkwave gpu.vcd
```

---

## Future Work

**Branch Divergence**
Add BEQ/BNE instructions with a divergence stack to handle conditional branches where different lanes take different paths. Requires a masker module and reconvergence logic.

**Memory Coalescing**
Detect when consecutive lanes access consecutive addresses and merge into a single burst transaction — reducing approx 60 cycles to 1 burst for sequential access patterns.

**Round-Robin Fairness**
Current queue always serves lowest-index slot first. True round-robin would give equal priority to all warps regardless of their ID.

**FPGA Implementation**
Synthesize and verify on physical hardware. 

---

## References

- Tiny-GPU (architectural reference)
- NVIDIA SIMT Architecture — GTC whitepapers
- Programming Massively Parallel Processors — Hwu and Kirk
- General Purpose Graphics Processor Architectures — Aamodt, Fung, Rogers

---

**Status:** 4-warp multi-warp execution with load/store and basic ops verified, thorough testing still underway 
