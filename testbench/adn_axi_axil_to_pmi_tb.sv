/*

| TEST CASE | DATE       | AUTHOR          | DESCRIPTION                                                                            |
|-----------|------------|-----------------|----------------------------------------------------------------------------------------|  
| TC_001    | 2026-08-10 | Motasim Faiyaz  | single write followed by a read-back, full strobe, no contention.                      |
| TC_002    | 2026-08-10 | Motasim Faiyaz  | back-to-back writes to different addresses, then verify each independently.            |
| TC_003    | 2026-08-10 | Motasim Faiyaz  | partial byte-strobe write must only update the enabled bytes.                          |
| TC_004    | 2026-08-10 | Motasim Faiyaz  | outstanding-transaction depth stress                                                   |
| TC_005    | 2026-08-10 | Motasim Faiyaz  | PMI grant backpressure.                                                                |
| TC_006    | 2026-08-10 | Motasim Faiyaz  | PMI error response (mresp) must be visible on the AXI side as a non-OKAY response.     |
| TC_007    | 2026-08-10 | Motasim Faiyaz  | reset asserted mid-transaction must not hang the DUT or corrupt the next transaction.  |
| TC_008    | 2026-08-10 | Motasim Faiyaz  | randomized read/write mix against a reference memory model, N transactions.            |
 
| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-10 | Motasim Faiyaz  | Initial version                                        |
| 1.0      | 2026-08-10 | Motasim Faiyaz  | Stable release                                         |

Author : Motasim Faiyaz (motasimfaiyaz@gmail.com)
This file is part of ADN-VLSI/adn_axi
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

//////////////////////////////////////////////////////////////////////////////////////////////////
// adn_common_axil_to_pmi_tb.sv
//
// Directed + light-random self-checking testbench for adn_common_axil_to_pmi.
//
// ------------------------------------------------------------------------------------------------
// ASSUMPTIONS (read this before wiring into the real ADN flow):
//
//  1. axil_req_t / axil_resp_t come from the repository's AXIL_T typedef used by the DUT.
//     The resulting nested channel names must match the DUT interface.
//
//  2. `ADDR_WIDTH / `DATA_WIDTH are macros the DUT expects to already exist (used as parameter
//     defaults). This TB defines them locally with an `ifndef guard so it's drop-in safe even if
//     your build already defines them elsewhere (e.g. adn_common_defines.svh).
//
//  3. PMI handshake semantics (mreq/mgnt/mack) are not specified anywhere in the block diagram
//     beyond signal names, so this TB assumes a generic pipelined request/grant/ack protocol:
//       - DUT asserts mreq and holds maddr/mwe/mwdata/mstrb stable until mgnt is seen high
//         in the same cycle (valid/ready-style acceptance, NOT a level-held "accepted" signal).
//       - Once accepted, the memory model may take N cycles before returning mack=1 for exactly
//         one cycle, together with mrdata (for reads) and mresp (error flag, active high).
//       - Multiple transactions can be in flight (this is what "Outstanding FIFO" in your diagram
//         is for), and mack responses come back in the SAME ORDER requests were granted (FIFO).
//     If your real PMI target (e.g. Lattice PMI / a specific memory generator) behaves
//     differently -- e.g. mgnt is a held "ready" level rather than a pulsed accept, or mack can
//     return out of order -- the pmi_mem_model block below is the ONLY place you need to edit.
//
//  4. note_case() is referenced in your other ADN testbenches from
//     vip/adn_common_tb_headers.sv. That file wasn't provided, so a local, compatible
//     PASS/FAIL/summary implementation is included here. Swap the local task for
//     `import adn_common_tb_headers::*;` once you drop this into the real repo, and it should
//     just work as long as the call signature (name, condition) matches.
//
// ------------------------------------------------------------------------------------------------
// TOOL COMPATIBILITY:
//   Compiled clean with Icarus Verilog 12.0 (`iverilog -g2012`) against a port-matching stub DUT.
//   Icarus has a few known SystemVerilog gaps that shaped some choices below:
//     - No SV queues of struct type          -> PMI model uses a plain fixed-depth ring buffer
//                                                of parallel arrays instead of a queue-of-struct.
//     - No associative arrays / .exists()     -> TC8's reference model uses a small fixed-size
//                                                window array + a parallel "valid" bit array.
//     - No `break` inside loops               -> driver-task wait loops use a `done` flag instead.
//     - No/partial concurrent assertion (SVA) -> the whole assertion block is wrapped in
//                                                `ifndef __ICARUS__ (Icarus auto-defines this),
//                                                so it still runs under VCS/Questa/Xcelium/Verilator.
//   None of this should matter if you simulate elsewhere, but it's why the code looks the way it
//   does in a couple of spots instead of using the more "obvious" SV construct.
//////////////////////////////////////////////////////////////////////////////////////////////////

`include "pmi/typedef.svh"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

`ifndef ADDR_WIDTH
`define ADDR_WIDTH 32

`endif
`ifndef DATA_WIDTH
`define DATA_WIDTH 32
`endif

module adn_axi_axil_to_pmi_tb;

    `include "vip/adn_common_tb_headers.sv"

    //////////////////////////////////////////////////////////////////////////////////////////////
    // LOCALPARAMS 
    //////////////////////////////////////////////////////////////////////////////////////////////
    localparam int ADDR_WIDTH  = `ADDR_WIDTH;
    localparam int DATA_WIDTH  = `DATA_WIDTH;
    localparam int FIFO_DEPTH  = 8;
    localparam time CLK_PERIOD = 10ns;

    localparam int AXIL_TIMEOUT_CYCLES = 200; // watchdog for stuck handshakes

    //////////////////////////////////////////////////////////////////////////////////////////////
    // ASSIGNMENTS --INSTANTIATION
    //////////////////////////////////////////////////////////////////////////////////////////////
    logic clk;
    logic arst_n;

    axil_req_t  s_axil_req;
    axil_resp_t s_axil_resp;

    pmi_req_t  m_pmi_req;
    pmi_resp_t m_pmi_resp;

    int pass_count = 0;
    int fail_count = 0;

    task automatic tb_note_case(string name, bit condition);
        note_case(condition);
        if (condition) begin
            pass_count++;
            $display("[%0t] PASS : %s", $time, name);
        end else begin
            fail_count++;
            $display("[%0t] FAIL : %s", $time, name);
        end
    endtask

    task automatic print_summary();
        $display("============================================================");
        $display(" TEST SUMMARY :  PASS = %0d   FAIL = %0d   TOTAL = %0d",
                 pass_count, fail_count, pass_count + fail_count);
        $display("============================================================");
        if (fail_count != 0) $display(" >>> OVERALL: FAIL <<<");
        else                 $display(" >>> OVERALL: PASS <<<");
    endtask

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    task automatic apply_reset(int cycles = 5);
        arst_n = 1'b0;
        s_axil_req = '0;
        repeat (cycles) @(posedge clk);
        @(negedge clk);
        arst_n = 1'b1;
        @(posedge clk);
    endtask

    adn_axi_axil_to_pmi #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH)
    ) dut (
        .clk         (clk),
        .arst_n      (arst_n),
        .s_axil_req  (s_axil_req),
        .s_axil_resp (s_axil_resp),
        .m_pmi_req   (m_pmi_req),
        .m_pmi_resp  (m_pmi_resp)
    );
    //////////////////////////////////////////////////////////////////////////////////////////////
    // PMI MEMORY MODEL  (generic pipelined req/grant/ack, see ASSUMPTIONS block at top)
    //////////////////////////////////////////////////////////////////////////////////////////////
    localparam int MEM_DEPTH_WORDS = 4096;
    logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH_WORDS-1];


    //////////////////////////////////////////////////////////////////////////////////////////////////
    // SIGNALS
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // knobs the test cases can twiddle to control the model's behaviour
    int  pmi_min_ack_latency   = 1;   // cycles between grant and ack
    int  pmi_max_ack_latency   = 3;
    bit  pmi_stall_grant       = 0;   // force mgnt low regardless of mreq (backpressure test)
    int  pmi_max_outstanding   = FIFO_DEPTH + 2; // model's own pipeline capacity
    bit [ADDR_WIDTH-1:0] pmi_error_addr = '1;    // address that always returns mresp=1
    bit  pmi_error_addr_valid  = 0;

    // Pending-transaction tracking uses a plain fixed-depth circular buffer of parallel arrays
    // (head/tail/size pointers) rather than an SV queue-of-struct. This is deliberate: Icarus
    // Verilog (and some other tools) don't support queues whose element type is a struct, and a
    // hand-rolled ring buffer is arguably a more honest model of the "Outstanding FIFO" hardware
    // block in the diagram anyway. Capacity is a fixed localparam; pmi_max_outstanding is a
    // runtime throttle beneath that capacity that test cases can dial down to force backpressure.
    localparam int PMI_MODEL_CAPACITY = FIFO_DEPTH + 8;

    logic [ADDR_WIDTH-1:0]   pq_addr  [0:PMI_MODEL_CAPACITY-1];
    logic                    pq_we    [0:PMI_MODEL_CAPACITY-1];
    logic [DATA_WIDTH-1:0]   pq_wdata [0:PMI_MODEL_CAPACITY-1];
    logic [DATA_WIDTH/8-1:0] pq_strb  [0:PMI_MODEL_CAPACITY-1];
    int                      pq_cntdn [0:PMI_MODEL_CAPACITY-1];
    int pq_head;
    int pq_tail;
    int pq_size;

    // Single combined process: complete the oldest pending transaction (if its latency has
    // elapsed) and accept a new one (if there's room), every cycle. Using blocking assignment
    // deliberately -- this is a testbench behavioral model, not synthesizable RTL, and blocking
    // assignment keeps the head/tail/size bookkeeping simple and race-free within one time step.
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            pq_head = 0;
            pq_tail = 0;
            pq_size = 0;
            m_pmi_resp.mgnt  = 1'b0;
            m_pmi_resp.mack = 1'b0;
            m_pmi_resp.mrdata = '0;
            m_pmi_resp.mresp = 1'b0;
        end else begin
            bit err;
            m_pmi_resp.mack = 1'b0;

            // 1) age / complete the oldest pending transaction
            if (pq_size > 0) begin
                if (pq_cntdn[pq_head] > 0) begin
                    pq_cntdn[pq_head] = pq_cntdn[pq_head] - 1;
                end else begin
                    err = pmi_error_addr_valid && (pq_addr[pq_head] == pmi_error_addr);

                    if (pq_we[pq_head]) begin
                        for (int b = 0; b < DATA_WIDTH/8; b++) begin
                            if (pq_strb[pq_head][b]) begin
                                mem[pq_addr[pq_head][$clog2(MEM_DEPTH_WORDS)+1:2]][b*8 +: 8]
                                    = pq_wdata[pq_head][b*8 +: 8];
                            end
                        end
                        m_pmi_resp.mrdata = '0;
                    end else begin
                        m_pmi_resp.mrdata = mem[pq_addr[pq_head][$clog2(MEM_DEPTH_WORDS)+1:2]];
                    end
                    m_pmi_resp.mresp = err;
                    m_pmi_resp.mack  = 1'b1;

                    pq_head = (pq_head + 1) % PMI_MODEL_CAPACITY;
                    pq_size = pq_size - 1;
                end
            end

            // 2) grant + accept a new request if there's room and we're not deliberately stalling
            if (m_pmi_req.mreq && !m_pmi_resp.mgnt && !pmi_stall_grant &&
                (pq_size < pmi_max_outstanding) && (pq_size < PMI_MODEL_CAPACITY)) begin
                m_pmi_resp.mgnt = 1'b1;

                pq_addr [pq_tail] = m_pmi_req.maddr;
                pq_we   [pq_tail] = m_pmi_req.mwe;
                pq_wdata[pq_tail] = m_pmi_req.mwdata;
                pq_strb [pq_tail] = m_pmi_req.mstrb;
                pq_cntdn[pq_tail] = $urandom_range(pmi_max_ack_latency, pmi_min_ack_latency);

                pq_tail = (pq_tail + 1) % PMI_MODEL_CAPACITY;
                pq_size = pq_size + 1;
            end else begin
                m_pmi_resp.mgnt = 1'b0;
            end
        end
    end


    // memory init
    initial begin
        for (int i = 0; i < MEM_DEPTH_WORDS; i++) mem[i] = '0;
    end

    //////////////////////////////////////////////////////////////////////////////////////////////
    // PROTOCOL ASSERTIONS (lightweight, catch obvious DUT-side handshake bugs)
    //
    // XSim does not support the property forms used here, so keep these checks opt-in for
    // simulators with complete SVA support.
    //////////////////////////////////////////////////////////////////////////////////////////////
`ifdef ENABLE_SVA
    // AW/W/AR address+data must stay stable while valid is asserted and ready hasn't come yet.
    property p_stable(valid_sig, ready_sig, payload_sig);
        @(posedge clk) disable iff (!arst_n)
        (valid_sig && !ready_sig) |=> $stable(payload_sig);
    endproperty

    ap_awaddr_stable: assert property (
        p_stable(s_axil_req.aw_valid, s_axil_resp.aw_ready, s_axil_req.aw.addr)
    ) else $error("AWADDR changed while aw_valid=1 and aw_ready=0");

    ap_araddr_stable: assert property (
        p_stable(s_axil_req.ar_valid, s_axil_resp.ar_ready, s_axil_req.ar.addr)
    ) else $error("ARADDR changed while ar_valid=1 and ar_ready=0");

    // No X on the PMI address/data when a request is actually being issued.
    ap_no_x_maddr: assert property (
        @(posedge clk) disable iff (!arst_n) (m_pmi_req.mreq |-> !$isunknown(m_pmi_req.maddr))
    ) else $error("maddr is X while mreq=1");

    // mreq must not glitch low without ever seeing a grant (basic valid stability, per PMI
    // assumption #3 above). Adjust/remove if your real PMI target allows req to retract early.
    ap_mreq_holds_until_grant: assert property (
        @(posedge clk) disable iff (!arst_n)
        (m_pmi_req.mreq && !m_pmi_resp.mgnt) |=> m_pmi_req.mreq
    ) else $error("mreq deasserted before being granted (mgnt) -- check PMI assumption in TB header");
`endif // ENABLE_SVA

    //////////////////////////////////////////////////////////////////////////////////////////////
    // AXI-LITE DRIVER TASKS
    //////////////////////////////////////////////////////////////////////////////////////////////
    task automatic axil_write(
        input  logic [ADDR_WIDTH-1:0] addr,
        input  logic [DATA_WIDTH-1:0] data,
        input  logic [DATA_WIDTH/8-1:0] strb = '1,
        output logic [1:0] bresp_o
    );
        int timeout;
        bit done;

        // Drive AW and W together (simplest legal case: both valid on the same cycle).
        @(negedge clk);
        s_axil_req.aw_valid = 1'b1;
        s_axil_req.aw.addr  = addr;
        s_axil_req.w_valid  = 1'b1;
        s_axil_req.w.data   = data;
        s_axil_req.w.strb   = strb;

        timeout = 0;
        done    = 0;
        while (!done) begin
            @(posedge clk);
            timeout++;
            if (s_axil_resp.aw_ready && s_axil_resp.w_ready) begin
                done = 1;
            end else if (timeout > AXIL_TIMEOUT_CYCLES) begin
                tb_note_case($sformatf("axil_write addr=0x%0h TIMEOUT waiting AW/W ready", addr), 0);
                done = 1;
            end
        end

        @(negedge clk);
        s_axil_req.aw_valid = 1'b0;
        s_axil_req.w_valid  = 1'b0;

        // Wait for the write response.
        s_axil_req.b_ready = 1'b1;
        timeout = 0;
        done    = 0;
        while (!done) begin
            @(posedge clk);
            timeout++;
            if (s_axil_resp.b_valid) begin
                done = 1;
            end else if (timeout > AXIL_TIMEOUT_CYCLES) begin
                tb_note_case($sformatf("axil_write addr=0x%0h TIMEOUT waiting BVALID", addr), 0);
                done = 1;
            end
        end

        bresp_o = s_axil_resp.b.resp;
        @(negedge clk);
        s_axil_req.b_ready = 1'b0;
    endtask

    task automatic axil_read(
        input  logic [ADDR_WIDTH-1:0] addr,
        output logic [DATA_WIDTH-1:0] data_o,
        output logic [1:0] rresp_o
    );
        int timeout;
        bit done;

        @(negedge clk);
        s_axil_req.ar_valid = 1'b1;
        s_axil_req.ar.addr  = addr;

        timeout = 0;
        done    = 0;
        while (!done) begin
            @(posedge clk);
            timeout++;
            if (s_axil_resp.ar_ready) begin
                done = 1;
            end else if (timeout > AXIL_TIMEOUT_CYCLES) begin
                tb_note_case($sformatf("axil_read addr=0x%0h TIMEOUT waiting ARREADY", addr), 0);
                done = 1;
            end
        end

        @(negedge clk);
        s_axil_req.ar_valid = 1'b0;

        s_axil_req.r_ready = 1'b1;
        timeout = 0;
        done    = 0;
        while (!done) begin
            @(posedge clk);
            timeout++;
            if (s_axil_resp.r_valid) begin
                done = 1;
            end else if (timeout > AXIL_TIMEOUT_CYCLES) begin
                tb_note_case($sformatf("axil_read addr=0x%0h TIMEOUT waiting RVALID", addr), 0);
                done = 1;
            end
        end

        data_o  = s_axil_resp.r.data;
        rresp_o = s_axil_resp.r.resp;
        @(negedge clk);
        s_axil_req.r_ready = 1'b0;
    endtask

    //////////////////////////////////////////////////////////////////////////////////////////////
    // TEST CASES
    //////////////////////////////////////////////////////////////////////////////////////////////

    // TC1: single write followed by a read-back, full strobe, no contention.
    task automatic tc1_basic_write_readback();
        logic [1:0] bresp;
        logic [1:0] rresp;
        logic [DATA_WIDTH-1:0] rdata;

        axil_write(32'h0000_0010, 32'hDEAD_BEEF, '1, bresp);
        tb_note_case("TC1: write bresp == OKAY", bresp == 2'b00);

        axil_read(32'h0000_0010, rdata, rresp);
        tb_note_case("TC1: read-back data matches", rdata == 32'hDEAD_BEEF);
        tb_note_case("TC1: read rresp == OKAY", rresp == 2'b00);
    endtask

    // TC2: back-to-back writes to different addresses, then verify each independently.
    task automatic tc2_back_to_back_writes();
        logic [1:0] bresp;
        logic [1:0] rresp;
        logic [DATA_WIDTH-1:0] rdata;
        logic [DATA_WIDTH-1:0] expected[4];
        bit ok = 1;

        expected[0] = 32'h1111_1111;
        expected[1] = 32'h2222_2222;
        expected[2] = 32'h3333_3333;
        expected[3] = 32'h4444_4444;

        for (int i = 0; i < 4; i++) begin
            axil_write(32'h0000_0100 + i*4, expected[i], '1, bresp);
            if (bresp != 2'b00) ok = 0;
        end
        tb_note_case("TC2: all writes returned OKAY", ok);

        ok = 1;
        for (int i = 0; i < 4; i++) begin
            axil_read(32'h0000_0100 + i*4, rdata, rresp);
            if (rdata != expected[i] || rresp != 2'b00) ok = 0;
        end
        tb_note_case("TC2: all read-backs match", ok);
    endtask

    // TC3: partial byte-strobe write must only update the enabled bytes.
    task automatic tc3_partial_strobe();
        logic [1:0] bresp;
        logic [1:0] rresp;
        logic [DATA_WIDTH-1:0] rdata;

        axil_write(32'h0000_0200, 32'hAAAA_AAAA, 4'b1111, bresp);
        axil_write(32'h0000_0200, 32'h1234_5678, 4'b0011, bresp); // only lower 2 bytes
        axil_read (32'h0000_0200, rdata, rresp);

        tb_note_case("TC3: partial strobe updates only enabled bytes",
                  rdata == 32'hAAAA_5678);
    endtask

    // TC4: outstanding-transaction depth stress -- fire more requests back-to-back than
    // FIFO_DEPTH and rely on AXI backpressure (awready/arready deassertion) to throttle us,
    // rather than manually pacing. This is the main check on the "Outstanding FIFO" block.
    task automatic tc4_outstanding_stress();
        logic [1:0] bresp;
        logic [1:0] rresp;
        logic [DATA_WIDTH-1:0] rdata;
        int n = FIFO_DEPTH * 2;
        bit ok = 1;

        pmi_min_ack_latency = 2;
        pmi_max_ack_latency = 6; // slow memory -> forces backpressure to build up

        for (int i = 0; i < n; i++) begin
            axil_write(32'h0000_0400 + i*4, 32'hB000_0000 + i, '1, bresp);
            if (bresp != 2'b00) ok = 0;
        end
        tb_note_case($sformatf("TC4: %0d back-to-back writes past FIFO_DEPTH=%0d all completed OKAY",
                             n, FIFO_DEPTH), ok);

        ok = 1;
        for (int i = 0; i < n; i++) begin
            axil_read(32'h0000_0400 + i*4, rdata, rresp);
            if (rdata != (32'hB000_0000 + i)) ok = 0;
        end
        tb_note_case("TC4: order preserved under outstanding-transaction pressure", ok);

        pmi_min_ack_latency = 1;
        pmi_max_ack_latency = 3;
    endtask

    // TC5: PMI grant backpressure -- DUT must stall gracefully when the memory side refuses
    // to grant for a while, and recover cleanly once grants resume.
    task automatic tc5_pmi_grant_backpressure();
        logic [1:0] bresp;
        logic [1:0] rresp;
        logic [DATA_WIDTH-1:0] rdata;

        pmi_stall_grant = 1;
        fork
            axil_write(32'h0000_0500, 32'hC0FF_EE00, '1, bresp);
            begin
                repeat (15) @(posedge clk);
                pmi_stall_grant = 0;
            end
        join
        tb_note_case("TC5: write completes OKAY after PMI grant backpressure clears",
                  bresp == 2'b00);

        axil_read(32'h0000_0500, rdata, rresp);
        tb_note_case("TC5: data correct after backpressure scenario", rdata == 32'hC0FF_EE00);
    endtask

    // TC6: PMI error response (mresp) must be visible on the AXI side as a non-OKAY response.
    task automatic tc6_pmi_error_response();
        logic [1:0] bresp;
        logic [1:0] rresp;
        logic [DATA_WIDTH-1:0] rdata;

        pmi_error_addr       = 32'h0000_0F00;
        pmi_error_addr_valid = 1;

        axil_write(32'h0000_0F00, 32'hBAD0_0000, '1, bresp);
        tb_note_case("TC6: write to non existent returns non-OKAY bresp", bresp != 2'b00);

        axil_read(32'h0000_0F00, rdata, rresp);
        tb_note_case("TC6: read from non existent returns non-OKAY rresp", rresp != 2'b00);

        pmi_error_addr_valid = 0;
    endtask

    // TC7: reset asserted mid-transaction must not hang the DUT or corrupt the next transaction.
    task automatic tc7_reset_mid_transaction();
        logic [1:0] bresp;
        logic [1:0] rresp;
        logic [DATA_WIDTH-1:0] rdata;

        pmi_min_ack_latency = 5;
        pmi_max_ack_latency = 10;

        fork
            axil_write(32'h0000_0600, 32'hFEED_FACE, '1, bresp);
            begin
                repeat (3) @(posedge clk);
                apply_reset(5);
            end
        join_any
        disable fork;

        pmi_min_ack_latency = 1;
        pmi_max_ack_latency = 3;

        // DUT must be responsive again after reset -- prove it with a clean transaction.
        axil_write(32'h0000_0610, 32'h1357_9BDF, '1, bresp);
        tb_note_case("TC7: DUT responsive after mid-transaction reset (write OKAY)",
                  bresp == 2'b00);

        axil_read(32'h0000_0610, rdata, rresp);
        tb_note_case("TC7: DUT data integrity correct after reset recovery",
                  rdata == 32'h1357_9BDF);
    endtask

    // TC8: randomized read/write mix against a reference memory model, N transactions.
    //
    // Uses a small, fixed-size reference window (64 words) instead of an associative array --
    // deliberately portable to simulators (Icarus included) that don't support SV associative
    // arrays with .exists()/.delete(). The window is intentionally small vs. num_txns so the
    // same addresses get hit repeatedly, exercising read-after-write and write-after-write.
    localparam int TC8_WINDOW_WORDS = 64;
    task automatic tc8_random_traffic(int num_txns = 50);
        logic [1:0]  bresp, rresp;
        logic [DATA_WIDTH-1:0] rdata;
        logic [DATA_WIDTH-1:0] ref_mem  [0:TC8_WINDOW_WORDS-1];
        bit                    ref_valid[0:TC8_WINDOW_WORDS-1];
        bit ok = 1;
        logic [ADDR_WIDTH-1:0] addr;
        logic [DATA_WIDTH-1:0] wdata;
        logic [DATA_WIDTH/8-1:0] strb;
        int word_idx;

        for (int i = 0; i < TC8_WINDOW_WORDS; i++) begin
            ref_mem[i] = '0;
            ref_valid[i] = 0;
        end

        pmi_min_ack_latency = 1;
        pmi_max_ack_latency = 4;

        for (int i = 0; i < num_txns; i++) begin
            word_idx = $urandom_range(0, TC8_WINDOW_WORDS-1);
            addr = {word_idx[ADDR_WIDTH-3:0], 2'b00}; // word-aligned, small window -> forces reuse

            if ($urandom_range(0,1)) begin
                wdata = $urandom;
                strb  = $urandom_range(1, 15); // never all-zero strobe
                axil_write(addr, wdata, strb, bresp);
                if (bresp != 2'b00) begin
                    ok = 0;
                end else begin
                    for (int b = 0; b < DATA_WIDTH/8; b++) begin
                        if (strb[b]) begin
                            ref_mem[word_idx][b*8 +: 8] = wdata[b*8 +: 8];
                        end
                    end
                    ref_valid[word_idx] = 1;
                end
            end else begin
                axil_read(addr, rdata, rresp);
                if (ref_valid[word_idx]) begin
                    if (rdata !== ref_mem[word_idx] || rresp != 2'b00) ok = 0;
                end
            end
        end
        tb_note_case($sformatf("TC8: %0d-transaction randomized read/write stream matches reference model",
                             num_txns), ok);
    endtask

    //////////////////////////////////////////////////////////////////////////////////////////////
    // MAIN SEQUENCE
    //////////////////////////////////////////////////////////////////////////////////////////////
    initial begin
        $display("==================================================================");
        $display(" tb_adn_common_axil_to_pmi -- starting");
        $display("==================================================================");

        apply_reset();
case(test_name)
    "TC_ALL": begin
        tc1_basic_write_readback();
        tc2_back_to_back_writes();
        tc3_partial_strobe();
        tc4_outstanding_stress();
        tc5_pmi_grant_backpressure();
        tc6_pmi_error_response();
        tc7_reset_mid_transaction();
        tc8_random_traffic(50);

        print_summary();
    end
    "TC_001": tc1_basic_write_readback();
    "TC_002": tc2_back_to_back_writes();
    "TC_003": tc3_partial_strobe();
    "TC_004": tc4_outstanding_stress();
    "TC_005": tc5_pmi_grant_backpressure();
    "TC_006": tc6_pmi_error_response();
    "TC_007": tc7_reset_mid_transaction();
    "TC_008": tc8_random_traffic(50);
    default: begin
        tc1_basic_write_readback();
        tc2_back_to_back_writes();
        tc3_partial_strobe();
        tc4_outstanding_stress();
        tc5_pmi_grant_backpressure();
        tc6_pmi_error_response();
        tc7_reset_mid_transaction();
        tc8_random_traffic(50);
        print_summary();

    end
endcase
  $finish;
    end

    // global watchdog in case something hangs completely
    initial begin
        #(CLK_PERIOD * 20000);
        $display("[%0t] WATCHDOG TIMEOUT -- simulation did not finish in time", $time);
        print_summary();
        $finish;
    end

endmodule
