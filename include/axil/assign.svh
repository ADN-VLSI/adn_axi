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
`define APB_COMMUNICATION(__M__, __S__, __MT__, __AS__)               \
  ``__MT__`` ``__S__``.psel    ``__AS__`` {'0, ``__M__``.psel};       \
  ``__MT__`` ``__S__``.penable ``__AS__`` {'0, ``__M__``.penable};    \
  ``__MT__`` ``__S__``.paddr   ``__AS__`` {'0, ``__M__``.paddr};      \
  ``__MT__`` ``__S__``.pprot   ``__AS__`` {'0, ``__M__``.pprot};      \
  ``__MT__`` ``__S__``.pwrite  ``__AS__`` {'0, ``__M__``.pwrite};     \
  ``__MT__`` ``__S__``.pwdata  ``__AS__`` {'0, ``__M__``.pwdata};     \
  ``__MT__`` ``__S__``.pstrb   ``__AS__`` {'0, ``__M__``.pstrb};      \
  ``__MT__`` ``__M__``.pready  ``__AS__`` {'0, ``__S__``.pready};     \
  ``__MT__`` ``__M__``.prdata  ``__AS__`` {'0, ``__S__``.prdata};     \
  ``__MT__`` ``__M__``.pslverr ``__AS__`` {'0, ``__S__``.pslverr};    \


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define APB_COMB_ASSIGN(__M__, __S__)                                 \
  `APB_COMMUNICATION(``__M__``, ``__S__``, always_comb, =)            \


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define APB_BLOCKING_ASSIGN(__M__, __S__)                             \
  `APB_COMMUNICATION(``__M__``, ``__S__``, , =)                       \


// @foez-bhai, add comments here about the purpose and usecase of this macro
`define APB_NONBLOCKING_ASSIGN(__M__, __S__)                          \
  `APB_COMMUNICATION(``__M__``, ``__S__``, , <=)                      \


`endif
