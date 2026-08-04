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


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXI_AW_T(__NM__, __IW__, __AW__, __UW__)                           \
  `AXI_AX_T(``__NM__``, ``__IW__``, ``__AW__``, ``__UW__``, w)             \


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXI_W_T(__NM__, __DW__, __UW__)                                    \
  typedef struct packed {                                                  \
    logic [  ``__DW__``-1:0] data;                                         \
    logic [``__DW__``/8-1:0] strb;                                         \
    logic                    last;                                         \
    logic [  ``__UW__``-1:0] user;                                         \
  } ``__NM__``_w_t;                                                        \


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXI_B_T(__NM__, __IW__, __UW__)                                    \
  typedef struct packed {                                                  \
    logic [  ``__IW__``-1:0] id;                                           \
    logic [             1:0] resp;                                         \
    logic [  ``__UW__``-1:0] user;                                         \
  } ``__NM__``_b_t;                                                        \


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXI_AR_T(__NM__, __IW__, __AW__, __UW__)                           \
  `AXI_AX_T(``__NM__``, ``__IW__``, ``__AW__``, ``__UW__``, r)             \


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXI_R_T(__NM__, __IW__, __DW__, __UW__)                            \
  typedef struct packed {                                                  \
    logic [  ``__IW__``-1:0] id;                                           \
    logic [  ``__DW__``-1:0] data;                                         \
    logic [             1:0] resp;                                         \
    logic                    last;                                         \
    logic [  ``__UW__``-1:0] user;                                         \
  } ``__NM__``_r_t;                                                        \



// @foez-bhai, add comments here about the purpose and usecase of this macro
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


// @foez-bhai, add comments here about the purpose and usecase of this macro
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


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXI_T(__NM__, __IW__, __AW__, __DW__, __UW__)                    \
  `AXI_REQ_T(``__NM__``, ``__IW__``, ``__AW__``, ``__DW__``, ``__UW__``) \
  `AXI_RESP_T(``__NM__``, ``__IW__``, ``__DW__``, ``__UW__``)            \


`endif
