# axi/axi_fifo_tb_macro.svh  (include)

### Source: axi_fifo_tb_macro.svh

## Parameters

_None_


## Include Guard

__GUARD_AXI_TB_MACROS_SVH__


## Macros

|Name|Args|Description|Preview|
|-|-|-|-|
|GEN_DRIVE_REQ_TASK|CH, TYPE|================================================================== REQUEST-DIRECTION DRIVER  (AW, W, AR) ==================================================================|`define GEN_DRIVE_REQ_TASK(CH, TYPE)                                 task automatic drive_``CH``(TYPE item);                            @(posedge clk_i);|
|GEN_DRIVE_RESP_TASK|CH, TYPE|================================================================== RESPONSE-DIRECTION DRIVER  (B, R channel) ==================================================================|`define GEN_DRIVE_RESP_TASK(CH, TYPE)                                task automatic drive_``CH``(TYPE item);                            @(posedge clk_i);|
|GEN_CHECK_REQ_TASK|CH, TYPE|================================================================== REQUEST-DIRECTION CHECKER  (output side = mst_req_o, AW/W/AR) ==================================================================|`define GEN_CHECK_REQ_TASK(CH, TYPE)                                  task automatic check_``CH``();                                      forever begin|
|GEN_CHECK_RESP_TASK|CH, TYPE|================================================================== RESPONSE-DIRECTION CHECKER  (output side = slv_resp_o, B/R) ==================================================================|`define GEN_CHECK_RESP_TASK(CH, TYPE)                                task automatic check_``CH``();                                     forever begin|


## Description

_No top-level description found._
