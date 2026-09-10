/*

| TEST CASE | DATE       | AUTHOR          | DESCRIPTION                                               |
|-----------|------------|-----------------|-----------------------------------------------------------|
| TC_001    | 2026-09-09 | Annim Jannat    | Reset / idle state check                                  |
| TC_002    | 2026-09-09 | Annim Jannat    | INCR burst - address, data and strobe propagation         |
| TC_003    | 2026-09-09 | Annim Jannat    | FIXED burst - address stays constant across all beats     |
| TC_004    | 2026-09-09 | Annim Jannat    | WRAP burst - address wraps at the alignment boundary      |
| TC_005    | 2026-09-09 | Annim Jannat    | AXI4-Lite backpressure - beat stalls until AW/W ready     |
| TC_006    | 2026-09-09 | Annim Jannat    | AW/W channel skew - handshake combiner waits for both     |
| TC_007    | 2026-09-09 | Annim Jannat    | SLVERR response aggregation                               |
| TC_008    | 2026-09-09 | Annim Jannat    | Back-to-back bursts - AW accepted again after B completes |
| TC_009    | 2026-09-09 | Annim Jannat    | Randomized burst regression vs. reference address model   |
| TC_ALL    | 2026-09-09 | Annim Jannat    | Run all the test cases above                              |

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-09-09 | Annim Jannat    | Initial version                                        |
| 1.0      | 2026-09-09 | Annim Jannat    | Stable release                                         |

Author : Annim Jannat    (jannatannim@gmail.com)
This file is part of ADN-VLSI/adn_axi
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_axi_agu_burst_splitter_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int  ADDR_WIDTH = 32;
  localparam int  DATA_WIDTH = 32;
  localparam int  ID_WIDTH   = 4;
  localparam int  STRB_WIDTH = DATA_WIDTH / 8;
  localparam time CLK_PERIOD = 10ns;
  localparam int  NUM_RANDOM_ITERS = 20;

  localparam logic [2:0] AXBURST_FIXED = 3'b000;
  localparam logic [2:0] AXBURST_INCR  = 3'b001;
  localparam logic [2:0] AXBURST_WRAP  = 3'b010;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // NOTE: mirrors the field usage inside adn_axi_agu_burst_splitter exactly
  // (aw.id/addr/len/size/burst, w.data/strb, b.id/resp, plus valid/ready). If
  // the project provides shared `AXI_T(...)/AXIL_T(...) typedef macros (like
  // axil/typedef.svh used elsewhere), prefer those over these local typedefs
  // so the TB and DUT share one source of truth.
  typedef struct packed {
    logic [ID_WIDTH-1:0]   id;
    logic [ADDR_WIDTH-1:0] addr;
    logic [7:0]            len;
    logic [2:0]            size;
    logic [2:0]            burst;
  } axi_aw_t;

  typedef struct packed {
    logic [DATA_WIDTH-1:0] data;
    logic [STRB_WIDTH-1:0] strb;
  } axi_w_t;

  typedef struct packed {
    logic [ID_WIDTH-1:0] id;
    logic [1:0]           resp;
  } axi_b_t;

  typedef struct packed {
    axi_aw_t aw;
    logic    aw_valid;
    axi_w_t  w;
    logic    w_valid;
    logic    b_ready;
  } axi_req_t;

  typedef struct packed {
    logic   aw_ready;
    logic   w_ready;
    axi_b_t b;
    logic   b_valid;
  } axi_rsp_t;

  typedef struct packed {
    logic [ADDR_WIDTH-1:0] addr;
    logic [2:0]            prot;
  } axil_aw_t;

  typedef struct packed {
    logic [DATA_WIDTH-1:0] data;
    logic [STRB_WIDTH-1:0] strb;
  } axil_w_t;

  typedef struct packed {
    logic [1:0] resp;
  } axil_b_t;

  typedef struct packed {
    axil_aw_t aw;
    logic     aw_valid;
    axil_w_t  w;
    logic     w_valid;
    logic     b_ready;
  } axil_req_t;

  typedef struct packed {
    logic    aw_ready;
    logic    w_ready;
    axil_b_t b;
    logic    b_valid;
  } axil_rsp_t;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic      clk_i;
  logic      arst_ni;

  axi_req_t  axi_req_i;
  axi_rsp_t  axi_rsp_o;

  axil_req_t axil_req_o;
  axil_rsp_t axil_rsp_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // DUT
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // NOTE: adn_axi_agu_burst_splitter instantiates adn_common_hs_combiner
  // internally; that module must be on the compile/elaboration path too.
  adn_axi_agu_burst_splitter #(
      .ADDR_WIDTH (ADDR_WIDTH),
      .DATA_WIDTH (DATA_WIDTH),
      .ID_WIDTH   (ID_WIDTH),
      .STRB_WIDTH (STRB_WIDTH),
      .axi_req_t  (axi_req_t),
      .axi_rsp_t  (axi_rsp_t),
      .axil_req_t (axil_req_t),
      .axil_rsp_t (axil_rsp_t)
  ) dut (
      .clk_i     (clk_i),
      .arst_ni   (arst_ni),
      .axi_req_i (axi_req_i),
      .axi_rsp_o (axi_rsp_o),
      .axil_req_o(axil_req_o),
      .axil_rsp_i(axil_rsp_i)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // CLOCK GENERATION
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin
    clk_i = 0;
    forever #(CLK_PERIOD / 2) clk_i = ~clk_i;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // DEFAULT SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic axi4_default();

    axi_req_i.aw       = '0;
    axi_req_i.aw_valid = 1'b0;
    axi_req_i.w        = '0;
    axi_req_i.w_valid  = 1'b0;
    axi_req_i.b_ready  = 1'b0;

  endtask

  task automatic axil_default();

    axil_rsp_i.aw_ready = 1'b0;
    axil_rsp_i.w_ready  = 1'b0;
    axil_rsp_i.b.resp   = 2'b00;
    axil_rsp_i.b_valid  = 1'b0;

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RESET
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic apply_reset();

    arst_ni = 1'b0;

    axi4_default();
    axil_default();

    #22;

    arst_ni = 1'b1;

    @(posedge clk_i);

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // REFERENCE MODEL
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Mirrors the DUT's address decipheral + counter (S_DECODE / S_NEXT_BEAT)
  // exactly, producing the expected per-beat AXI4-Lite AWADDR sequence.
  function automatic void ref_model(input logic [ADDR_WIDTH-1:0] awaddr,
                                     input logic [7:0] awlen, input logic [2:0] awsize,
                                     input logic [2:0] awburst,
                                     output logic [ADDR_WIDTH-1:0] exp_addr[$]);
    logic [ADDR_WIDTH-1:0] capacity, wrap_mask, addr_l, addr_u, cur, nxt;
    exp_addr  = {};
    capacity  = ({{(ADDR_WIDTH - 8) {1'b0}}, awlen} + 1'b1) << awsize;
    wrap_mask = capacity - 1'b1;
    unique case (awburst)
      AXBURST_WRAP: begin
        addr_l = awaddr & ~wrap_mask;
        addr_u = (awaddr & ~wrap_mask) + capacity;
      end
      default: begin
        addr_l = awaddr;
        addr_u = '0;
      end
    endcase
    cur = awaddr;
    for (int unsigned i = 0; i <= awlen; i++) begin
      exp_addr.push_back(cur);
      nxt = cur + ({{(ADDR_WIDTH - 1) {1'b0}}, 1'b1} << awsize);
      unique case (awburst)
        AXBURST_FIXED: cur = cur;
        AXBURST_WRAP:  cur = (nxt == addr_u) ? addr_l : nxt;
        default:       cur = nxt;  // INCR
      endcase
    end
  endfunction

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // AXI4 WRITE BURST (MASTER SIDE)
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic axi4_send_burst(input logic [ID_WIDTH-1:0] id, input logic [ADDR_WIDTH-1:0] addr,
                                  input logic [7:0] len, input logic [2:0] size,
                                  input logic [2:0] burst,
                                  input logic [DATA_WIDTH-1:0] wdata[$],
                                  input logic [STRB_WIDTH-1:0] wstrb);
    begin
      @(negedge clk_i);

      axi_req_i.aw.id    = id;
      axi_req_i.aw.addr  = addr;
      axi_req_i.aw.len   = len;
      axi_req_i.aw.size  = size;
      axi_req_i.aw.burst = burst;
      axi_req_i.aw_valid = 1'b1;

      while (!axi_rsp_o.aw_ready) @(posedge clk_i);

      @(negedge clk_i);
      axi_req_i.aw_valid = 1'b0;

      foreach (wdata[i]) begin
        axi_req_i.w.data  = wdata[i];
        axi_req_i.w.strb  = wstrb;
        axi_req_i.w_valid = 1'b1;

        @(posedge clk_i);
        while (!axi_rsp_o.w_ready) @(posedge clk_i);

        @(negedge clk_i);
        axi_req_i.w_valid = 1'b0;
      end

      axi_req_i.b_ready = 1'b1;
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // WAIT FOR AXI4 BRESP
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic wait_axi_bresp(input logic [ID_WIDTH-1:0] expected_id,
                                 input logic [1:0] expected_resp);
    int timeout;
    begin
      timeout = 0;
      while (!axi_rsp_o.b_valid) begin
        @(posedge clk_i);
        timeout++;

        if (timeout > 200) begin
          $error("[%0t] Timeout waiting for AXI4 BVALID", $time);
          return;
        end
      end

      if (axi_rsp_o.b.id !== expected_id) begin
        $error("[%0t] BID mismatch: expected=%0d actual=%0d", $time, expected_id, axi_rsp_o.b.id);
      end

      if (axi_rsp_o.b.resp !== expected_resp) begin
        $error("[%0t] BRESP mismatch: expected=%0b actual=%0b", $time, expected_resp,
               axi_rsp_o.b.resp);
      end

      @(negedge clk_i);
      axi_req_i.b_ready = 1'b0;
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // WAIT FOR AXI4-LITE BEAT (SLAVE SIDE)
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic wait_axil_beat(input logic [ADDR_WIDTH-1:0] expected_addr,
                                 input logic [DATA_WIDTH-1:0] expected_data,
                                 input logic [STRB_WIDTH-1:0] expected_strb);
    int timeout;
    begin
      timeout = 0;
      while (!(axil_req_o.aw_valid && axil_req_o.w_valid)) begin
        @(posedge clk_i);
        timeout++;

        if (timeout > 100) begin
          $error("[%0t] Timeout waiting for AXI4-Lite beat", $time);
          return;
        end
      end

      if (axil_req_o.aw.addr !== expected_addr) begin
        $error("[%0t] AWADDR mismatch: expected=0x%08h actual=0x%08h", $time, expected_addr,
               axil_req_o.aw.addr);
      end

      if (axil_req_o.w.data !== expected_data) begin
        $error("[%0t] WDATA mismatch: expected=0x%08h actual=0x%08h", $time, expected_data,
               axil_req_o.w.data);
      end

      if (axil_req_o.w.strb !== expected_strb) begin
        $error("[%0t] WSTRB mismatch: expected=%0h actual=%0h", $time, expected_strb,
               axil_req_o.w.strb);
      end

      if (axil_req_o.aw.prot !== 3'b000) begin
        $error("[%0t] AWPROT mismatch: expected=000 actual=%b", $time, axil_req_o.aw.prot);
      end
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // AXI4-LITE BEAT RESPONSE (SLAVE SIDE)
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic axil_beat_response(input logic [1:0] resp);
    begin
      while (!axil_req_o.b_ready) @(posedge clk_i);
      @(negedge clk_i);

      axil_rsp_i.b.resp  = resp;
      axil_rsp_i.b_valid = 1'b1;

      @(posedge clk_i);

      if (!axil_req_o.b_ready) begin
        $error("[%0t] AXI4-Lite BREADY not asserted during BVALID", $time);
      end

      @(negedge clk_i);

      axil_rsp_i.b_valid = 1'b0;
      axil_rsp_i.b.resp  = 2'b00;
    end
  endtask

  // Convenience wrapper: waits for + checks + responds to every beat of a
  // burst, in order. Requires axil_rsp_i.aw_ready / w_ready to already be
  // set by the caller (mirrors wait_axi_write + axi_write_response usage).
  task automatic axil_serve_burst(input logic [ADDR_WIDTH-1:0] exp_addr[$],
                                   input logic [DATA_WIDTH-1:0] exp_data[$],
                                   input logic [STRB_WIDTH-1:0] exp_strb,
                                   input logic [1:0] resp_per_beat[$]);
    begin
      foreach (exp_addr[i]) begin
        wait_axil_beat(exp_addr[i], exp_data[i], exp_strb);
        axil_beat_response(resp_per_beat[i]);
      end
    end
  endtask

  // Same as above, but drives AW ready and W ready with independent per-beat
  // delays so AW and W can legitimately complete on different cycles -
  // exercises the DUT's handshake combiner directly.
  task automatic axil_serve_beat_skewed(input logic [ADDR_WIDTH-1:0] expected_addr,
                                         input logic [DATA_WIDTH-1:0] expected_data,
                                         input logic [STRB_WIDTH-1:0] expected_strb,
                                         input logic [1:0] resp,
                                         input int unsigned aw_delay_cyc,
                                         input int unsigned w_delay_cyc);
    begin
      fork
        begin : aw_branch
          repeat (aw_delay_cyc) @(posedge clk_i);
          @(negedge clk_i);
          axil_rsp_i.aw_ready = 1'b1;
          @(posedge clk_i);
          while (!axil_req_o.aw_valid) @(posedge clk_i);
          if (axil_req_o.aw.addr !== expected_addr) begin
            $error("[%0t] AWADDR mismatch: expected=0x%08h actual=0x%08h", $time, expected_addr,
                   axil_req_o.aw.addr);
          end
          @(negedge clk_i);
          axil_rsp_i.aw_ready = 1'b0;
        end
        begin : w_branch
          repeat (w_delay_cyc) @(posedge clk_i);
          @(negedge clk_i);
          axil_rsp_i.w_ready = 1'b1;
          @(posedge clk_i);
          while (!axil_req_o.w_valid) @(posedge clk_i);
          if (axil_req_o.w.data !== expected_data) begin
            $error("[%0t] WDATA mismatch: expected=0x%08h actual=0x%08h", $time, expected_data,
                   axil_req_o.w.data);
          end
          if (axil_req_o.w.strb !== expected_strb) begin
            $error("[%0t] WSTRB mismatch: expected=%0h actual=%0h", $time, expected_strb,
                   axil_req_o.w.strb);
          end
          @(negedge clk_i);
          axil_rsp_i.w_ready = 1'b0;
        end
      join

      axil_beat_response(resp);
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_001
  //
  // RESET / IDLE STATE
  //
  // Right after reset the DUT must sit in S_IDLE: AXI4 AWREADY high, AXI4
  // BVALID low, and no beat yet driven onto the AXI4-Lite side.
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_001_reset_idle();
    begin
      note_case(1);
      $display("\nTC_001: RESET / IDLE STATE");

      if (!axi_rsp_o.aw_ready) $error("TC_001: AWREADY should be high in idle right after reset");
      if (axi_rsp_o.b_valid) $error("TC_001: BVALID should be low in idle right after reset");
      if (axil_req_o.aw_valid)
        $error("TC_001: AXI4-Lite AWVALID should be low in idle right after reset");
      if (axil_req_o.w_valid)
        $error("TC_001: AXI4-Lite WVALID should be low in idle right after reset");

      $display("TC_001 PASS");
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_002
  //
  // INCR BURST
  //
  // 4-beat INCR burst, 4B/beat. Every beat's AWADDR must match the
  // reference model, and WDATA/WSTRB must pass through untouched.
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_002_incr_burst();
    logic [ADDR_WIDTH-1:0] exp_addr[$];
    logic [DATA_WIDTH-1:0] wdata[$];
    logic [1:0] exp_resp[$];
    begin
      note_case(1);
      $display("\nTC_002: INCR BURST");

      axil_rsp_i.aw_ready = 1'b1;
      axil_rsp_i.w_ready  = 1'b1;

      ref_model(32'h1000_0000, 8'd3, 3'd2, AXBURST_INCR, exp_addr);
      wdata    = '{32'hBEEF_0000, 32'hBEEF_0001, 32'hBEEF_0002, 32'hBEEF_0003};
      exp_resp = '{2'b00, 2'b00, 2'b00, 2'b00};

      fork
        begin
          axi4_send_burst(4'h1, 32'h1000_0000, 8'd3, 3'd2, AXBURST_INCR, wdata, 4'b1111);
          wait_axi_bresp(4'h1, 2'b00);
        end
        begin
          axil_serve_burst(exp_addr, wdata, 4'b1111, exp_resp);
        end
      join

      $display("TC_002 PASS");
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_003
  //
  // FIXED BURST
  //
  // 8-beat FIXED burst - AWADDR must stay identical on every beat.
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_003_fixed_burst();
    logic [ADDR_WIDTH-1:0] exp_addr[$];
    logic [DATA_WIDTH-1:0] wdata[$];
    logic [1:0] exp_resp[$];
    begin
      note_case(1);
      $display("\nTC_003: FIXED BURST");

      axil_rsp_i.aw_ready = 1'b1;
      axil_rsp_i.w_ready  = 1'b1;

      ref_model(32'h2000_0010, 8'd7, 3'd2, AXBURST_FIXED, exp_addr);
      wdata = '{
          32'hCAFE_0000,
          32'hCAFE_0001,
          32'hCAFE_0002,
          32'hCAFE_0003,
          32'hCAFE_0004,
          32'hCAFE_0005,
          32'hCAFE_0006,
          32'hCAFE_0007
      };
      exp_resp = '{2'b00, 2'b00, 2'b00, 2'b00, 2'b00, 2'b00, 2'b00, 2'b00};

      fork
        begin
          axi4_send_burst(4'h2, 32'h2000_0010, 8'd7, 3'd2, AXBURST_FIXED, wdata, 4'b1111);
          wait_axi_bresp(4'h2, 2'b00);
        end
        begin
          axil_serve_burst(exp_addr, wdata, 4'b1111, exp_resp);
        end
      join

      $display("TC_003 PASS");
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_004
  //
  // WRAP BURST
  //
  // 4-beat WRAP burst, 4B/beat, unaligned start address - the address must
  // wrap back to the lower boundary mid-burst per the reference model.
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_004_wrap_burst();
    logic [ADDR_WIDTH-1:0] exp_addr[$];
    logic [DATA_WIDTH-1:0] wdata[$];
    logic [1:0] exp_resp[$];
    begin
      note_case(1);
      $display("\nTC_004: WRAP BURST");

      axil_rsp_i.aw_ready = 1'b1;
      axil_rsp_i.w_ready  = 1'b1;

      ref_model(32'h3000_0004, 8'd3, 3'd2, AXBURST_WRAP, exp_addr);
      wdata    = '{32'hD00D_0000, 32'hD00D_0001, 32'hD00D_0002, 32'hD00D_0003};
      exp_resp = '{2'b00, 2'b00, 2'b00, 2'b00};

      fork
        begin
          axi4_send_burst(4'h3, 32'h3000_0004, 8'd3, 3'd2, AXBURST_WRAP, wdata, 4'b1111);
          wait_axi_bresp(4'h3, 2'b00);
        end
        begin
          axil_serve_burst(exp_addr, wdata, 4'b1111, exp_resp);
        end
      join

      $display("TC_004 PASS");
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_005
  //
  // AXI4-LITE BACKPRESSURE
  //
  // AXI4-Lite AWREADY/WREADY held low. Therefore:
  //   AXI4 WREADY = 0
  //   AXI4-Lite AWVALID/WVALID stay asserted, waiting
  //
  // Once ready is released, the stalled beats complete normally.
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_005_axil_backpressure();
    logic [ADDR_WIDTH-1:0] exp_addr[$];
    logic [DATA_WIDTH-1:0] wdata[$];
    logic [1:0] exp_resp[$];
    begin
      note_case(1);
      $display("\nTC_005: AXI4-LITE BACKPRESSURE");

      axil_rsp_i.aw_ready = 1'b0;
      axil_rsp_i.w_ready  = 1'b0;

      ref_model(32'hA000_0000, 8'd1, 3'd2, AXBURST_INCR, exp_addr);
      wdata    = '{32'hBEEF_0000, 32'hBEEF_0001};
      exp_resp = '{2'b00, 2'b00};

      fork
        begin
          axi4_send_burst(4'h4, 32'hA000_0000, 8'd1, 3'd2, AXBURST_INCR, wdata, 4'b1111);
          wait_axi_bresp(4'h4, 2'b00);
        end
        begin
          repeat (3) begin
            @(posedge clk_i);
            if (axi_rsp_o.w_ready !== 1'b0)
              $error("TC_005: WREADY asserted during AXI4-Lite backpressure");
          end

          @(negedge clk_i);
          axil_rsp_i.aw_ready = 1'b1;
          axil_rsp_i.w_ready  = 1'b1;

          axil_serve_burst(exp_addr, wdata, 4'b1111, exp_resp);
        end
      join

      $display("TC_005 PASS");
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_006
  //
  // AW/W CHANNEL SKEW
  //
  // AXI4-Lite AWREADY and WREADY are asserted with different per-beat
  // delays, so AW and W legitimately complete on different cycles. The
  // handshake combiner inside the DUT must still only advance to BRESP once
  // BOTH channels of a beat have completed.
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_006_aw_w_skew();
    logic [ADDR_WIDTH-1:0] exp_addr[$];
    logic [DATA_WIDTH-1:0] wdata[$];
    begin
      note_case(1);
      $display("\nTC_006: AW/W CHANNEL SKEW");

      ref_model(32'hB000_0000, 8'd3, 3'd2, AXBURST_INCR, exp_addr);
      wdata = '{32'hFEED_0000, 32'hFEED_0001, 32'hFEED_0002, 32'hFEED_0003};

      fork
        begin
          axi4_send_burst(4'h5, 32'hB000_0000, 8'd3, 3'd2, AXBURST_INCR, wdata, 4'b1111);
          wait_axi_bresp(4'h5, 2'b00);
        end
        begin
          axil_serve_beat_skewed(exp_addr[0], wdata[0], 4'b1111, 2'b00, 3, 0);  // AW late
          axil_serve_beat_skewed(exp_addr[1], wdata[1], 4'b1111, 2'b00, 0, 3);  // W late
          axil_serve_beat_skewed(exp_addr[2], wdata[2], 4'b1111, 2'b00, 2, 1);
          axil_serve_beat_skewed(exp_addr[3], wdata[3], 4'b1111, 2'b00, 1, 2);
        end
      join

      $display("TC_006 PASS");
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_007
  //
  // SLVERR RESPONSE AGGREGATION
  //
  // AXI4-Lite:
  //   2'b10 = SLVERR on the 2nd beat of a 2-beat INCR burst
  //
  // DUT must elevate the aggregated AXI4 BRESP to SLVERR.
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_007_slverr_response();
    logic [ADDR_WIDTH-1:0] exp_addr[$];
    logic [DATA_WIDTH-1:0] wdata[$];
    logic [1:0] exp_resp[$];
    begin
      note_case(1);
      $display("\nTC_007: SLVERR RESPONSE AGGREGATION");

      axil_rsp_i.aw_ready = 1'b1;
      axil_rsp_i.w_ready  = 1'b1;

      ref_model(32'hC000_0000, 8'd1, 3'd2, AXBURST_INCR, exp_addr);
      wdata    = '{32'hABCD_0000, 32'hABCD_0001};
      exp_resp = '{2'b00, 2'b10};

      fork
        begin
          axi4_send_burst(4'h6, 32'hC000_0000, 8'd1, 3'd2, AXBURST_INCR, wdata, 4'b1111);
          wait_axi_bresp(4'h6, 2'b10);
        end
        begin
          axil_serve_burst(exp_addr, wdata, 4'b1111, exp_resp);
        end
      join

      $display("TC_007 PASS");
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_008
  //
  // BACK-TO-BACK BURSTS
  //
  // First single-beat burst completes, then a second single-beat burst must
  // be accepted (AWREADY high again) immediately.
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_008_back_to_back();
    logic [ADDR_WIDTH-1:0] exp_addr[$];
    logic [DATA_WIDTH-1:0] wdata[$];
    logic [1:0] exp_resp[$];
    begin
      note_case(1);
      $display("\nTC_008: BACK-TO-BACK BURSTS");

      axil_rsp_i.aw_ready = 1'b1;
      axil_rsp_i.w_ready  = 1'b1;

      ref_model(32'hD000_0000, 8'd0, 3'd2, AXBURST_INCR, exp_addr);
      wdata    = '{32'h1111_0000};
      exp_resp = '{2'b00};

      fork
        begin
          axi4_send_burst(4'h7, 32'hD000_0000, 8'd0, 3'd2, AXBURST_INCR, wdata, 4'b1111);
          wait_axi_bresp(4'h7, 2'b00);
        end
        begin
          axil_serve_burst(exp_addr, wdata, 4'b1111, exp_resp);
        end
      join

      if (!axi_rsp_o.aw_ready)
        $error("TC_008: AWREADY not asserted immediately after previous burst completed");

      ref_model(32'hD000_0100, 8'd0, 3'd2, AXBURST_INCR, exp_addr);
      wdata    = '{32'h2222_0000};
      exp_resp = '{2'b00};

      fork
        begin
          axi4_send_burst(4'h8, 32'hD000_0100, 8'd0, 3'd2, AXBURST_INCR, wdata, 4'b1111);
          wait_axi_bresp(4'h8, 2'b00);
        end
        begin
          axil_serve_burst(exp_addr, wdata, 4'b1111, exp_resp);
        end
      join

      $display("TC_008 PASS");
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_009
  //
  // RANDOMIZED BURST REGRESSION
  //
  // Random burst type / length / address, checked beat-by-beat against
  // ref_model(). WRAP lengths are constrained to legal 2/4/8/16-beat sizes.
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_009_randomized_regression();
    begin
      note_case(1);
      $display("\nTC_009: RANDOMIZED REGRESSION");

      axil_rsp_i.aw_ready = 1'b1;
      axil_rsp_i.w_ready  = 1'b1;

      for (int unsigned i = 0; i < NUM_RANDOM_ITERS; i++) begin
        logic [ADDR_WIDTH-1:0] r_addr;
        logic [7:0] r_len;
        logic [2:0] r_size;
        logic [2:0] r_burst;
        logic [ADDR_WIDTH-1:0] exp_addr[$];
        logic [DATA_WIDTH-1:0] wdata[$];
        logic [1:0] exp_resp[$];
        int unsigned burst_pick;

        r_size     = 3'd2;
        burst_pick = $urandom_range(0, 2);
        r_burst    = (burst_pick == 0) ? AXBURST_FIXED :
                     (burst_pick == 1) ? AXBURST_INCR : AXBURST_WRAP;

        if (r_burst == AXBURST_WRAP) begin
          unique case ($urandom_range(0, 3))
            0: r_len = 8'd1;
            1: r_len = 8'd3;
            2: r_len = 8'd7;
            default: r_len = 8'd15;
          endcase
        end else begin
          r_len = $urandom_range(0, 15);
        end
        r_addr = $urandom & 32'hFFFF_FFFC;

        ref_model(r_addr, r_len, r_size, r_burst, exp_addr);
        wdata    = {};
        exp_resp = {};
        for (int unsigned b = 0; b <= r_len; b++) begin
          wdata.push_back(32'h9000_0000 + {20'h0, i[5:0], b[5:0]});
          exp_resp.push_back(2'b00);
        end

        fork
          begin
            axi4_send_burst(4'h9, r_addr, r_len, r_size, r_burst, wdata, 4'b1111);
            wait_axi_bresp(4'h9, 2'b00);
          end
          begin
            axil_serve_burst(exp_addr, wdata, 4'b1111, exp_resp);
          end
        join
      end

      $display("TC_009 PASS");
    end
  endtask

  task automatic tc_all();
    tc_001_reset_idle();
    tc_002_incr_burst();
    tc_003_fixed_burst();
    tc_004_wrap_burst();
    tc_005_axil_backpressure();
    tc_006_aw_w_skew();
    tc_007_slverr_response();
    tc_008_back_to_back();
    tc_009_randomized_regression();
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // MAIN INITIAL
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin

    axi4_default();
    axil_default();

    arst_ni = 1'b0;

    apply_reset();

    case (test_name)
      "TC_ALL": tc_all();
      "TC_001", "reset_idle": tc_001_reset_idle();
      "TC_002", "incr_burst": tc_002_incr_burst();
      "TC_003", "fixed_burst": tc_003_fixed_burst();
      "TC_004", "wrap_burst": tc_004_wrap_burst();
      "TC_005", "axil_backpressure": tc_005_axil_backpressure();
      "TC_006", "aw_w_skew": tc_006_aw_w_skew();
      "TC_007", "slverr_response": tc_007_slverr_response();
      "TC_008", "back_to_back": tc_008_back_to_back();
      "TC_009", "randomized_regression": tc_009_randomized_regression();
      default: tc_all();
    endcase

    $display("");
    $display("==============================================================");
    $display("ALL DIRECTED TESTS COMPLETED");
    $display("==============================================================");
    $display("");

    $finish;
  end

endmodule
