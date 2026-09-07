# adn_axi_agu_burst_splitter (module)

### Author: Motasim Faiyaz (motasimfaiyaz@gmail.com)

### Source: adn_axi_agu_burst_splitter.sv

## Top IO

<img src="./adn_axi_agu_burst_splitter_top.svg">

## Parameters

|Name|Type|Dimension|Default|Description|
|-|-|-|-|-|
|ADDR_WIDTH|int||32|//////////////////////////////////////////////////////////////////////////////////////////////// PARAMETERS ////////////////////////////////////////////////////////////////////////////////////////////////|
|DATA_WIDTH|int||32||
|ID_WIDTH|int||4||
|STRB_WIDTH|int||DATA_WIDTH/8||
|axi_req_t|type||logic||
|axi_rsp_t|type||logic||
|axil_req_t|type||logic||
|axil_rsp_t|type||logic||


## Ports

|Name|Direction|Type|Dimension|Description|
|-|-|-|-|-|
|clk_i|input|logic|||
|arst_ni|input|logic|||
|axi_req_i|input|axi_req_t||//////////////////////////////////////////////////////////////////////////////////////////////// INTERFACES : AXI4 (full) slave -- burst side ////////////////////////////////////////////////////////////////////////////////////////////////|
|axi_rsp_o|output|axi_rsp_t|||
|axil_req_o|output|axil_req_t||//////////////////////////////////////////////////////////////////////////////////////////////// INTERFACES : AXI4-Lite master -- split single-beat side ////////////////////////////////////////////////////////////////////////////////////////////////|
|axil_rsp_i|input|axil_rsp_t|||


## Description

This module implements an Address Generation Unit (AGU) that decomposes AXI4 burst transactions into a series of individual AXI4-Lite write transactions. It handles address calculation for FIXED, INCR, and WRAP burst types and manages the handshake synchronization between the AXI4 burst interface and the AXI4-Lite beat-by-beat interface.

### Use Case
The `adn_axi_agu_burst_splitter` is designed to bridge high-performance AXI4 burst-capable masters with simpler AXI4-Lite peripherals. Its primary use cases include:
- **Protocol Conversion:** Enabling AXI4 masters to communicate with AXI4-Lite slaves that do not support burst transactions.
- **System Integration:** Simplifying the design of peripherals by offloading the complexity of burst address calculation (including wrapping logic) to a dedicated hardware block.
- **Resource Optimization:** Providing a compact, shared-datapath implementation of address generation that handles multiple burst types (FIXED, INCR, WRAP) without requiring redundant hardware logic.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-09-03 | Motasim Faiyaz | Initial version                                        |
| 1.0      | 2026-09-03 | Motasim Faiyaz | Stable release                                         |

Author : Motasim Faiyaz (motasimfaiyaz@gmail.com)
