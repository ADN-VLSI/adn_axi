# axil/assign.svh  (include)

### Author: Foez Ahmed (foez.official@gmail.com)

### Source: assign.svh

## Parameters

_None_


## Include Guard

__GUARD_AXIL_ASSIGN_SVH__


## Macros

|Name|Args|Description|Preview|
|-|-|-|-|
|AXIL_COMMUNICATION|__M__, __S__, __MT__, __AS__|@brief: Connects AXI4-Lite Master and Slave interfaces. @usecase: Used internally by assignment macros to map signals across all 5 AXI channels.|`define AXIL_COMMUNICATION(__M__, __S__, __MT__, __AS__)                      ``__MT__`` ``__S__``.aw.addr    ``__AS__`` {'0, ``__M__``.aw.addr};        ``__MT_|
|AXIL_BLOCKING_ASSIGN|__M__, __S__|@brief: Performs a blocking assignment (=) between AXI4-Lite interfaces. @usecase: Used in procedural blocks (initial/always) for sequential logic or testbench stimulus.|`define AXIL_BLOCKING_ASSIGN(__M__, __S__)                               `AXIL_COMMUNICATION(``__M__``, ``__S__``, , =)|
|AXIL_NONBLOCKING_ASSIGN|__M__, __S__|@brief: Performs a non-blocking assignment (<=) between AXI4-Lite interfaces. @usecase: Used in sequential logic blocks to ensure proper timing and avoid race conditions.|`define AXIL_NONBLOCKING_ASSIGN(__M__, __S__)                            `AXIL_COMMUNICATION(``__M__``, ``__S__``, , <=)|


## Description

# axil/assign.svh 
This file provides a set of SystemVerilog macros designed to streamline the assignment of AXI4-Lite interface signals between a master and a slave. It abstracts the repetitive task of connecting individual AXI4-Lite channels (Write Address, Write Data, Write Response, Read Address, and Read Data) by providing unified macros for combinational, blocking, and non-blocking assignments.

### Use Case
This file is primarily used in testbenches or verification environments where an AXI4-Lite Master interface needs to be connected to a Slave interface. By using these macros, developers can avoid writing dozens of individual signal assignments, reducing boilerplate code and minimizing the risk of connection errors. It supports various assignment types (combinational, blocking, and non-blocking), making it versatile for both RTL-level connectivity and simulation-based stimulus generation.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-04 | Foez Ahmed      | Initial version                                        |

Author : Foez Ahmed (foez.official@gmail.com)
