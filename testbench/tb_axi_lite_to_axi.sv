`include "axi/typedef.svh"
`include "axil/typedef.svh"

module tb_axi_lite_to_axi;

  // ==========================================================================
  // PARAMETERS
  // ==========================================================================

  localparam int unsigned ID_WIDTH = 4;
  localparam int unsigned ADDR_WIDTH = 32;
  localparam int unsigned DATA_WIDTH = 32;
  localparam int unsigned USER_WIDTH = 1;

  localparam int unsigned BYTE_WIDTH = DATA_WIDTH / 8;

  localparam logic [ID_WIDTH-1:0] AXI_AWID = 4'h1;
  localparam logic [ID_WIDTH-1:0] AXI_ARID = 4'h2;

  localparam logic [3:0] AXI_CACHE = 4'b0011;
  localparam logic [3:0] AXI_QOS = 4'b0000;
  localparam logic [3:0] AXI_REGION = 4'b0000;

  localparam logic [2:0] EXPECTED_AXI_SIZE = 3'd2;


  // ==========================================================================
  // CLOCK / RESET
  // ==========================================================================

  logic clk;
  logic aresetn;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    aresetn = 1'b0;

    repeat (4) @(posedge clk);

    // Release reset away from the active sampling edge.
    #1;
    aresetn = 1'b1;

    $display("");
    $display("[%0t] RESET RELEASED", $time);
    $display("");
  end


  // ==========================================================================
  // AXI TYPES
  // ==========================================================================

  `AXIL_T(axil, ADDR_WIDTH, DATA_WIDTH)
  `AXI_T(axi, ID_WIDTH, ADDR_WIDTH, DATA_WIDTH, USER_WIDTH)


  // ==========================================================================
  // DUT INTERFACE SIGNALS
  // ==========================================================================

  axil_req_t s_axi_req;
  axil_rsp_t s_axi_rsp;

  axi_req_t  m_axi_req;
  axi_rsp_t  m_axi_rsp;


  // ==========================================================================
  // DUT
  // ==========================================================================

  adn_axi_axil_to_axi #(
      .ID_WIDTH  (ID_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .USER_WIDTH(USER_WIDTH),

      .AXI_AWID(AXI_AWID),
      .AXI_ARID(AXI_ARID),

      .AXI_CACHE (AXI_CACHE),
      .AXI_QOS   (AXI_QOS),
      .AXI_REGION(AXI_REGION)
  ) dut (
      .clk    (clk),
      .aresetn(aresetn),

      .s_axi_req(s_axi_req),
      .s_axi_rsp(s_axi_rsp),

      .m_axi_req(m_axi_req),
      .m_axi_rsp(m_axi_rsp)
  );


  // ==========================================================================
  // TESTBENCH VARIABLES
  // ==========================================================================

  int errors = 0;

  logic [ADDR_WIDTH-1:0] test_addr;
  logic [DATA_WIDTH-1:0] test_wdata;
  logic [BYTE_WIDTH-1:0] test_strb;

  logic [DATA_WIDTH-1:0] expected_rdata;


  // ==========================================================================
  // INITIAL SIGNAL VALUES
  // ==========================================================================

  initial begin
    s_axi_req = '0;
    m_axi_rsp = '0;
  end


  // ==========================================================================
  // UTILITY: CHECK
  // ==========================================================================

  task automatic check(input bit condition, input string message);
    begin
      if (condition) begin
        $display("[%0t] CHECK PASSED: %s", $time, message);
      end else begin
        $error("[%0t] CHECK FAILED: %s", $time, message);
        errors++;
      end
    end
  endtask


  // ==========================================================================
  // AXI-LITE WRITE
  //
  // expected_bresp allows both normal and error-response testing.
  // ==========================================================================

  task automatic axil_write(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data,
                            input logic [BYTE_WIDTH-1:0] strb, input logic [2:0] prot = 3'b000,
                            input logic [1:0] expected_bresp = 2'b00);

    bit aw_done;
    bit w_done;
    bit b_done;

    int timeout;

    begin

      aw_done = 1'b0;
      w_done  = 1'b0;
      b_done  = 1'b0;
      timeout = 0;

      $display("");
      $display("============================================================");
      $display("AXI-LITE WRITE");
      $display("  ADDR = 0x%08h", addr);
      $display("  DATA = 0x%08h", data);
      $display("  STRB = 0x%0h", strb);
      $display("  EXPECTED BRESP = %02b", expected_bresp);
      $display("============================================================");

      // ----------------------------------------------------------
      // Present AW and W.
      // ----------------------------------------------------------

      @(negedge clk);

      s_axi_req.aw.addr  <= addr;
      s_axi_req.aw.prot  <= prot;
      s_axi_req.aw_valid <= 1'b1;

      s_axi_req.w.data   <= data;
      s_axi_req.w.strb   <= strb;
      s_axi_req.w_valid  <= 1'b1;

      // ----------------------------------------------------------
      // Wait for AW/W handshakes.
      // ----------------------------------------------------------

      while (!(aw_done && w_done)) begin

        @(posedge clk);

        if (!aw_done && s_axi_req.aw_valid && s_axi_rsp.aw_ready) begin

          aw_done = 1'b1;

          $display("[%0t] AXI-Lite AW HANDSHAKE", $time);

          @(negedge clk);
          s_axi_req.aw_valid <= 1'b0;

        end

        if (!w_done && s_axi_req.w_valid && s_axi_rsp.w_ready) begin

          w_done = 1'b1;

          $display("[%0t] AXI-Lite W HANDSHAKE", $time);

          @(negedge clk);
          s_axi_req.w_valid <= 1'b0;

        end

        timeout++;

        if (timeout > 100) begin

          $error("[%0t] AXI-Lite WRITE TIMEOUT waiting for AW/W", $time);

          errors++;
          break;

        end

      end

      // ----------------------------------------------------------
      // Assert BREADY.
      // ----------------------------------------------------------

      @(negedge clk);

      s_axi_req.b_ready <= 1'b1;

      timeout = 0;

      // ----------------------------------------------------------
      // Wait for B response.
      // ----------------------------------------------------------

      while (!b_done) begin

        @(posedge clk);

        if (s_axi_rsp.b_valid && s_axi_req.b_ready) begin

          b_done = 1'b1;

          $display("[%0t] AXI-Lite B HANDSHAKE BRESP=%02b", $time, s_axi_rsp.b.resp);

          check(s_axi_rsp.b.resp == expected_bresp, $sformatf(
                "AXI-Lite BRESP == expected %02b", expected_bresp));

          @(negedge clk);
          s_axi_req.b_ready <= 1'b0;

        end

        timeout++;

        if (timeout > 100) begin

          $error("[%0t] AXI-Lite WRITE TIMEOUT waiting for B response", $time);

          errors++;
          break;

        end

      end

      check(aw_done, "AXI-Lite AW channel completed");

      check(w_done, "AXI-Lite W channel completed");

      check(b_done, "AXI-Lite B channel completed");

      $display("[%0t] AXI-Lite WRITE COMPLETE", $time);

    end

  endtask


  // ==========================================================================
  // AXI-LITE READ
  // ==========================================================================

  task automatic axil_read(input logic [ADDR_WIDTH-1:0] addr, output logic [DATA_WIDTH-1:0] data);

    bit ar_done;
    bit r_done;

    int timeout;

    begin

      ar_done = 0;
      r_done  = 0;
      data    = '0;
      timeout = 0;

      $display("");
      $display("============================================================");
      $display("AXI-LITE READ");
      $display("  ADDR = 0x%08h", addr);
      $display("============================================================");

      // ----------------------------------------------------------
      // Drive AR before rising edge.
      // ----------------------------------------------------------

      @(negedge clk);

      s_axi_req.ar.addr  <= addr;
      s_axi_req.ar.prot  <= 3'b000;
      s_axi_req.ar_valid <= 1'b1;

      // ----------------------------------------------------------
      // Wait for AR handshake.
      // ----------------------------------------------------------

      while (!ar_done) begin

        @(posedge clk);

        if (s_axi_req.ar_valid && s_axi_rsp.ar_ready) begin

          ar_done = 1;

          $display("[%0t] AXI-Lite AR HANDSHAKE", $time);

          s_axi_req.ar_valid <= 1'b0;
        end

        timeout++;

        if (timeout > 100) begin
          $error("[%0t] AXI-Lite READ TIMEOUT waiting for AR", $time);
          errors++;
          break;
        end

      end

      // ----------------------------------------------------------
      // Ready for R response.
      // ----------------------------------------------------------

      @(negedge clk);

      s_axi_req.ar_valid <= 1'b0;
      s_axi_req.r_ready  <= 1'b1;

      timeout = 0;

      while (!r_done) begin

        @(posedge clk);

        if (s_axi_rsp.r_valid && s_axi_req.r_ready) begin

          r_done = 1;

          data   = s_axi_rsp.r.data;

          $display("[%0t] AXI-Lite R HANDSHAKE RRESP=%02b DATA=0x%08h", $time, s_axi_rsp.r.resp,
                   s_axi_rsp.r.data);

          check(s_axi_rsp.r.resp == 2'b00, "AXI-Lite RRESP == OKAY");

          s_axi_req.r_ready <= 1'b0;
        end

        timeout++;

        if (timeout > 100) begin
          $error("[%0t] AXI-Lite READ TIMEOUT waiting for R response", $time);
          errors++;
          break;
        end

      end

      // ----------------------------------------------------------
      // Final cleanup.
      // ----------------------------------------------------------

      @(negedge clk);

      s_axi_req.ar_valid <= 1'b0;
      s_axi_req.r_ready  <= 1'b0;

      $display("[%0t] AXI-Lite READ COMPLETE", $time);

    end

  endtask

  // ==========================================================================
  // AXI WRITE SLAVE
  //
  // The AXI slave accepts AW and W independently.
  // This is important because AXI permits AW and W to arrive independently.
  // ==========================================================================

  task automatic axi_write_slave(
      input logic [ADDR_WIDTH-1:0] expected_addr, input logic [DATA_WIDTH-1:0] expected_data,
      input logic [BYTE_WIDTH-1:0] expected_strb, input logic [1:0] response);

    bit aw_seen;
    bit w_seen;

    int timeout;

    begin

      aw_seen = 0;
      w_seen  = 0;
      timeout = 0;

      // ----------------------------------------------------------
      // Slave ready for AW and W.
      // ----------------------------------------------------------

      @(negedge clk);

      m_axi_rsp.aw_ready <= 1'b1;
      m_axi_rsp.w_ready  <= 1'b1;

      while (!(aw_seen && w_seen)) begin

        @(posedge clk);

        // --------------------------------------------------------
        // AW handshake
        // --------------------------------------------------------

        if (!aw_seen && m_axi_req.aw_valid && m_axi_rsp.aw_ready) begin

          aw_seen = 1;

          $display("");
          $display("[%0t] AXI AW HANDSHAKE", $time);
          $display("  ID     = 0x%0h", m_axi_req.aw.id);
          $display("  ADDR   = 0x%08h", m_axi_req.aw.addr);
          $display("  LEN    = %0d", m_axi_req.aw.len);
          $display("  SIZE   = %0d", m_axi_req.aw.size);
          $display("  BURST  = %03b", m_axi_req.aw.burst);
          $display("  LOCK   = %0b", m_axi_req.aw.lock);
          $display("  CACHE  = %04b", m_axi_req.aw.cache);
          $display("  PROT   = %03b", m_axi_req.aw.prot);
          $display("  QOS    = %04b", m_axi_req.aw.qos);
          $display("  REGION = %04b", m_axi_req.aw.region);

          check(m_axi_req.aw.id == AXI_AWID, "AXI AWID");

          check(m_axi_req.aw.addr == expected_addr, "AXI AWADDR");

          check(m_axi_req.aw.len == 8'd0, "AXI AWLEN == 0");

          check(m_axi_req.aw.size == EXPECTED_AXI_SIZE, "AXI AWSIZE == 2");

          check(m_axi_req.aw.burst == 3'b001, "AXI AWBURST == INCR");

          check(m_axi_req.aw.lock == 1'b0, "AXI AWLOCK == 0");

          check(m_axi_req.aw.cache == AXI_CACHE, "AXI AWCACHE");

          check(m_axi_req.aw.prot == 3'b000, "AXI AWPROT");

          check(m_axi_req.aw.qos == AXI_QOS, "AXI AWQOS");

          check(m_axi_req.aw.region == AXI_REGION, "AXI AWREGION");
        end

        // --------------------------------------------------------
        // W handshake
        // --------------------------------------------------------

        if (!w_seen && m_axi_req.w_valid && m_axi_rsp.w_ready) begin

          w_seen = 1;

          $display("");
          $display("[%0t] AXI W HANDSHAKE", $time);
          $display("  DATA = 0x%08h", m_axi_req.w.data);
          $display("  STRB = 0x%0h", m_axi_req.w.strb);
          $display("  LAST = %0b", m_axi_req.w.last);

          check(m_axi_req.w.data == expected_data, "AXI WDATA");

          check(m_axi_req.w.strb == expected_strb, "AXI WSTRB");

          check(m_axi_req.w.last == 1'b1, "AXI WLAST == 1");
        end

        timeout++;

        if (timeout > 100) begin
          $error("[%0t] AXI WRITE SLAVE TIMEOUT waiting for AW/W", $time);
          errors++;
          break;
        end

      end

      // ----------------------------------------------------------
      // Stop accepting new AW/W.
      // ----------------------------------------------------------

      @(negedge clk);

      m_axi_rsp.aw_ready <= 1'b0;
      m_axi_rsp.w_ready  <= 1'b0;

      // ----------------------------------------------------------
      // Generate B response.
      //
      // Keep BVALID asserted until BREADY.
      // ----------------------------------------------------------

      m_axi_rsp.b.resp   <= response;
      m_axi_rsp.b_valid  <= 1'b1;

      $display("[%0t] AXI B RESPONSE ASSERTED BRESP=%02b", $time, response);

      timeout = 0;

      while (!(m_axi_rsp.b_valid && m_axi_req.b_ready)) begin

        @(posedge clk);

        timeout++;

        if (timeout > 100) begin
          $error("[%0t] AXI WRITE SLAVE TIMEOUT waiting for BREADY", $time);
          errors++;
          break;
        end

      end

      if (m_axi_rsp.b_valid && m_axi_req.b_ready) begin

        $display("[%0t] AXI B HANDSHAKE", $time);

      end

      @(negedge clk);

      m_axi_rsp.b_valid <= 1'b0;
      m_axi_rsp.b.resp  <= 2'b00;

    end

  endtask


  // ==========================================================================
  // AXI READ SLAVE
  // ==========================================================================

  task automatic axi_read_slave(input logic [ADDR_WIDTH-1:0] expected_addr,
                                input logic [DATA_WIDTH-1:0] read_data, input logic [1:0] response);

    bit ar_seen;

    int timeout;

    begin

      ar_seen = 0;
      timeout = 0;

      // ----------------------------------------------------------
      // Slave ready for AR.
      // ----------------------------------------------------------

      @(negedge clk);

      m_axi_rsp.ar_ready <= 1'b1;

      // ----------------------------------------------------------
      // Wait for AR.
      // ----------------------------------------------------------

      while (!ar_seen) begin

        @(posedge clk);

        if (m_axi_req.ar_valid && m_axi_rsp.ar_ready) begin

          ar_seen = 1;

          $display("");
          $display("[%0t] AXI AR HANDSHAKE", $time);
          $display("  ID     = 0x%0h", m_axi_req.ar.id);
          $display("  ADDR   = 0x%08h", m_axi_req.ar.addr);
          $display("  LEN    = %0d", m_axi_req.ar.len);
          $display("  SIZE   = %0d", m_axi_req.ar.size);
          $display("  BURST  = %03b", m_axi_req.ar.burst);
          $display("  LOCK   = %0b", m_axi_req.ar.lock);
          $display("  CACHE  = %04b", m_axi_req.ar.cache);
          $display("  PROT   = %03b", m_axi_req.ar.prot);
          $display("  QOS    = %04b", m_axi_req.ar.qos);
          $display("  REGION = %04b", m_axi_req.ar.region);

          check(m_axi_req.ar.id == AXI_ARID, "AXI ARID");

          check(m_axi_req.ar.addr == expected_addr, "AXI ARADDR");

          check(m_axi_req.ar.len == 8'd0, "AXI ARLEN == 0");

          check(m_axi_req.ar.size == EXPECTED_AXI_SIZE, "AXI ARSIZE == 2");

          check(m_axi_req.ar.burst == 3'b001, "AXI ARBURST == INCR");

          check(m_axi_req.ar.lock == 1'b0, "AXI ARLOCK == 0");

          check(m_axi_req.ar.cache == AXI_CACHE, "AXI ARCACHE");

          check(m_axi_req.ar.prot == 3'b000, "AXI ARPROT");

          check(m_axi_req.ar.qos == AXI_QOS, "AXI ARQOS");

          check(m_axi_req.ar.region == AXI_REGION, "AXI ARREGION");
        end

        timeout++;

        if (timeout > 100) begin
          $error("[%0t] AXI READ SLAVE TIMEOUT waiting for AR", $time);
          errors++;
          break;
        end

      end

      // ----------------------------------------------------------
      // Stop accepting AR.
      // ----------------------------------------------------------

      @(negedge clk);

      m_axi_rsp.ar_ready <= 1'b0;

      // ----------------------------------------------------------
      // Generate R response.
      // ----------------------------------------------------------

      m_axi_rsp.r.data   <= read_data;
      m_axi_rsp.r.resp   <= response;
      m_axi_rsp.r.last   <= 1'b1;
      m_axi_rsp.r_valid  <= 1'b1;

      $display("[%0t] AXI R RESPONSE ASSERTED DATA=0x%08h RRESP=%02b", $time, read_data, response);

      timeout = 0;

      while (!(m_axi_rsp.r_valid && m_axi_req.r_ready)) begin

        @(posedge clk);

        timeout++;

        if (timeout > 100) begin
          $error("[%0t] AXI READ SLAVE TIMEOUT waiting for RREADY", $time);
          errors++;
          break;
        end

      end

      if (m_axi_rsp.r_valid && m_axi_req.r_ready) begin

        $display("[%0t] AXI R HANDSHAKE", $time);

      end

      @(negedge clk);

      m_axi_rsp.r_valid <= 1'b0;
      m_axi_rsp.r.data  <= '0;
      m_axi_rsp.r.resp  <= 2'b00;
      m_axi_rsp.r.last  <= 1'b0;

    end

  endtask


  // ==========================================================================
  // TEST 1: NORMAL WRITE
  // ==========================================================================

  task automatic test_normal_write;

    begin

      $display("");
      $display("############################################################");
      $display("# TEST 1: NORMAL WRITE");
      $display("############################################################");

      test_addr  = 32'h0000_1000;
      test_wdata = 32'hDEAD_BEEF;
      test_strb  = 4'b1111;

      fork

        begin
          axil_write(test_addr, test_wdata, test_strb);
        end

        begin
          axi_write_slave(test_addr, test_wdata, test_strb, 2'b00);
        end

      join

      $display("");
      $display("******** TEST 1 COMPLETE ********");

    end

  endtask


  // ==========================================================================
  // TEST 2: NORMAL READ
  // ==========================================================================

  task automatic test_normal_read;

    logic [DATA_WIDTH-1:0] read_data;

    begin

      $display("");
      $display("############################################################");
      $display("# TEST 2: NORMAL READ");
      $display("############################################################");

      test_addr      = 32'h0000_2000;
      expected_rdata = 32'hCAFE_BABE;

      fork

        begin

          axil_read(test_addr, read_data);

          check(read_data == expected_rdata, "AXI-Lite read data matches expected data");

        end

        begin

          axi_read_slave(test_addr, expected_rdata, 2'b00);

        end

      join

      $display("");
      $display("******** TEST 2 COMPLETE ********");

    end

  endtask


  // ==========================================================================
  // TEST 3: W BEFORE AW
  //
  // AXI-Lite permits W to arrive before AW.
  // ==========================================================================

  task automatic test_w_before_aw;

    bit w_done;
    bit aw_done;
    bit b_done;

    int timeout;

    begin

      $display("");
      $display("############################################################");
      $display("# TEST 3: W BEFORE AW");
      $display("############################################################");

      test_addr = 32'h0000_3000;
      test_wdata = 32'h1234_5678;
      test_strb = 4'b1010;

      w_done = 0;
      aw_done = 0;
      b_done = 0;

      // ----------------------------------------------------------------------
      // Make absolutely sure no request signals from a previous transaction
      // remain asserted.
      // ----------------------------------------------------------------------

      @(negedge clk);

      s_axi_req.aw_valid <= 1'b0;
      s_axi_req.w_valid  <= 1'b0;
      s_axi_req.b_ready  <= 1'b0;

      // ----------------------------------------------------------------------
      // Master + AXI slave
      // ----------------------------------------------------------------------

      fork

        // ====================================================================
        // AXI-Lite MASTER
        // ====================================================================

        begin : AXIL_W_FIRST

          // ------------------------------------------------------------
          // Drive W FIRST.
          // ------------------------------------------------------------

          @(negedge clk);

          s_axi_req.w.data  <= test_wdata;
          s_axi_req.w.strb  <= test_strb;
          s_axi_req.w_valid <= 1'b1;

          $display("[%0t] AXI-Lite W VALID ASSERTED (BEFORE AW)", $time);

          // ------------------------------------------------------------
          // Wait for W handshake.
          // ------------------------------------------------------------

          timeout = 0;

          while (!w_done) begin

            @(posedge clk);

            if (s_axi_req.w_valid && s_axi_rsp.w_ready) begin

              w_done = 1;

              $display("[%0t] AXI-Lite W HANDSHAKE (W BEFORE AW)", $time);

              timeout = 0;
            end else begin

              timeout++;

              if (timeout > 100) begin
                $error("[%0t] TEST 3 timeout waiting for AXI-Lite W handshake", $time);
                errors++;
                break;
              end

            end

          end

          // ------------------------------------------------------------
          // Deassert W cleanly.
          // ------------------------------------------------------------

          @(negedge clk);

          s_axi_req.w_valid <= 1'b0;

          // ------------------------------------------------------------
          // Deliberately wait before sending AW.
          // ------------------------------------------------------------

          repeat (2) @(negedge clk);

          // ------------------------------------------------------------
          // Drive AW AFTER W.
          // ------------------------------------------------------------

          s_axi_req.aw.addr  <= test_addr;
          s_axi_req.aw.prot  <= 3'b000;
          s_axi_req.aw_valid <= 1'b1;

          $display("[%0t] AXI-Lite AW VALID ASSERTED (AFTER W)", $time);

          // ------------------------------------------------------------
          // Wait for AW handshake.
          // ------------------------------------------------------------

          timeout = 0;

          while (!aw_done) begin

            @(posedge clk);

            if (s_axi_req.aw_valid && s_axi_rsp.aw_ready) begin

              aw_done = 1;

              $display("[%0t] AXI-Lite AW HANDSHAKE (AFTER W)", $time);

              timeout = 0;
            end else begin

              timeout++;

              if (timeout > 100) begin
                $error("[%0t] TEST 3 timeout waiting for AXI-Lite AW handshake", $time);
                errors++;
                break;
              end

            end

          end

          // ------------------------------------------------------------
          // Deassert AW.
          // ------------------------------------------------------------

          @(negedge clk);

          s_axi_req.aw_valid <= 1'b0;

          // ------------------------------------------------------------
          // Wait for B response.
          // ------------------------------------------------------------

          @(negedge clk);

          s_axi_req.b_ready <= 1'b1;

          timeout = 0;

          while (!b_done) begin

            @(posedge clk);

            if (s_axi_rsp.b_valid && s_axi_req.b_ready) begin

              b_done = 1;

              $display("[%0t] AXI-Lite B HANDSHAKE (W BEFORE AW) BRESP=%02b", $time,
                       s_axi_rsp.b.resp);

              check(s_axi_rsp.b.resp == 2'b00, "W-before-AW BRESP == OKAY");

            end else begin

              timeout++;

              if (timeout > 100) begin
                $error("[%0t] TEST 3 timeout waiting for AXI-Lite B response", $time);
                errors++;
                break;
              end

            end

          end

          // ------------------------------------------------------------
          // Deassert BREADY.
          // ------------------------------------------------------------

          @(negedge clk);

          s_axi_req.b_ready <= 1'b0;

        end


        // ====================================================================
        // AXI SLAVE
        // ====================================================================

        begin : AXI_SLAVE_W_FIRST

          axi_write_slave(test_addr, test_wdata, test_strb, 2'b00);

        end

      join

      // ----------------------------------------------------------------------
      // Final transaction check.
      // ----------------------------------------------------------------------

      check(w_done, "W-before-AW W channel completed");

      check(aw_done, "W-before-AW AW channel completed");

      check(b_done, "W-before-AW B channel completed");

      check(w_done && aw_done && b_done, "W-before-AW transaction completed");

      // ----------------------------------------------------------------------
      // Cleanup.
      // ----------------------------------------------------------------------

      @(negedge clk);

      s_axi_req.aw_valid <= 1'b0;
      s_axi_req.w_valid  <= 1'b0;
      s_axi_req.b_ready  <= 1'b0;

      $display("");
      $display("******** TEST 3 COMPLETE ********");

    end

  endtask


  // ==========================================================================
  // TEST 4: AW BEFORE W
  //
  // Explicitly verify the opposite ordering.
  // ==========================================================================

  task automatic test_aw_before_w;

    bit aw_done;
    bit w_done;
    bit b_done;

    int timeout;

    begin

      $display("");
      $display("############################################################");
      $display("# TEST 4: AW BEFORE W");
      $display("############################################################");

      test_addr = 32'h0000_4000;
      test_wdata = 32'hA5A5_5A5A;
      test_strb = 4'b0101;

      aw_done = 0;
      w_done = 0;
      b_done = 0;

      // ----------------------------------------------------------------------
      // Clean up any signals left by previous transaction.
      // ----------------------------------------------------------------------

      @(negedge clk);

      s_axi_req.aw_valid <= 1'b0;
      s_axi_req.w_valid  <= 1'b0;
      s_axi_req.b_ready  <= 1'b0;

      // ----------------------------------------------------------------------
      // Master + AXI slave
      // ----------------------------------------------------------------------

      fork

        // ====================================================================
        // AXI-Lite MASTER
        // ====================================================================

        begin : AXIL_AW_FIRST

          // ------------------------------------------------------------
          // Drive AW FIRST.
          // ------------------------------------------------------------

          @(negedge clk);

          s_axi_req.aw.addr  <= test_addr;
          s_axi_req.aw.prot  <= 3'b000;
          s_axi_req.aw_valid <= 1'b1;

          $display("[%0t] AXI-Lite AW VALID ASSERTED (BEFORE W)", $time);

          // ------------------------------------------------------------
          // Wait for AW handshake.
          // ------------------------------------------------------------

          timeout = 0;

          while (!aw_done) begin

            @(posedge clk);

            if (s_axi_req.aw_valid && s_axi_rsp.aw_ready) begin

              aw_done = 1;

              $display("[%0t] AXI-Lite AW HANDSHAKE (AW BEFORE W)", $time);

              timeout = 0;
            end else begin

              timeout++;

              if (timeout > 100) begin
                $error("[%0t] TEST 4 timeout waiting for AXI-Lite AW handshake", $time);
                errors++;
                break;
              end

            end

          end

          // ------------------------------------------------------------
          // Deassert AW.
          // ------------------------------------------------------------

          @(negedge clk);

          s_axi_req.aw_valid <= 1'b0;

          // ------------------------------------------------------------
          // Deliberately wait before sending W.
          // ------------------------------------------------------------

          repeat (2) @(negedge clk);

          // ------------------------------------------------------------
          // Drive W AFTER AW.
          // ------------------------------------------------------------

          s_axi_req.w.data  <= test_wdata;
          s_axi_req.w.strb  <= test_strb;
          s_axi_req.w_valid <= 1'b1;

          $display("[%0t] AXI-Lite W VALID ASSERTED (AFTER AW)", $time);

          // ------------------------------------------------------------
          // Wait for W handshake.
          // ------------------------------------------------------------

          timeout = 0;

          while (!w_done) begin

            @(posedge clk);

            if (s_axi_req.w_valid && s_axi_rsp.w_ready) begin

              w_done = 1;

              $display("[%0t] AXI-Lite W HANDSHAKE (AFTER AW)", $time);

              timeout = 0;
            end else begin

              timeout++;

              if (timeout > 100) begin
                $error("[%0t] TEST 4 timeout waiting for AXI-Lite W handshake", $time);
                errors++;
                break;
              end

            end

          end

          // ------------------------------------------------------------
          // Deassert W.
          // ------------------------------------------------------------

          @(negedge clk);

          s_axi_req.w_valid <= 1'b0;

          // ------------------------------------------------------------
          // Wait for B response.
          // ------------------------------------------------------------

          @(negedge clk);

          s_axi_req.b_ready <= 1'b1;

          timeout = 0;

          while (!b_done) begin

            @(posedge clk);

            if (s_axi_rsp.b_valid && s_axi_req.b_ready) begin

              b_done = 1;

              $display("[%0t] AXI-Lite B HANDSHAKE (AW BEFORE W) BRESP=%02b", $time,
                       s_axi_rsp.b.resp);

              check(s_axi_rsp.b.resp == 2'b00, "AW-before-W BRESP == OKAY");

            end else begin

              timeout++;

              if (timeout > 100) begin
                $error("[%0t] TEST 4 timeout waiting for AXI-Lite B response", $time);
                errors++;
                break;
              end

            end

          end

          // ------------------------------------------------------------
          // Deassert BREADY.
          // ------------------------------------------------------------

          @(negedge clk);

          s_axi_req.b_ready <= 1'b0;

        end


        // ====================================================================
        // AXI SLAVE
        // ====================================================================

        begin : AXI_SLAVE_AW_FIRST

          axi_write_slave(test_addr, test_wdata, test_strb, 2'b00);

        end

      join

      // ----------------------------------------------------------------------
      // Final transaction check.
      // ----------------------------------------------------------------------

      check(aw_done, "AW-before-W AW channel completed");

      check(w_done, "AW-before-W W channel completed");

      check(b_done, "AW-before-W B channel completed");

      check(aw_done && w_done && b_done, "AW-before-W transaction completed");

      // ----------------------------------------------------------------------
      // Cleanup.
      // ----------------------------------------------------------------------

      @(negedge clk);

      s_axi_req.aw_valid <= 1'b0;
      s_axi_req.w_valid  <= 1'b0;
      s_axi_req.b_ready  <= 1'b0;

      $display("");
      $display("******** TEST 4 COMPLETE ********");

    end

  endtask


  // ==========================================================================
  // TEST 5: PARTIAL WRITE / WSTRB
  // ==========================================================================

  task automatic test_partial_write;

    begin

      $display("");
      $display("############################################################");
      $display("# TEST 5: PARTIAL WRITE / WSTRB");
      $display("############################################################");

      test_addr  = 32'h0000_5000;
      test_wdata = 32'hFACE_B00C;
      test_strb  = 4'b0101;

      fork

        begin
          axil_write(test_addr, test_wdata, test_strb);
        end

        begin
          axi_write_slave(test_addr, test_wdata, test_strb, 2'b00);
        end

      join

      $display("");
      $display("******** TEST 5 COMPLETE ********");

    end

  endtask


  ////////////////////////////////////////////////////////////
  // TEST 6: WRITE ERROR RESPONSE
  ////////////////////////////////////////////////////////////
  
  task test_write_error;
  
      $display("\n############################################################");
      $display("# TEST 6: WRITE ERROR RESPONSE");
      $display("############################################################");
  
      fork
          begin
              // AXI-Lite master write
              axil_write(
                  32'h00006000,
                  32'h11112222,
                  4'hf
              );
          
              $display("[%0t] AXI-Lite WRITE ERROR REQUEST COMPLETE", $time);
          end
        
          begin
              // AXI slave generates error response
              wait(axi_awvalid && axi_awready);
          
              $display("[%0t] AXI AW HANDSHAKE", $time);
              $display("  ID     = 0x%0h", axi_awid);
              $display("  ADDR   = 0x%08h", axi_awaddr);
              $display("  LEN    = %0d", axi_awlen);
              $display("  SIZE   = %0d", axi_awsize);
              $display("  BURST  = %03b", axi_awburst);
          
              check(axi_awaddr == 32'h00006000,
                    "Write-error AXI AWADDR");
          
              wait(axi_wvalid && axi_wready);
          
              $display("[%0t] AXI W HANDSHAKE", $time);
              $display("  DATA = 0x%08h", axi_wdata);
              $display("  STRB = 0x%0h", axi_wstrb);
              $display("  LAST = %0d", axi_wlast);
          
              check(axi_wdata == 32'h11112222,
                    "Write-error AXI WDATA");
          
              check(axi_wstrb == 4'hf,
                    "Write-error AXI WSTRB");
          
              check(axi_wlast == 1'b1,
                    "Write-error AXI WLAST");
          
              // Return AXI SLVERR
              axi_bvalid <= 1'b1;
              axi_bresp  <= 2'b10;
              axi_bid    <= axi_awid;
          
              wait(axi_bready);
          
              $display("[%0t] AXI B HANDSHAKE BRESP=10", $time);
          
              axi_bvalid <= 1'b0;
          
          end
      join
    
    
      wait(axil_bvalid);
    
      $display("[%0t] AXI-Lite B HANDSHAKE BRESP=%02b",
               $time, axil_bresp);
    
      check(axil_bresp == 2'b10,
            "AXI-Lite BRESP propagates SLVERR");
    
    
      check(axil_aw_done,
            "Write-error AW channel completed");
    
      check(axil_w_done,
            "Write-error W channel completed");
    
      check(axil_b_done,
            "Write-error AXI-Lite B channel completed");
    
    
      $display("\n******** TEST 6 COMPLETE ********\n");
    
  endtask
  
  
  
  ////////////////////////////////////////////////////////////
  // TEST 7: READ ERROR RESPONSE
  ////////////////////////////////////////////////////////////
  
  task test_read_error;
  
      logic [31:0] rdata;
  
      $display("\n############################################################");
      $display("# TEST 7: READ ERROR RESPONSE");
      $display("############################################################");
  
  
      // AXI slave response generation
      fork
  
          begin
          
              wait(axi_arvalid && axi_arready);
          
              $display("[%0t] AXI AR HANDSHAKE", $time);
              $display("  ID     = 0x%0h", axi_arid);
              $display("  ADDR   = 0x%08h", axi_araddr);
              $display("  LEN    = %0d", axi_arlen);
              $display("  SIZE   = %0d", axi_arsize);
              $display("  BURST  = %03b", axi_arburst);
          
          
              check(axi_araddr == 32'h00007000,
                    "Read-error AXI ARADDR");
          
          
              // Return AXI SLVERR read response
          
              axi_rvalid <= 1'b1;
              axi_rdata  <= 32'hbad00001;
              axi_rresp  <= 2'b10;
              axi_rlast  <= 1'b1;
              axi_rid    <= axi_arid;
          
          
              wait(axi_rready);
          
          
              $display("[%0t] AXI R HANDSHAKE", $time);
              $display("  DATA = 0x%08h RRESP=%02b",
                       axi_rdata,
                       axi_rresp);
          
          
              axi_rvalid <= 1'b0;
          
          
          end
        
        
          begin
          
              // AXI-Lite read requires address + expected data
              axil_read(
                  32'h00007000,
                  32'hbad00001
              );
          
          end
        
      join
    
    
    
      wait(axil_rvalid);
    
      $display("[%0t] AXI-Lite R HANDSHAKE RRESP=%02b DATA=0x%08h",
               $time,
               axil_rresp,
               axil_rdata);
    
    
      check(axil_rresp == 2'b10,
            "AXI-Lite RRESP propagates SLVERR");
    
    
      check(axil_rdata == 32'hbad00001,
            "Read error test returned expected data");
    
    
      $display("\n******** TEST 7 COMPLETE ********\n");
    
  endtask



  // ==========================================================================
  // TEST 8: BACKPRESSURE ON AXI B CHANNEL
  //
  // Verify bridge holds AXI-Lite B response until BREADY.
  // ==========================================================================

  task automatic test_b_backpressure;

    bit aw_done;
    bit w_done;
    bit b_seen;
    int timeout;

    begin

      $display("");
      $display("############################################################");
      $display("# TEST 8: B CHANNEL BACKPRESSURE");
      $display("############################################################");

      test_addr = 32'h0000_8000;
      test_wdata = 32'h5555_AAAA;
      test_strb = 4'b1111;

      aw_done = 0;
      w_done = 0;
      b_seen = 0;

      fork

        begin : MASTER

          @(negedge clk);

          s_axi_req.aw.addr  <= test_addr;
          s_axi_req.aw.prot  <= 3'b000;
          s_axi_req.aw_valid <= 1'b1;

          s_axi_req.w.data   <= test_wdata;
          s_axi_req.w.strb   <= test_strb;
          s_axi_req.w_valid  <= 1'b1;

          while (!(aw_done && w_done)) begin

            @(posedge clk);

            if (!aw_done && s_axi_req.aw_valid && s_axi_rsp.aw_ready) begin

              aw_done = 1;

              @(negedge clk);
              s_axi_req.aw_valid <= 1'b0;
            end

            if (!w_done && s_axi_req.w_valid && s_axi_rsp.w_ready) begin

              w_done = 1;

              @(negedge clk);
              s_axi_req.w_valid <= 1'b0;
            end

          end

          // Keep BREADY low deliberately.
          @(negedge clk);
          s_axi_req.b_ready <= 1'b0;

          // Wait until DUT produces BVALID.
          timeout = 0;

          while (!s_axi_rsp.b_valid) begin

            @(posedge clk);

            timeout++;

            if (timeout > 100) begin
              $error("[%0t] B backpressure timeout waiting for BVALID", $time);
              errors++;
              break;
            end

          end

          if (s_axi_rsp.b_valid) begin

            $display("[%0t] AXI-Lite BVALID observed while BREADY=0", $time);

            check(s_axi_rsp.b.resp == 2'b00, "B response is OKAY during backpressure");
          end

          // Hold BREADY low for three cycles.
          repeat (3) @(posedge clk);

          check(s_axi_rsp.b_valid == 1'b1, "BVALID remains asserted while BREADY=0");

          // Now accept response.
          @(negedge clk);
          s_axi_req.b_ready <= 1'b1;

          @(posedge clk);

          if (s_axi_rsp.b_valid && s_axi_req.b_ready) begin

            b_seen = 1;

            $display("[%0t] B HANDSHAKE after backpressure", $time);

          end

          @(negedge clk);
          s_axi_req.b_ready <= 1'b0;

        end


        begin : SLAVE

          axi_write_slave(test_addr, test_wdata, test_strb, 2'b00);

        end

      join

      check(b_seen, "B response eventually accepted after backpressure");

      $display("");
      $display("******** TEST 8 COMPLETE ********");

    end

  endtask


  // ==========================================================================
  // TEST 9: BACKPRESSURE ON AXI R CHANNEL
  // ==========================================================================

  task automatic test_r_backpressure;

    logic [DATA_WIDTH-1:0] read_data;

    begin

      $display("");
      $display("############################################################");
      $display("# TEST 9: R CHANNEL BACKPRESSURE");
      $display("############################################################");

      test_addr      = 32'h0000_9000;
      expected_rdata = 32'hFACE_CAFE;

      // The normal axil_read task asserts RREADY as soon as AR completes.
      // For this test we simply exercise the bridge's ability to hold
      // RVALID until AXI-Lite RREADY is asserted.

      fork

        begin : MASTER

          bit ar_done;
          bit r_done;
          int timeout;

          ar_done = 0;
          r_done  = 0;

          @(negedge clk);

          s_axi_req.ar.addr  <= test_addr;
          s_axi_req.ar.prot  <= 3'b000;
          s_axi_req.ar_valid <= 1'b1;

          while (!ar_done) begin

            @(posedge clk);

            if (s_axi_req.ar_valid && s_axi_rsp.ar_ready) begin

              ar_done = 1;

              $display("[%0t] AXI-Lite AR HANDSHAKE", $time);

              @(negedge clk);
              s_axi_req.ar_valid <= 1'b0;
            end

          end

          // Deliberately hold RREADY low.
          @(negedge clk);
          s_axi_req.r_ready <= 1'b0;

          timeout = 0;

          while (!s_axi_rsp.r_valid) begin

            @(posedge clk);

            timeout++;

            if (timeout > 100) begin
              $error("[%0t] R backpressure timeout waiting for RVALID", $time);
              errors++;
              break;
            end

          end

          if (s_axi_rsp.r_valid) begin

            $display("[%0t] AXI-Lite RVALID observed while RREADY=0 DATA=0x%08h", $time,
                     s_axi_rsp.r.data);

            check(s_axi_rsp.r.data == expected_rdata, "RDATA remains stable during backpressure");

            check(s_axi_rsp.r.resp == 2'b00, "RRESP remains OKAY during backpressure");
          end

          repeat (3) @(posedge clk);

          check(s_axi_rsp.r_valid == 1'b1, "RVALID remains asserted while RREADY=0");

          @(negedge clk);
          s_axi_req.r_ready <= 1'b1;

          @(posedge clk);

          if (s_axi_rsp.r_valid && s_axi_req.r_ready) begin

            r_done = 1;

            $display("[%0t] AXI-Lite R HANDSHAKE after backpressure", $time);

          end

          @(negedge clk);
          s_axi_req.r_ready <= 1'b0;

          check(r_done, "R response eventually accepted after backpressure");

        end


        begin : SLAVE

          axi_read_slave(test_addr, expected_rdata, 2'b00);

        end

      join

      $display("");
      $display("******** TEST 9 COMPLETE ********");

    end

  endtask


  // ==========================================================================
  // MAIN TEST
  // ==========================================================================

  initial begin

    $display("");
    $display("==================================================================");
    $display("       AXI-LITE TO AXI BRIDGE VERIFICATION");
    $display("==================================================================");
    $display("");
    $display("DUT : adn_axi_axil_to_axi");
    $display("ID_WIDTH   = %0d", ID_WIDTH);
    $display("ADDR_WIDTH = %0d", ADDR_WIDTH);
    $display("DATA_WIDTH = %0d", DATA_WIDTH);
    $display("USER_WIDTH = %0d", USER_WIDTH);
    $display("");


    // --------------------------------------------------------------
    // Wait for reset.
    // --------------------------------------------------------------

    wait (aresetn == 1'b1);

    repeat (2) @(posedge clk);


    // --------------------------------------------------------------
    // TEST 1
    // --------------------------------------------------------------

    test_normal_write();

    repeat (2) @(posedge clk);


    // --------------------------------------------------------------
    // TEST 2
    // --------------------------------------------------------------

    test_normal_read();

    repeat (2) @(posedge clk);


    // --------------------------------------------------------------
    // TEST 3
    // --------------------------------------------------------------

    test_w_before_aw();

    repeat (2) @(posedge clk);


    // --------------------------------------------------------------
    // TEST 4
    // --------------------------------------------------------------

    test_aw_before_w();

    repeat (2) @(posedge clk);


    // --------------------------------------------------------------
    // TEST 5
    // --------------------------------------------------------------

    test_partial_write();

    repeat (2) @(posedge clk);


    // --------------------------------------------------------------
    // TEST 6
    // --------------------------------------------------------------

    test_write_error();

    repeat (2) @(posedge clk);


    // --------------------------------------------------------------
    // TEST 7
    // --------------------------------------------------------------

    test_read_error();

    repeat (2) @(posedge clk);


    // --------------------------------------------------------------
    // TEST 8
    // --------------------------------------------------------------

    test_b_backpressure();

    repeat (2) @(posedge clk);


    // --------------------------------------------------------------
    // TEST 9
    // --------------------------------------------------------------

    test_r_backpressure();

    repeat (3) @(posedge clk);


    // --------------------------------------------------------------
    // FINAL RESULT
    // --------------------------------------------------------------

    $display("");
    $display("==================================================================");

    if (errors == 0) begin

      $display("                    ALL TESTS PASSED");
      $display("==================================================================");
      $display("");

    end else begin

      $display("                    TEST FAILED");
      $display("                    ERRORS = %0d", errors);
      $display("==================================================================");
      $display("");

    end

    $finish;

  end


  // ==========================================================================
  // GLOBAL TIMEOUT
  // ==========================================================================

  initial begin

    #50_000;

    $error("");
    $error("==================================================================");
    $error("                    GLOBAL TESTBENCH TIMEOUT");
    $error("==================================================================");

    $finish;

  end


  // ==========================================================================
  // WAVEFORM
  // ==========================================================================

  initial begin

    $dumpfile("tb_axi_lite_to_axi.vcd");
    $dumpvars(0, tb_axi_lite_to_axi);

  end

endmodule
