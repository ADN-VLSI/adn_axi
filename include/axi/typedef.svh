/*

@foez-bhai, write the purpose of this file in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

@foez-bhai, describe the use case of this file in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

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

// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXI_AW_T(__NM__, __AW__, __DW__)        \



// @foez-bhai, add comments here about the purpose and usecase of this macro
`define APB_REQ_T(__NM__, __AW__, __DW__)        \
  typedef struct packed {                        \
    logic                    psel;               \
    logic                    penable;            \
    logic [  ``__AW__``-1:0] paddr;              \
    logic [             2:0] pprot;              \
    logic                    pwrite;             \
    logic [  ``__DW__``-1:0] pwdata;             \
    logic [``__DW__``/8-1:0] pstrb;              \
} ``__NM__``_req_t;                              \


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define APB_RESP_T(__NM__, __DW__)               \
  typedef struct packed {                        \
    logic                    pready;             \
    logic [  ``__DW__``-1:0] prdata;             \
    logic                    pslverr;            \
} ``__NM__``_resp_t;                             \


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define APB_T(__NM__, __AW__, __DW__)            \
  `APB_REQ_T(``__NM__``, ``__AW__``, ``__DW__``) \
  `APB_RESP_T(``__NM__``, ``__DW__``)            \


`endif
