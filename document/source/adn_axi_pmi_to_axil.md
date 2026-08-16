# adn_axi_pmi_to_axil (module)

### Author: Motasim Faiyaz (motasimfaiyaz@gmail.com)

### Source: adn_axi_pmi_to_axil.sv

## Top IO

<img src="./adn_axi_pmi_to_axil_top.svg">

<img src="./adn_axi_pmi_to_axil_des.svg">

## Parameters

|Name|Type|Dimension|Default|Description|
|-|-|-|-|-|
|ADDR_WIDTH|int||32|Width of the address bus|
|DATA_WIDTH|int||32|Width of the data bus|
|STRB_WIDTH|int||DATA_WIDTH / 8|Width of the write strobe signal|


## Ports

|Name|Direction|Type|Dimension|Description|
|-|-|-|-|-|
|clk|input|logic||System clock|
|rst_n|input|logic||Asynchronous, active-low reset|
|mreq|input|logic|||
|mwe|input|logic|||
|maddr|input|logic [ADDR_WIDTH-1:0]|||
|mwdata|input|logic [DATA_WIDTH-1:0]||Write data bus|
|mstrb|input|logic [STRB_WIDTH-1:0]||Write strobe|
|mgnt|output|logic||Grant signal to PMI master|
|mack|output|logic||Acknowledge signal to PMI master|
|mrsp|output|logic [ 1:0]||Response status (OKAY, SLVERR, etc.)|
|mrdata|output|logic [DATA_WIDTH-1:0]||Read data bus|
|aw_addr|output|logic [ADDR_WIDTH-1:0]||AXI write address|
|aw_prot|output|logic [ 2:0]||AXI protection type|
|aw_valid|output|logic||AXI write address valid|
|aw_ready|input|logic||AXI write address ready|
|w_data|output|logic [DATA_WIDTH-1:0]||AXI write data|
|w_strb|output|logic [STRB_WIDTH-1:0]||AXI write strobe|
|w_valid|output|logic||AXI write valid|
|w_ready|input|logic||AXI write ready|
|b_rsp|input|logic [ 1:0]||AXI write response|
|b_valid|input|logic||AXI write response valid|
|b_ready|output|logic||AXI write response ready|
|ar_addr|output|logic [ADDR_WIDTH-1:0]||AXI read address|
|ar_prot|output|logic [ 2:0]||AXI read protection type|
|ar_valid|output|logic||AXI read address valid|
|ar_ready|input|logic||AXI read address ready|
|r_data|input|logic [DATA_WIDTH-1:0]||AXI read data|
|r_rsp|input|logic [ 1:0]||AXI read response|
|r_valid|input|logic||AXI read valid|
|r_ready|output|logic||AXI read ready|


## Description

Module: adn_axi_pmi_to_axil
Purpose:
This module acts as a protocol bridge, converting simple PMI-style (Processor Memory Interface)
slave requests into AXI4-Lite master transactions. It enables legacy or simplified
peripheral interfaces to communicate with AXI4-Lite compliant interconnects or slaves.

Use Case:
This is intended for system-on-chip (SoC) designs where a lightweight, non-pipelined
register access bus (PMI) needs to interface with standard AXI4-Lite peripherals.
It is ideal for control-plane register access where transaction throughput is
secondary to simplicity and compatibility.

Purpose
-------
Bridge from a simple PMI-style slave port (mreq/mwe/maddr/...) to an
AXI4-Lite master port. The original implementation lives in this file and
has been refactored to use the project's AXI4-Lite packed `request` and
`response` structs (see include/axil/typedef.svh) while preserving the
original scalar port interface for backwards compatibility.

Use Case
--------
Used where a PMI-style register access bus must be translated to an
AXI4-Lite master to talk to peripheral registers.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-13 | Motasim Faiyaz | Initial version (refactor to use typedef structs)      |
| 0.2      | 2026-08-14 | Motasim Faiyaz | Updated documentation and parameter descriptions       |

Author : Motasim Faiyaz (motasimfaiyaz@gmail.com)
