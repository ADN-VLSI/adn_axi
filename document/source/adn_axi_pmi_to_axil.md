# adn_axi_pmi_to_axil (module)

### Author: Motasim Faiyaz (motasimfaiyaz@gmail.com)

### Source: adn_axi_pmi_to_axil.sv

## Top IO

<img src="./adn_axi_pmi_to_axil_top.svg">

<img src="./adn_axi_pmi_to_axil_des.svg">

## Parameters

|Name|Type|Dimension|Default|Description|
|-|-|-|-|-|
|ADDR_WIDTH|int||32||
|DATA_WIDTH|int||32||
|pmi_req_t|type||logic||
|pmi_rsp_t|type||logic||
|axil_req_t|type||logic||
|axil_rsp_t|type||logic||
|OP_FIFO_SIZE|int||2|log2 depth of the op-type tracking FIFO|


## Ports

|Name|Direction|Type|Dimension|Description|
|-|-|-|-|-|
|clk_i|input|logic|||
|arst_ni|input|logic|||
|pmi_req_i|input|pmi_req_t||------------------------------------------------------------------------ PMI slave interface ------------------------------------------------------------------------|
|pmi_rsp_o|output|pmi_rsp_t|||
|axil_req_o|output|axil_req_t||------------------------------------------------------------------------ AXI4-Lite master interface ------------------------------------------------------------------------|
|axil_rsp_i|input|axil_rsp_t|||


## Description

### Purpose
This module serves as a bridge interface that converts PMI (Processor Memory Interface) protocol requests into AXI4-Lite master transactions. It manages address steering, write/read data handling, and response tracking using an internal FIFO to maintain transaction ordering and completion status.

### Use Case
The `adn_axi_pmi_to_axil` module is designed for SoC architectures where a processor or IP core utilizing the PMI protocol needs to interface with AXI4-Lite compliant peripherals or memory-mapped registers. It acts as a protocol translator, allowing the system to bridge lightweight, low-latency PMI requests into standard AXI4-Lite bus transactions. By incorporating an internal FIFO, it ensures that transaction ordering is preserved, making it suitable for systems requiring strict memory consistency or sequential completion of read/write operations across the bridge.

| REVISION | DATE       | AUTHOR         | DESCRIPTION                                            |
|----------|------------|----------------|--------------------------------------------------------|
| 1.0      | 2026-08-13 | Motasim Faiyaz | Initial version                                        |
| 1.1      | 2026-08-23 | Motasim Faiyaz | Added response tracking                                |
| 1.2      | 2026-08-24 | Motasim Faiyaz | Uses pre-built subcomponents  utility                  |

Author : Motasim Faiyaz (motasimfaiyaz@gmail.com)
