/*

# Purpose
This file provides a collection of SystemVerilog macros designed to standardize the definition of AXI4-Lite interface structures. It facilitates the generation of packed structs for address, write, read, and response channels, ensuring consistency across the ADN-VLSI/adn_axi project.

### Use Case
This file is intended to be included in SystemVerilog design modules that require AXI4-Lite interfaces. By using the provided macros, developers can automatically generate consistent, packed struct definitions for AXI4-Lite channels based on configurable address and data widths. This reduces boilerplate code, minimizes manual errors in struct definitions, and ensures that all interface structures across the project adhere to the same naming and layout conventions.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-04 | Foez Ahmed      | Initial version                                        |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of ADN-VLSI/adn_axi
Copyright (c) __YEAR__ ADN-VLSI
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

`ifndef __GUARD_AXIL_TYPEDEF_SVH__
`define __GUARD_AXIL_TYPEDEF_SVH__ 0

// Macro: AXIL_AX_T
// Purpose: Defines a generic AXI4-Lite address channel structure.
// Use Case: Used as a base for both Write Address (AW) and Read Address (AR) channels.
`define AXIL_AX_T(__NM__, __AW__, __TP__)                                  \
  typedef struct packed {                                                  \
    logic [  ``__AW__``-1:0] addr;                                         \
    logic [             2:0] prot;                                         \
  } ``__NM__``_a``__TP__``_t;                                              \
`define AXIL_AW_T(__NM__, __AW__)                                          \
  `AXIL_AX_T(``__NM__``, ``__AW__``, w)                                    \


// Macro: AXIL_W_T
// Purpose: Defines the AXI4-Lite Write Data channel structure.
// Use Case: Used to encapsulate data and strobe signals for write operations.
`define AXIL_W_T(__NM__, __DW__)                                           \
  typedef struct packed {                                                  \
    logic [  ``__DW__``-1:0] data;                                         \
    logic [``__DW__``/8-1:0] strb;                                         \
  } ``__NM__``_w_t;                                                        \
`define AXIL_B_T(__NM__)                                                   \
  typedef struct packed {                                                  \
    logic [           1:0] resp;                                           \
  } ``__NM__``_b_t;                                                        \


// Macro: AXIL_AR_T
// Purpose: Defines the AXI4-Lite Read Address channel structure.
// Use Case: Instantiates the generic address channel macro specifically for read operations.
`define AXIL_AR_T(__NM__, __AW__)                                          \
  `AXIL_AX_T(``__NM__``, ``__AW__``, r)                                    \
`define AXIL_R_T(__NM__, __DW__)                                           \
  typedef struct packed {                                                  \
    logic [``__DW__``-1:0] data;                                           \
    logic [           1:0] resp;                                           \
  } ``__NM__``_r_t;                                                        \



// Macro: AXIL_REQ_T
// Purpose: Aggregates all AXI4-Lite request-side channels (AW, W, AR) into a single packed struct.
// Use Case: Simplifies interface port declarations by bundling all request signals into one structure.
`define AXIL_REQ_T(__NM__, __AW__, __DW__)       \
  `AXIL_AW_T(``__NM__``, ``__AW__``)             \
  `AXIL_W_T(``__NM__``, ``__DW__``)              \
  `AXIL_AR_T(``__NM__``, ``__AW__``)             \
                                                 \
  typedef struct packed {                        \
    ``__NM__``_aw_t  aw;                         \
    logic            aw_valid;                   \
    ``__NM__``_w_t   w;                          \
    logic            w_valid;                    \
    logic            b_ready;                    \
    ``__NM__``_ar_t  ar;                         \
    logic            ar_valid;                   \
    logic            r_ready;                    \
  } ``__NM__``_req_t;                            \
`define AXIL_RESP_T(__NM__, __DW__)              \
  `AXIL_B_T(``__NM__``)                          \
  `AXIL_R_T(``__NM__``, ``__DW__``)              \
                                                 \
  typedef struct packed {                        \
    logic            aw_ready;                   \
    logic            w_ready;                    \
    ``__NM__``_b_t   b;                          \
    logic            b_valid;                    \
    logic            ar_ready;                   \
    ``__NM__``_r_t   r;                          \
    logic            r_valid;                    \
  } ``__NM__``_resp_t;                           \


// Macro: AXIL_T
// Purpose: Top-level macro to bundle both request and response structures.
// Use Case: Provides a single point of instantiation for a full AXI4-Lite interface bundle.
`define AXIL_T(__NM__, __AW__, __DW__)            \
  `AXIL_REQ_T(``__NM__``, ``__AW__``, ``__DW__``) \
  `AXIL_RESP_T(``__NM__``, ``__DW__``)            \


`endif
