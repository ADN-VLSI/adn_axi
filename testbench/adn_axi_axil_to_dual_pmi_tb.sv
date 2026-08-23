/*
| TEST CASE | DATE       | AUTHOR                     | DESCRIPTION                               | 
|-----------|------------|----------------------------|-------------------------------------------| 
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
| TC_ALL    | 2026-08-23 | Shykul Islam Siam          | All directed and randomized tests         | 


| REVISION | DATE       | AUTHOR                     | DESCRIPTION                      | 
|----------|------------|----------------------------|----------------------------------| 
| 0.1      | 2026-08-23 | Md Sakhawat Hossain Sabbir | Initial testbench version        | 
| 1.0      | 2026-08-23 | Shykul Islam Siam          | Stable release                   | 


Author : Shykul Islam Siam (shykulislam32@gmail.com) & Md Sakhawat Hossain Sabbir (sabbirone939@gmail.com)                                      
This file is part of ADN-VLSI/adn_common                                                        
Copyright (c) 2026 ADN Semiconductors                                                           
Licensed under the MIT License                                                                  
See LICENSE file in the project root for full license information                                
*/

module adn_axi_axil_to_dual_pmi_tb;

  `include "vip/adn_common_tb_headers.sv"   // test_name, test_count, debug, note_case()
  `include "axil/typedef.svh"               // AXI4-Lite typedef macros

  // ---- localparams -------------------------------------------------------
  localparam int ADDR_WIDTH     = 32;                 // AXI/PMI address width
  localparam int DATA_WIDTH     = 32;                 // AXI/PMI data width
  localparam int PIPELINE_DEPTH = 8;                  // max outstanding transactions
  localparam int FIFO_SIZE      = $clog2(PIPELINE_DEPTH); // FIFO pointer width

  localparam int  HANDSHAKE_TIMEOUT_CYCLES = 100;      // cycles before `WAIT_OR_TIMEOUT fires

  localparam logic [1:0] OKAY  = 2'b00;   // AXI4-Lite OKAY response
  localparam logic [1:0] ERROR = 2'b10;   // AXI4-Lite ERROR (SLVERR) response

  // ---- types --------------------------------------------------------------
  `AXIL_REQ_T(axil, ADDR_WIDTH, DATA_WIDTH)             // defines axil_req_t
  `AXIL_RSP_T(axil, DATA_WIDTH)                         // defines axil_rsp_t

  typedef struct packed {           // PMI request (write or read side)
    logic [ADDR_WIDTH-1:0]   maddr;   // memory address
    logic                    mwe;     // write enable
    logic [DATA_WIDTH-1:0]   mwdata;  // write data
    logic [DATA_WIDTH/8-1:0] mstrb;   // byte strobes
    logic                    mreq;    // request valid
  } pmi_req_t;

  typedef struct packed {           // PMI response (write or read side)
    logic                    mgnt;    // grant
    logic                    mack;    // acknowledge
    logic [DATA_WIDTH-1:0]   mrdata;  // read data (read side only)
    logic                    mrsp;    // 1 = error
  } pmi_rsp_t;

  // ---- signals --------------------------------------------------------------
  logic clk_i;                      // testbench clock
  logic arst_ni;                    // active-low async reset

  axil_req_t axil_req_i;            // AXI4-Lite request into the DUT
  axil_rsp_t axil_rsp_o;            // AXI4-Lite response from the DUT

  pmi_req_t pmi_req_wr_o;           // PMI write channel: DUT -> memory model
  pmi_rsp_t pmi_rsp_wr_i;           // PMI write channel: memory model -> DUT

  pmi_req_t pmi_req_rd_o;           // PMI read channel: DUT -> memory model
  pmi_rsp_t pmi_rsp_rd_i;           // PMI read channel: memory model -> DUT

  // ---- DUT --------------------------------------------------------------
  adn_axi_axil_to_dual_pmi #(
    .axil_req_t     (axil_req_t),        // AXI4-Lite request struct type
    .axil_rsp_t     (axil_rsp_t),        // AXI4-Lite response struct type
    .pmi_req_t      (pmi_req_t),         // PMI request struct type
    .pmi_rsp_t      (pmi_rsp_t),         // PMI response struct type
    .PIPELINE_DEPTH (PIPELINE_DEPTH),    // max outstanding transactions
    .FIFO_SIZE      (FIFO_SIZE)          // internal FIFO pointer width
  ) dut (
    .clk_i        (clk_i),               // clock
    .arst_ni      (arst_ni),             // active-low reset
    .axil_req_i   (axil_req_i),          // AXI4-Lite request in
    .axil_rsp_o   (axil_rsp_o),          // AXI4-Lite response out
    .pmi_req_wr_o (pmi_req_wr_o),        // PMI write request out
    .pmi_rsp_wr_i (pmi_rsp_wr_i),        // PMI write response in
    .pmi_req_rd_o (pmi_req_rd_o),        // PMI read request out
    .pmi_rsp_rd_i (pmi_rsp_rd_i)         // PMI read response in
  );

  // ---- clock --------------------------------------------------------------
  initial clk_i = 1'b0;                                 // start low
  always #5ns clk_i = ~clk_i;                           // free-running toggle, 100 MHz

  // ---- helpers --------------------------------------------------------------

  task automatic apply_reset;                       // drive reset, clear req/rsp, release sync
    begin
      arst_ni      = 1'b0;               // assert reset
      axil_req_i   = '0;                 // clear AXI request bus
      pmi_rsp_wr_i = '0;                 // clear PMI write response
      pmi_rsp_rd_i = '0;                 // clear PMI read response
      repeat (4) @(posedge clk_i);       // hold reset a few cycles
      @(negedge clk_i);                  // release on a negedge to avoid races
      arst_ni = 1'b1;                    // deassert reset
      @(posedge clk_i);                  // let DUT come out of reset
    end
  endtask

  `define WAIT_OR_TIMEOUT(COND, MSG)                       \
    begin                                                   \
      int __timeout__;                                      \
      __timeout__ = 0;                                      \
      while (!(COND)) begin              /* poll each cycle */ \
        @(posedge clk_i);                                  \
        __timeout__++;                                     \
        if (__timeout__ >= HANDSHAKE_TIMEOUT_CYCLES)       \
          $fatal(1, "Timeout waiting for %s", MSG);        \
      end                                                   \
    end

  task automatic axi_write_issue(                    // drive AW+W together, wait for ready
    input logic [ADDR_WIDTH-1:0]   addr,
    input logic [DATA_WIDTH-1:0]   data,
    input logic [DATA_WIDTH/8-1:0] strb
  );
    begin
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
    end
  endtask

  task automatic axi_write_wait_response(             // release b_ready, check b.rsp
    input logic [1:0] expected_rsp
  );
    begin
      axil_req_i.b_ready = 1'b1;                       // ready to accept the B response
      `WAIT_OR_TIMEOUT(axil_rsp_o.b_valid, "b_valid (axi_write_wait_response)")
      note_case(axil_rsp_o.b.rsp == expected_rsp);      // record pass/fail
      if (debug) $display("[%0t] WRITE rsp=%b expected=%b", $time, axil_rsp_o.b.rsp, expected_rsp);
      @(negedge clk_i);
      axil_req_i.b_ready = 1'b0;                        // drop ready
    end
  endtask

  task automatic axi_write(                           // issue + wait response
    input logic [ADDR_WIDTH-1:0]   addr,
    input logic [DATA_WIDTH-1:0]   data,
    input logic [DATA_WIDTH/8-1:0] strb,
    input logic [1:0]              expected_rsp
  );
    begin
      axi_write_issue(addr, data, strb);                // address/data phase
      axi_write_wait_response(expected_rsp);            // response phase
    end
  endtask

  task automatic axi_read_issue(                      // drive AR, wait for ready
    input logic [ADDR_WIDTH-1:0] addr
  );
    begin
      @(negedge clk_i);
      axil_req_i.ar.addr  = addr;                       // read address
      axil_req_i.ar.prot  = '0;                         // unused protection field
      axil_req_i.ar_valid = 1'b1;                       // assert AR valid
      `WAIT_OR_TIMEOUT(axil_rsp_o.ar_ready, "ar_ready (axi_read_issue)")
      @(negedge clk_i);                                 // handshake done, drop valid
      axil_req_i.ar_valid = 1'b0;
    end
  endtask

  task automatic axi_read_wait_response(              // release r_ready, check data+rsp
    input logic [DATA_WIDTH-1:0] expected_data,
    input logic [1:0]            expected_rsp
  );
    begin
      axil_req_i.r_ready = 1'b1;                        // ready to accept the R response
      `WAIT_OR_TIMEOUT(axil_rsp_o.r_valid, "r_valid (axi_read_wait_response)")
      note_case((axil_rsp_o.r.data == expected_data) && (axil_rsp_o.r.rsp == expected_rsp)); // pass/fail
      if (debug) $display("[%0t] READ data=%h expected=%h rsp=%b expected=%b",
                           $time, axil_rsp_o.r.data, expected_data, axil_rsp_o.r.rsp, expected_rsp);
      @(negedge clk_i);
      axil_req_i.r_ready = 1'b0;                        // drop ready
    end
  endtask

  task automatic axi_read(                            // issue + wait response
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [DATA_WIDTH-1:0] expected_data,
    input logic [1:0]            expected_rsp
  );
    begin
      axi_read_issue(addr);                             // address phase
      axi_read_wait_response(expected_data, expected_rsp); // response phase
    end
  endtask

  task automatic pmi_write_response(                  // grant then ack, with independent delays
    input int mgnt_delay,
    input int mack_delay,
    input logic error
  );
    begin
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
    end
  endtask

  task automatic pmi_read_response(                   // grant then ack, supplies read data
    input logic [DATA_WIDTH-1:0] data,
    input int mgnt_delay,
    input int mack_delay,
    input logic error
  );
    begin
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
    end
  endtask

  // ---- test cases --------------------------------------------------------------

  task automatic tc_basic_write;                      // TC_001: basic AXI write
    begin
      apply_reset();
      fork
        axi_write(32'h0000_1000, 32'hA5A5_5A5A, 4'b1111, OKAY);
        pmi_write_response(0, 0, 1'b0);
      join
    end
  endtask

  task automatic tc_basic_read;                       // TC_002: basic AXI read
    begin
      apply_reset();
      fork
        axi_read(32'h0000_2000, 32'h1234_5678, OKAY);
        pmi_read_response(32'h1234_5678, 0, 0, 1'b0);
      join
    end
  endtask

  task automatic tc_aw_w_same_cycle;                  // TC_003: AW/W accepted same cycle
    begin
      apply_reset();
      fork
        axi_write(32'h1000_0000, 32'h1111_2222, 4'b1111, OKAY);
        pmi_write_response(0, 0, 1'b0);
      join
    end
  endtask

  task automatic tc_b_backpressure;                   // TC_004: B-channel backpressure
    begin
      apply_reset();
      axil_req_i.b_ready = 1'b0;                        // hold B channel back before issuing

      fork
        begin pmi_write_response(0, 0, 1'b0); end       // memory-side completion
        begin axi_write_issue(32'h2000_0000, 32'hAAAA_BBBB, 4'b1111); end // AW/W phase only
      join

      repeat (4) begin                                // response must stay pending while low
        @(posedge clk_i);
        note_case(!axil_rsp_o.b_valid);
      end

      axil_req_i.b_ready = 1'b1;                       // release backpressure, verify response
      @(posedge clk_i);
      note_case(axil_rsp_o.b_valid && (axil_rsp_o.b.rsp == OKAY));
      axil_req_i.b_ready = 1'b0;
    end
  endtask

  task automatic tc_r_backpressure;                   // TC_005: R-channel backpressure
    begin
      apply_reset();
      axil_req_i.r_ready = 1'b0;                        // hold R channel back before issuing

      fork
        begin
          pmi_read_response(32'hCAFE_BABE, 0, 0, 1'b0); // memory-side completion
        end
        begin
          axi_read_issue(32'h3000_0000);                // AR phase
          repeat (2) @(posedge clk_i);                  // let response sit pending
          axil_req_i.r_ready = 1'b1;                    // release backpressure
          `WAIT_OR_TIMEOUT(axil_rsp_o.r_valid, "r_valid (tc_r_backpressure)")
          note_case(axil_rsp_o.r.data == 32'hCAFE_BABE); // record pass/fail
          @(posedge clk_i);
          axil_req_i.r_ready = 1'b0;
        end
      join
    end
  endtask

  task automatic tc_write_mgnt_delay;                 // TC_006: PMI write grant delay
    begin
      apply_reset();
      fork
        axi_write(32'h4000_0000, 32'h1111_1111, 4'b1111, OKAY);
        pmi_write_response(5, 0, 1'b0);
      join
    end
  endtask

  task automatic tc_read_mgnt_delay;                  // TC_007: PMI read grant delay
    begin
      apply_reset();
      fork
        axi_read(32'h5000_0000, 32'h2222_2222, OKAY);
        pmi_read_response(32'h2222_2222, 5, 0, 1'b0);
      join
    end
  endtask

  task automatic tc_write_mack_delay;                 // TC_008: PMI write ack delay
    begin
      apply_reset();
      fork
        axi_write(32'h6000_0000, 32'h3333_3333, 4'b1111, OKAY);
        pmi_write_response(0, 5, 1'b0);
      join
    end
  endtask

  task automatic tc_read_mack_delay;                  // TC_009: PMI read ack delay
    begin
      apply_reset();
      fork
        axi_read(32'h7000_0000, 32'h4444_4444, OKAY);
        pmi_read_response(32'h4444_4444, 0, 5, 1'b0);
      join
    end
  endtask

  task automatic tc_write_okay;                       // TC_010: successful write response
    begin
      apply_reset();
      fork
        axi_write(32'h8000_0000, 32'h5555_5555, 4'b1111, OKAY);
        pmi_write_response(0, 0, 1'b0);
      join
    end
  endtask

  task automatic tc_write_error;                      // TC_011: write error response
    begin
      apply_reset();
      fork
        axi_write(32'h8100_0000, 32'h6666_6666, 4'b1111, ERROR);
        pmi_write_response(0, 0, 1'b1);
      join
    end
  endtask

  task automatic tc_read_okay;                        // TC_012: successful read response
    begin
      apply_reset();
      fork
        axi_read(32'h8200_0000, 32'h7777_7777, OKAY);
        pmi_read_response(32'h7777_7777, 0, 0, 1'b0);
      join
    end
  endtask

  task automatic tc_read_error;                       // TC_013: read error response
    begin
      apply_reset();
      fork
        axi_read(32'h8300_0000, 32'h8888_8888, ERROR);
        pmi_read_response(32'h8888_8888, 0, 0, 1'b1);
      join
    end
  endtask

  task automatic tc_multiple_write;                   // TC_014: multiple outstanding writes
    begin
      apply_reset();
      fork
        begin : issue_writes                           // fire off 4 AW/W phases back to back
          for (int i = 0; i < 4; i++)
            axi_write_issue(32'h9000_0000 + i * 4, 32'h1000_0000 + i, 4'b1111);
        end
        begin : drive_pmi                               // complete each PMI write, staggered ack
          for (int i = 0; i < 4; i++)
            pmi_write_response(0, i, 1'b0);
        end
        begin : check_resp                              // drain all 4 B responses
          axil_req_i.b_ready = 1'b1;
          repeat (4) begin
            `WAIT_OR_TIMEOUT(axil_rsp_o.b_valid, "b_valid (tc_multiple_write)")
            note_case(axil_rsp_o.b.rsp == OKAY);
            @(posedge clk_i);
          end
          axil_req_i.b_ready = 1'b0;
        end
      join
    end
  endtask

  task automatic tc_multiple_read;                    // TC_015: multiple outstanding reads
    begin
      apply_reset();
      fork
        begin : issue_reads                             // fire off 4 AR phases back to back
          for (int i = 0; i < 4; i++)
            axi_read_issue(32'hA000_0000 + i * 4);
        end
        begin : drive_pmi                               // complete each PMI read, staggered ack
          for (int i = 0; i < 4; i++)
            pmi_read_response(32'h2000_0000 + i, 0, i, 1'b0);
        end
        begin : check_resp                              // drain and check all 4 R responses
          axil_req_i.r_ready = 1'b1;
          for (int i = 0; i < 4; i++) begin
            `WAIT_OR_TIMEOUT(axil_rsp_o.r_valid, "r_valid (tc_multiple_read)")
            note_case(axil_rsp_o.r.data == (32'h2000_0000 + i));
            note_case(axil_rsp_o.r.rsp == OKAY);
            @(posedge clk_i);
          end
          axil_req_i.r_ready = 1'b0;
        end
      join
    end
  endtask

  task automatic tc_pipeline_boundary;                // TC_016: fill to PIPELINE_DEPTH
    begin
      apply_reset();
      fork
        begin : issue_writes                           // fill the pipeline to its max depth
          for (int i = 0; i < PIPELINE_DEPTH; i++)
            axi_write_issue(32'hB000_0000 + i * 4, 32'h3000_0000 + i, 4'b1111);
        end
        begin : drive_pmi                               // complete each with rotating ack delay
          for (int i = 0; i < PIPELINE_DEPTH; i++)
            pmi_write_response(0, i % 3, 1'b0);
        end
        begin : check_resp                              // drain all PIPELINE_DEPTH responses
          axil_req_i.b_ready = 1'b1;
          repeat (PIPELINE_DEPTH) begin
            `WAIT_OR_TIMEOUT(axil_rsp_o.b_valid, "b_valid (tc_pipeline_boundary)")
            note_case(axil_rsp_o.b.rsp == OKAY);
            @(posedge clk_i);
          end
          axil_req_i.b_ready = 1'b0;
        end
      join
    end
  endtask

  task automatic tc_simultaneous_read_write;          // TC_017: concurrent read + write paths
    begin
      apply_reset();
      fork
        begin axi_write(32'hC000_0000, 32'hAAAA_5555, 4'b1111, OKAY); end  // write transaction
        begin pmi_write_response(0, 2, 1'b0); end                          // write completion
        begin axi_read(32'hC000_1000, 32'h5555_AAAA, OKAY); end            // read transaction
        begin pmi_read_response(32'h5555_AAAA, 0, 2, 1'b0); end            // read completion
      join
    end
  endtask

  task automatic tc_reset_idle;                       // TC_018: reset idle-state behavior
    begin
      arst_ni      = 1'b0;                              // assert reset, no apply_reset() wait
      axil_req_i   = '0;
      pmi_rsp_wr_i = '0;
      pmi_rsp_rd_i = '0;
      #1;                                                // let combinational outputs settle
      note_case((axil_rsp_o.aw_ready == 1'b0) && (axil_rsp_o.w_ready == 1'b0) && (axil_rsp_o.ar_ready == 1'b0)); // all readys low in reset
      arst_ni = 1'b1;                                    // release reset
      @(posedge clk_i);
    end
  endtask

  task automatic tc_reset_pending_write;              // TC_019: reset during pending write
    begin
      apply_reset();
      pmi_rsp_wr_i.mgnt = 1'b1;                          // permit the AXI write handshake
      axi_write_issue(32'hD000_0000, 32'hDEAD_BEEF, 4'b1111);
      pmi_rsp_wr_i.mgnt = 1'b0;                          // withhold mack so the write stays pending

      arst_ni = 1'b0;                                    // reset before PMI completion
      #1;                                                // let combinational outputs settle
      note_case(axil_rsp_o.b_valid == 1'b0);              // pending B response must be cleared
      repeat (2) @(posedge clk_i);
      arst_ni = 1'b1;                                    // release reset
      @(posedge clk_i);
    end
  endtask

  task automatic tc_reset_pending_read;               // TC_020: reset during pending read
    begin
      apply_reset();
      pmi_rsp_rd_i.mgnt = 1'b1;                          // permit the AXI read handshake
      axi_read_issue(32'hD000_1000);
      pmi_rsp_rd_i.mgnt = 1'b0;                          // withhold mack so the read stays pending

      arst_ni = 1'b0;                                    // reset before PMI read completion
      #1;                                                // let combinational outputs settle
      note_case(axil_rsp_o.r_valid == 1'b0);              // pending R response must be cleared
      repeat (2) @(posedge clk_i);
      arst_ni = 1'b1;                                    // release reset
      @(posedge clk_i);
    end
  endtask

  task automatic tc_random_stress;                    // TC_021: randomized read/write stress
    logic [ADDR_WIDTH-1:0] random_addr;
    logic [DATA_WIDTH-1:0] random_data;
    begin
      apply_reset();
      for (int i = 0; i < 20; i++) begin               // 20 randomized iterations
        random_addr = $urandom();                      // random address
        random_data = $urandom();                      // random data / expected read value

        if ($urandom_range(0, 1)) begin                // 50/50 write
          fork
            begin axi_write(random_addr, random_data, 4'b1111, OKAY); end
            begin pmi_write_response(0, 0, 1'b0); end
          join
        end else begin                                 // 50/50 read
          fork
            begin axi_read(random_addr, random_data, OKAY); end
            begin pmi_read_response(random_data, 0, 0, 1'b0); end
          join
        end
      end
    end
  endtask

  // ---- procedural: main sequencer --------------------------------------------------------------
  // Runs the test selected via the common +test_name plusarg; TC_ALL/default runs every test.

  initial begin : main
    if (test_count == 0)
      test_count = 1;                                  // run selected test at least once

    repeat (test_count) begin
      case (test_name)
        "TC_001":  tc_basic_write();                    // basic AXI write
        "TC_002":  tc_basic_read();                     // basic AXI read
        "TC_003":  tc_aw_w_same_cycle();                // AW/W same-cycle handshake
        "TC_004":  tc_b_backpressure();                 // B-channel backpressure
        "TC_005":  tc_r_backpressure();                 // R-channel backpressure
        "TC_006":  tc_write_mgnt_delay();                // PMI write grant delay
        "TC_007":  tc_read_mgnt_delay();                 // PMI read grant delay
        "TC_008":  tc_write_mack_delay();                // PMI write ack delay
        "TC_009":  tc_read_mack_delay();                 // PMI read ack delay
        "TC_010":  tc_write_okay();                      // successful write
        "TC_011":  tc_write_error();                     // write error response
        "TC_012":  tc_read_okay();                       // successful read
        "TC_013":  tc_read_error();                      // read error response
        "TC_014":  tc_multiple_write();                  // multiple outstanding writes
        "TC_015":  tc_multiple_read();                   // multiple outstanding reads
        "TC_016":  tc_pipeline_boundary();                // fill to PIPELINE_DEPTH
        "TC_017":  tc_simultaneous_read_write();          // concurrent read + write
        "TC_018":  tc_reset_idle();                       // reset idle-state behavior
        "TC_019":  tc_reset_pending_write();              // reset during pending write
        "TC_020":  tc_reset_pending_read();               // reset during pending read
        "TC_021":  tc_random_stress();                    // randomized stress

        "TC_ALL", "default": begin                    // run every directed + randomized test
          tc_basic_write();          tc_basic_read();
          tc_aw_w_same_cycle();
          tc_b_backpressure();       tc_r_backpressure();
          tc_write_mgnt_delay();     tc_read_mgnt_delay();
          tc_write_mack_delay();     tc_read_mack_delay();
          tc_write_okay();           tc_write_error();
          tc_read_okay();            tc_read_error();
          tc_multiple_write();       tc_multiple_read();
          tc_pipeline_boundary();    tc_simultaneous_read_write();
          tc_reset_idle();           tc_reset_pending_write();
          tc_reset_pending_read();   tc_random_stress();
        end

        default: begin                                 // unknown test name -> fail, not silent skip
          $display("[FAIL] Unknown test case '%s'", test_name);
          note_case(1'b0);
        end
      endcase
    end

    repeat (5) @(posedge clk_i);                        // let final transactions settle
    $finish;
  end

endmodule
