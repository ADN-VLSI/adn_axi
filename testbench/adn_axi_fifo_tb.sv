/*

| TEST CASE | DATE       | AUTHOR             | DESCRIPTION                                                          |
|-----------|------------|--------------------|-----------------------------------------------------------------------|
| TC_001    | 2026-08-09 | Adnan Sami Anirban | Basic AW channel pass-through sanity check                           |
| TC_002    | 2026-08-09 | Adnan Sami Anirban | Fill AW FIFO to full depth, verify overflow is rejected, verify flush |
| TC_003    | 2026-08-09 | Adnan Sami Anirban | Fill W FIFO to full depth, verify ready deasserts, verify flush       |
| TC_004    | 2026-08-09 | Adnan Sami Anirban | Fill AR FIFO to full depth, verify ready deasserts, verify flush      |
| TC_005    | 2026-08-09 | Adnan Sami Anirban | Fill R FIFO to full depth, verify ready deasserts, verify flush       |
| TC_006    | 2026-08-09 | Adnan Sami Anirban | Fill B FIFO to full depth, verify ready deasserts, verify flush       |
| TC_007    | 2026-08-09 | Adnan Sami Anirban | AW field boundary sweep (all-0 / all-1 struct patterns)               |
| TC_008    | 2026-08-09 | Adnan Sami Anirban | Reset mid-transfer, verify clean recovery on AW channel               |
| TC_009    | 2026-08-09 | Adnan Sami Anirban | Cross-channel independence - AW stalled, W/AR run concurrently        |
| TC_010    | 2026-08-09 | Adnan Sami Anirban | Randomized valid/ready backpressure stress on AW channel              |

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-09 | Adnan Sami Anirban | Initial version                                        |
| 1.0      | 2026-08-09 | Adnan Sami Anirban | Stable release                                         |
| 1.1      | 2026-08-10 | Adnan Sami Anirban | Parameterized field widths, added TC_007-TC_010        |

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
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////
adn_axi_fifo #(
    .axi_req_t    (axi_req_t    ),
    .axi_resp_t   (axi_resp_t   ),
    .AW_FIFO_SIZE (AW_FIFO_SIZE ),
    .W_FIFO_SIZE  (W_FIFO_SIZE  ),
    .B_FIFO_SIZE  (B_FIFO_SIZE  ),
    .AR_FIFO_SIZE (AR_FIFO_SIZE ),
    .R_FIFO_SIZE  (R_FIFO_SIZE  )
  )dut(
      .clk_i      (clk_i        ),
      .arst_ni    (arst_ni      ),
      .slv_req_i  (slv_req_i    ),
      .slv_resp_o (slv_resp_o   ),
      .mst_req_o  (mst_req_o    ),
      .mst_resp_i (mst_resp_i   )
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `GEN_DRIVE_REQ_TASK  (aw, axi_aw_t  )
  `GEN_DRIVE_REQ_TASK  (w,  axi_w_t   )
  `GEN_DRIVE_REQ_TASK  (ar, axi_ar_t  )
  `GEN_DRIVE_RESP_TASK (b, axi_b_t    )
  `GEN_DRIVE_RESP_TASK (r, axi_r_t    )

  `GEN_CHECK_REQ_TASK  (aw, axi_aw_t  )
  `GEN_CHECK_REQ_TASK  (w,  axi_w_t   )
  `GEN_CHECK_REQ_TASK  (ar, axi_ar_t  )
  `GEN_CHECK_RESP_TASK (b, axi_b_t    )
  `GEN_CHECK_RESP_TASK (r, axi_r_t    )

  task automatic apply_reset();
    arst_ni    = 1'b0;
    slv_req_i  = '0;
    mst_resp_i = '0;
    #22;
    arst_ni = 1'b1;
    @(posedge clk_i);
  endtask

  // helper to build a simple, deterministic AW item using parameterized field widths
  function automatic axi_aw_t make_aw_item(int idx);
    axi_aw_t item;
    item.id     = $bits(item.id)'(idx);
    item.addr   = $bits(item.addr)'(32'h1000_0000 + idx);
    item.len    = '0;
    item.size   = 3'h2;
    item.burst  = 2'b01;
    item.lock   = 1'b0;
    item.cache  = '0;
    item.prot   = '0;
    item.qos    = '0;
    item.region = '0;
    item.user   = $bits(item.user)'(0);
    return item;
  endfunction

// tc_001 : basic AW channel test, send one AW item and check that it is received correctly
  task automatic tc_001_basic_aw();
    axi_aw_t item;
    mst_resp_i.aw_ready = 1'b1;   // output side always ready, no backpressure

    item.id     = $bits(item.id)'(1);
    item.addr   = $bits(item.addr)'(32'hA000_0000);
    item.len    = '0;
    item.size   = 3'h2;
    item.burst  = 2'b01;
    item.lock   = 1'b0;
    item.cache  = '0;
    item.prot   = '0;
    item.qos    = '0;
    item.region = '0;
    item.user   = $bits(item.user)'(0);

    drive_aw(item);

    repeat (3) @(posedge clk_i);
    if (aw_ref_q.size() == 0)
      note_case(1);
    else
      note_case(0);
  endtask

// tc_002 : fill the AW FIFO to full, then verify overflow is correctly rejected
task automatic tc_002_aw_fifo_full();
    axi_aw_t item;
    int push_count;
    localparam int AW_FIFO_DEPTH = 2 ** AW_FIFO_SIZE;
    bit overflow_detected;

    mst_resp_i.aw_ready <= 1'b0;

    for (push_count = 0; push_count < AW_FIFO_DEPTH; push_count++) begin
      item = make_aw_item(push_count);
      drive_aw(item);
      $display("T=%0t: pushed #%0d, ready=%b", $time, push_count+1, slv_resp_o.aw_ready);
    end
    @(posedge clk_i);

    // attempt one extra push beyond depth, guarded by a timeout so a
    // correct rejection (ready never returns) cannot hang the simulation
    fork: overflow_check
      begin
        drive_aw(item);
        overflow_detected = 1'b1;
      end
      begin
        repeat (20) @(posedge clk_i);
        overflow_detected = 1'b0;
      end
    join_any
    disable overflow_check;
    slv_req_i.aw_valid <= 1'b0;   // ensure valid is low regardless of which branch won
    @(posedge clk_i);

    if (overflow_detected == 1'b0) begin
      note_case(1);
      if (aw_ref_q.size() > 0)
        aw_ref_q.pop_back();      // remove the phantom entry from the rejected push
    end else
      note_case(0);

    mst_resp_i.aw_ready <= 1'b1;
    repeat (AW_FIFO_DEPTH + 2) @(posedge clk_i);

    // verify the FIFO actually drained and the reference queue matches
    if (mst_req_o.aw_valid !== 1'b0)
      $error("[TC_002] flush incomplete - aw_valid still high after expected flush time");
    if (aw_ref_q.size() != 0)
      $error("[TC_002] flush incomplete - aw_ref_q still has %0d entries, expected 0", aw_ref_q.size());
endtask

// tc_003 : fill the W FIFO to full and check that the ready signal is deasserted
task automatic tc_003_w_fifo_full();
    axi_w_t item;
    int push_count;
    localparam int W_FIFO_DEPTH = 2 ** W_FIFO_SIZE;

    mst_resp_i.w_ready <= 1'b0;

    for (push_count = 0; push_count < W_FIFO_DEPTH; push_count++) begin
      item.data = $bits(item.data)'(push_count);
      item.strb = '1;
      item.last = (push_count == W_FIFO_DEPTH-1) ? 1'b1 : 1'b0;
      item.user = $bits(item.user)'(0);
      drive_w(item);
      $display("T=%0t: pushed #%0d, ready=%b", $time, push_count+1, slv_resp_o.w_ready);
    end
    @(posedge clk_i);
    if (slv_resp_o.w_ready === 1'b0)
      note_case(1);
    else
      note_case(0);

    mst_resp_i.w_ready <= 1'b1;
    repeat (W_FIFO_DEPTH + 2) @(posedge clk_i);

    if (mst_req_o.w_valid !== 1'b0)
      $error("[TC_003] flush incomplete - w_valid still high after expected flush time");
    if (w_ref_q.size() != 0)
      $error("[TC_003] flush incomplete - w_ref_q still has %0d entries, expected 0", w_ref_q.size());
endtask

// tc_004 : fill the AR FIFO to full and check that the ready signal is deasserted
task automatic tc_004_ar_fifo_full();
    axi_ar_t item;
    int push_count;
    localparam int AR_FIFO_DEPTH = 2 ** AR_FIFO_SIZE;

    mst_resp_i.ar_ready <= 1'b0;

    for (push_count = 0; push_count < AR_FIFO_DEPTH; push_count++) begin
      item.id       = $bits(item.id)'(push_count);
      item.addr     = $bits(item.addr)'(32'h1000_0000 + push_count);
      item.len      = '0;
      item.size     = 3'h2;
      item.burst    = 2'b01;
      item.lock     = 1'b0;
      item.cache    = '0;
      item.prot     = '0;
      item.qos      = '0;
      item.region   = '0;
      item.user     = $bits(item.user)'(0);
      drive_ar(item);
      $display("T=%0t: pushed #%0d, ready=%b", $time, push_count+1, slv_resp_o.ar_ready);
    end
    @(posedge clk_i);
    if (slv_resp_o.ar_ready === 1'b0)
      note_case(1);
    else
      note_case(0);

    mst_resp_i.ar_ready <= 1'b1;
    repeat (AR_FIFO_DEPTH + 2) @(posedge clk_i);

    if (mst_req_o.ar_valid !== 1'b0)
      $error("[TC_004] flush incomplete - ar_valid still high after expected flush time");
    if (ar_ref_q.size() != 0)
      $error("[TC_004] flush incomplete - ar_ref_q still has %0d entries, expected 0", ar_ref_q.size());
endtask

// tc_005 : fill the R FIFO to full and check that the ready signal is deasserted
task automatic tc_005_r_fifo_full();
    axi_r_t item;
    int push_count;
    localparam int R_FIFO_DEPTH = 2 ** R_FIFO_SIZE;

    slv_req_i.r_ready <= 1'b0;

    for (push_count = 0; push_count < R_FIFO_DEPTH; push_count++) begin
      item.id       = $bits(item.id)'(push_count);
      item.data     = $bits(item.data)'(push_count);
      item.resp     = 2'b00;
      item.last     = (push_count == R_FIFO_DEPTH-1) ? 1'b1 : 1'b0;
      item.user     = $bits(item.user)'(0);
      drive_r(item);
      $display("T=%0t: pushed #%0d, ready=%b", $time, push_count+1, mst_req_o.r_ready);
    end
    @(posedge clk_i);
    if (mst_req_o.r_ready === 1'b0)
      note_case(1);
    else
      note_case(0);

    slv_req_i.r_ready <= 1'b1;
    repeat (R_FIFO_DEPTH + 2) @(posedge clk_i);

    if (slv_resp_o.r_valid !== 1'b0)
      $error("[TC_005] flush incomplete - r_valid still high after expected flush time");
    if (r_ref_q.size() != 0)
      $error("[TC_005] flush incomplete - r_ref_q still has %0d entries, expected 0", r_ref_q.size());
endtask

// tc_006 : fill the B FIFO to full and check that the ready signal is deasserted
task automatic tc_006_b_fifo_full();
    axi_b_t item;
    int push_count;
    localparam int B_FIFO_DEPTH = 2 ** B_FIFO_SIZE;

    slv_req_i.b_ready <= 1'b0;

    for (push_count = 0; push_count < B_FIFO_DEPTH; push_count++) begin
      item.id       = $bits(item.id)'(push_count);
      item.resp     = 2'b00;
      item.user     = $bits(item.user)'(0);
      drive_b(item);
      $display("T=%0t: pushed #%0d, ready=%b", $time, push_count+1, mst_req_o.b_ready);
    end
    @(posedge clk_i);
    if (mst_req_o.b_ready === 1'b0)
      note_case(1);
    else
      note_case(0);

    slv_req_i.b_ready <= 1'b1;
    repeat (B_FIFO_DEPTH + 2) @(posedge clk_i);

    if (slv_resp_o.b_valid !== 1'b0)
      $error("[TC_006] flush incomplete - b_valid still high after expected flush time");
    if (b_ref_q.size() != 0)
      $error("[TC_006] flush incomplete - b_ref_q still has %0d entries, expected 0", b_ref_q.size());
endtask

// tc_007 : AW field boundary sweep - push an all-0 item then an all-1 item,
//          catches any bit-position error in the pack/unpack cast logic
task automatic tc_007_aw_boundary_sweep();
    axi_aw_t item;
    mst_resp_i.aw_ready = 1'b1;

    item = '0;
    drive_aw(item);
    repeat (3) @(posedge clk_i);

    item = '1;
    drive_aw(item);
    repeat (3) @(posedge clk_i);

    if (aw_ref_q.size() == 0)
      note_case(1);
    else
      note_case(0);
endtask

// tc_008 : reset mid-transfer - partially fill AW, assert reset mid-stream,
//          verify the DUT returns to a clean, empty state afterward
task automatic tc_008_aw_reset_midtransfer();
    axi_aw_t item;
    int push_count;
    localparam int AW_FIFO_DEPTH = 2 ** AW_FIFO_SIZE;

    mst_resp_i.aw_ready <= 1'b0;

    for (push_count = 0; push_count < AW_FIFO_DEPTH/2; push_count++) begin
      item = make_aw_item(push_count);
      drive_aw(item);
    end

    arst_ni = 1'b0;
    slv_req_i.aw_valid <= 1'b0;
    repeat (3) @(posedge clk_i);
    arst_ni = 1'b1;
    @(posedge clk_i);

    // the DUT drops everything on reset, so the reference model must match
    aw_ref_q.delete();

    if (mst_req_o.aw_valid === 1'b0 && slv_resp_o.aw_ready === 1'b1)
      note_case(1);
    else
      note_case(0);

    // confirm the channel works normally again after reset
    mst_resp_i.aw_ready <= 1'b1;
    item = make_aw_item(0);
    drive_aw(item);
    repeat (3) @(posedge clk_i);

    if (aw_ref_q.size() == 0)
      note_case(1);
    else
      note_case(0);
endtask

// tc_009 : cross-channel independence - stall AW completely while driving
//          normal traffic on W and AR concurrently, verify no coupling
task automatic tc_009_cross_channel_independence();
    axi_aw_t aw_item;
    axi_w_t  w_item;
    axi_ar_t ar_item;
    int      i;
    time     start_time, end_time;
    localparam int AW_FIFO_DEPTH = 2 ** AW_FIFO_SIZE;

    start_time = $time;

    fork
      begin
        mst_resp_i.aw_ready <= 1'b0;
        for (i = 0; i < AW_FIFO_DEPTH; i++) begin
          aw_item = make_aw_item(i);
          drive_aw(aw_item);
        end
      end
      begin
        mst_resp_i.w_ready <= 1'b1;
        for (i = 0; i < 10; i++) begin
          w_item.data = $bits(w_item.data)'(i);
          w_item.strb = '1;
          w_item.last = 1'b0;
          w_item.user = $bits(w_item.user)'(0);
          drive_w(w_item);
        end
      end
      begin
        mst_resp_i.ar_ready <= 1'b1;
        for (i = 0; i < 10; i++) begin
          ar_item.id     = $bits(ar_item.id)'(i);
          ar_item.addr   = $bits(ar_item.addr)'(32'h3000_0000 + i);
          ar_item.len    = '0;
          ar_item.size   = 3'h2;
          ar_item.burst  = 2'b01;
          ar_item.lock   = 1'b0;
          ar_item.cache  = '0;
          ar_item.prot   = '0;
          ar_item.qos    = '0;
          ar_item.region = '0;
          ar_item.user   = $bits(ar_item.user)'(0);
          drive_ar(ar_item);
        end
      end
    join

    end_time = $time;
    $display("T=%0t: [TC_009] W+AR completed in %0t while AW stalled", end_time, end_time - start_time);

    if (w_ref_q.size() == 0 && ar_ref_q.size() == 0)
      note_case(1);
    else
      note_case(0);

    mst_resp_i.aw_ready <= 1'b1;
    repeat (AW_FIFO_DEPTH + 2) @(posedge clk_i);
    aw_ref_q.delete();
endtask

// tc_010 : randomized valid/ready backpressure stress on the AW channel
task automatic tc_010_aw_randomized_backpressure();
    axi_aw_t item;
    int i;
    int num_txns;
    num_txns = 20;

    fork
      begin : rand_ready_gen
        forever begin
          @(posedge clk_i);
          mst_resp_i.aw_ready <= $urandom_range(0,1);
        end
      end
      begin
        for (i = 0; i < num_txns; i++) begin
          item = make_aw_item(i);
          drive_aw(item);
        end
      end
    join_any
    disable rand_ready_gen;

    mst_resp_i.aw_ready <= 1'b1;
    repeat (num_txns + 5) @(posedge clk_i);

    if (aw_ref_q.size() == 0)
      note_case(1);
    else
      note_case(0);
endtask

  initial clk_i = 1'b0;
  always #(CLK_PERIOD/2) clk_i = ~clk_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

initial begin
  $dumpfile("adn_axi_fifo_tb.vcd");
  $dumpvars(0, adn_axi_fifo_tb);
  apply_reset();
  $display("T=%0t: reset done", $time);

  fork
    check_aw  ();
    check_w   ();
    check_b   ();
    check_ar  ();
    check_r   ();
  join_none

  case(test_name)
    "TC_ALL": begin  
      $display("T=%0t: starting tc_001", $time);
      tc_001_basic_aw();
      $display("T=%0t: tc_001 done", $time);

      $display("T=%0t: starting tc_002", $time);
      tc_002_aw_fifo_full();
      $display("T=%0t: tc_002 done", $time);

      $display("T=%0t: starting tc_003", $time);
      tc_003_w_fifo_full();
      $display("T=%0t: tc_003 done", $time);

      $display("T=%0t: starting tc_004", $time);
      tc_004_ar_fifo_full();
      $display("T=%0t: tc_004 done", $time);

      $display("T=%0t: starting tc_005", $time);
      tc_005_r_fifo_full();
      $display("T=%0t: tc_005 done", $time);

      $display("T=%0t: starting tc_006", $time);
      tc_006_b_fifo_full();
      $display("T=%0t: tc_006 done", $time);

      $display("T=%0t: starting tc_007", $time);
      tc_007_aw_boundary_sweep();
      $display("T=%0t: tc_007 done", $time);

      $display("T=%0t: starting tc_008", $time);
      tc_008_aw_reset_midtransfer();
      $display("T=%0t: tc_008 done", $time);

      $display("T=%0t: starting tc_009", $time);
      tc_009_cross_channel_independence();
      $display("T=%0t: tc_009 done", $time);

      $display("T=%0t: starting tc_010", $time);
      tc_010_aw_randomized_backpressure();
      $display("T=%0t: tc_010 done", $time);

      $display("T=%0t: all test cases done", $time);
      $display("T=%0t: simulation finished", $time);
    end
    "TC_001": tc_001_basic_aw();
    "TC_002": tc_002_aw_fifo_full();
    "TC_003": tc_003_w_fifo_full();
    "TC_004": tc_004_ar_fifo_full();
    "TC_005": tc_005_r_fifo_full();
    "TC_006": tc_006_b_fifo_full();
    "TC_007": tc_007_aw_boundary_sweep();
    "TC_008": tc_008_aw_reset_midtransfer();
    "TC_009": tc_009_cross_channel_independence();
    "TC_010": tc_010_aw_randomized_backpressure();
    default: begin
      $error("Unknown test case name '%s' specified in TN parameter", test_name);
      $finish;
    end
  endcase

  $finish;
end

endmodule
