# adn_axi_axil_to_dual_pmi (module)

### Author: Adnan Sami Anirban (adnananirban259@gmail.com)

### Source: adn_axi_axil_to_dual_pmi.sv

## Top IO

<img src="./adn_axi_axil_to_dual_pmi_top.svg">

<img src="./adn_axi_axil_to_dual_pmi_des.svg">

## Parameters

|Name|Type|Dimension|Default|Description|
|-|-|-|-|-|
|axil_req_t|type||logic|PARAMETERS|
|axil_rsp_t|type||logic||
|pmi_req_t|type||logic||
|pmi_rsp_t|type||logic||
|PIPELINE_DEPTH|int||8||
|FIFO_SIZE|int||$clog2(PIPELINE_DEPTH)||


## Ports

|Name|Direction|Type|Dimension|Description|
|-|-|-|-|-|
|clk_i|input|logic||PORTS|
|arst_ni|input|logic|||
|axil_req_i|input|axil_req_t|||
|axil_rsp_o|output|axil_rsp_t|||
|pmi_req_wr_o|output|pmi_req_t|||
|pmi_rsp_wr_i|input|pmi_rsp_t|||
|pmi_req_rd_i|output|pmi_req_t|||
|pmi_rsp_rd_i|input|pmi_rsp_t|||


## Description

@foez---bhai, write the purpose of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

@foez---bhai, describe the use case of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-13 | Adnan Sami Anirban | Initial version                                        |
| 1.0      | 2026-08-13 | Adnan Sami Anirban | Stable release                                         |

Author : Adnan Sami Anirban (adnananirban259@gmail.com)
