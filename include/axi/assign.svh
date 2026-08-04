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

`ifndef __GUARD_AXI_ASSIGN_SVH__
`define __GUARD_AXI_ASSIGN_SVH__ 0


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXI_COMMUNICATION(__M__, __S__, __MT__, __AS__)                     \
                                                                            \
  ``__MT__`` ``__S__``.aw.id      ``__AS__`` {'0, ``__M__``.aw.id};         \
  ``__MT__`` ``__S__``.aw.addr    ``__AS__`` {'0, ``__M__``.aw.addr};       \
  ``__MT__`` ``__S__``.aw.len     ``__AS__`` {'0, ``__M__``.aw.len};        \
  ``__MT__`` ``__S__``.aw.size    ``__AS__`` {'0, ``__M__``.aw.size};       \
  ``__MT__`` ``__S__``.aw.burst   ``__AS__`` {'0, ``__M__``.aw.burst};      \
  ``__MT__`` ``__S__``.aw.lock    ``__AS__`` {'0, ``__M__``.aw.lock};       \
  ``__MT__`` ``__S__``.aw.cache   ``__AS__`` {'0, ``__M__``.aw.cache};      \
  ``__MT__`` ``__S__``.aw.prot    ``__AS__`` {'0, ``__M__``.aw.prot};       \
  ``__MT__`` ``__S__``.aw.qos     ``__AS__`` {'0, ``__M__``.aw.qos};        \
  ``__MT__`` ``__S__``.aw.region  ``__AS__`` {'0, ``__M__``.aw.region};     \
  ``__MT__`` ``__S__``.aw.user    ``__AS__`` {'0, ``__M__``.aw.user};       \
  ``__MT__`` ``__S__``.aw_valid   ``__AS__`` {'0, ``__M__``.aw_valid};      \
  ``__MT__`` ``__M__``.aw_ready   ``__AS__`` {'0, ``__S__``.aw_ready};      \
                                                                            \
  ``__MT__`` ``__S__``.w.data     ``__AS__`` {'0, ``__M__``.w.data};        \
  ``__MT__`` ``__S__``.w.strb     ``__AS__`` {'0, ``__M__``.w.strb};        \
  ``__MT__`` ``__S__``.w.last     ``__AS__`` {'0, ``__M__``.w.last};        \
  ``__MT__`` ``__S__``.w.user     ``__AS__`` {'0, ``__M__``.w.user};        \
  ``__MT__`` ``__S__``.w_valid    ``__AS__`` {'0, ``__M__``.w_valid};       \
  ``__MT__`` ``__M__``.w_ready    ``__AS__`` {'0, ``__S__``.w_ready};       \
                                                                            \
  ``__MT__`` ``__M__``.b.id       ``__AS__`` {'0, ``__S__``.b.id};          \
  ``__MT__`` ``__M__``.b.resp     ``__AS__`` {'0, ``__S__``.b.resp};        \
  ``__MT__`` ``__M__``.b.user     ``__AS__`` {'0, ``__S__``.b.user};        \
  ``__MT__`` ``__M__``.b_valid    ``__AS__`` {'0, ``__S__``.b_valid};       \
  ``__MT__`` ``__S__``.b_ready    ``__AS__`` {'0, ``__M__``.b_ready};       \
                                                                            \
  ``__MT__`` ``__S__``.ar.id      ``__AS__`` {'0, ``__M__``.ar.id};         \
  ``__MT__`` ``__S__``.ar.addr    ``__AS__`` {'0, ``__M__``.ar.addr};       \
  ``__MT__`` ``__S__``.ar.len     ``__AS__`` {'0, ``__M__``.ar.len};        \
  ``__MT__`` ``__S__``.ar.size    ``__AS__`` {'0, ``__M__``.ar.size};       \
  ``__MT__`` ``__S__``.ar.burst   ``__AS__`` {'0, ``__M__``.ar.burst};      \
  ``__MT__`` ``__S__``.ar.lock    ``__AS__`` {'0, ``__M__``.ar.lock};       \
  ``__MT__`` ``__S__``.ar.cache   ``__AS__`` {'0, ``__M__``.ar.cache};      \
  ``__MT__`` ``__S__``.ar.prot    ``__AS__`` {'0, ``__M__``.ar.prot};       \
  ``__MT__`` ``__S__``.ar.qos     ``__AS__`` {'0, ``__M__``.ar.qos};        \
  ``__MT__`` ``__S__``.ar.region  ``__AS__`` {'0, ``__M__``.ar.region};     \
  ``__MT__`` ``__S__``.ar.user    ``__AS__`` {'0, ``__M__``.ar.user};       \
  ``__MT__`` ``__S__``.ar_valid   ``__AS__`` {'0, ``__M__``.ar_valid};      \
  ``__MT__`` ``__M__``.ar_ready   ``__AS__`` {'0, ``__S__``.ar_ready};      \
                                                                            \
  ``__MT__`` ``__M__``.r.id       ``__AS__`` {'0, ``__S__``.r.id};          \
  ``__MT__`` ``__M__``.r.data     ``__AS__`` {'0, ``__S__``.r.data};        \
  ``__MT__`` ``__M__``.r.resp     ``__AS__`` {'0, ``__S__``.r.resp};        \
  ``__MT__`` ``__M__``.r.last     ``__AS__`` {'0, ``__S__``.r.last};        \
  ``__MT__`` ``__M__``.r.user     ``__AS__`` {'0, ``__S__``.r.user};        \
  ``__MT__`` ``__M__``.r_valid    ``__AS__`` {'0, ``__S__``.r_valid};       \
  ``__MT__`` ``__S__``.r_ready    ``__AS__`` {'0, ``__M__``.r_ready};       \
  


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXI_COMB_ASSIGN(__M__, __S__)                                  \
  `AXI_COMMUNICATION(``__M__``, ``__S__``, always_comb, =)             \


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXI_BLOCKING_ASSIGN(__M__, __S__)                              \
  `AXI_COMMUNICATION(``__M__``, ``__S__``, , =)                        \


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXI_NONBLOCKING_ASSIGN(__M__, __S__)                           \
  `AXI_COMMUNICATION(``__M__``, ``__S__``, , <=)                       \


`endif
