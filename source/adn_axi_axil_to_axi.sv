/*

@foez-bhai, write the purpose of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

@foez-bhai, describe the use case of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-27 | Md. Sakib Hasan Shawon | Initial version                                        |
| 1.0      | 2026-08-27 | Md. Sakib Hasan Shawon | Stable release                                         |

Author : Md. Sakib Hasan Shawon (mdsakibhasanshawon20@gmail.com)
This file is part of ADN-VLSI/adn_axi
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

// @foez-bhai, add comments to the parameters, ports
module adn_axi_axil_to_axi #(
    
    ////////////////////////////////////////////////////////////////////////////////////////////
    // PARAMETERS
    ////////////////////////////////////////////////////////////////////////////////////////////
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int ID_WIDTH   = 4,
    parameter int USER_WIDTH = 1,

    parameter type axil_req_t = logic,
    parameter type axil_rsp_t = logic,
    parameter type axi_req_t  = logic,
    parameter type axi_rsp_t  = logic
) (
    input logic clk_i,
    input logic rst_ni,

    // AXI4-Lite Slave Interface
    input  axil_req_t s_req_i,
    output axil_rsp_t s_rsp_o,

    // AXI4 Master Interface
    output axi_req_t m_req_o,
    input  axi_rsp_t m_rsp_i
);

  // @foez-bhai, add comments to the functional blocks, signals, and submodules

  // ------------------------------------------------------------
  // Local Parameters
  // ------------------------------------------------------------

  localparam int DATA_BYTES = DATA_WIDTH / 8;
  localparam int SIZE_WIDTH = $clog2(DATA_BYTES);

  localparam logic [2:0] AXI_BURST_INCR = 3'b001;

  // ------------------------------------------------------------
  // AXI-Lite Write Buffers
  //
  // AXI-Lite AW and W channels are independent. Both must be
  // captured before a complete AXI write transaction is started.
  // ------------------------------------------------------------

  logic                    aw_pending_q;
  logic [  ADDR_WIDTH-1:0] aw_addr_q;
  logic [             2:0] aw_prot_q;

  logic                    w_pending_q;
  logic [  DATA_WIDTH-1:0] w_data_q;
  logic [DATA_WIDTH/8-1:0] w_strb_q;


  // ------------------------------------------------------------
  // AXI-Lite Read Buffer
  //
  // The AXI-Lite AR information must be captured because the
  // upstream master may change its signals after the handshake.
  // ------------------------------------------------------------

  logic                    ar_pending_q;
  logic [  ADDR_WIDTH-1:0] ar_addr_q;
  logic [             2:0] ar_prot_q;


  // ------------------------------------------------------------
  // Transaction State
  // ------------------------------------------------------------

  logic                    write_active_q;
  logic                    read_active_q;


  // ------------------------------------------------------------
  // AXI Write Channel Progress
  //
  // AXI AW and W channels may handshake independently.
  // ------------------------------------------------------------

  logic                    m_aw_done_q;
  logic                    m_w_done_q;


  // ------------------------------------------------------------
  // AXI Read Channel Progress
  //
  // Once AXI AR handshakes, ARVALID must be deasserted while
  // waiting for the AXI R response.
  // ------------------------------------------------------------

module adn_axi_axil_to_axi #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int ID_WIDTH   = 4,
    parameter int USER_WIDTH = 1,

    parameter type axil_req_t = logic,
    parameter type axil_rsp_t = logic,
    parameter type axi_req_t  = logic,
    parameter type axi_rsp_t  = logic
) (
    input logic clk_i,
    input logic rst_ni,

    // AXI4-Lite Slave Interface
    input  axil_req_t s_req_i,
    output axil_rsp_t s_rsp_o,

  // ------------------------------------------------------------
  // AXI-Lite Response Registers
  // ------------------------------------------------------------

  logic                    b_valid_q;
  logic [             1:0] b_resp_q;

  logic                    r_valid_q;
  logic [  DATA_WIDTH-1:0] r_data_q;
  logic [             1:0] r_resp_q;


  // ------------------------------------------------------------
  // Handshake Signals
  // ------------------------------------------------------------

  logic                    s_aw_hs;
  logic                    s_w_hs;
  logic                    s_ar_hs;

  logic                    m_aw_hs;
  logic                    m_w_hs;
  logic                    m_b_hs;

  logic                    m_ar_hs;
  logic                    m_r_hs;


  // ============================================================
  // AXI4-Lite Slave Response Interface
  // ============================================================

  always_comb begin
    s_rsp_o = '0;


    // --------------------------------------------------------
    // AXI-Lite Write Address Ready
    // --------------------------------------------------------

    s_rsp_o.aw_ready = !read_active_q  &&
                           !r_valid_q      &&
                           !b_valid_q      &&
                           !aw_pending_q   &&
                           !write_active_q;


    // --------------------------------------------------------
    // AXI-Lite Write Data Ready
    // --------------------------------------------------------

    s_rsp_o.w_ready = !read_active_q && !r_valid_q && !b_valid_q && !w_pending_q && !write_active_q;


    // --------------------------------------------------------
    // AXI-Lite Write Response
    // --------------------------------------------------------

    s_rsp_o.b.resp = b_resp_q;
    s_rsp_o.b_valid = b_valid_q;


    // --------------------------------------------------------
    // AXI-Lite Read Address Ready
    //
    // A read is accepted only when there is no write activity,
    // partial write request, outstanding response, or another
    // pending read.
    // --------------------------------------------------------

    s_rsp_o.ar_ready = !read_active_q  &&
                           !r_valid_q      &&
                           !write_active_q &&
                           !b_valid_q      &&
                           !aw_pending_q   &&
                           !w_pending_q    &&
                           !ar_pending_q;


    // --------------------------------------------------------
    // AXI-Lite Read Response
    // --------------------------------------------------------

    s_rsp_o.r.data = r_data_q;
    s_rsp_o.r.resp = r_resp_q;
    s_rsp_o.r_valid = r_valid_q;
  end


  // ============================================================
  // AXI4 Master Request Interface
  // ============================================================

  always_comb begin
    m_req_o = '0;


    // --------------------------------------------------------
    // AXI Write Address Channel
    //
    // Keep AWVALID asserted until the AXI slave accepts AW.
    // --------------------------------------------------------

    if (write_active_q && !m_aw_done_q) begin
      m_req_o.aw.id     = '0;
      m_req_o.aw.addr   = aw_addr_q;
      m_req_o.aw.len    = 8'd0;
      m_req_o.aw.size   = SIZE_WIDTH[2:0];
      m_req_o.aw.burst  = AXI_BURST_INCR;
      m_req_o.aw.lock   = 1'b0;
      m_req_o.aw.cache  = '0;
      m_req_o.aw.prot   = aw_prot_q;
      m_req_o.aw.qos    = '0;
      m_req_o.aw.region = '0;
      m_req_o.aw.user   = '0;
      m_req_o.aw_valid  = 1'b1;
    end


    // --------------------------------------------------------
    // AXI Write Data Channel
    //
    // Keep WVALID asserted until the AXI slave accepts W.
    // --------------------------------------------------------

    if (write_active_q && !m_w_done_q) begin
      m_req_o.w.data  = w_data_q;
      m_req_o.w.strb  = w_strb_q;
      m_req_o.w.last  = 1'b1;
      m_req_o.w.user  = '0;
      m_req_o.w_valid = 1'b1;
    end


    // --------------------------------------------------------
    // AXI Write Response Ready
    //
    // BREADY is asserted only after both AW and W have been
    // accepted by the AXI slave.
    // --------------------------------------------------------

    m_req_o.b_ready = write_active_q && m_aw_done_q && m_w_done_q && !b_valid_q;


    // --------------------------------------------------------
    // AXI Read Address Channel
    //
    // Keep ARVALID asserted until AR handshake occurs.
    // m_ar_done_q prevents repeated AXI AR transactions while
    // waiting for the AXI R response.
    // --------------------------------------------------------

    if (read_active_q && !m_ar_done_q) begin
      m_req_o.ar.id     = '0;
      m_req_o.ar.addr   = ar_addr_q;
      m_req_o.ar.len    = 8'd0;
      m_req_o.ar.size   = SIZE_WIDTH[2:0];
      m_req_o.ar.burst  = AXI_BURST_INCR;
      m_req_o.ar.lock   = 1'b0;
      m_req_o.ar.cache  = '0;
      m_req_o.ar.prot   = ar_prot_q;
      m_req_o.ar.qos    = '0;
      m_req_o.ar.region = '0;
      m_req_o.ar.user   = '0;
      m_req_o.ar_valid  = 1'b1;
    end


    // --------------------------------------------------------
    // AXI Read Response Ready
    //
    // Once the AXI read transaction is active, accept the
    // response unless it has already been captured.
    // --------------------------------------------------------

    m_req_o.r_ready = read_active_q && !r_valid_q;
  end


  // ============================================================
  // Handshake Detection
  // ============================================================

  assign s_aw_hs = s_req_i.aw_valid && s_rsp_o.aw_ready;
  assign s_w_hs  = s_req_i.w_valid && s_rsp_o.w_ready;
  assign s_ar_hs = s_req_i.ar_valid && s_rsp_o.ar_ready;

  assign m_aw_hs = m_req_o.aw_valid && m_rsp_i.aw_ready;
  assign m_w_hs  = m_req_o.w_valid && m_rsp_i.w_ready;
  assign m_b_hs  = m_rsp_i.b_valid && m_req_o.b_ready;

  assign m_ar_hs = m_req_o.ar_valid && m_rsp_i.ar_ready;
  assign m_r_hs  = m_rsp_i.r_valid && m_req_o.r_ready;


  // ============================================================
  // Sequential Logic
  // ============================================================

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin

      // ----------------------------------------------------
      // Write Buffers
      // ----------------------------------------------------

      aw_pending_q   <= 1'b0;
      aw_addr_q      <= '0;
      aw_prot_q      <= '0;

      w_pending_q    <= 1'b0;
      w_data_q       <= '0;
      w_strb_q       <= '0;


      // ----------------------------------------------------
      // Read Buffer
      // ----------------------------------------------------

      ar_pending_q   <= 1'b0;
      ar_addr_q      <= '0;
      ar_prot_q      <= '0;


      // ----------------------------------------------------
      // Transaction State
      // ----------------------------------------------------

      write_active_q <= 1'b0;
      read_active_q  <= 1'b0;


      // ----------------------------------------------------
      // AXI Write Progress
      // ----------------------------------------------------

      m_aw_done_q    <= 1'b0;
      m_w_done_q     <= 1'b0;


      // ----------------------------------------------------
      // AXI Read Progress
      // ----------------------------------------------------

      m_ar_done_q    <= 1'b0;


      // ----------------------------------------------------
      // AXI-Lite Write Response
      // ----------------------------------------------------

      b_valid_q      <= 1'b0;
      b_resp_q       <= '0;


      // ----------------------------------------------------
      // AXI-Lite Read Response
      // ----------------------------------------------------

      r_valid_q      <= 1'b0;
      r_data_q       <= '0;
      r_resp_q       <= '0;

    end else begin


      // ====================================================
      // AXI-Lite AW Capture
      // ====================================================

      if (s_aw_hs) begin
        aw_pending_q <= 1'b1;
        aw_addr_q    <= s_req_i.aw.addr;
        aw_prot_q    <= s_req_i.aw.prot;
      end


      // ====================================================
      // AXI-Lite W Capture
      // ====================================================

      if (s_w_hs) begin
        w_pending_q <= 1'b1;
        w_data_q    <= s_req_i.w.data;
        w_strb_q    <= s_req_i.w.strb;
      end


      // ====================================================
      // Start AXI Write
      //
      // Both AXI-Lite AW and W must be available.
      //
      // s_aw_hs and s_w_hs allow a write to start immediately
      // when the final missing component arrives.
      // ====================================================

      if (!write_active_q &&
                !read_active_q  &&
                !b_valid_q      &&
                !r_valid_q      &&
                (aw_pending_q || s_aw_hs) &&
                (w_pending_q  || s_w_hs)) begin

        write_active_q <= 1'b1;

        aw_pending_q   <= 1'b0;
        w_pending_q    <= 1'b0;

        m_aw_done_q    <= 1'b0;
        m_w_done_q     <= 1'b0;
      end


      // ====================================================
      // AXI AW Handshake
      // ====================================================

      if (m_aw_hs) begin
        m_aw_done_q <= 1'b1;
      end


      // ====================================================
      // AXI W Handshake
      // ====================================================

      if (m_w_hs) begin
        m_w_done_q <= 1'b1;
      end


      // ====================================================
      // AXI B Response Capture
      // ====================================================

      if (m_b_hs) begin
        b_valid_q      <= 1'b1;
        b_resp_q       <= m_rsp_i.b.resp;

        write_active_q <= 1'b0;

        m_aw_done_q    <= 1'b0;
        m_w_done_q     <= 1'b0;
      end


      // ====================================================
      // AXI-Lite B Response Handshake
      // ====================================================

      if (b_valid_q && s_req_i.b_ready) begin
        b_valid_q <= 1'b0;
      end


      // ====================================================
      // AXI-Lite AR Capture
      // ====================================================

      if (s_ar_hs) begin
        ar_pending_q <= 1'b1;
        ar_addr_q    <= s_req_i.ar.addr;
        ar_prot_q    <= s_req_i.ar.prot;
      end


      // ====================================================
      // Start AXI Read
      //
      // s_ar_hs allows the read transaction to start
      // immediately when AXI-Lite AR is accepted.
      // ====================================================

      if (!read_active_q  &&
                !write_active_q &&
                !b_valid_q      &&
                !r_valid_q      &&
                (ar_pending_q || s_ar_hs)) begin

        read_active_q <= 1'b1;
        ar_pending_q  <= 1'b0;
        m_ar_done_q   <= 1'b0;
      end


      // ====================================================
      // AXI AR Handshake
      //
      // Mark the AXI address as completed so ARVALID is
      // deasserted while waiting for the R response.
      // ====================================================

      if (m_ar_hs) begin
        m_ar_done_q <= 1'b1;
      end


      // ====================================================
      // AXI R Response Capture
      // ====================================================

      if (m_r_hs) begin
        r_valid_q     <= 1'b1;
        r_data_q      <= m_rsp_i.r.data;
        r_resp_q      <= m_rsp_i.r.resp;

        read_active_q <= 1'b0;
        m_ar_done_q   <= 1'b0;
      end


      // ====================================================
      // AXI-Lite R Response Handshake
      // ====================================================

      if (r_valid_q && s_req_i.r_ready) begin
        r_valid_q <= 1'b0;
      end

    end
  end

endmodule

