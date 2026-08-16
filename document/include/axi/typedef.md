# axi/typedef.svh  (include)

### Author: Foez Ahmed (foez.official@gmail.com)

### Source: typedef.svh

## Parameters

_None_


## Include Guard

__GUARD_AXI_TYPEDEF_SVH__


## Macros

|Name|Args|Description|Preview|
|-|-|-|-|
|AXI_AX_T|__NM__, __IW__, __AW__, __UW__, __TP__|@brief Generates a packed struct for AXI Address channels (AW or AR). @param __NM__ Name prefix for the generated struct. @param __IW__ ID width. @param __AW__ Address width. @param __UW__ User signal width. @param __TP__ Type suffix (w for write, r for read).|`define AXI_AX_T(__NM__, __IW__, __AW__, __UW__, __TP__)                    typedef struct packed {                                                   logic [  `|
|AXI_AW_T|__NM__, __IW__, __AW__, __UW__|@brief Generates a packed struct for the AXI Write Address channel. @param __NM__ Name prefix for the generated struct. @param __IW__ ID width. @param __AW__ Address width. @param __UW__ User signal width.|`define AXI_AW_T(__NM__, __IW__, __AW__, __UW__)                            `AXI_AX_T(``__NM__``, ``__IW__``, ``__AW__``, ``__UW__``, w)|
|AXI_W_T|__NM__, __DW__, __UW__|@brief Generates a packed struct for the AXI Write Data channel. @param __NM__ Name prefix for the generated struct. @param __DW__ Data width. @param __UW__ User signal width.|`define AXI_W_T(__NM__, __DW__, __UW__)                                     typedef struct packed {                                                   logic [  `|
|AXI_B_T|__NM__, __IW__, __UW__|@brief Generates a packed struct for the AXI Write Response channel. @param __NM__ Name prefix for the generated struct. @param __IW__ ID width. @param __UW__ User signal width.|`define AXI_B_T(__NM__, __IW__, __UW__)                                     typedef struct packed {                                                   logic [  `|
|AXI_AR_T|__NM__, __IW__, __AW__, __UW__|@brief Generates a packed struct for the AXI Read Address channel. @param __NM__ Name prefix for the generated struct. @param __IW__ ID width. @param __AW__ Address width. @param __UW__ User signal width.|`define AXI_AR_T(__NM__, __IW__, __AW__, __UW__)                            `AXI_AX_T(``__NM__``, ``__IW__``, ``__AW__``, ``__UW__``, r)|
|AXI_R_T|__NM__, __IW__, __DW__, __UW__|@brief Generates a packed struct for the AXI Read Data channel. @param __NM__ Name prefix for the generated struct. @param __IW__ ID width. @param __DW__ Data width. @param __UW__ User signal width.|`define AXI_R_T(__NM__, __IW__, __DW__, __UW__)                             typedef struct packed {                                                   logic [  `|
|AXI_REQ_T|__NM__, __IW__, __AW__, __DW__, __UW__|@brief Generates a combined AXI request structure containing AW, W, and AR channels. @usecase Used to bundle all AXI request signals into a single packed struct for simplified port mapping.|`define AXI_REQ_T(__NM__, __IW__, __AW__, __DW__, __UW__)        `AXI_AW_T(``__NM__``, ``__IW__``, ``__AW__``, ``__UW__``)      `AXI_W_T(``__NM__``, ``__DW__``,|
|AXI_RSP_T|__NM__, __IW__, __DW__, __UW__|@brief Generates a combined AXI response structure containing B and R channels. @usecase Used to bundle all AXI response signals into a single packed struct for simplified port mapping.|`define AXI_RSP_T(__NM__, __IW__, __DW__, __UW__)               `AXI_B_T(``__NM__``, ``__IW__``, ``__UW__``)                   `AXI_R_T(``__NM__``, ``__IW__``,|
|AXI_T|__NM__, __IW__, __AW__, __DW__, __UW__|@brief Generates a complete AXI interface structure containing both request and response channels. @usecase Used to instantiate a full AXI master/slave interface bundle in a single line.|`define AXI_T(__NM__, __IW__, __AW__, __DW__, __UW__)                     `AXI_REQ_T(``__NM__``, ``__IW__``, ``__AW__``, ``__DW__``, ``__UW__``)  `AXI_RSP_T(``_|


## Description

### Purpose
This file defines a collection of SystemVerilog macros used to generate packed structures for AXI4 interface signals. It provides a standardized way to define AXI channel types (AW, W, B, AR, R) and combined request/response structures, ensuring consistency across the ADN-VLSI/adn_axi project.

### Use Case
This file serves as a centralized library for AXI4 interface definitions. By utilizing these macros, developers can instantiate standardized, packed SystemVerilog structures for AXI channels with configurable widths for IDs, addresses, data, and user signals. This ensures type safety and reduces boilerplate code when connecting AXI-compliant modules within the ADN-VLSI ecosystem.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-04 | Foez Ahmed      | Initial version                                        |

Author : Foez Ahmed (foez.official@gmail.com)
