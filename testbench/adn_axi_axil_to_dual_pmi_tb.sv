/*

| TEST CASE | DATE       | AUTHOR                     | DESCRIPTION                               |
|-----------|------------|----------------------------|--------------------------------------------|
| TC_001    | 2026-08-23 | Md Sakhawat Hossain Sabbir | Basic AXI4-Lite write transaction         |
| TC_002    | 2026-08-23 | Md Sakhawat Hossain Sabbir | Basic AXI4-Lite read transaction          |
| TC_003    | 2026-08-23 | Md Sakhawat Hossain Sabbir | Simultaneous AW and W handshake           |
| TC_004    | 2026-08-23 | Md Sakhawat Hossain Sabbir | AXI write-response backpressure           |
| TC_005    | 2026-08-23 | Md Sakhawat Hossain Sabbir | AXI read-response backpressure            |
| TC_006    | 2026-08-23 | Md Sakhawat Hossain Sabbir | PMI write grant delay                     |
| TC_007    | 2026-08-23 | Md Sakhawat Hossain Sabbir | PMI read grant delay                      |
| TC_008    | 2026-08-23 | Md Sakhawat Hossain Sabbir | PMI write acknowledge delay               |
| TC_009    | 2026-08-23 | Md Sakhawat Hossain Sabbir | PMI read acknowledge delay                |
| TC_010    | 2026-08-23 | Md Sakhawat Hossain Sabbir | Successful AXI write response             |
| TC_011    | 2026-08-23 | Shykul Islam Siam          | AXI write error response                  |
| TC_012    | 2026-08-23 | Shykul Islam Siam          | Successful AXI read response              |
| TC_013    | 2026-08-23 | Shykul Islam Siam          | AXI read error response                   |
| TC_014    | 2026-08-23 | Shykul Islam Siam          | Multiple outstanding write transactions   |
| TC_015    | 2026-08-23 | Shykul Islam Siam          | Multiple outstanding read transactions    |
| TC_016    | 2026-08-23 | Shykul Islam Siam          | Maximum pipeline-depth write transactions |
| TC_017    | 2026-08-23 | Shykul Islam Siam          | Simultaneous read and write activity      |
| TC_018    | 2026-08-23 | Shykul Islam Siam          | Reset idle-state behavior                 |
| TC_019    | 2026-08-23 | Shykul Islam Siam          | Reset during pending write transaction    |
| TC_020    | 2026-08-23 | Shykul Islam Siam          | Reset during pending read transaction     |
| TC_021    | 2026-08-23 | Shykul Islam Siam          | Randomized read/write stress testing      |

| REVISION | DATE       | AUTHOR                     | DESCRIPTION                |
|----------|------------|----------------------------|-----------------------------|
| 0.1      | 2026-08-23 | Md Sakhawat Hossain Sabbir | Initial testbench version   |
| 1.0      | 2026-08-23 | Shykul Islam Siam          | Stable release               |

Author : Shykul Islam Siam (shykulislam32@gmail.com) & Md Sakhawat Hossain Sabbir (sabbirone939@gmail.com)
This file is part of ADN-VLSI/adn_common
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_axi_axil_to_dual_pmi_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"  // test_name, test_count, debug, note_case()
  `include "axil/typedef.svh"              // AXI4-Lite typedef macros
  `include "pmi/typedef.svh"               // PMI typedef macros (PMI_REQ_T/PMI_RSP_T/PMI_T)

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  localparam int ADDR_WIDTH     = 32;                      // AXI/PMI address width
  localparam int DATA_WIDTH     = 32;                      // AXI/PMI data width
  localparam int PIPELINE_DEPTH = 8;                       // max outstanding transactions
  localparam int FIFO_SIZE      = $clog2(PIPELINE_DEPTH);  // internal FIFO pointer width
  localparam int HANDSHAKE_TIMEOUT_CYCLES = 100;            // cycles before WAIT_OR_TIMEOUT fires

  localparam logic [1:0] OKAY  = 2'b00;  // AXI4-Lite OKAY response
  localparam logic [1:0] ERROR = 2'b10;  // AXI4-Lite ERROR (SLVERR) response

  `AXIL_REQ_T(axil, ADDR_WIDTH, DATA_WIDTH)  // defines axil_req_t
  `AXIL_RSP_T(axil, DATA_WIDTH)              // defines axil_rsp_t

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  `PMI_T(pmi, ADDR_WIDTH, DATA_WIDTH)  // defines pmi_req_t (maddr/mwe/mwdata/mstrb/mreq)
                                       // and pmi_rsp_t (mgnt/mack/mrdata/mrsp)

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  logic      clk_i;                // testbench clock
  logic      arst_ni;              // active-low async reset
  axil_req_t axil_req_i;           // AXI4-Lite request into the DUT
  axil_rsp_t axil_rsp_o;           // AXI4-Lite response from the DUT
  pmi_req_t  pmi_req_wr_o;         // PMI write channel: DUT -> memory model
  pmi_rsp_t  pmi_rsp_wr_i;         // PMI write channel: memory model -> DUT
  pmi_req_t  pmi_req_rd_o;         // PMI read channel: DUT -> memory model
  pmi_rsp_t  pmi_rsp_rd_i;         // PMI read channel: memory model -> DUT

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  adn_axi_axil_to_dual_pmi #(
      .axil_req_t    (axil_req_t),      // AXI4-Lite request struct type
      .axil_rsp_t    (axil_rsp_t),      // AXI4-Lite response struct type
      .pmi_req_t     (pmi_req_t),       // PMI request struct type
      .pmi_rsp_t     (pmi_rsp_t),       // PMI response struct type
      .PIPELINE_DEPTH(PIPELINE_DEPTH),  // max outstanding transactions
      .FIFO_SIZE     (FIFO_SIZE)        // internal FIFO pointer width
  ) dut (
      .clk_i       (clk_i),          // clock
      .arst_ni     (arst_ni),        // active-low reset
      .axil_req_i  (axil_req_i),     // AXI4-Lite request in
      .axil_rsp_o  (axil_rsp_o),     // AXI4-Lite response out
      .pmi_req_wr_o(pmi_req_wr_o),   // PMI write request out
      .pmi_rsp_wr_i(pmi_rsp_wr_i),   // PMI write response in
      .pmi_req_rd_o(pmi_req_rd_o),   // PMI read request out
      .pmi_rsp_rd_i(pmi_rsp_rd_i)    // PMI read response in
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `define WAIT_OR_TIMEOUT(COND, MSG) \
    begin \
      int __timeout__; \
      __timeout__ = 0; \
      while (!(COND)) begin              /* poll each cycle */ \
        @(posedge clk_i); \
        __timeout__++; \
        if (__timeout__ >= HANDSHAKE_TIMEOUT_CYCLES) \
          $fatal(1, "Timeout waiting for %s", MSG); \
      end \
    end

  task automatic apply_reset();  // drive reset, clear req/rsp, release sync
    arst_ni      = 1'b0;               // assert reset
    axil_req_i   = '0;                 // clear AXI request bus
    pmi_rsp_wr_i = '0;                 // clear PMI write response
    pmi_rsp_rd_i = '0;                 // clear PMI read response
    repeat (4) @(posedge clk_i);       // hold reset a few cycles
    @(negedge clk_i);                  // release on a negedge to avoid races
    arst_ni = 1'b1;                    // deassert reset
    @(posedge clk_i);                  // let DUT come out of reset
  endtask

  // drive AW+W together and wait for the address/data handshake to complete
  task automatic axi_write_issue(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data,
                                  input logic [DATA_WIDTH/8-1:0] strb);
    @(negedge clk_i);                               // set up on negedge, sample on posedge
    axil_req_i.aw.addr  = addr;                     // write address
    axil_req_i.aw.prot  = '0;                       // unused protection field
    axil_req_i.aw_valid = 1'b1;                     // assert AW valid
    axil_req_i.w.data   = data;                     // write data
    axil_req_i.w.strb   = strb;                     // byte strobes
    axil_req_i.w_valid  = 1'b1;                     // assert W valid
    `WAIT_OR_TIMEOUT(axil_rsp_o.aw_ready && axil_rsp_o.w_ready, "aw_ready && w_ready (axi_write_issue)")
    @(negedge clk_i);                               // handshake done, drop valids
    axil_req_i.aw_valid = 1'b0;
    axil_req_i.w_valid  = 1'b0;
  endtask

  // release b_ready and check the write response against the expected code
  task automatic axi_write_wait_response(input logic [1:0] expected_rsp);
    axil_req_i.b_ready = 1'b1;                       // ready to accept the B response
    `WAIT_OR_TIMEOUT(axil_rsp_o.b_valid, "b_valid (axi_write_wait_response)")
    note_case(axil_rsp_o.b.rsp == expected_rsp);      // record pass/fail
    if (debug) $display("[%0t] WRITE rsp=%b expected=%b", $time, axil_rsp_o.b.rsp, expected_rsp);
    @(negedge clk_i);
    axil_req_i.b_ready = 1'b0;                        // drop ready
  endtask

  // issue an AXI write and wait for its response in one call
  task automatic axi_write(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data,
                            input logic [DATA_WIDTH/8-1:0] strb, input logic [1:0] expected_rsp);
    axi_write_issue(addr, data, strb);                // address/data phase
    axi_write_wait_response(expected_rsp);            // response phase
  endtask

  // drive AR and wait for the address handshake to complete
  task automatic axi_read_issue(input logic [ADDR_WIDTH-1:0] addr);
    @(negedge clk_i);
    axil_req_i.ar.addr  = addr;                       // read address
    axil_req_i.ar.prot  = '0;                         // unused protection field
    axil_req_i.ar_valid = 1'b1;                       // assert AR valid
    `WAIT_OR_TIMEOUT(axil_rsp_o.ar_ready, "ar_ready (axi_read_issue)")
    @(negedge clk_i);                                 // handshake done, drop valid
    axil_req_i.ar_valid = 1'b0;
  endtask

  // release r_ready and check the read data and response code
  task automatic axi_read_wait_response(input logic [DATA_WIDTH-1:0] expected_data, input logic [1:0] expected_rsp);
    axil_req_i.r_ready = 1'b1;                        // ready to accept the R response
    `WAIT_OR_TIMEOUT(axil_rsp_o.r_valid, "r_valid (axi_read_wait_response)")
    note_case((axil_rsp_o.r.data == expected_data) && (axil_rsp_o.r.rsp == expected_rsp));  // pass/fail
    if (debug)
      $display("[%0t] READ data=%h expected=%h rsp=%b expected=%b", $time, axil_rsp_o.r.data,
                expected_data, axil_rsp_o.r.rsp, expected_rsp);
    @(negedge clk_i);
    axil_req_i.r_ready = 1'b0;                        // drop ready
  endtask

  // issue an AXI read and wait for its response in one call
  task automatic axi_read(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] expected_data,
                           input logic [1:0] expected_rsp);
    axi_read_issue(addr);                             // address phase
    axi_read_wait_response(expected_data, expected_rsp);  // response phase
  endtask

  // model the PMI write side: grant then acknowledge, with independent delays
  task automatic pmi_write_response(input int mgnt_delay, input int mack_delay, input logic error);
    repeat (mgnt_delay) @(posedge clk_i);             // model grant latency
    pmi_rsp_wr_i.mgnt = 1'b1;                         // assert grant
    `WAIT_OR_TIMEOUT(pmi_req_wr_o.mreq, "pmi_req_wr_o.mreq")
    @(posedge clk_i);
    pmi_rsp_wr_i.mgnt = 1'b0;                         // drop grant
    repeat (mack_delay) @(posedge clk_i);             // model ack latency
    pmi_rsp_wr_i.mrsp = error;                        // 1 = simulate error response
    pmi_rsp_wr_i.mack = 1'b1;                         // assert acknowledge
    @(posedge clk_i);
    pmi_rsp_wr_i.mack = 1'b0;                         // drop ack
    pmi_rsp_wr_i.mrsp = 1'b0;                         // clear error flag
  endtask

  // model the PMI read side: grant then acknowledge, supplying read data
  task automatic pmi_read_response(input logic [DATA_WIDTH-1:0] data, input int mgnt_delay,
                                    input int mack_delay, input logic error);
    repeat (mgnt_delay) @(posedge clk_i);             // model grant latency
    pmi_rsp_rd_i.mgnt = 1'b1;                         // assert grant
    `WAIT_OR_TIMEOUT(pmi_req_rd_o.mreq, "pmi_req_rd_o.mreq")
    @(posedge clk_i);
    pmi_rsp_rd_i.mgnt = 1'b0;                         // drop grant
    repeat (mack_delay) @(posedge clk_i);             // model ack latency
    pmi_rsp_rd_i.mrdata = data;                       // supply read data
    pmi_rsp_rd_i.mrsp   = error;                      // 1 = simulate error response
    pmi_rsp_rd_i.mack   = 1'b1;                       // assert acknowledge
    @(posedge clk_i);
    pmi_rsp_rd_i.mack   = 1'b0;                       // drop ack
    pmi_rsp_rd_i.mrsp   = 1'b0;                       // clear error flag
    pmi_rsp_rd_i.mrdata = '0;                         // clear read data
  endtask

  initial clk_i = 1'b0;              // start low
  always #5ns clk_i = ~clk_i;        // free-running toggle, 100 MHz

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TEST CASES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // tc_001 : basic AXI4-Lite write transaction
  task automatic tc_001_basic_write();
    apply_reset();
    fork
      axi_write(32'h0000_1000, 32'hA5A5_5A5A, 4'b1111, OKAY);  // AXI-side write
      pmi_write_response(0, 0, 1'b0);                          // memory-side completion
    join
  endtask

  // tc_002 : basic AXI4-Lite read transaction
  task automatic tc_002_basic_read();
    apply_reset();
    fork
      axi_read(32'h0000_2000, 32'h1234_5678, OKAY);   // AXI-side read
      pmi_read_response(32'h1234_5678, 0, 0, 1'b0);    // memory-side completion
    join
  endtask

  // tc_003 : AW and W accepted on the same cycle
  task automatic tc_003_aw_w_same_cycle();
    apply_reset();
    fork
      axi_write(32'h1000_0000, 32'h1111_2222, 4'b1111, OKAY);
      pmi_write_response(0, 0, 1'b0);
    join
  endtask

  // tc_004 : B-channel backpressure - response must stay pending while b_ready is low
  task automatic tc_004_b_backpressure();
    apply_reset();
    axil_req_i.b_ready = 1'b0;  // hold B channel back before issuing

    fork
      begin
        pmi_write_response(0, 0, 1'b0);  // memory-side completion
      end
      begin
        axi_write_issue(32'h2000_0000, 32'hAAAA_BBBB, 4'b1111);  // AW/W phase only
      end
    join

    repeat (4) begin                     // response must stay pending while low
      @(posedge clk_i);
      note_case(!axil_rsp_o.b_valid);
    end

    axil_req_i.b_ready = 1'b1;           // release backpressure, verify response
    @(posedge clk_i);
    note_case(axil_rsp_o.b_valid && (axil_rsp_o.b.rsp == OKAY));
    axil_req_i.b_ready = 1'b0;
  endtask

  // tc_005 : R-channel backpressure - response must stay pending while r_ready is low
  task automatic tc_005_r_backpressure();
    apply_reset();
    axil_req_i.r_ready = 1'b0;  // hold R channel back before issuing

    fork
      begin
        pmi_read_response(32'hCAFE_BABE, 0, 0, 1'b0);  // memory-side completion
      end
      begin
        axi_read_issue(32'h3000_0000);                  // AR phase
        repeat (2) @(posedge clk_i);                    // let response sit pending
        axil_req_i.r_ready = 1'b1;                       // release backpressure
        `WAIT_OR_TIMEOUT(axil_rsp_o.r_valid, "r_valid (tc_005_r_backpressure)")
        note_case(axil_rsp_o.r.data == 32'hCAFE_BABE);   // record pass/fail
        @(posedge clk_i);
        axil_req_i.r_ready = 1'b0;
      end
    join
  endtask

  // tc_006 : PMI write grant delay
  task automatic tc_006_write_mgnt_delay();
    apply_reset();
    fork
      axi_write(32'h4000_0000, 32'h1111_1111, 4'b1111, OKAY);
      pmi_write_response(5, 0, 1'b0);  // 5-cycle grant delay
    join
  endtask

  // tc_007 : PMI read grant delay
  task automatic tc_007_read_mgnt_delay();
    apply_reset();
    fork
      axi_read(32'h5000_0000, 32'h2222_2222, OKAY);
      pmi_read_response(32'h2222_2222, 5, 0, 1'b0);  // 5-cycle grant delay
    join
  endtask

  // tc_008 : PMI write acknowledge delay
  task automatic tc_008_write_mack_delay();
    apply_reset();
    fork
      axi_write(32'h6000_0000, 32'h3333_3333, 4'b1111, OKAY);
      pmi_write_response(0, 5, 1'b0);  // 5-cycle ack delay
    join
  endtask

  // tc_009 : PMI read acknowledge delay
  task automatic tc_009_read_mack_delay();
    apply_reset();
    fork
      axi_read(32'h7000_0000, 32'h4444_4444, OKAY);
      pmi_read_response(32'h4444_4444, 0, 5, 1'b0);  // 5-cycle ack delay
    join
  endtask

  // tc_010 : successful AXI write response
  task automatic tc_010_write_okay();
    apply_reset();
    fork
      axi_write(32'h8000_0000, 32'h5555_5555, 4'b1111, OKAY);
      pmi_write_response(0, 0, 1'b0);
    join
  endtask

  // tc_011 : AXI write error response
  task automatic tc_011_write_error();
    apply_reset();
    fork
      axi_write(32'h8100_0000, 32'h6666_6666, 4'b1111, ERROR);
      pmi_write_response(0, 0, 1'b1);  // 1 = inject error
    join
  endtask

  // tc_012 : successful AXI read response
  task automatic tc_012_read_okay();
    apply_reset();
    fork
      axi_read(32'h8200_0000, 32'h7777_7777, OKAY);
      pmi_read_response(32'h7777_7777, 0, 0, 1'b0);
    join
  endtask

  // tc_013 : AXI read error response
  task automatic tc_013_read_error();
    apply_reset();
    fork
      axi_read(32'h8300_0000, 32'h8888_8888, ERROR);
      pmi_read_response(32'h8888_8888, 0, 0, 1'b1);  // 1 = inject error
    join
  endtask

  // tc_014 : multiple outstanding write transactions
  task automatic tc_014_multiple_write();
    apply_reset();
    fork
      begin : issue_writes                            // fire off 4 AW/W phases back to back
        for (int i = 0; i < 4; i++) axi_write_issue(32'h9000_0000 + i * 4, 32'h1000_0000 + i, 4'b1111);
      end
      begin : drive_pmi                                // complete each PMI write, staggered ack
        for (int i = 0; i < 4; i++) pmi_write_response(0, i, 1'b0);
      end
      begin : check_resp                                // drain all 4 B responses
        axil_req_i.b_ready = 1'b1;
        repeat (4) begin
          `WAIT_OR_TIMEOUT(axil_rsp_o.b_valid, "b_valid (tc_014_multiple_write)")
          note_case(axil_rsp_o.b.rsp == OKAY);
          @(posedge clk_i);
        end
        axil_req_i.b_ready = 1'b0;
      end
    join
  endtask

  // tc_015 : multiple outstanding read transactions
  task automatic tc_015_multiple_read();
    apply_reset();
    fork
      begin : issue_reads                              // fire off 4 AR phases back to back
        for (int i = 0; i < 4; i++) axi_read_issue(32'hA000_0000 + i * 4);
      end
      begin : drive_pmi                                 // complete each PMI read, staggered ack
        for (int i = 0; i < 4; i++) pmi_read_response(32'h2000_0000 + i, 0, i, 1'b0);
      end
      begin : check_resp                                 // drain and check all 4 R responses
        axil_req_i.r_ready = 1'b1;
        for (int i = 0; i < 4; i++) begin
          `WAIT_OR_TIMEOUT(axil_rsp_o.r_valid, "r_valid (tc_015_multiple_read)")
          note_case(axil_rsp_o.r.data == (32'h2000_0000 + i));
          note_case(axil_rsp_o.r.rsp == OKAY);
          @(posedge clk_i);
        end
        axil_req_i.r_ready = 1'b0;
      end
    join
  endtask

  // tc_016 : fill the pipeline to PIPELINE_DEPTH outstanding write transactions
  task automatic tc_016_pipeline_boundary();
    apply_reset();
    fork
      begin : issue_writes                             // fill the pipeline to its max depth
        for (int i = 0; i < PIPELINE_DEPTH; i++)
          axi_write_issue(32'hB000_0000 + i * 4, 32'h3000_0000 + i, 4'b1111);
      end
      begin : drive_pmi                                 // complete each with rotating ack delay
        for (int i = 0; i < PIPELINE_DEPTH; i++) pmi_write_response(0, i % 3, 1'b0);
      end
      begin : check_resp                                 // drain all PIPELINE_DEPTH responses
        axil_req_i.b_ready = 1'b1;
        repeat (PIPELINE_DEPTH) begin
          `WAIT_OR_TIMEOUT(axil_rsp_o.b_valid, "b_valid (tc_016_pipeline_boundary)")
          note_case(axil_rsp_o.b.rsp == OKAY);
          @(posedge clk_i);
        end
        axil_req_i.b_ready = 1'b0;
      end
    join
  endtask

  // tc_017 : simultaneous read and write activity on independent PMI channels
  task automatic tc_017_simultaneous_read_write();
    apply_reset();
    fork
      begin
        axi_write(32'hC000_0000, 32'hAAAA_5555, 4'b1111, OKAY);  // write transaction
      end
      begin
        pmi_write_response(0, 2, 1'b0);                          // write completion
      end
      begin
        axi_read(32'hC000_1000, 32'h5555_AAAA, OKAY);            // read transaction
      end
      begin
        pmi_read_response(32'h5555_AAAA, 0, 2, 1'b0);            // read completion
      end
    join
  endtask

  // tc_018 : reset idle-state behavior - all readys must be low while in reset
  task automatic tc_018_reset_idle();
    arst_ni      = 1'b0;  // assert reset, no apply_reset() wait
    axil_req_i   = '0;
    pmi_rsp_wr_i = '0;
    pmi_rsp_rd_i = '0;
    #1;                   // let combinational outputs settle
    note_case((axil_rsp_o.aw_ready == 1'b0) && (axil_rsp_o.w_ready == 1'b0) &&
              (axil_rsp_o.ar_ready == 1'b0));  // all readys low in reset
    arst_ni = 1'b1;       // release reset
    @(posedge clk_i);
  endtask

  // tc_019 : reset asserted while a write is pending PMI completion
  task automatic tc_019_reset_pending_write();
    apply_reset();
    pmi_rsp_wr_i.mgnt = 1'b1;  // permit the AXI write handshake
    axi_write_issue(32'hD000_0000, 32'hDEAD_BEEF, 4'b1111);
    pmi_rsp_wr_i.mgnt = 1'b0;  // withhold mack so the write stays pending

    arst_ni = 1'b0;             // reset before PMI completion
    #1;                         // let combinational outputs settle
    note_case(axil_rsp_o.b_valid == 1'b0);  // pending B response must be cleared
    repeat (2) @(posedge clk_i);
    arst_ni = 1'b1;             // release reset
    @(posedge clk_i);
  endtask

  // tc_020 : reset asserted while a read is pending PMI completion
  task automatic tc_020_reset_pending_read();
    apply_reset();
    pmi_rsp_rd_i.mgnt = 1'b1;  // permit the AXI read handshake
    axi_read_issue(32'hD000_1000);
    pmi_rsp_rd_i.mgnt = 1'b0;  // withhold mack so the read stays pending

    arst_ni = 1'b0;             // reset before PMI read completion
    #1;                         // let combinational outputs settle
    note_case(axil_rsp_o.r_valid == 1'b0);  // pending R response must be cleared
    repeat (2) @(posedge clk_i);
    arst_ni = 1'b1;             // release reset
    @(posedge clk_i);
  endtask

  // tc_021 : randomized read/write stress testing
  task automatic tc_021_random_stress();
    logic [ADDR_WIDTH-1:0] random_addr;
    logic [DATA_WIDTH-1:0] random_data;

    apply_reset();
    for (int i = 0; i < 20; i++) begin  // 20 randomized iterations
      random_addr = $urandom();          // random address
      random_data = $urandom();          // random data / expected read value

      if ($urandom_range(0, 1)) begin    // 50/50 write
        fork
          begin
            axi_write(random_addr, random_data, 4'b1111, OKAY);
          end
          begin
            pmi_write_response(0, 0, 1'b0);
          end
        join
      end else begin                     // 50/50 read
        fork
          begin
            axi_read(random_addr, random_data, OKAY);
          end
          begin
            pmi_read_response(random_data, 0, 0, 1'b0);
          end
        join
      end
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // runs the test selected via the common +test_name plusarg; TC_ALL runs every test
  initial begin
    if (test_count == 0) test_count = 1;  // run selected test at least once

    repeat (test_count) begin
      case (test_name)
        "TC_001": tc_001_basic_write();              // basic AXI write
        "TC_002": tc_002_basic_read();                // basic AXI read
        "TC_003": tc_003_aw_w_same_cycle();            // AW/W same-cycle handshake
        "TC_004": tc_004_b_backpressure();             // B-channel backpressure
        "TC_005": tc_005_r_backpressure();             // R-channel backpressure
        "TC_006": tc_006_write_mgnt_delay();           // PMI write grant delay
        "TC_007": tc_007_read_mgnt_delay();            // PMI read grant delay
        "TC_008": tc_008_write_mack_delay();           // PMI write ack delay
        "TC_009": tc_009_read_mack_delay();            // PMI read ack delay
        "TC_010": tc_010_write_okay();                 // successful write
        "TC_011": tc_011_write_error();                // write error response
        "TC_012": tc_012_read_okay();                  // successful read
        "TC_013": tc_013_read_error();                 // read error response
        "TC_014": tc_014_multiple_write();             // multiple outstanding writes
        "TC_015": tc_015_multiple_read();              // multiple outstanding reads
        "TC_016": tc_016_pipeline_boundary();          // fill to PIPELINE_DEPTH
        "TC_017": tc_017_simultaneous_read_write();    // concurrent read + write
        "TC_018": tc_018_reset_idle();                 // reset idle-state behavior
        "TC_019": tc_019_reset_pending_write();        // reset during pending write
        "TC_020": tc_020_reset_pending_read();         // reset during pending read
        "TC_021": tc_021_random_stress();              // randomized stress

        "TC_ALL", "default": begin  // run every directed + randomized test (also covers the
                                     // literal TN="default" value used when +TN is not passed)
          tc_001_basic_write();
          tc_002_basic_read();
          tc_003_aw_w_same_cycle();
          tc_004_b_backpressure();
          tc_005_r_backpressure();
          tc_006_write_mgnt_delay();
          tc_007_read_mgnt_delay();
          tc_008_write_mack_delay();
          tc_009_read_mack_delay();
          tc_010_write_okay();
          tc_011_write_error();
          tc_012_read_okay();
          tc_013_read_error();
          tc_014_multiple_write();
          tc_015_multiple_read();
          tc_016_pipeline_boundary();
          tc_017_simultaneous_read_write();
          tc_018_reset_idle();
          tc_019_reset_pending_write();
          tc_020_reset_pending_read();
          tc_021_random_stress();
        end

        default: begin  // unknown test name -> fail, not silent skip
          $error("Unknown test case name '%s' specified in TN parameter", test_name);
          $finish;
        end
      endcase
    end

    repeat (5) @(posedge clk_i);  // let final transactions settle
    $finish;
  end

endmodule