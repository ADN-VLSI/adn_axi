# axi/assign.svh  (include)

### Author: Foez Ahmed (foez.official@gmail.com)

### Source: assign.svh

## Parameters

_None_


## Include Guard

__GUARD_AXI_ASSIGN_SVH__


## Macros

|Name|Args|Description|Preview|
|-|-|-|-|
|AXI_COMMUNICATION|__M__, __S__, __MT__, __AS__|@brief Performs bulk signal assignment between AXI Master and Slave interfaces. @param __M__  Master interface instance. @param __S__  Slave interface instance. @param __MT__ Macro type/block context (e.g., always_comb). @param __AS__ Assignment operator (e.g., =, <=).|`define AXI_COMMUNICATION(__M__, __S__, __MT__, __AS__)                       ``__MT__`` ``__S__``.aw.id      ``__AS__`` {'0, ``__M__``.aw.id};          ``__MT_|
|AXI_COMB_ASSIGN|__M__, __S__|@brief Performs a combinatorial assignment for AXI signals. @usecase Use this within `always_comb` blocks for immediate, combinatorial signal updates.|`define AXI_COMB_ASSIGN(__M__, __S__)                                   `AXI_COMMUNICATION(``__M__``, ``__S__``, always_comb, =)|
|AXI_BLOCKING_ASSIGN|__M__, __S__|@brief Performs a blocking assignment for AXI signals. @usecase Use this within procedural blocks (initial/always) for immediate, blocking signal updates.|`define AXI_BLOCKING_ASSIGN(__M__, __S__)                               `AXI_COMMUNICATION(``__M__``, ``__S__``, , =)|
|AXI_NONBLOCKING_ASSIGN|__M__, __S__|@brief Performs a non-blocking assignment for AXI signals. @usecase Use this within procedural blocks (initial/always) for scheduled, non-blocking signal updates.|`define AXI_NONBLOCKING_ASSIGN(__M__, __S__)                            `AXI_COMMUNICATION(``__M__``, ``__S__``, , <=)|


## Description

### Purpose
This file provides a set of SystemVerilog macros designed to simplify the assignment and connection of AXI4 interface signals between Master and Slave components. It abstracts the repetitive task of mapping individual AXI channel signals (AW, W, B, AR, R) by providing unified macros for combinatorial, blocking, and non-blocking assignments.

### Use Case
This file is primarily used in SystemVerilog testbenches or RTL integration layers where AXI4 interfaces need to be connected between a Master and a Slave. Instead of manually mapping every signal in the five AXI channels (AW, W, B, AR, R), developers can use these macros to perform bulk assignments.

- **`AXI_COMB_ASSIGN`**: Used within `always_comb` blocks for combinatorial signal propagation.
- **`AXI_BLOCKING_ASSIGN`**: Used for sequential blocking assignments.
- **`AXI_NONBLOCKING_ASSIGN`**: Used for sequential non-blocking assignments (e.g., within `always_ff` blocks).

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-04 | Foez Ahmed      | Initial version                                        |

Author : Foez Ahmed (foez.official@gmail.com)
