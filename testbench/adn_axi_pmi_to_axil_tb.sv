/*

| TEST CASE | DATE       | AUTHOR                                          | DESCRIPTION                                           |
|-----------|------------|-------------------------------------------------|-------------------------------------------------------|
| TC_001    | 2026-08-25 |Adnan Sami Anirban & Md. Sakib Hasan Shawon      | Basic PMI write to AXI4-Lite                          |
| TC_002    | 2026-08-25 |Adnan Sami Anirban & Md. Sakib Hasan Shawon      | Basic PMI read from AXI4-Lite                         |
| TC_003    | 2026-08-25 |Adnan Sami Anirban & Md. Sakib Hasan Shawon      | PMI write with AXI backpressure                       |
| TC_004    | 2026-08-25 |Adnan Sami Anirban & Md. Sakib Hasan Shawon      | PMI read with AXI backpressure                        |
| TC_005    | 2026-08-25 |Adnan Sami Anirban & Md. Sakib Hasan Shawon      | AXI write response propagation                        |
| TC_006    | 2026-08-25 |Adnan Sami Anirban & Md. Sakib Hasan Shawon      | AXI read response propagation                         |
| TC_007    | 2026-08-25 |Adnan Sami Anirban & Md. Sakib Hasan Shawon      | Write/read response ordering                          |
| TC_008    | 2026-08-25 |Adnan Sami Anirban & Md. Sakib Hasan Shawon      | Wrong AXI response channel blocking                   |
| TC_009    | 2026-08-25 |Adnan Sami Anirban & Md. Sakib Hasan Shawon      | Write byte-strobe propagation                         |
| TC_010    | 2026-08-25 |Adnan Sami Anirban & Md. Sakib Hasan Shawon      | AXI error response propagation                        |


Author : Md. Sakib Hasan Shawon (mdsakibhasanshawon20@gmail.com)
This file is part of ADN-VLSI/adn_axi
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_axi_pmi_to_axil_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"
  `include "axil/typedef.svh"
  `include "pmi/typedef.svh"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int ADDR_WIDTH = 32;
  localparam int DATA_WIDTH = 32;
  `AXIL_T(axil, ADDR_WIDTH, DATA_WIDTH)
  `PMI_T(pmi, ADDR_WIDTH, DATA_WIDTH)
  localparam int OP_FIFO_SIZE = 2;
  localparam time CLK_PERIOD = 10ns;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic      clk_i;
  logic      arst_ni;

  pmi_req_t  pmi_req_i;
  pmi_rsp_t  pmi_rsp_o;

  axil_req_t axil_req_o;
  axil_rsp_t axil_rsp_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // DUT
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_axi_pmi_to_axil #(
      .ADDR_WIDTH  (ADDR_WIDTH  ),
      .DATA_WIDTH  (DATA_WIDTH  ),
      .pmi_req_t   (pmi_req_t   ),
      .pmi_rsp_t   (pmi_rsp_t   ),
      .axil_req_t  (axil_req_t  ),
      .axil_rsp_t  (axil_rsp_t  ),
      .OP_FIFO_SIZE(OP_FIFO_SIZE)
  ) dut (
      .clk_i     (clk_i),
      .arst_ni   (arst_ni),
      .pmi_req_i (pmi_req_i),
      .pmi_rsp_o (pmi_rsp_o),
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

  task automatic pmi_default();

    pmi_req_i.maddr  = '0;
    pmi_req_i.mwe    = 1'b0;
    pmi_req_i.mwdata = '0;
    pmi_req_i.mstrb  = '0;
    pmi_req_i.mreq   = 1'b0;

  endtask

  task automatic axil_default();

    axil_rsp_i.aw_ready = 1'b0;
    axil_rsp_i.w_ready  = 1'b0;
    axil_rsp_i.b.rsp    = 2'b00;
    axil_rsp_i.b_valid  = 1'b0;
    axil_rsp_i.ar_ready = 1'b0;
    axil_rsp_i.r.data   = '0;
    axil_rsp_i.r.rsp    = 2'b00;
    axil_rsp_i.r_valid  = 1'b0;

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RESET
  //////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic apply_reset();

    arst_ni = 1'b0;

    pmi_default();
    axil_default();

    #22;

    arst_ni = 1'b1;

    @(posedge clk_i);

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PMI WRITE
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic pmi_write(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data,
                           input logic [DATA_WIDTH/8-1:0] strb);
    begin
      @(negedge clk_i);

      pmi_req_i.maddr  = addr;
      pmi_req_i.mwe    = 1'b1;
      pmi_req_i.mwdata = data;
      pmi_req_i.mstrb  = strb;
      pmi_req_i.mreq   = 1'b1;

      while (!pmi_rsp_o.mgnt) @(posedge clk_i);

      @(negedge clk_i);
      pmi_req_i.mreq = 1'b0;
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PMI READ
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic pmi_read(input logic [ADDR_WIDTH-1:0] addr);
    begin
      @(negedge clk_i);

      pmi_req_i.maddr  = addr;
      pmi_req_i.mwe    = 1'b0;
      pmi_req_i.mwdata = '0;
      pmi_req_i.mstrb  = '0;
      pmi_req_i.mreq   = 1'b1;

      while (!pmi_rsp_o.mgnt) @(posedge clk_i);

      @(negedge clk_i);
      pmi_req_i.mreq = 1'b0;
    end
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // WAIT FOR PMI ACK
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic wait_pmi_ack(input logic expected_mrsp,
                              input logic [DATA_WIDTH-1:0] expected_data);

    int timeout;
    begin
      timeout = 0;
      while (!pmi_rsp_o.mack) begin
        @(posedge clk_i);
        timeout++;

        if (timeout > 100) begin
          $error("[%0t] Timeout waiting for PMI MACK", $time);
          return;
        end
      end

      if (pmi_rsp_o.mrsp !== expected_mrsp) begin
        $error("[%0t] PMI MRSP mismatch: expected=%0b actual=%0b", $time, expected_mrsp,
               pmi_rsp_o.mrsp);
      end

      if (!expected_mrsp) begin
        if (pmi_rsp_o.mrdata !== expected_data) begin
          $error("[%0t] PMI MRDATA mismatch: expected=0x%08h actual=0x%08h", $time, expected_data,
                 pmi_rsp_o.mrdata);
        end
      end
    end
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // WAIT FOR AXI WRITE REQUEST
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic wait_axi_write(input logic [ADDR_WIDTH-1:0] expected_addr,
                                input logic [DATA_WIDTH-1:0] expected_data,
                                input logic [DATA_WIDTH/8-1:0] expected_strb);
    int timeout;
    begin
      timeout = 0;
      while (!(axil_req_o.aw_valid && axil_req_o.w_valid)) begin
        @(posedge clk_i);
        timeout++;

        if (timeout > 100) begin
          $error("[%0t] Timeout waiting for AXI write request", $time);
          return;
        end
      end

      if (axil_req_o.aw.addr !== expected_addr) begin
        $error("[%0t] AXI AWADDR mismatch: expected=0x%08h actual=0x%08h", $time, expected_addr,
               axil_req_o.aw.addr);
      end

      if (axil_req_o.w.data !== expected_data) begin
        $error("[%0t] AXI WDATA mismatch: expected=0x%08h actual=0x%08h", $time, expected_data,
               axil_req_o.w.data);
      end

      if (axil_req_o.w.strb !== expected_strb) begin
        $error("[%0t] AXI WSTRB mismatch: expected=%0h actual=%0h", $time, expected_strb,
               axil_req_o.w.strb);
      end

      if (axil_req_o.aw.prot !== 3'b000) begin
        $error("[%0t] AXI AWPROT mismatch: expected=000 actual=%b", $time, axil_req_o.aw.prot);
      end
    end
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // WAIT FOR AXI READ REQUEST
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic wait_axi_read(input logic [ADDR_WIDTH-1:0] expected_addr);

    int timeout;
    begin
      timeout = 0;
      while (!axil_req_o.ar_valid) begin
        @(posedge clk_i);
        timeout++;

        if (timeout > 100) begin
          $error("[%0t] Timeout waiting for AXI read request", $time);
          return;
        end
      end

      if (axil_req_o.ar.addr !== expected_addr) begin
        $error("[%0t] AXI ARADDR mismatch: expected=0x%08h actual=0x%08h", $time, expected_addr,
               axil_req_o.ar.addr);
      end

      if (axil_req_o.ar.prot !== 3'b000) begin
        $error("[%0t] AXI ARPROT mismatch: expected=000 actual=%b", $time, axil_req_o.ar.prot);
      end
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // AXI WRITE RESPONSE
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic axi_write_response(input logic [1:0] rsp);

    begin
      while (!axil_req_o.b_ready) @(posedge clk_i);
      @(negedge clk_i);

      axil_rsp_i.b.rsp   = rsp;
      axil_rsp_i.b_valid = 1'b1;

      @(posedge clk_i);

      // ------------------------------------------------------------
      // AXI B handshake and PMI MACK happen on this cycle.
      // ------------------------------------------------------------

      if (!axil_req_o.b_ready) begin
        $error("[%0t] AXI BREADY not asserted during BVALID", $time);
      end

      if (!pmi_rsp_o.mack) begin
        $error("[%0t] PMI MACK not asserted for AXI write response", $time);
      end

      if (pmi_rsp_o.mrsp !== rsp[1]) begin
        $error("[%0t] PMI MRSP mismatch: expected=%0b actual=%0b", $time, rsp[1], pmi_rsp_o.mrsp);
      end

      @(negedge clk_i);

      axil_rsp_i.b_valid = 1'b0;
      axil_rsp_i.b.rsp   = 2'b00;
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // AXI READ RESPONSE
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic axi_read_response(input logic [DATA_WIDTH-1:0] data, input logic [1:0] rsp);

    begin
      while (!axil_req_o.r_ready) @(posedge clk_i);
      @(negedge clk_i);

      axil_rsp_i.r.data  = data;
      axil_rsp_i.r.rsp   = rsp;
      axil_rsp_i.r_valid = 1'b1;

      @(posedge clk_i);

      // ------------------------------------------------------------
      // AXI R handshake and PMI MACK happen on this cycle.
      // ------------------------------------------------------------

      if (!axil_req_o.r_ready) begin
        $error("[%0t] AXI RREADY not asserted during RVALID", $time);
      end

      if (!pmi_rsp_o.mack) begin
        $error("[%0t] PMI MACK not asserted for AXI read response", $time);
      end

      if (pmi_rsp_o.mrsp !== rsp[1]) begin
        $error("[%0t] PMI MRSP mismatch: expected=%0b actual=%0b", $time, rsp[1], pmi_rsp_o.mrsp);
      end

      if (pmi_rsp_o.mrdata !== data) begin
        $error("[%0t] PMI MRDATA mismatch: expected=0x%08h actual=0x%08h", $time, data,
               pmi_rsp_o.mrdata);
      end

      @(negedge clk_i);

      axil_rsp_i.r_valid = 1'b0;
      axil_rsp_i.r.data  = '0;
      axil_rsp_i.r.rsp   = 2'b00;
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_001
  //
  // Basic PMI WRITE
  //
  // PMI:
  //   mreq = 1
  //   mwe  = 1
  //
  // Expected:
  //   AXI AWVALID = 1
  //   AXI WVALID  = 1
  //
  // Then:
  //   AXI BVALID
  //   PMI MACK
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_001_basic_write();

    begin
      note_case(1);
      $display("\nTC_001: BASIC WRITE");

      axil_rsp_i.aw_ready = 1'b1;
      axil_rsp_i.w_ready  = 1'b1;

      fork
        begin
          pmi_write(32'h0000_1000, 32'hDEAD_BEEF, 4'b1111);
        end


        begin
          wait_axi_write(32'h0000_1000, 32'hDEAD_BEEF, 4'b1111);
          axi_write_response(2'b00);
        end
      join

      $display("TC_001 PASS");
    end
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_002
  //
  // Basic PMI READ
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_002_basic_read();
    begin
      note_case(1);
      $display("\nTC_002: BASIC READ");

      axil_rsp_i.ar_ready = 1'b1;

      fork
        begin
          pmi_read(32'h0000_2000);
        end

        begin
          wait_axi_read(32'h0000_2000);
          axi_read_response(32'h1234_5678, 2'b00);
        end
      join

      $display("TC_002 PASS");
    end
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_003
  //
  // WRITE BACKPRESSURE
  //
  // AXI AWREADY/WREADY initially low.
  //
  // Therefore:
  //   PMI MGNT = 0
  //   AWVALID  = 0
  //   WVALID   = 0
  //
  // Once both ready signals become high, request proceeds.
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_003_write_backpressure();

    begin
      note_case(1);
      $display("\nTC_003: WRITE BACKPRESSURE");

      axil_rsp_i.aw_ready = 1'b0;
      axil_rsp_i.w_ready  = 1'b0;

      fork
        begin
          pmi_req_i.maddr  = 32'h0000_3000;
          pmi_req_i.mwe    = 1'b1;
          pmi_req_i.mwdata = 32'hAAAA_5555;
          pmi_req_i.mstrb  = 4'b1111;
          pmi_req_i.mreq   = 1'b1;

          repeat (3) begin
            @(posedge clk_i);
            if (pmi_rsp_o.mgnt !== 1'b0) $error("TC_003: PMI request granted during backpressure");
            if (axil_req_o.aw_valid !== 1'b0)
              $error("TC_003: AWVALID asserted during backpressure");
            if (axil_req_o.w_valid !== 1'b0) $error("TC_003: WVALID asserted during backpressure");
          end

          @(negedge clk_i);

          axil_rsp_i.aw_ready = 1'b1;
          axil_rsp_i.w_ready  = 1'b1;

          @(posedge clk_i);
          if (!pmi_rsp_o.mgnt) $error("TC_003: PMI request not granted after ready");

          @(negedge clk_i);

          pmi_req_i.mreq = 1'b0;
        end


        begin
          wait_axi_write(32'h0000_3000, 32'hAAAA_5555, 4'b1111);
          axi_write_response(2'b00);
        end
      join

      $display("TC_003 PASS");
    end
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_004
  //
  // READ BACKPRESSURE
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_004_read_backpressure();

    begin
      note_case(1);
      $display("\nTC_004: READ BACKPRESSURE");

      axil_rsp_i.ar_ready = 1'b0;

      fork
        begin
          pmi_req_i.maddr = 32'h0000_4000;
          pmi_req_i.mwe   = 1'b0;
          pmi_req_i.mreq  = 1'b1;

          repeat (3) begin
            @(posedge clk_i);
            if (pmi_rsp_o.mgnt !== 1'b0) $error("TC_004: PMI request granted during backpressure");
            if (axil_req_o.ar_valid !== 1'b0)
              $error("TC_004: ARVALID asserted during backpressure");
          end

          @(negedge clk_i);

          axil_rsp_i.ar_ready = 1'b1;

          @(posedge clk_i);
          if (!pmi_rsp_o.mgnt) $error("TC_004: PMI request not granted after ARREADY");

          @(negedge clk_i);
          pmi_req_i.mreq = 1'b0;
        end

        begin
          wait_axi_read(32'h0000_4000);
          axi_read_response(32'hCAFE_BABE, 2'b00);
        end
      join

      $display("TC_004 PASS");
    end
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_005
  //
  // WRITE RESPONSE PROPAGATION
  //
  // AXI BRESP[1] -> PMI MRSP
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_005_write_response();

    begin
      note_case(1);
      $display("\nTC_005: WRITE RESPONSE");

      axil_rsp_i.aw_ready = 1'b1;
      axil_rsp_i.w_ready  = 1'b1;

      fork
        begin
          pmi_write(32'h0000_5000, 32'h1111_2222, 4'b1111);
        end

        begin
          wait_axi_write(32'h0000_5000, 32'h1111_2222, 4'b1111);
          axi_write_response(2'b00);
        end
      join

      if (pmi_rsp_o.mrdata !== '0) $error("TC_005: Write response returned non-zero MRDATA");
      $display("TC_005 PASS");
    end
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_006
  //
  // READ RESPONSE PROPAGATION
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_006_read_response();

    begin
      note_case(1);
      $display("\nTC_006: READ RESPONSE");

      axil_rsp_i.ar_ready = 1'b1;

      fork
        begin
          pmi_read(32'h0000_6000);
        end

        begin
          wait_axi_read(32'h0000_6000);
          axi_read_response(32'hFACE_1234, 2'b00);
        end
      join

      $display("TC_006 PASS");
    end
  endtask


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_007
  //
  // WRITE -> READ RESPONSE ORDERING
  //
  // First outstanding operation is WRITE.
  // Therefore:
  //
  //   BREADY = 1
  //   RREADY = 0
  //
  // After B response:
  //
  //   BREADY = 0
  //   RREADY = 1
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_007_response_ordering();

    begin
      note_case(1);
      $display("\nTC_007: RESPONSE ORDERING");

      axil_rsp_i.aw_ready = 1'b1;
      axil_rsp_i.w_ready  = 1'b1;
      axil_rsp_i.ar_ready = 1'b1;

      // ----------------------------------------------------------------------
      // WRITE
      // ----------------------------------------------------------------------

      pmi_req_i.maddr  = 32'h0000_7000;
      pmi_req_i.mwe    = 1'b1;
      pmi_req_i.mwdata = 32'h1111_1111;
      pmi_req_i.mstrb  = 4'b1111;
      pmi_req_i.mreq   = 1'b1;

      @(posedge clk_i);

      if (!pmi_rsp_o.mgnt) $error("TC_007: WRITE was not granted");

      @(negedge clk_i);
      pmi_req_i.mreq  = 1'b0;

      // ----------------------------------------------------------------------
      // READ
      // ----------------------------------------------------------------------

      pmi_req_i.maddr = 32'h0000_8000;
      pmi_req_i.mwe   = 1'b0;
      pmi_req_i.mreq  = 1'b1;

      @(posedge clk_i);

      if (!pmi_rsp_o.mgnt) $error("TC_007: READ was not granted");

      @(negedge clk_i);

      pmi_req_i.mreq = 1'b0;

      // ----------------------------------------------------------------------
      // WRITE must be at response head.
      // ----------------------------------------------------------------------

      @(posedge clk_i);

      if (!axil_req_o.b_ready) $error("TC_007: BREADY should be asserted");
      if (axil_req_o.r_ready) $error("TC_007: RREADY should not be asserted");

      // ----------------------------------------------------------------------
      // Send WRITE response.
      // ----------------------------------------------------------------------

      @(negedge clk_i);

      axil_rsp_i.b_valid = 1'b1;
      axil_rsp_i.b.rsp   = 2'b00;

      @(posedge clk_i);

      if (!pmi_rsp_o.mack) $error("TC_007: WRITE MACK missing");

      @(negedge clk_i);

      axil_rsp_i.b_valid = 1'b0;

      // ----------------------------------------------------------------------
      // READ should now be at response head.
      // ----------------------------------------------------------------------

      @(posedge clk_i);

      if (axil_req_o.b_ready) $error("TC_007: BREADY should be deasserted");
      if (!axil_req_o.r_ready) $error("TC_007: RREADY should be asserted");

      // ----------------------------------------------------------------------
      // Send READ response.
      // ----------------------------------------------------------------------

      @(negedge clk_i);

      axil_rsp_i.r_valid = 1'b1;
      axil_rsp_i.r.data  = 32'h2222_2222;
      axil_rsp_i.r.rsp   = 2'b00;

      @(posedge clk_i);

      if (!pmi_rsp_o.mack) $error("TC_007: READ MACK missing");
      if (pmi_rsp_o.mrdata !== 32'h2222_2222) $error("TC_007: READ data mismatch");

      @(negedge clk_i);
      axil_rsp_i.r_valid = 1'b0;
      $display("TC_007 PASS");
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_008
  //
  // WRONG RESPONSE CHANNEL
  //
  // Outstanding WRITE must ignore RVALID.
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_008_wrong_response_channel();

    begin
      note_case(1);
      $display("\nTC_008: WRONG RESPONSE CHANNEL");

      axil_rsp_i.aw_ready = 1'b1;
      axil_rsp_i.w_ready  = 1'b1;

      pmi_req_i.maddr  = 32'h0000_9000;
      pmi_req_i.mwe    = 1'b1;
      pmi_req_i.mwdata = 32'hAAAA_BBBB;
      pmi_req_i.mstrb  = 4'b1111;
      pmi_req_i.mreq   = 1'b1;

      @(posedge clk_i);

      @(negedge clk_i);
      pmi_req_i.mreq = 1'b0;

      // Wait until WRITE is outstanding.
      repeat (2) @(posedge clk_i);

      if (!axil_req_o.b_ready) $error("TC_008: BREADY should be asserted");
      if (axil_req_o.r_ready) $error("TC_008: RREADY should be low");

      // ----------------------------------------------------------------------
      // Give an R response even though operation is WRITE.
      // ----------------------------------------------------------------------

      @(negedge clk_i);

      axil_rsp_i.r_valid = 1'b1;
      axil_rsp_i.r.data  = 32'hDEAD_BEEF;
      axil_rsp_i.r.rsp   = 2'b00;

      @(posedge clk_i);

      if (pmi_rsp_o.mack) $error("TC_008: WRITE incorrectly completed from R response");

      @(negedge clk_i);

      axil_rsp_i.r_valid = 1'b0;

      // ----------------------------------------------------------------------
      // Now give the correct B response.
      // ----------------------------------------------------------------------

      axi_write_response(2'b00);
      $display("TC_008 PASS");
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_009
  //
  // WRITE STROBE PROPAGATION
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_009_write_strobe();

    begin
      note_case(1);
      $display("\nTC_009: WRITE STROBE");

      axil_rsp_i.aw_ready = 1'b1;
      axil_rsp_i.w_ready  = 1'b1;

      fork
        begin
          pmi_write(32'h0000_A000, 32'h1234_5678, 4'b0101);
        end

        begin
          wait_axi_write(32'h0000_A000, 32'h1234_5678, 4'b0101);
          axi_write_response(2'b00);
        end
      join

      $display("TC_009 PASS");
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TC_010
  //
  // AXI ERROR RESPONSE
  //
  // AXI:
  //   2'b10 = SLVERR
  //
  // DUT:
  //   mrsp = rsp[1] = 1
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic tc_010_error_response();

    begin
      note_case(1);
      $display("\nTC_010: AXI ERROR RESPONSE");

      axil_rsp_i.aw_ready = 1'b1;
      axil_rsp_i.w_ready  = 1'b1;

      fork
        begin
          pmi_write(32'h0000_B000, 32'hCAFE_BABE, 4'b1111);
        end

        begin
          wait_axi_write(32'h0000_B000, 32'hCAFE_BABE, 4'b1111);
          axi_write_response(2'b10);
        end
      join

      $display("TC_010 PASS");
    end
  endtask

  task automatic tc_all();
    tc_001_basic_write();
    tc_002_basic_read();
    tc_003_write_backpressure();
    tc_004_read_backpressure();
    tc_005_write_response();
    tc_006_read_response();
    tc_007_response_ordering();
    tc_008_wrong_response_channel();
    tc_009_write_strobe();
    tc_010_error_response();
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // MAIN INITIAL
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin

    pmi_default();
    axil_default();

    arst_ni = 1'b0;

    apply_reset();

    case(test_name)
    "TC_ALL":tc_all();
    "TC_001", "basic_write"            : tc_001_basic_write();
    "TC_002", "basic_read"             : tc_002_basic_read();
    "TC_003", "write_backpressure"     : tc_003_write_backpressure();
    "TC_004", "read_backpressure"      : tc_004_read_backpressure();
    "TC_005", "write_response"         : tc_005_write_response();
    "TC_006", "read_response"          : tc_006_read_response();
    "TC_007", "response_ordering"      : tc_007_response_ordering();
    "TC_008", "wrong_response_channel" : tc_008_wrong_response_channel();
    "TC_009", "write_strobe"           : tc_009_write_strobe();
    "TC_010", "error_response"         : tc_010_error_response();
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
