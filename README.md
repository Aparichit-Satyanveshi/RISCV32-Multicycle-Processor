# RISC-V RV32I Multi-Cycle Processor (Verilog)

## Overview and Design

This project implements a **32-bit RISC-V (RV32I) processor** in Verilog using a **multi-cycle architecture** controlled by a finite state machine (FSM). Each instruction is executed over multiple clock cycles, enabling efficient reuse of hardware components such as the ALU and memory interface while maintaining structured control flow.

The execution process is divided into four stages:

**FETCH → EXECUTE → MEMORY → WRITEBACK**

* **Fetch**: Instruction is retrieved using the program counter
* **Execute**: Instruction is decoded and processed by the ALU
* **Memory**: Data memory is accessed for load/store instructions
* **Writeback**: Result is written back to the register file

The FSM governs execution through the following states:

**FETCH → FETCH_WAIT → EXECUTE → (MEMREAD → MEMREAD_WAIT) → WRITEBACK**

Instructions that do not require memory access transition directly from **EXECUTE** to **WRITEBACK**.

The processor implements a subset of the RV32I instruction set with a modular datapath consisting of the ALU, register file, program counter, and immediate generator. Control logic is divided into a main decoder (opcode-based) and an ALU decoder (function-based). The design supports arithmetic, logical, immediate, load/store, branch, jump (JAL, JALR), and upper immediate (LUI, AUIPC) instructions. System instructions such as ECALL and EBREAK are not implemented.

---

## Source Files and Usage

### Core Modules

* `riscv_processor.v`
  Top-level module implementing the processor with FSM control and memory interface

* `riscv_processor_combined.v`
  Integrated version of the processor for simplified simulation

* `alu.v`
  Performs arithmetic, logical, shift, and comparison operations

* `alu_decoder.v`
  Generates ALU control signals

* `main_decoder.v`
  Produces high-level control signals from opcode

* `imm_gen.v`
  Extracts and sign-extends immediate values

* `reg_file.v`
  Implements a 32 × 32-bit register file

* `pc.v`
  Handles program counter updates and next PC logic

---

### Testbench

The `test_bench` directory contains the following testbenches:

* `riscv_tb_1.v`
* `riscv_tb_2.v`
* `riscv_tb_3.v`

Each testbench instantiates the processor,generates clock and reset signals,simulates memory behavior and produces waveform output for verification.
---


## How to Run

### Compilation

```bash
iverilog -o sim *.v test_bench/riscv_tb_{number}.v
```

### Simulation

```bash
vvp sim
```

### Waveform Viewing

```bash
gtkwave wave.vcd
```

## Requirements

* Icarus Verilog (`iverilog`)
* GTKWave (optional, for waveform visualization)

---

This project was made as a Course Project in Computer Organisation and Architecture (DAC - 102),under Prof.Sparsh Mittal
during Spring Semester 2025-26.
---

## Author

Sahil Jain
Indian Institute of Technology Roorkee
Department of Data Science and Artificial Intelligence
