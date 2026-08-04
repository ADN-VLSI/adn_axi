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

`ifndef __GUARD_AXIL_ASSIGN_SVH__
`define __GUARD_AXIL_ASSIGN_SVH__ 0


// @foez-bhai, add comments here about the purpose and usecase of this macro
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
  ``__MT__`` ``__M__``.b.resp     ``__AS__`` {'0, ``__S__``.b.resp};        \
  ``__MT__`` ``__M__``.b_valid    ``__AS__`` {'0, ``__S__``.b_valid};       \
  ``__MT__`` ``__S__``.b_ready    ``__AS__`` {'0, ``__M__``.b_ready};       \
                                                                            \
  ``__MT__`` ``__S__``.ar.addr    ``__AS__`` {'0, ``__M__``.ar.addr};       \
  ``__MT__`` ``__S__``.ar.prot    ``__AS__`` {'0, ``__M__``.ar.prot};       \
  ``__MT__`` ``__S__``.ar_valid   ``__AS__`` {'0, ``__M__``.ar_valid};      \
  ``__MT__`` ``__M__``.ar_ready   ``__AS__`` {'0, ``__S__``.ar_ready};      \
                                                                            \
  ``__MT__`` ``__M__``.r.data     ``__AS__`` {'0, ``__S__``.r.data};        \
  ``__MT__`` ``__M__``.r.resp     ``__AS__`` {'0, ``__S__``.r.resp};        \
  ``__MT__`` ``__M__``.r_valid    ``__AS__`` {'0, ``__S__``.r_valid};       \
  ``__MT__`` ``__S__``.r_ready    ``__AS__`` {'0, ``__M__``.r_ready};       \
  


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXIL_COMB_ASSIGN(__M__, __S__)                                  \
  `AXIL_COMMUNICATION(``__M__``, ``__S__``, always_comb, =)             \


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXIL_BLOCKING_ASSIGN(__M__, __S__)                              \
  `AXIL_COMMUNICATION(``__M__``, ``__S__``, , =)                        \


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define AXIL_NONBLOCKING_ASSIGN(__M__, __S__)                           \
  `AXIL_COMMUNICATION(``__M__``, ``__S__``, , <=)                       \


`endif
