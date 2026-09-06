/*

| TEST CASE  | DATE       | AUTHOR              | DESCRIPTION                                                                           |
| ---------- | ---------- | ------------------- | ------------------------------------------------------------------------------------- |
| TC_RST_01  | 2026-09-06 | Ahasan Ullah Khalid | Active-low reset check verifying default handshake and deasserted valid states        |
| TC_RST_02  | 2026-09-06 | Ahasan Ullah Khalid | Mid-transaction asynchronous reset assertion to verify graceful recovery              |
| TC_WR_01   | 2026-09-06 | Ahasan Ullah Khalid | Standard single write transaction converting AXIL to full AXI write channels          |
| TC_WR_02   | 2026-09-06 | Ahasan Ullah Khalid | Byte, halfword, and unaligned strobe write checks ensuring correct WSTRB mapping      |
| TC_RD_01   | 2026-09-06 | Ahasan Ullah Khalid | Standard single read transaction converting AXIL AR to full AXI AR with valid return  |
| TC_RD_02   | 2026-09-06 | Ahasan Ullah Khalid | Read access over boundary and highest address ranges (0x0, 0xFFFF_FFFC)               |
| TC_B2B_01  | 2026-09-06 | Ahasan Ullah Khalid | Continuous back-to-back streaming of interleaved write and read commands              |
| TC_BP_01   | 2026-09-06 | Ahasan Ullah Khalid | Downstream AXI slave backpressure test (decoupled AW/W/AR handshake acceptance)       |
| TC_BP_02   | 2026-09-06 | Ahasan Ullah Khalid | Upstream AXIL master backpressure test (delayed BREADY and RREADY acceptance)         |
| TC_ERR_01  | 2026-09-06 | Ahasan Ullah Khalid | Full AXI error response propagation verification (SLVERR/DECERR to AXIL BRESP/RRESP)  |
| TC_PROT_01 | 2026-09-06 | Ahasan Ullah Khalid | Protection attribute propagation check across secure/privileged/instruction values    |
| TC_ALL     | 2026-09-06 | Ahasan Ullah Khalid | Full regression suite executing all test scenarios sequentially                       |

| REVISION | DATE       | AUTHOR              | DESCRIPTION                                                                           |
| -------- | ---------- | ------------------- | ------------------------------------------------------------------------------------- |
| 1.0      | 2026-09-06 | Ahasan Ullah Khalid | Initial testbench release                                                             |
| 1.1      | 2026-09-06 | Ahasan Ullah Khalid | Stable Release                                                                        |

Author : Ahasan Ullah Khalid (aukhalid02@gmail.com)
This file is part of ADN-VLSI/adn_axi
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_axi_axil_to_axi_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS & INCLUDES
  //////////////////////////////////////////////////////////////////////////////////////////////////
  `include "vip/adn_common_tb_headers.sv"
  `include "axi/typedef.svh"
  `include "axi/assign.svh"
  `include "axil/typedef.svh"
  `include "axil/assign.svh"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS & TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  localparam time CLKPeriod = 10ns;
  localparam time CLKHalfPeriod = 5ns;

  localparam int ADDR_WIDTH = 32;
  localparam int DATA_WIDTH = 32;
  localparam int ID_WIDTH = 4;
  localparam int USER_WIDTH = 1;

  `AXIL_T(tb_axil, ADDR_WIDTH, DATA_WIDTH)
  `AXI_T(tb_axi, ID_WIDTH, ADDR_WIDTH, DATA_WIDTH, USER_WIDTH)

  typedef tb_axil_req_t axil_req_t;
  typedef tb_axil_rsp_t axil_rsp_t;
  typedef tb_axi_req_t axi_req_t;
  typedef tb_axi_rsp_t axi_rsp_t;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  logic                       clk;
  logic                       rst_n;

  axil_req_t                  s_req;
  axil_rsp_t                  s_rsp;
  axi_req_t                   m_req;
  axi_rsp_t                   m_rsp;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////
  bit                         is_clk_edge_aligned;

  bit                         downstream_ready_en;
  bit                         inject_downstream_bp;

  // Multi-channel independent AXI responder state registers
  logic                       aw_pending;
  logic      [  ID_WIDTH-1:0] aw_pending_id;
  logic      [ADDR_WIDTH-1:0] aw_pending_addr;

  logic                       w_pending;
  logic      [DATA_WIDTH-1:0] w_pending_data;

  logic                       ar_pending;
  logic      [  ID_WIDTH-1:0] ar_pending_id;
  logic      [ADDR_WIDTH-1:0] ar_pending_addr;

  // Memory backing store
  logic      [DATA_WIDTH-1:0] mem_store            [logic [ADDR_WIDTH-1:0]];

  // Scoreboard tracking structures
  typedef struct {
    logic [ADDR_WIDTH-1:0]   addr;
    logic [DATA_WIDTH-1:0]   data;
    logic [DATA_WIDTH/8-1:0] strb;
    logic [2:0]              prot;
    logic [1:0]              resp;
  } exp_wr_t;

  typedef struct {
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] exp_data;
    logic [2:0]            prot;
    logic [1:0]            resp;
  } exp_rd_t;

  exp_wr_t exp_wr_fifo[$];
  exp_rd_t exp_rd_fifo[$];

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  adn_axi_axil_to_axi #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .ID_WIDTH  (ID_WIDTH),
      .USER_WIDTH(USER_WIDTH),
      .axil_req_t(axil_req_t),
      .axil_rsp_t(axil_rsp_t),
      .axi_req_t (axi_req_t),
      .axi_rsp_t (axi_rsp_t)
  ) u_dut (
      .clk_i  (clk),
      .rst_ni (rst_n),
      .s_req_i(s_req),
      .s_rsp_o(s_rsp),
      .m_req_o(m_req),
      .m_rsp_i(m_rsp)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS & VIP RESPONDER
  //////////////////////////////////////////////////////////////////////////////////////////////////
  always @(posedge clk) begin
    is_clk_edge_aligned <= rst_n;
    #1ns;
    is_clk_edge_aligned <= '0;
  end

  // Decoupled AXI4 Full Slave VIP Responder
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      aw_pending      <= 1'b0;
      aw_pending_id   <= '0;
      aw_pending_addr <= '0;
      w_pending       <= 1'b0;
      w_pending_data  <= '0;
      m_rsp.aw_ready  <= 1'b0;
      m_rsp.w_ready   <= 1'b0;
      m_rsp.b_valid   <= 1'b0;
      m_rsp.b.id      <= '0;
      m_rsp.b.resp    <= '0;
      m_rsp.b.user    <= '0;
      ar_pending      <= 1'b0;
      ar_pending_id   <= '0;
      ar_pending_addr <= '0;
      m_rsp.ar_ready  <= 1'b0;
      m_rsp.r_valid   <= 1'b0;
      m_rsp.r.id      <= '0;
      m_rsp.r.data    <= '0;
      m_rsp.r.resp    <= '0;
      m_rsp.r.last    <= 1'b0;
      m_rsp.r.user    <= '0;
    end else begin
      logic aw_hs, w_hs, ar_hs;
      logic [ADDR_WIDTH-1:0] act_wr_addr;
      logic [DATA_WIDTH-1:0] act_wr_data;
      logic [  ID_WIDTH-1:0] act_wr_id;

      aw_hs = m_req.aw_valid && m_rsp.aw_ready;
      w_hs  = m_req.w_valid && m_rsp.w_ready;
      ar_hs = m_req.ar_valid && m_rsp.ar_ready;

      // Downstream Ready handshake generation
      if (downstream_ready_en) begin
        if (inject_downstream_bp) begin
          m_rsp.aw_ready <= !(aw_pending || aw_hs) && ($urandom_range(0, 3) > 0);
          m_rsp.w_ready  <= !(w_pending || w_hs) && ($urandom_range(0, 3) > 0);
          m_rsp.ar_ready <= !(ar_pending || ar_hs) && !m_rsp.r_valid && ($urandom_range(0, 3) > 0);
        end else begin
          m_rsp.aw_ready <= !(aw_pending || aw_hs);
          m_rsp.w_ready  <= !(w_pending || w_hs);
          m_rsp.ar_ready <= !(ar_pending || ar_hs) && !m_rsp.r_valid;
        end
      end else begin
        m_rsp.aw_ready <= 1'b0;
        m_rsp.w_ready  <= 1'b0;
        m_rsp.ar_ready <= 1'b0;
      end

      // Latch Write Address and Write Data independently
      if (aw_hs) begin
        aw_pending      <= 1'b1;
        aw_pending_id   <= m_req.aw.id;
        aw_pending_addr <= m_req.aw.addr;
      end
      if (w_hs) begin
        w_pending      <= 1'b1;
        w_pending_data <= m_req.w.data;
      end

      // Complete Write Transaction when both AW and W phases have completed
      if ((aw_pending || aw_hs) && (w_pending || w_hs) && (!m_rsp.b_valid || (m_rsp.b_valid && m_req.b_ready))) begin
        act_wr_addr = aw_hs ? m_req.aw.addr : aw_pending_addr;
        act_wr_data = w_hs ? m_req.w.data : w_pending_data;
        act_wr_id = aw_hs ? m_req.aw.id : aw_pending_id;

        mem_store[act_wr_addr] = act_wr_data;

        m_rsp.b_valid <= 1'b1;
        m_rsp.b.id    <= act_wr_id;
        if (act_wr_addr == 32'hFFFF_0000) m_rsp.b.resp <= 2'b10;  // SLVERR
        else if (act_wr_addr == 32'hFFFF_0004) m_rsp.b.resp <= 2'b11;  // DECERR
        else m_rsp.b.resp <= 2'b00;  // OKAY

        aw_pending <= 1'b0;
        w_pending  <= 1'b0;
      end else if (m_rsp.b_valid && m_req.b_ready) begin
        m_rsp.b_valid <= 1'b0;
      end

      // Latch Read Address
      if (ar_hs) begin
        ar_pending      <= 1'b1;
        ar_pending_id   <= m_req.ar.id;
        ar_pending_addr <= m_req.ar.addr;
      end

      // Complete Read Transaction and return data
      if ((ar_pending || ar_hs) && (!m_rsp.r_valid || (m_rsp.r_valid && m_req.r_ready))) begin
        logic [ADDR_WIDTH-1:0] act_rd_addr;
        logic [  ID_WIDTH-1:0] act_rd_id;
        act_rd_addr = ar_hs ? m_req.ar.addr : ar_pending_addr;
        act_rd_id   = ar_hs ? m_req.ar.id : ar_pending_id;

        m_rsp.r_valid <= 1'b1;
        m_rsp.r.id    <= act_rd_id;
        m_rsp.r.last  <= 1'b1;
        if (act_rd_addr == 32'hFFFF_0000) begin
          m_rsp.r.data <= 32'hDEAD_DEAD;
          m_rsp.r.resp <= 2'b10;  // SLVERR
        end else if (act_rd_addr == 32'hFFFF_0004) begin
          m_rsp.r.data <= 32'hDEAD_DECE;
          m_rsp.r.resp <= 2'b11;  // DECERR
        end else begin
          if (mem_store.exists(act_rd_addr)) m_rsp.r.data <= mem_store[act_rd_addr];
          else m_rsp.r.data <= act_rd_addr ^ 32'hA5A5_5A5A;
          m_rsp.r.resp <= 2'b00;  // OKAY
        end

        ar_pending <= 1'b0;
      end else if (m_rsp.r_valid && m_req.r_ready) begin
        m_rsp.r_valid <= 1'b0;
      end
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic start_clock();
    fork
      forever #CLKHalfPeriod clk <= ~clk;
    join_none
    @(posedge clk);
  endtask

  task automatic apply_reset();
    rst_n                <= 1'b0;
    s_req                <= '0;
    s_req.b_ready        <= 1'b1;
    s_req.r_ready        <= 1'b1;
    downstream_ready_en  <= 1'b1;
    inject_downstream_bp <= 1'b0;
    exp_wr_fifo.delete();
    exp_rd_fifo.delete();
    repeat (5) @(posedge clk);
    rst_n <= 1'b1;
    repeat (5) @(posedge clk);
  endtask

  task automatic axil_write(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data,
                            input logic [DATA_WIDTH/8-1:0] strb, input logic [2:0] prot,
                            input logic [1:0] exp_resp);
    bit aw_done, w_done, b_done;
    exp_wr_t exp;
    exp.addr = addr;
    exp.data = data;
    exp.strb = strb;
    exp.prot = prot;
    exp.resp = exp_resp;
    exp_wr_fifo.push_back(exp);

    wait (is_clk_edge_aligned);
    s_req.aw.addr  <= addr;
    s_req.aw.prot  <= prot;
    s_req.aw_valid <= 1'b1;
    s_req.w.data   <= data;
    s_req.w.strb   <= strb;
    s_req.w_valid  <= 1'b1;
    aw_done = 1'b0;
    w_done  = 1'b0;
    b_done  = 1'b0;

    fork
      begin
        while (!(aw_done && w_done && b_done)) begin
          @(posedge clk);
          if (s_rsp.aw_ready && s_req.aw_valid) begin
            s_req.aw_valid <= 1'b0;
            aw_done = 1'b1;
          end
          if (s_rsp.w_ready && s_req.w_valid) begin
            s_req.w_valid <= 1'b0;
            w_done = 1'b1;
          end
          if (s_rsp.b_valid && s_req.b_ready) begin
            b_done = 1'b1;
          end
        end
      end
      begin
        repeat (1000) @(posedge clk);
        note_case(0);
        $display("[%s] [FAIL] AXIL Write handshake timed out! [%0t]", test_name, $realtime);
      end
    join_any
    disable fork;

    s_req.aw_valid <= 1'b0;
    s_req.w_valid  <= 1'b0;
  endtask

  task automatic axil_read(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] exp_data,
                           input logic [2:0] prot, input logic [1:0] exp_resp);
    bit ar_done, r_done;
    exp_rd_t exp;
    exp.addr     = addr;
    exp.exp_data = exp_data;
    exp.prot     = prot;
    exp.resp     = exp_resp;
    exp_rd_fifo.push_back(exp);

    wait (is_clk_edge_aligned);
    s_req.ar.addr  <= addr;
    s_req.ar.prot  <= prot;
    s_req.ar_valid <= 1'b1;
    ar_done = 1'b0;
    r_done  = 1'b0;

    fork
      begin
        while (!(ar_done && r_done)) begin
          @(posedge clk);
          if (s_rsp.ar_ready && s_req.ar_valid) begin
            s_req.ar_valid <= 1'b0;
            ar_done = 1'b1;
          end
          if (s_rsp.r_valid && s_req.r_ready) begin
            r_done = 1'b1;
          end
        end
      end
      begin
        repeat (1000) @(posedge clk);
        note_case(0);
        $display("[%s] [FAIL] AXIL Read handshake timed out! [%0t]", test_name, $realtime);
      end
    join_any
    disable fork;

    s_req.ar_valid <= 1'b0;
  endtask

  task automatic start_checking();
    fork
      // Write Channel Attribute & Response Verification
      forever
      @(posedge clk) begin
        #1ps;
        if (m_req.aw_valid && m_rsp.aw_ready) begin
          if ((m_req.aw.len === 8'd0) && (m_req.aw.burst === 2'b01) && (m_req.aw.size === 3'($clog2(
                  DATA_WIDTH / 8
              ))) && (m_req.aw.id === '0) && (m_req.aw.lock === 1'b0) && (m_req.aw.cache === 4'b0)
                  && (m_req.aw.qos === 4'b0) && (m_req.aw.region === 4'b0) && (m_req.aw.user === '0)
                  && (m_req.aw.addr === s_req.aw.addr) && (m_req.aw.prot === s_req.aw.prot)) begin
            note_case(1);
          end else begin
            note_case(0);
            $display(
                "[%s] [FAIL] AW channel mapping error: addr=0x%08x prot=%b len=%0d size=%0d burst=%0d [%0t]",
                test_name, m_req.aw.addr, m_req.aw.prot, m_req.aw.len, m_req.aw.size,
                m_req.aw.burst, $realtime);
          end
        end

        if (m_req.w_valid && m_rsp.w_ready) begin
          if (m_req.w.last === 1'b1 && m_req.w.user === '0 &&
              m_req.w.data === s_req.w.data && m_req.w.strb === s_req.w.strb) begin
            note_case(1);
          end else begin
            note_case(0);
            $display("[%s] [FAIL] W channel mapping error: WLAST=%b WDATA=0x%08x WSTRB=%b [%0t]",
                     test_name, m_req.w.last, m_req.w.data, m_req.w.strb, $realtime);
          end
        end

        if (s_rsp.b_valid && s_req.b_ready) begin
          if (exp_wr_fifo.size() > 0) begin
            exp_wr_t exp = exp_wr_fifo.pop_front();
            if (s_rsp.b.resp === exp.resp) begin
              note_case(1);
              if (debug)
                $display("[%s] [PASS] BRESP match: %b [%0t]", test_name, s_rsp.b.resp, $realtime);
            end else begin
              note_case(0);
              $display("[%s] [FAIL] BRESP mismatch! Got: %b, Expected: %b [%0t]", test_name,
                       s_rsp.b.resp, exp.resp, $realtime);
            end
          end else begin
            note_case(0);
            $display("[%s] [FAIL] Unexpected b_valid with empty write scoreboard! [%0t]",
                     test_name, $realtime);
          end
        end
      end

      // Read Channel Attribute & Data Verification
      forever
      @(posedge clk) begin
        #1ps;
        if (m_req.ar_valid && m_rsp.ar_ready) begin
          if ((m_req.ar.len === 8'd0) && (m_req.ar.burst === 2'b01) && (m_req.ar.size === 3'($clog2(
                  DATA_WIDTH / 8
              ))) && (m_req.ar.id === '0) && (m_req.ar.lock === 1'b0) && (m_req.ar.cache === 4'b0)
                  && (m_req.ar.qos === 4'b0) && (m_req.ar.region === 4'b0) && (m_req.ar.user === '0)
                  && (m_req.ar.addr === s_req.ar.addr) && (m_req.ar.prot === s_req.ar.prot)) begin
            note_case(1);
          end else begin
            note_case(0);
            $display(
                "[%s] [FAIL] AR channel mapping error: addr=0x%08x prot=%b len=%0d size=%0d burst=%0d [%0t]",
                test_name, m_req.ar.addr, m_req.ar.prot, m_req.ar.len, m_req.ar.size,
                m_req.ar.burst, $realtime);
          end
        end

        if (s_rsp.r_valid && s_req.r_ready) begin
          if (exp_rd_fifo.size() > 0) begin
            exp_rd_t exp = exp_rd_fifo.pop_front();
            if (s_rsp.r.data === exp.exp_data && s_rsp.r.resp === exp.resp) begin
              note_case(1);
              if (debug) begin
                $display("[%s] [PASS] R match: Data=0x%08x Resp=%b [%0t]", test_name, s_rsp.r.data,
                         s_rsp.r.resp, $realtime);
              end
            end else begin
              note_case(0);
              $display(
                  "[%s] [FAIL] R mismatch! Got Data: 0x%08x Resp: %b | Expected Data: 0x%08x Resp: %b [%0t]",
                  test_name, s_rsp.r.data, s_rsp.r.resp, exp.exp_data, exp.resp, $realtime);
            end
          end else begin
            note_case(0);
            $display("[%s] [FAIL] Unexpected r_valid with empty read scoreboard! [%0t]", test_name,
                     $realtime);
          end
        end
      end
    join_none
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST CASE TASKS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic run_tc_rst_01();
    apply_reset();
    #1ps;
    if (!s_rsp.b_valid && !s_rsp.r_valid &&
        !m_req.aw_valid && !m_req.w_valid && !m_req.ar_valid) begin
      note_case(1);
    end else begin
      note_case(0);
      $display("[%s] [FAIL] Post-reset valid signals are asserted! [%0t]", test_name, $realtime);
    end
  endtask

  task automatic run_tc_rst_02();
    apply_reset();
    wait (is_clk_edge_aligned);
    s_req.aw.addr       <= 32'h0000_1000;
    s_req.aw_valid      <= 1'b1;
    s_req.w.data        <= 32'hDEAD_BEEF;
    s_req.w.strb        <= 4'b1111;
    s_req.w_valid       <= 1'b1;
    downstream_ready_en <= 1'b0;
    @(posedge clk);
    rst_n <= 1'b0;
    repeat (3) @(posedge clk);
    rst_n <= 1'b1;
    s_req <= '0;
    s_req.b_ready <= 1'b1;
    s_req.r_ready <= 1'b1;
    downstream_ready_en <= 1'b1;
    exp_wr_fifo.delete();
    exp_rd_fifo.delete();
    repeat (5) @(posedge clk);
    #1ps;
    if (!s_rsp.b_valid && !s_rsp.r_valid && !m_req.aw_valid && !m_req.w_valid) begin
      note_case(1);
    end else begin
      note_case(0);
      $display("[%s] [FAIL] Mid-operation reset recovery failed! [%0t]", test_name, $realtime);
    end
  endtask

  task automatic run_tc_wr_01();
    apply_reset();
    axil_write(32'h0000_1000, 32'h1234_5678, 4'b1111, 3'b000, 2'b00);
    repeat (5) @(posedge clk);
  endtask

  task automatic run_tc_wr_02();
    apply_reset();
    axil_write(32'h0000_1010, 32'h0000_00AA, 4'b0001, 3'b000, 2'b00);
    axil_write(32'h0000_1014, 32'h0000_BB00, 4'b0010, 3'b000, 2'b00);
    axil_write(32'h0000_1018, 32'h00CC_0000, 4'b0100, 3'b000, 2'b00);
    axil_write(32'h0000_101C, 32'hDD00_0000, 4'b1000, 3'b000, 2'b00);
    axil_write(32'h0000_1020, 32'h0000_BEEF, 4'b0011, 3'b000, 2'b00);
    axil_write(32'h0000_1024, 32'hDEAD_0000, 4'b1100, 3'b000, 2'b00);
    repeat (5) @(posedge clk);
  endtask

  task automatic run_tc_rd_01();
    apply_reset();
    axil_read(32'h0000_2000, (32'h0000_2000 ^ 32'hA5A5_5A5A), 3'b000, 2'b00);
    repeat (5) @(posedge clk);
  endtask

  task automatic run_tc_rd_02();
    apply_reset();
    axil_read(32'h0000_0000, (32'h0000_0000 ^ 32'hA5A5_5A5A), 3'b000, 2'b00);
    axil_read(32'hFFFF_FFFC, (32'hFFFF_FFFC ^ 32'hA5A5_5A5A), 3'b000, 2'b00);
    repeat (5) @(posedge clk);
  endtask

  task automatic run_tc_b2b_01();
    apply_reset();
    for (int i = 0; i < 5; i++) begin
      axil_write(32'h0000_3000 + (i * 4), 32'hA000_0000 + i, 4'b1111, 3'b000, 2'b00);
      axil_read(32'h0000_3000 + (i * 4), 32'hA000_0000 + i, 3'b000, 2'b00);
    end
    repeat (10) @(posedge clk);
  endtask

  task automatic run_tc_bp_01();
    apply_reset();
    inject_downstream_bp <= 1'b1;
    for (int i = 0; i < 4; i++) begin
      axil_write(32'h0000_4000 + (i * 4), 32'hB000_0000 + i, 4'b1111, 3'b000, 2'b00);
      axil_read(32'h0000_4000 + (i * 4), 32'hB000_0000 + i, 3'b000, 2'b00);
    end
    inject_downstream_bp <= 1'b0;
    repeat (10) @(posedge clk);
  endtask

  task automatic run_tc_bp_02();
    apply_reset();
    fork
      begin
        axil_write(32'h0000_5000, 32'hCAFE_BABE, 4'b1111, 3'b000, 2'b00);
        axil_read(32'h0000_5000, 32'hCAFE_BABE, 3'b000, 2'b00);
      end
      begin
        repeat (2) @(posedge clk);
        s_req.b_ready <= 1'b0;
        s_req.r_ready <= 1'b0;
        repeat (4) @(posedge clk);
        s_req.b_ready <= 1'b1;
        s_req.r_ready <= 1'b1;
      end
    join
    repeat (10) @(posedge clk);
  endtask

  task automatic run_tc_err_01();
    apply_reset();
    // 0xFFFF_0000 -> SLVERR (2'b10)
    axil_write(32'hFFFF_0000, 32'hDEAD_BEEF, 4'b1111, 3'b000, 2'b10);
    axil_read(32'hFFFF_0000, 32'hDEAD_DEAD, 3'b000, 2'b10);

    // 0xFFFF_0004 -> DECERR (2'b11)
    axil_write(32'hFFFF_0004, 32'hDEAD_C0DE, 4'b1111, 3'b000, 2'b11);
    axil_read(32'hFFFF_0004, 32'hDEAD_DECE, 3'b000, 2'b11);
    repeat (10) @(posedge clk);
  endtask

  task automatic run_tc_prot_01();
    apply_reset();
    // Exercise privileged (3'b001), non-secure (3'b010), and instruction fetch (3'b100)
    axil_write(32'h0000_6000, 32'h1111_2222, 4'b1111, 3'b001, 2'b00);
    axil_write(32'h0000_6004, 32'h3333_4444, 4'b1111, 3'b010, 2'b00);
    axil_read(32'h0000_6008, (32'h0000_6008 ^ 32'hA5A5_5A5A), 3'b100, 2'b00);
    repeat (10) @(posedge clk);
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  initial begin
    clk                  = '0;
    rst_n                = '0;
    s_req                = '0;
    s_req.b_ready        = '1;
    s_req.r_ready        = '1;
    m_rsp                = '0;
    downstream_ready_en  = '1;
    inject_downstream_bp = '0;

    start_clock();
    start_checking();

    case (test_name)
      "TC_RST_01":  run_tc_rst_01();
      "TC_RST_02":  run_tc_rst_02();
      "TC_WR_01":   run_tc_wr_01();
      "TC_WR_02":   run_tc_wr_02();
      "TC_RD_01":   run_tc_rd_01();
      "TC_RD_02":   run_tc_rd_02();
      "TC_B2B_01":  run_tc_b2b_01();
      "TC_BP_01":   run_tc_bp_01();
      "TC_BP_02":   run_tc_bp_02();
      "TC_ERR_01":  run_tc_err_01();
      "TC_PROT_01": run_tc_prot_01();
      "TC_ALL": begin
        run_tc_rst_01();
        run_tc_rst_02();
        run_tc_wr_01();
        run_tc_wr_02();
        run_tc_rd_01();
        run_tc_rd_02();
        run_tc_b2b_01();
        run_tc_bp_01();
        run_tc_bp_02();
        run_tc_err_01();
        run_tc_prot_01();
      end

      default: begin
        $fatal(1, "Unrecognized test_name '%s'", test_name);
      end
    endcase

    #100ns;
    $finish;
  end

endmodule
