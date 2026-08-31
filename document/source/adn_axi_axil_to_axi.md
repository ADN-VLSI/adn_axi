# adn_axi_axil_to_axi (module)

### Author: Md. Sakib Hasan Shawon (mdsakibhasanshawon20@gmail.com)

### Source: adn_axi_axil_to_axi.sv

## Top IO

<img src="./adn_axi_axil_to_axi_top.svg">

<img src="./adn_axi_axil_to_axi_des.svg">

## Parameters

|Name|Type|Dimension|Default|Description|
|-|-|-|-|-|
|ADDR_WIDTH|int||32|Width of the address bus|
|DATA_WIDTH|int||32|Width of the data bus|
|ID_WIDTH|int||4|Width of the AXI ID signals|
|USER_WIDTH|int||1|Width of the user sideband signals|
|axil_req_t|type||logic|AXI4-Lite request struct type|
|axil_rsp_t|type||logic|AXI4-Lite response struct type|
|axi_req_t|type||logic|AXI4 request struct type|
|axi_rsp_t|type||logic|AXI4 response struct type|


## Ports

|Name|Direction|Type|Dimension|Description|
|-|-|-|-|-|
|clk_i|input|logic||System clock|
|rst_ni|input|logic||Active-low asynchronous reset|
|s_req_i|input|axil_req_t||Slave request signals|
|s_rsp_o|output|axil_rsp_t||Slave response signals|
|m_req_o|output|axi_req_t||Master request signals|
|m_rsp_i|input|axi_rsp_t||Master response signals|


## Description

This module acts as a protocol bridge that converts AXI4-Lite transactions into full AXI4 transactions. It manages the necessary buffering and state transitions to ensure that AXI4-Lite read and write requests are correctly mapped to the AXI4 interface, handling handshake signals and response propagation between the two protocols.

### Use Case
The `adn_axi_axil_to_axi` module is designed to interface AXI4-Lite masters (such as simple control registers or low-bandwidth peripherals) with high-performance AXI4 interconnects or memory controllers. It effectively acts as a protocol converter, allowing a system to integrate legacy or simplified AXI4-Lite components into a full-featured AXI4 system-on-chip (SoC) architecture without requiring the master to support the full AXI4 burst and ID features.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-27 | Md. Sakib Hasan Shawon | Initial version                                        |
| 1.0      | 2026-08-27 | Md. Sakib Hasan Shawon | Stable release                                         |

Author : Md. Sakib Hasan Shawon (mdsakibhasanshawon20@gmail.com)
