# adn_axi_pmi_to_axil (module)

### Author: Motasim Faiyaz (motasimfaiyaz@gmail.com)

### Source: adn_axi_pmi_to_axil.sv

## Top IO

<img src="./adn_axi_pmi_to_axil_top.svg">

<img src="./adn_axi_pmi_to_axil_des.svg">

## Parameters

|Name|Type|Dimension|Default|Description|
|-|-|-|-|-|
|pmi_req_t|type||adn_axi_pmi_to_axil_pmi_default_req_t|PMI request type|
|pmi_rsp_t|type||adn_axi_pmi_to_axil_pmi_default_rsp_t|PMI response type|
|axil_req_t|type||adn_axi_pmi_to_axil_default_req_t|AXI4-Lite request type|
|axil_rsp_t|type||adn_axi_pmi_to_axil_default_rsp_t|AXI4-Lite response type|
|FIFO_DEPTH|int||4|Outstanding-txn tracking depth|


## Ports

|Name|Direction|Type|Dimension|Description|
|-|-|-|-|-|
|clk|input|logic||System clock|
|rst_n|input|logic||Active-low asynchronous reset|
|s_pmi_req|input|pmi_req_t||PMI request input|
|s_pmi_rsp|output|pmi_rsp_t||PMI response output|
|m_axil_req|output|axil_req_t||AXI4-Lite request output|
|m_axil_rsp|input|axil_rsp_t||AXI4-Lite response input|


## Description

### Purpose
This module serves as a bridge interface that converts PMI (Processor Memory Interface) protocol requests into AXI4-Lite master transactions. It manages address steering, write/read data handling, and response tracking using an internal FIFO to maintain transaction ordering and completion status.

### Use Case
The `adn_axi_pmi_to_axil` module is designed for SoC architectures where a processor or IP core utilizing the PMI protocol needs to interface with AXI4-Lite compliant peripherals or memory-mapped registers. It acts as a protocol translator, allowing the system to bridge lightweight, low-latency PMI requests into standard AXI4-Lite bus transactions. By incorporating an internal FIFO, it ensures that transaction ordering is preserved, making it suitable for systems requiring strict memory consistency or sequential completion of read/write operations across the bridge.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-23 | Motasim Faiyaz | Initial version                                        |
| 1.0      | 2026-08-23 | Motasim Faiyaz | Stable release                                         |

Author : Motasim Faiyaz (motasimfaiyaz@gmail.com)
