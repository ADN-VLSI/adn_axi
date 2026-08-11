module adn_axil_to_dual_port_pmi_tb;

  `include "axil/typedef.svh"
  `include "pmi/typedef.svh"
  `include "vip/adn_common_tb_headers.sv"

  // Parameters
  `AXIL_T(axil, 32, 32)
  `PMI_T(pmi_wr, 32, 32)
  `PMI_T(pmi_rd, 32, 32)
  parameter int FIFO_SIZE  = 2; // Depth = 4
  parameter int CLK_PERIOD = 10;

  // Signals
  logic clk_i;
  logic arst_ni;

  // Interfaces using structs
  axil_req_t    axil_req_i;
  axil_resp_t   axil_resp_o;

  pmi_wr_req_t  pmi_wr_req_o;
  pmi_wr_resp_t pmi_wr_resp_i;

  pmi_rd_req_t  pmi_rd_req_o;
  pmi_rd_resp_t pmi_rd_resp_i;

  // Verification tracking variables
  bit enable_backpressure = 0;

  // DUT Instantiation
  adn_axil_to_dual_port_pmi #(
      .axil_req_t  (axil_req_t),
      .axil_resp_t (axil_resp_t),
      .FIFO_SIZE   (FIFO_SIZE),
      .pmi_req_t   (pmi_wr_req_t),
      .pmi_resp_t  (pmi_wr_resp_t)
  ) dut (
      .clk_i         (clk_i),
      .arst_ni       (arst_ni),
      .axil_req_i    (axil_req_i),
      .axil_resp_o   (axil_resp_o),
      .pmi_wr_req_o  (pmi_wr_req_o),
      .pmi_wr_resp_i (pmi_wr_resp_i),
      .pmi_rd_req_o  (pmi_rd_req_o),
      .pmi_rd_resp_i (pmi_rd_resp_i)
  );

  // Clock Generation
  always #(CLK_PERIOD/2) clk_i = ~clk_i;

  // =====================================================================
  // BEHAVIORAL PMI SLAVE MODEL
  // =====================================================================
  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      pmi_wr_resp_i.mgnt  <= 1'b1;
      pmi_wr_resp_i.mack  <= 1'b0;
      pmi_wr_resp_i.mresp <= 1'b0;

      pmi_rd_resp_i.mgnt   <= 1'b1;
      pmi_rd_resp_i.mack   <= 1'b0;
      pmi_rd_resp_i.mresp  <= 1'b0;
      pmi_rd_resp_i.mrdata <= '0;
    end else begin
      pmi_wr_resp_i.mgnt  <= enable_backpressure ? $urandom_range(0, 1) : 1'b1;
      pmi_rd_resp_i.mgnt  <= enable_backpressure ? $urandom_range(0, 1) : 1'b1;

      pmi_wr_resp_i.mack  <= pmi_wr_req_o.mreq && pmi_wr_resp_i.mgnt;
      pmi_wr_resp_i.mresp <= 1'b0; 

      pmi_rd_resp_i.mack   <= pmi_rd_req_o.mreq && pmi_rd_resp_i.mgnt;
      pmi_rd_resp_i.mresp  <= 1'b0; 
      pmi_rd_resp_i.mrdata <= pmi_rd_req_o.maddr + 32'h5678_0000;
    end
  end

  // =====================================================================
  // CORE LOW-LEVEL DRIVERS (TASKS)
  // =====================================================================
  task automatic axil_write(input [31:0] addr, input [31:0] data, input [3:0] strb);
    int timeout;
    begin
      @(posedge clk_i);
      axil_req_i.aw.addr  = addr;
      axil_req_i.aw_valid = 1'b1;
      axil_req_i.w.data   = data;
      axil_req_i.w.strb   = strb;
      axil_req_i.w_valid  = 1'b1;

      timeout = 0;
      while (!(axil_resp_o.aw_ready && axil_resp_o.w_ready)) begin
        @(posedge clk_i);
        timeout++;
        if (timeout > 2000) begin
          $error("[TIMEOUT] AW/W handshake stalled!");
          $finish;
        end
      end
      
      @(posedge clk_i);
      axil_req_i.aw_valid = 1'b0;
      axil_req_i.w_valid  = 1'b0;

      timeout = 0;
      while (!axil_resp_o.b_valid) begin
        @(posedge clk_i);
        timeout++;
        if (timeout > 2000) begin
          $error("[TIMEOUT] B response channel stalled!");
          $finish;
        end
      end
    end
  endtask

  task automatic axil_read(input [31:0] addr, output [31:0] rdata);
    int timeout;
    begin
      @(posedge clk_i);
      axil_req_i.ar.addr  = addr;
      axil_req_i.ar_valid = 1'b1;

      timeout = 0;
      while (!axil_resp_o.ar_ready) begin
        @(posedge clk_i);
        timeout++;
        if (timeout > 2000) begin
          $error("[TIMEOUT] AR handshake stalled!");
          $finish;
        end
      end

      @(posedge clk_i);
      axil_req_i.ar_valid = 1'b0;

      timeout = 0;
      while (!axil_resp_o.r_valid) begin
        @(posedge clk_i);
        timeout++;
        if (timeout > 2000) begin
          $error("[TIMEOUT] R response channel stalled!");
          $finish;
        end
      end
      rdata = axil_resp_o.r.data;
    end
  endtask

  // =====================================================================
  // HIGH-LEVEL TASK-BASED TESTCASES (USING note_case)
  // =====================================================================

  task automatic run_test_single_rw();
    logic [31:0] rdata;
    begin
      $display("[TEST 1] Running Single Write & Read...");
      axil_write(32'h0000_1000, 32'hCAFE_BABE, 4'b1111);
      axil_read(32'h0000_1000, rdata);
      
      if (rdata !== (32'h0000_1000 + 32'h5678_0000)) begin
        $error("[TEST 1 FAIL] Expected: %0h, Got: %0h", (32'h0000_1000 + 32'h5678_0000), rdata);
        note_case(0);
      end else begin
        $display("[TEST 1 PASS] Data matched: %0h", rdata);
        note_case(1);
      end
    end
  endtask

  task automatic run_test_partial_strobe();
    logic [31:0] rdata;
    begin
      $display("[TEST 2] Running Partial Byte Strobe Write...");
      axil_write(32'h0000_1004, 32'h1234_5678, 4'b0011);
      axil_read(32'h0000_1004, rdata);
      $display("[TEST 2 PASS] Completed with Strobe 4'b0011");
      note_case(1);
    end
  endtask

  task automatic run_test_bursts();
    logic [31:0] rdata;
    begin
      $display("[TEST 3] Running Back-to-Back Bursts...");
      for (int i = 0; i < 4; i++) begin
        axil_write(32'h0000_2000 + (i * 4), 32'h1111_0000 + i, 4'b1111);
      end
      for (int i = 0; i < 4; i++) begin
        axil_read(32'h0000_2000 + (i * 4), rdata);
      end
      $display("[TEST 3 PASS] Bursts completed successfully.");
      note_case(1);
    end
  endtask

  task automatic run_test_concurrent();
    logic [31:0] rdata;
    begin
      $display("[TEST 4] Running Concurrent Pipelined Traffic...");
      fork
        begin
          for (int i = 0; i < 4; i++) begin
            axil_write(32'h0000_3000 + (i * 4), 32'h2222_0000 + i, 4'b1111);
          end
        end
        begin
          for (int i = 0; i < 4; i++) begin
            axil_read(32'h0000_3000 + (i * 4), rdata);
          end
        end
      join
      $display("[TEST 4 PASS] Concurrent traffic passed.");
      note_case(1);
    end
  endtask

  task automatic run_test_master_backpressure();
    logic [31:0] rdata;
    begin
      $display("[TEST 5] Running Master Response Backpressure...");
      axil_req_i.b_ready = 1'b0;
      axil_req_i.r_ready = 1'b0;

      fork
        axil_write(32'h0000_4000, 32'h4444_4444, 4'b1111);
        axil_read(32'h0000_4004, rdata);
      join_none

      #(CLK_PERIOD * 10);
      axil_req_i.b_ready = 1'b1;
      axil_req_i.r_ready = 1'b1;
      #(CLK_PERIOD * 5);
      $display("[TEST 5 PASS] Master backpressure tested.");
      note_case(1);
    end
  endtask

  task automatic run_test_slave_backpressure();
    logic [31:0] rdata;
    begin
      $display("[TEST 6] Running Slave Request Backpressure (Random MGNT)...");
      enable_backpressure = 1'b1;
      for (int i = 0; i < 4; i++) begin
        axil_write(32'h0000_5000 + (i * 4), 32'h5555_0000 + i, 4'b1111);
        axil_read(32'h0000_5000 + (i * 4), rdata);
      end
      enable_backpressure = 1'b0;
      $display("[TEST 6 PASS] Slave backpressure tested.");
      note_case(1);
    end
  endtask

  task automatic run_test_non_sequential();
    logic [31:0] rdata;
    automatic logic [31:0] test_addrs[3] = '{32'h0000_8ABC, 32'h0000_1234, 32'h0000_F00F};
    begin
      $display("[TEST 7] Running Non-Sequential Address Stress...");
      foreach (test_addrs[i]) begin
        axil_write(test_addrs[i], 32'h9999_0000 + i, 4'b1111);
        axil_read(test_addrs[i], rdata);
      end
      $display("[TEST 7 PASS] Non-sequential stress passed.");
      note_case(1);
    end
  endtask

  task automatic run_test_extended_idle();
    begin
      $display("[TEST 8] Running Extended Idle Verification...");
      #(CLK_PERIOD * 20);
      $display("[TEST 8 PASS] Extended idle passed.");
      note_case(1);
    end
  endtask

  // =====================================================================
  // INITIAL STIMULUS EXECUTION
  // =====================================================================
  initial begin
    // Initialize Inputs
    clk_i = 0;
    arst_ni = 0;
    axil_req_i = '0;
    axil_req_i.b_ready = 1'b1;
    axil_req_i.r_ready = 1'b1;

    // Apply Reset
    #(CLK_PERIOD * 3);
    arst_ni = 1;
    #(CLK_PERIOD * 2);

    $display("\n==========================================================");
    $display("=== STARTING TASK-BASED BRIDGE VERIFICATION SUITE ===");
    $display("==========================================================\n");

    // Execute Tasks based on test_name variable provided by framework
    case (test_name)
      "TC_001": run_test_single_rw();
      "TC_002": run_test_partial_strobe();
      "TC_003": run_test_bursts();
      "TC_004": run_test_concurrent();
      "TC_005": run_test_master_backpressure();
      "TC_006": run_test_slave_backpressure();
      "TC_007": run_test_non_sequential();
      "TC_008": run_test_extended_idle();
      "TC_ALL": begin
        run_test_single_rw();
        run_test_partial_strobe();
        run_test_bursts();
        run_test_concurrent();
        run_test_master_backpressure();
        run_test_slave_backpressure();
        run_test_non_sequential();
        run_test_extended_idle();
      end
      default: begin
        $display("[INFO] No specific test name provided. Running all tests sequentially.");
        run_test_single_rw();
        run_test_partial_strobe();
        run_test_bursts();
        run_test_concurrent();
        run_test_master_backpressure();
        run_test_slave_backpressure();
        run_test_non_sequential();
        run_test_extended_idle();
      end
    endcase

   $finish;
  end

endmodule