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

`ifndef __GUARD_AXIL_TYPEDEF_SVH__
`define __GUARD_AXIL_TYPEDEF_SVH__ 0

// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXIL_AX_T(__NM__, __AW__, __TP__)                                  \
  typedef struct packed {                                                  \
    logic [  ``__AW__``-1:0] addr;                                         \
    logic [             2:0] prot;                                         \
  } ``__NM__``_a``__TP__``_t;                                              \


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXIL_AW_T(__NM__, __AW__)                                          \
  `AXIL_AX_T(``__NM__``, ``__AW__``, w)                                    \


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXIL_W_T(__NM__, __DW__)                                           \
  typedef struct packed {                                                  \
    logic [  ``__DW__``-1:0] data;                                         \
    logic [``__DW__``/8-1:0] strb;                                         \
  } ``__NM__``_w_t;                                                        \


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXIL_B_T(__NM__)                                                   \
  typedef struct packed {                                                  \
    logic [           1:0] resp;                                           \
  } ``__NM__``_b_t;                                                        \


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXIL_AR_T(__NM__, __AW__)                                          \
  `AXIL_AX_T(``__NM__``, ``__AW__``, r)                                    \


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXIL_R_T(__NM__, __DW__)                                           \
  typedef struct packed {                                                  \
    logic [           1:0] resp;                                           \
    logic [``__DW__``-1:0] data;                                           \
  } ``__NM__``_r_t;                                                        \



// @foez-bhai, add comments here about the purpose and usecase of this macro
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


// @foez-bhai, add comments here about the purpose and usecase of this macro
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


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXIL_T(__NM__, __AW__, __DW__)            \
  `AXIL_REQ_T(``__NM__``, ``__AW__``, ``__DW__``) \
  `AXIL_RESP_T(``__NM__``, ``__DW__``)            \


`endif
