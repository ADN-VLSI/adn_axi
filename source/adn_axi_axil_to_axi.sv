// /*

// @foez---bhai, write the purpose of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

// @foez---bhai, describe the use case of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

// | REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
// |----------|------------|-----------------|--------------------------------------------------------|
// | 0.1      | 2026-08-27 | Md. Sakib Hasan Shawon | Initial version                                        |
// | 1.0      | 2026-08-27 | Md. Sakib Hasan Shawon | Stable release                                         |

// Author : Md. Sakib Hasan Shawon (mdsakibhasanshawon20@gmail.com)
// This file is part of ADN-VLSI/adn_axi
// Copyright (c) 2026 ADN Semiconductors
// Licensed under the MIT License
// See LICENSE file in the project root for full license information

// */

// // @foez---bhai, add comments to the parameters, ports
// // module adn_axi_axil_to_axi #(
// //     // PARAMETERS
// //     // LOCALPARAMS
// // ) (
// //     // PORTS
// // );

// //   // @foez---bhai, add comments to the functional blocks, signals, and submodules

// //   //////////////////////////////////////////////////////////////////////////////////////////////////
// //   // LOCALPARAMS GENERATED
// //   //////////////////////////////////////////////////////////////////////////////////////////////////

// //   //////////////////////////////////////////////////////////////////////////////////////////////////
// //   // TYPEDEFS
// //   //////////////////////////////////////////////////////////////////////////////////////////////////

// //   //////////////////////////////////////////////////////////////////////////////////////////////////
// //   // SIGNALS
// //   //////////////////////////////////////////////////////////////////////////////////////////////////

// //   //////////////////////////////////////////////////////////////////////////////////////////////////
// //   // ASSIGNMENTS
// //   //////////////////////////////////////////////////////////////////////////////////////////////////

// //   //////////////////////////////////////////////////////////////////////////////////////////////////
// //   // SUBMODULES
// //   //////////////////////////////////////////////////////////////////////////////////////////////////

// //   //////////////////////////////////////////////////////////////////////////////////////////////////
// //   // SEQUENTIALS
// //   //////////////////////////////////////////////////////////////////////////////////////////////////

// //   //////////////////////////////////////////////////////////////////////////////////////////////////
// //   // INITIAL CHECKS
// //   //////////////////////////////////////////////////////////////////////////////////////////////////

// //   //////////////////////////////////////////////////////////////////////////////////////////////////
// //   // METHODS
// //   //////////////////////////////////////////////////////////////////////////////////////////////////

// //   //////////////////////////////////////////////////////////////////////////////////////////////////
// //   // INITIAL CHECKS
// //   //////////////////////////////////////////////////////////////////////////////////////////////////



// // endmodule










`include "axi/typedef.svh"
`include "axil/typedef.svh"

