# RISC-V RV32I Multi-Cycle Processor (Verilog)

## Overview and Design

This project implements a **32-bit RISC-V (RV32I) processor** in Verilog using a **multi-cycle architecture** controlled by a finite state machine (FSM). Each instruction is executed over multiple clock cycles, enabling efficient reuse of hardware components while maintaining structured control flow.

The execution process is divided into four stages:

**FETCH → EXECUTE → MEMORY → WRITEBACK**

* **Fetch**: Instruction is retrieved using the program counter
* **Execute**: Instruction is decoded and processed by the ALU
* **Memory**: Data memory is accessed for load/store instructions
* **Writeback**: Result is written back to the register file

The FSM operates with the following state transitions:

**FETCH → FETCH_WAIT → EXECUTE → (MEMREAD → MEMREAD_WAIT) → WRITEBACK**

Instructions that do not require memory access transition directly from **EXECUTE** to **WRITEBACK**.

The processor implements a subset of the RV32I instruction set with a modular datapath consisting of the ALU, register file, program counter, and immediate generator. Control logic is divided into a main decoder (opcode-based) and an ALU decoder (function-based). The design supports arithmetic, logical, immediate, load/store, branch, jump (JAL, JALR), and upper immediate (LUI, AUIPC) instructions. System instructions such as ECALL and EBREAK are not implemented.

---

## Source Files and Usage

### Core Modules

* `riscv_processor.v` — Top-level processor with FSM and memory interface
* `riscv_processor_combined.v` — Integrated version for simplified simulation
* `alu.v` — Arithmetic, logical, shift, and comparison operations
* `alu_decoder.v` — ALU control signal generation
* `main_decoder.v` — Opcode-based control logic
* `imm_gen.v` — Immediate extraction and sign extension
* `reg_file.v` — 32 × 32-bit register file
* `pc.v` — Program counter and next PC logic

---

## Testbench

The `test_bench` directory contains:

* `riscv_tb_1.v`
* `riscv_tb_2.v`
* `riscv_tb_3.v`

Each testbench instantiates the processor, generates clock and reset signals, simulates memory behavior, and produces waveform output for verification.

---

## How to Run

### Compilation

```bash id="cqqsop"
iverilog -o sim *.v test_bench/riscv_tb_{number}.v
```

### Simulation

```bash id="p33dpr"
vvp sim
```

### Waveform Viewing

```bash id="g3u0z7"
gtkwave wave.vcd
```

---

## Requirements

* Icarus Verilog (`iverilog`)
* GTKWave (optional)

---

This project was developed as part of the course Computer Organisation and Architecture (DAC-102) under Prof. Sparsh Mittal during the Spring Semester 2025–26.

Author:
Sahil Jain  
Indian Institute of Technology Roorkee  
Mehta Family School of Data Science and Artificial Intelligence
