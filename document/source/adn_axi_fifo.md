# adn_axi_fifo (module)

### Source: adn_axi_fifo.sv

## Top IO

<img src="./adn_axi_fifo_top.svg">

## Parameters

|Name|Type|Dimension|Default|Description|
|-|-|-|-|-|
|axi_req_t|type||logic|AXI request structure type|
|axi_resp_t|type||logic|AXI response structure type|
|FIFO_SIZE|int||4|Default FIFO depth for all channels|
|AW_FIFO_SIZE|int||FIFO_SIZE|Write Address channel FIFO depth|
|W_FIFO_SIZE|int||FIFO_SIZE|Write Data channel FIFO depth|
|B_FIFO_SIZE|int||FIFO_SIZE|Write Response channel FIFO depth|
|AR_FIFO_SIZE|int||FIFO_SIZE|Read Address channel FIFO depth|
|R_FIFO_SIZE|int||FIFO_SIZE|Read Data channel FIFO depth|


## Ports

|Name|Direction|Type|Dimension|Description|
|-|-|-|-|-|
|clk_i|input|logic||System clock|
|arst_ni|input|logic||Asynchronous reset, active low|
|slv_req_i|input|axi_req_t||AXI request signals from Master|
|slv_resp_o|output|axi_resp_t||AXI response signals to Master|
|mst_req_o|output|axi_req_t||AXI request signals to Slave|
|mst_resp_i|input|axi_resp_t||AXI response signals from Slave|


## Description

_No top-level description found._
