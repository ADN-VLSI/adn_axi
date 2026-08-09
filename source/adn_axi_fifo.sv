/*

@foez-bhai, write the purpose of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

@foez-bhai, describe the use case of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

| REVISION | DATE       | AUTHOR                     | DESCRIPTION                                            |
|----------|------------|----------------------------|--------------------------------------------------------|
| 0.1      | 2026-08-09 | Md Sakhawat Hossain Sabbir | Initial version                                        |
| 1.0      | 2026-08-09 | Md Sakhawat Hossain Sabbir | Stable release                                         |

Author : Md Sakhawat Hossain Sabbir (sabbirone939@gmail.com)
This file is part of ADN-VLSI/adn_axi
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

// @foez-bhai, add comments to the parameters, ports
module adn_axi_fifo #(
  // PARAMETERS
  parameter type axi_req_t    = logic, // AXI request structure type
  parameter type axi_resp_t   = logic, // AXI response structure type
  parameter int  FIFO_SIZE    = 4,     // Default FIFO depth
  parameter int  AW_FIFO_SIZE = FIFO_SIZE, // Write Address channel FIFO depth
  parameter int  W_FIFO_SIZE  = FIFO_SIZE, // Write Data channel FIFO depth
  parameter int  B_FIFO_SIZE  = FIFO_SIZE, // Write Response channel FIFO depth
  parameter int  AR_FIFO_SIZE = FIFO_SIZE, // Read Address channel FIFO depth
  parameter int  R_FIFO_SIZE  = FIFO_SIZE  // Read Data channel FIFO depth
    // LOCALPARAMS
) (
  // PORTS
  input  logic       clk_i,       // System clock
  input  logic       arst_ni,     // Asynchronous reset, active low
  input  axi_req_t   slv_req_i,   // From Master to FIFO
  output axi_resp_t  slv_resp_o,  // From FIFO to Master
  output axi_req_t   mst_req_o,   // From FIFO to Slave
  input  axi_resp_t  mst_resp_i   // From Slave to FIFO
);

  // @foez-bhai, add comments to the functional blocks, signals, and submodules

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS GENERATED
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  typedef type(slv_req_i.aw)  axi_aw_t;
  typedef type(slv_req_i.w)   axi_w_t;
  typedef type(mst_resp_i.b)  axi_b_t;
  typedef type(slv_req_i.ar)  axi_ar_t;
  typedef type(mst_resp_i.r)  axi_r_t;
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  logic [$bits(axi_aw_t)-1:0] aw_in_flat, aw_out_flat;
  logic [$bits(axi_w_t) -1:0] w_in_flat,  w_out_flat;
  logic [$bits(axi_b_t) -1:0] b_in_flat,  b_out_flat;
  logic [$bits(axi_ar_t)-1:0] ar_in_flat, ar_out_flat;
  logic [$bits(axi_r_t) -1:0] r_in_flat,  r_out_flat;
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // COMBINATIONAL LOGICS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  always_comb aw_in_flat = slv_req_i.aw;
  always_comb mst_req_o.aw = axi_aw_t'(aw_out_flat);

  always_comb w_in_flat = slv_req_i.w;
  always_comb mst_req_o.w = axi_w_t'(w_out_flat);

  always_comb b_in_flat = mst_resp_i.b;
  always_comb slv_resp_o.b = axi_b_t'(b_out_flat);

  always_comb ar_in_flat = slv_req_i.ar;
  always_comb mst_req_o.ar = axi_ar_t'(ar_out_flat);

  always_comb r_in_flat = mst_resp_i.r;
  always_comb slv_resp_o.r = axi_r_t'(r_out_flat);
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // AW channel FIFO: Buffers Write Address from Master to Slave
  adn_common_fifo #(
      .DATA_WIDTH($bits(axi_aw_t)),
      .FIFO_SIZE (AW_FIFO_SIZE),
      .PIPELINED (1)
  ) u_aw_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       (aw_in_flat),
      .data_in_valid_i (slv_req_i.aw_valid),
      .data_in_ready_o (slv_resp_o.aw_ready),
      .count_o         (),
      .data_out_o      (aw_out_flat),
      .data_out_valid_o(mst_req_o.aw_valid),
      .data_out_ready_i(mst_resp_i.aw_ready)
  );

  // W channel FIFO: Buffers Write Data from Master to Slave
  adn_common_fifo #(
      .DATA_WIDTH($bits(axi_w_t)),
      .FIFO_SIZE (W_FIFO_SIZE),
      .PIPELINED (1)
  ) u_w_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       (w_in_flat),
      .data_in_valid_i (slv_req_i.w_valid),
      .data_in_ready_o (slv_resp_o.w_ready),
      .count_o         (),
      .data_out_o      (w_out_flat),
      .data_out_valid_o(mst_req_o.w_valid),
      .data_out_ready_i(mst_resp_i.w_ready)
  );

  // B channel FIFO: Buffers Write Response from Slave to Master
  adn_common_fifo #(
      .DATA_WIDTH($bits(axi_b_t)),
      .FIFO_SIZE (B_FIFO_SIZE),
      .PIPELINED (1)
  ) u_b_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       (b_in_flat),
      .data_in_valid_i (mst_resp_i.b_valid),
      .data_in_ready_o (mst_req_o.b_ready),
      .count_o         (),
      .data_out_o      (b_out_flat),
      .data_out_valid_o(slv_resp_o.b_valid),
      .data_out_ready_i(slv_req_i.b_ready)
  );

  // AR channel FIFO: Buffers Read Address from Master to Slave
  adn_common_fifo #(
      .DATA_WIDTH($bits(axi_ar_t)),
      .FIFO_SIZE (AR_FIFO_SIZE),
      .PIPELINED (1)
  ) u_ar_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       (ar_in_flat),
      .data_in_valid_i (slv_req_i.ar_valid),
      .data_in_ready_o (slv_resp_o.ar_ready),
      .count_o         (),
      .data_out_o      (ar_out_flat),
      .data_out_valid_o(mst_req_o.ar_valid),
      .data_out_ready_i(mst_resp_i.ar_ready)
  );

  // R channel FIFO: Buffers Read Data from Slave to Master
  adn_common_fifo #(
      .DATA_WIDTH($bits(axi_r_t)),
      .FIFO_SIZE (R_FIFO_SIZE),
      .PIPELINED (1)
  ) u_r_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       (r_in_flat),
      .data_in_valid_i (mst_resp_i.r_valid),
      .data_in_ready_o (mst_req_o.r_ready),
      .count_o         (),
      .data_out_o      (r_out_flat),
      .data_out_valid_o(slv_resp_o.r_valid),
      .data_out_ready_i(slv_req_i.r_ready)
  );
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INITIAL CHECKS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSERTIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INITIAL CHECKS
  //////////////////////////////////////////////////////////////////////////////////////////////////

 // SIMULATION

endmodule