module adn_axi_axil_to_axi #(
    parameter int unsigned ID_WIDTH   = 4,
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned USER_WIDTH = 1,

    parameter logic [ID_WIDTH-1:0] AXI_AWID = '0,
    parameter logic [ID_WIDTH-1:0] AXI_ARID = '0,

    parameter logic [3:0] AXI_CACHE  = 4'b0000,
    parameter logic [3:0] AXI_QOS    = 4'b0000,
    parameter logic [3:0] AXI_REGION = 4'b0000
) (
    clk,
    aresetn,
    s_axi_req,
    s_axi_rsp,
    m_axi_req,
    m_axi_rsp
);

  `AXIL_T(axil, ADDR_WIDTH, DATA_WIDTH)
  `AXI_T(axi, ID_WIDTH, ADDR_WIDTH, DATA_WIDTH, USER_WIDTH)

  input logic clk;
  input logic aresetn;

  input  axil_req_t s_axi_req;
  output axil_rsp_t s_axi_rsp;

  output axi_req_t m_axi_req;
  input  axi_rsp_t m_axi_rsp;
  
  localparam int unsigned BYTE_WIDTH = DATA_WIDTH / 8;
  localparam logic [2:0] AXI_SIZE = $clog2(BYTE_WIDTH);

  axil_aw_t                  wr_aw_q;
  axil_w_t                   wr_w_q;

  logic                      wr_aw_stored_q;
  logic                      wr_w_stored_q;

  logic                      wr_aw_done_q;
  logic                      wr_w_done_q;

  logic                      wr_b_valid_q;
  logic     [           1:0] wr_b_resp_q;

  axil_ar_t                  rd_ar_q;

  logic                      rd_ar_stored_q;
  logic                      rd_ar_done_q;

  logic                      rd_r_valid_q;
  logic     [DATA_WIDTH-1:0] rd_r_data_q;
  logic     [           1:0] rd_r_resp_q;

  always_comb begin
    s_axi_rsp           = '0;

    s_axi_rsp.aw_ready  = !wr_aw_stored_q && !wr_b_valid_q;
    s_axi_rsp.w_ready   = !wr_w_stored_q && !wr_b_valid_q;

    s_axi_rsp.b_valid   = wr_b_valid_q;
    s_axi_rsp.b.resp    = wr_b_resp_q;

    s_axi_rsp.ar_ready  = !rd_ar_stored_q && !rd_r_valid_q;

    s_axi_rsp.r_valid   = rd_r_valid_q;
    s_axi_rsp.r.data    = rd_r_data_q;
    s_axi_rsp.r.resp    = rd_r_resp_q;

    m_axi_req           = '0;

    m_axi_req.aw.id     = AXI_AWID;
    m_axi_req.aw.addr   = wr_aw_q.addr;
    m_axi_req.aw.len    = 8'd0;
    m_axi_req.aw.size   = AXI_SIZE;
    m_axi_req.aw.burst  = 3'b001;
    m_axi_req.aw.lock   = 1'b0;
    m_axi_req.aw.cache  = AXI_CACHE;
    m_axi_req.aw.prot   = wr_aw_q.prot;
    m_axi_req.aw.qos    = AXI_QOS;
    m_axi_req.aw.region = AXI_REGION;
    m_axi_req.aw.user   = '0;

    m_axi_req.aw_valid  = wr_aw_stored_q && !wr_aw_done_q;

    m_axi_req.w.data    = wr_w_q.data;
    m_axi_req.w.strb    = wr_w_q.strb;
    m_axi_req.w.last    = 1'b1;
    m_axi_req.w.user    = '0;

    m_axi_req.w_valid   = wr_w_stored_q && !wr_w_done_q;

    m_axi_req.b_ready   = !wr_b_valid_q;

    m_axi_req.ar.id     = AXI_ARID;
    m_axi_req.ar.addr   = rd_ar_q.addr;
    m_axi_req.ar.len    = 8'd0;
    m_axi_req.ar.size   = AXI_SIZE;
    m_axi_req.ar.burst  = 3'b001;
    m_axi_req.ar.lock   = 1'b0;
    m_axi_req.ar.cache  = AXI_CACHE;
    m_axi_req.ar.prot   = rd_ar_q.prot;
    m_axi_req.ar.qos    = AXI_QOS;
    m_axi_req.ar.region = AXI_REGION;
    m_axi_req.ar.user   = '0;

    m_axi_req.ar_valid  = rd_ar_stored_q && !rd_ar_done_q;

    m_axi_req.r_ready   = !rd_r_valid_q;
  end

  always_ff @(posedge clk or negedge aresetn) begin
    if (!aresetn) begin
      wr_aw_q        <= '0;
      wr_w_q         <= '0;

      wr_aw_stored_q <= 1'b0;
      wr_w_stored_q  <= 1'b0;

      wr_aw_done_q   <= 1'b0;
      wr_w_done_q    <= 1'b0;

      wr_b_valid_q   <= 1'b0;
      wr_b_resp_q    <= 2'b00;

      rd_ar_q        <= '0;

      rd_ar_stored_q <= 1'b0;
      rd_ar_done_q   <= 1'b0;

      rd_r_valid_q   <= 1'b0;
      rd_r_data_q    <= '0;
      rd_r_resp_q    <= 2'b00;
    end else begin
      if (s_axi_req.aw_valid && s_axi_rsp.aw_ready) begin
        wr_aw_q        <= s_axi_req.aw;
        wr_aw_stored_q <= 1'b1;
      end

      if (s_axi_req.w_valid && s_axi_rsp.w_ready) begin
        wr_w_q        <= s_axi_req.w;
        wr_w_stored_q <= 1'b1;
      end

      if (m_axi_req.aw_valid && m_axi_rsp.aw_ready) begin
        wr_aw_done_q <= 1'b1;
      end

      if (m_axi_req.w_valid && m_axi_rsp.w_ready) begin
        wr_w_done_q <= 1'b1;
      end

      if (m_axi_rsp.b_valid && m_axi_req.b_ready && wr_aw_done_q && wr_w_done_q) begin
        wr_b_resp_q  <= m_axi_rsp.b.resp;
        wr_b_valid_q <= 1'b1;
      end

      if (s_axi_rsp.b_valid && s_axi_req.b_ready) begin
        wr_b_valid_q   <= 1'b0;
        wr_aw_stored_q <= 1'b0;
        wr_w_stored_q  <= 1'b0;
        wr_aw_done_q   <= 1'b0;
        wr_w_done_q    <= 1'b0;
      end

      if (s_axi_req.ar_valid && s_axi_rsp.ar_ready) begin
        rd_ar_q        <= s_axi_req.ar;
        rd_ar_stored_q <= 1'b1;
      end

      if (m_axi_req.ar_valid && m_axi_rsp.ar_ready) begin
        rd_ar_done_q <= 1'b1;
      end

      if (m_axi_rsp.r_valid && m_axi_req.r_ready && rd_ar_done_q) begin
        rd_r_data_q  <= m_axi_rsp.r.data;
        rd_r_resp_q  <= m_axi_rsp.r.resp;
        rd_r_valid_q <= 1'b1;
      end

      if (s_axi_rsp.r_valid && s_axi_req.r_ready) begin
        rd_r_valid_q   <= 1'b0;
        rd_ar_stored_q <= 1'b0;
        rd_ar_done_q   <= 1'b0;
      end
    end
  end

endmodule
