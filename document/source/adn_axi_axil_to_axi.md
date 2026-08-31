# adn_axi_axil_to_axi (module)

### Source: adn_axi_axil_to_axi.sv

## Top IO

<img src="./adn_axi_axil_to_axi_top.svg">

## Parameters

|Name|Type|Dimension|Default|Description|
|-|-|-|-|-|
|ID_WIDTH|int unsigned||4||
|ADDR_WIDTH|int unsigned||32||
|DATA_WIDTH|int unsigned||32||
|USER_WIDTH|int unsigned||1||
|AXI_AWID|logic [ID_WIDTH-1:0]||'0||
|AXI_ARID|logic [ID_WIDTH-1:0]||'0||
|AXI_CACHE|logic [3:0]||4'b0000||
|AXI_QOS|logic [3:0]||4'b0000||
|AXI_REGION|logic [3:0]||4'b0000||


## Ports

|Name|Direction|Type|Dimension|Description|
|-|-|-|-|-|
|clk|interface||||
|aresetn|interface||||
|s_axi_req|interface||||
|s_axi_rsp|interface||||
|m_axi_req|interface||||
|m_axi_rsp|interface||||


## Description

_No top-level description found._
