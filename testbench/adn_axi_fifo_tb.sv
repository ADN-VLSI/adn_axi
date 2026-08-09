/*

| TEST CASE | DATE       | AUTHOR          | DESCRIPTION                                           |
|-----------|------------|-----------------|-------------------------------------------------------|
| TC_001    | 2026-08-09 | Adnan Sami Anirban | Test case description goes here                       |
| TC_002    | 2026-08-09 | Adnan Sami Anirban | Test case description goes here                       |

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-09 | Adnan Sami Anirban | Initial version                                        |
| 1.0      | 2026-08-09 | Adnan Sami Anirban | Stable release                                         |

Author : Adnan Sami Anirban (adnananirban259@gmail.com)
This file is part of ADN-VLSI/adn_axi
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_axi_fifo_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"
  `include "axi/typedef.svh"
  `include "axi/axi_fifo_tb_macro.svh"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  localparam int  AXI_ID_WIDTH   = 3;
  localparam int  AXI_ADDR_WIDTH = 32;
  localparam int  AXI_DATA_WIDTH = 32;
  localparam int  AXI_USER_WIDTH = 4;
  `AXI_REQ_T(axi, AXI_ID_WIDTH, AXI_ADDR_WIDTH, AXI_DATA_WIDTH, AXI_USER_WIDTH)
  `AXI_RESP_T(axi, AXI_ID_WIDTH, AXI_DATA_WIDTH, AXI_USER_WIDTH)
  localparam int  FIFO_SIZE    = 4;
  localparam int  AW_FIFO_SIZE = FIFO_SIZE;
  localparam int  W_FIFO_SIZE  = FIFO_SIZE;
  localparam int  B_FIFO_SIZE  = FIFO_SIZE;
  localparam int  AR_FIFO_SIZE = FIFO_SIZE;
  localparam int  R_FIFO_SIZE  = FIFO_SIZE;
  localparam time CLK_PERIOD   = 10ns;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  logic       clk_i;
  logic       arst_ni;
  axi_req_t   slv_req_i;
  axi_resp_t  slv_resp_o;
  axi_req_t   mst_req_o;
  axi_resp_t  mst_resp_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////
  axi_aw_t  aw_ref_q  [$];
  axi_w_t   w_ref_q   [$];
  axi_b_t   b_ref_q   [$];
  axi_ar_t  ar_ref_q  [$];
  axi_r_t   r_ref_q   [$];

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERFACES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // CLASSES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////
adn_axi_fifo #(
    .axi_req_t (axi_req_t),
    .axi_resp_t(axi_resp_t),
    .AW_FIFO_SIZE(AW_FIFO_SIZE),
    .W_FIFO_SIZE(W_FIFO_SIZE),
    .B_FIFO_SIZE(B_FIFO_SIZE),
    .AR_FIFO_SIZE(AR_FIFO_SIZE),
    .R_FIFO_SIZE(R_FIFO_SIZE)
  )dut(
      .clk_i      (clk_i     ),  
      .arst_ni    (arst_ni   ),  
      .slv_req_i  (slv_req_i ),  
      .slv_resp_o (slv_resp_o),  
      .mst_req_o  (mst_req_o ),  
      .mst_resp_i (mst_resp_i)  
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `GEN_DRIVE_REQ_TASK(aw, axi_aw_t)
  `GEN_DRIVE_REQ_TASK(w,  axi_w_t)
  `GEN_DRIVE_REQ_TASK(ar, axi_ar_t)
  `GEN_DRIVE_RESP_TASK(b, axi_b_t)
  `GEN_DRIVE_RESP_TASK(r, axi_r_t)

  `GEN_CHECK_REQ_TASK(aw, axi_aw_t)
  `GEN_CHECK_REQ_TASK(w,  axi_w_t)
  `GEN_CHECK_REQ_TASK(ar, axi_ar_t)
  `GEN_CHECK_RESP_TASK(b, axi_b_t)
  `GEN_CHECK_RESP_TASK(r, axi_r_t)

  task automatic apply_reset();
    arst_ni    = 1'b0;
    slv_req_i  = '0;
    mst_resp_i = '0;
    repeat (5) @(posedge clk_i);
    arst_ni = 1'b1;
    @(posedge clk_i);
  endtask

// TC_001 : single AW transaction pass-through sanity check
  task automatic tc_001_basic_aw();
    axi_aw_t item;
    mst_resp_i.aw_ready = 1'b1;   // output side always ready, no backpressure

    item.id     = 3'h1;
    item.addr   = 32'hA000_0000;
    item.len    = 8'h0;
    item.size   = 3'h2;
    item.burst  = 2'b01;
    item.lock   = 1'b0;
    item.cache  = 4'h0;
    item.prot   = 3'h0;
    item.qos    = 4'h0;
    item.region = 4'h0;
    item.user   = 4'h0;

    drive_aw(item);

    repeat (3) @(posedge clk_i);
    if (aw_ref_q.size() == 0)
      note_case(1); 
    else
      note_case(0);
  endtask

task automatic tc_002_aw_fifo_full();
    axi_aw_t item;
    int push_count;
    localparam int AW_FIFO_DEPTH = 2 ** AW_FIFO_SIZE;

    mst_resp_i.aw_ready <= 1'b0;

    for (push_count = 0; push_count < AW_FIFO_DEPTH; push_count++) begin
      item.id       = 3'(push_count);
      item.addr     = 32'h1000_0000 + push_count;
      item.len      = 8'h0;
      item.size     = 3'h2;
      item.burst    = 2'b01;
      item.lock     = 1'b0;
      item.cache    = 4'h0;
      item.prot     = 3'h0;
      item.qos      = 4'h0;
      item.region   = 4'h0;
      item.user     = 4'h0;
      drive_aw(item);
      $display("T=%0t: pushed #%0d, ready=%b", $time, push_count+1, slv_resp_o.aw_ready);
    end
    //#(10ns);   // wait a bit for the last push to be processed
    @(posedge clk_i);
    if (slv_resp_o.aw_ready === 1'b0)
      note_case(1);   
    else
      note_case(0);  

    mst_resp_i.aw_ready <= 1'b1;
    repeat (AW_FIFO_DEPTH + 2) @(posedge clk_i);
endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial clk_i = 1'b0;
  always #(CLK_PERIOD/2) clk_i = ~clk_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

initial begin
  apply_reset();
  $display("T=%0t: reset done", $time);

  fork
    check_aw(); check_w(); check_b(); check_ar(); check_r();
  join_none

  $display("T=%0t: starting tc_001", $time);
  tc_001_basic_aw();
  $display("T=%0t: tc_001 done", $time);

  $display("T=%0t: starting tc_002", $time);
  tc_002_aw_fifo_full();
  $display("T=%0t: tc_002 done", $time);

  $finish;
end

endmodule