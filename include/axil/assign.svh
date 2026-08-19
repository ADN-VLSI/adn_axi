/*

# Purpose
This file provides a set of SystemVerilog macros designed to streamline the assignment of AXI4-Lite interface signals between a master and a slave. It abstracts the repetitive task of connecting individual AXI4-Lite channels (Write Address, Write Data, Write Response, Read Address, and Read Data) by providing unified macros for combinational, blocking, and non-blocking assignments.

### Use Case
This file is primarily used in testbenches or verification environments where an AXI4-Lite Master interface needs to be connected to a Slave interface. By using these macros, developers can avoid writing dozens of individual signal assignments, reducing boilerplate code and minimizing the risk of connection errors. It supports various assignment types (combinational, blocking, and non-blocking), making it versatile for both RTL-level connectivity and simulation-based stimulus generation.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-04 | Foez Ahmed      | Initial version                                        |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of ADN-VLSI/adn_axi
Copyright (c) 2026 ADN-VLSI
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

`ifndef __GUARD_AXIL_ASSIGN_SVH__
`define __GUARD_AXIL_ASSIGN_SVH__ 0


/*
  @brief: Connects AXI4-Lite Master and Slave interfaces.
  @usecase: Used internally by assignment macros to map signals across all 5 AXI channels.
*/
`define AXIL_COMMUNICATION(__M__, __S__, __MT__, __AS__)                    \
                                                                            \
  ``__MT__`` ``__S__``.aw.addr    ``__AS__`` {'0, ``__M__``.aw.addr};       \
  ``__MT__`` ``__S__``.aw.prot    ``__AS__`` {'0, ``__M__``.aw.prot};       \
  ``__MT__`` ``__S__``.aw_valid   ``__AS__`` {'0, ``__M__``.aw_valid};      \
  ``__MT__`` ``__M__``.aw_ready   ``__AS__`` {'0, ``__S__``.aw_ready};      \
                                                                            \
  ``__MT__`` ``__S__``.w.data     ``__AS__`` {'0, ``__M__``.w.data};        \
  ``__MT__`` ``__S__``.w.strb     ``__AS__`` {'0, ``__M__``.w.strb};        \
  ``__MT__`` ``__S__``.w_valid    ``__AS__`` {'0, ``__M__``.w_valid};       \
  ``__MT__`` ``__M__``.w_ready    ``__AS__`` {'0, ``__S__``.w_ready};       \
                                                                            \
  ``__MT__`` ``__M__``.b.rsp     ``__AS__`` {'0, ``__S__``.b.rsp};        \
  ``__MT__`` ``__M__``.b_valid    ``__AS__`` {'0, ``__S__``.b_valid};       \
  ``__MT__`` ``__S__``.b_ready    ``__AS__`` {'0, ``__M__``.b_ready};       \
                                                                            \
  ``__MT__`` ``__S__``.ar.addr    ``__AS__`` {'0, ``__M__``.ar.addr};       \
  ``__MT__`` ``__S__``.ar.prot    ``__AS__`` {'0, ``__M__``.ar.prot};       \
  ``__MT__`` ``__S__``.ar_valid   ``__AS__`` {'0, ``__M__``.ar_valid};      \
  ``__MT__`` ``__M__``.ar_ready   ``__AS__`` {'0, ``__S__``.ar_ready};      \
                                                                            \
  ``__MT__`` ``__M__``.r.data     ``__AS__`` {'0, ``__S__``.r.data};        \
  ``__MT__`` ``__M__``.r.rsp     ``__AS__`` {'0, ``__S__``.r.rsp};        \
  ``__MT__`` ``__M__``.r_valid    ``__AS__`` {'0, ``__S__``.r_valid};       \
  ``__MT__`` ``__S__``.r_ready    ``__AS__`` {'0, ``__M__``.r_ready};       \
`define AXIL_COMB_ASSIGN(__M__, __S__)                                  \
  `AXIL_COMMUNICATION(``__M__``, ``__S__``, always_comb, =)             \


/*
  @brief: Performs a blocking assignment (=) between AXI4-Lite interfaces.
  @usecase: Used in procedural blocks (initial/always) for sequential logic or testbench stimulus.
*/
`define AXIL_BLOCKING_ASSIGN(__M__, __S__)                              \
  `AXIL_COMMUNICATION(``__M__``, ``__S__``, , =)                        \


/*
  @brief: Performs a non-blocking assignment (<=) between AXI4-Lite interfaces.
  @usecase: Used in sequential logic blocks to ensure proper timing and avoid race conditions.
*/
`define AXIL_NONBLOCKING_ASSIGN(__M__, __S__)                           \
  `AXIL_COMMUNICATION(``__M__``, ``__S__``, , <=)                       \


`endif
