/*

### Purpose
This file defines a collection of SystemVerilog macros used to generate packed structures for AXI4 interface signals. It provides a standardized way to define AXI channel types (AW, W, B, AR, R) and combined request/response structures, ensuring consistency across the ADN-VLSI/adn_axi project.

### Use Case
This file serves as a centralized library for AXI4 interface definitions. By utilizing these macros, developers can instantiate standardized, packed SystemVerilog structures for AXI channels with configurable widths for IDs, addresses, data, and user signals. This ensures type safety and reduces boilerplate code when connecting AXI-compliant modules within the ADN-VLSI ecosystem.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-04 | Foez Ahmed      | Initial version                                        |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of ADN-VLSI/adn_axi
Copyright (c) __YEAR__ ADN-VLSI
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

`ifndef __GUARD_AXI_TYPEDEF_SVH__
`define __GUARD_AXI_TYPEDEF_SVH__ 0

// @brief Generates a packed struct for AXI Address channels (AW or AR).
// @param __NM__ Name prefix for the generated struct.
// @param __IW__ ID width.
// @param __AW__ Address width.
// @param __UW__ User signal width.
// @param __TP__ Type suffix (w for write, r for read).
`define AXI_AX_T(__NM__, __IW__, __AW__, __UW__, __TP__)                   \
  typedef struct packed {                                                  \
    logic [  ``__IW__``-1:0] id;                                           \
    logic [  ``__AW__``-1:0] addr;                                         \
    logic [             7:0] len;                                          \
    logic [             2:0] size;                                         \
    logic [             2:0] burst;                                        \
    logic                    lock;                                         \
    logic [             3:0] cache;                                        \
    logic [             2:0] prot;                                         \
    logic [             3:0] qos;                                          \
    logic [             3:0] region;                                       \
    logic [  ``__UW__``-1:0] user;                                         \
  } ``__NM__``_a``__TP__``_t;                                              \
`define AXI_AW_T(__NM__, __IW__, __AW__, __UW__)                           \
  `AXI_AX_T(``__NM__``, ``__IW__``, ``__AW__``, ``__UW__``, w)             \


// @brief Generates a packed struct for the AXI Write Data channel.
// @param __NM__ Name prefix for the generated struct.
// @param __DW__ Data width.
// @param __UW__ User signal width.
`define AXI_W_T(__NM__, __DW__, __UW__)                                    \
  typedef struct packed {                                                  \
    logic [  ``__DW__``-1:0] data;                                         \
    logic [``__DW__``/8-1:0] strb;                                         \
    logic                    last;                                         \
    logic [  ``__UW__``-1:0] user;                                         \
  } ``__NM__``_w_t;                                                        \
`define AXI_B_T(__NM__, __IW__, __UW__)                                    \
  typedef struct packed {                                                  \
    logic [  ``__IW__``-1:0] id;                                           \
    logic [             1:0] resp;                                         \
    logic [  ``__UW__``-1:0] user;                                         \
  } ``__NM__``_b_t;                                                        \


// @brief Generates a packed struct for the AXI Read Address channel.
// @param __NM__ Name prefix for the generated struct.
// @param __IW__ ID width.
// @param __AW__ Address width.
// @param __UW__ User signal width.
`define AXI_AR_T(__NM__, __IW__, __AW__, __UW__)                           \
  `AXI_AX_T(``__NM__``, ``__IW__``, ``__AW__``, ``__UW__``, r)             \
`define AXI_R_T(__NM__, __IW__, __DW__, __UW__)                            \
  typedef struct packed {                                                  \
    logic [  ``__IW__``-1:0] id;                                           \
    logic [  ``__DW__``-1:0] data;                                         \
    logic [             1:0] resp;                                         \
    logic                    last;                                         \
    logic [  ``__UW__``-1:0] user;                                         \
  } ``__NM__``_r_t;                                                        \



// @brief Generates a combined AXI request structure containing AW, W, and AR channels.
// @usecase Used to bundle all AXI request signals into a single packed struct for simplified port mapping.
`define AXI_REQ_T(__NM__, __IW__, __AW__, __DW__, __UW__)       \
  `AXI_AW_T(``__NM__``, ``__IW__``, ``__AW__``, ``__UW__``)     \
  `AXI_W_T(``__NM__``, ``__DW__``, ``__UW__``)                  \
  `AXI_AR_T(``__NM__``, ``__IW__``, ``__AW__``, ``__UW__``)     \
                                                                \
  typedef struct packed {                                       \
    ``__NM__``_aw_t  aw;                                        \
    logic            aw_valid;                                  \
    ``__NM__``_w_t   w;                                         \
    logic            w_valid;                                   \
    logic            b_ready;                                   \
    ``__NM__``_ar_t  ar;                                        \
    logic            ar_valid;                                  \
    logic            r_ready;                                   \
  } ``__NM__``_req_t;                                           \
`define AXI_RESP_T(__NM__, __IW__, __DW__, __UW__)              \
  `AXI_B_T(``__NM__``, ``__IW__``, ``__UW__``)                  \
  `AXI_R_T(``__NM__``, ``__IW__``, ``__DW__``, ``__UW__``)      \
                                                                \
  typedef struct packed {                                       \
    logic            aw_ready;                                  \
    logic            w_ready;                                   \
    ``__NM__``_b_t   b;                                         \
    logic            b_valid;                                   \
    logic            ar_ready;                                  \
    ``__NM__``_r_t   r;                                         \
    logic            r_valid;                                   \
  } ``__NM__``_resp_t;                                          \


// @brief Generates a complete AXI interface structure containing both request and response channels.
// @usecase Used to instantiate a full AXI master/slave interface bundle in a single line.
`define AXI_T(__NM__, __IW__, __AW__, __DW__, __UW__)                    \
  `AXI_REQ_T(``__NM__``, ``__IW__``, ``__AW__``, ``__DW__``, ``__UW__``) \
  `AXI_RESP_T(``__NM__``, ``__IW__``, ``__DW__``, ``__UW__``)            \


`endif
