/*

### Purpose

Directed SystemVerilog testbench for verifying the
adn_axi_axil_to_axi AXI4-Lite to AXI4 converter.

The testbench verifies:

1. Reset behavior.
2. AXI-Lite simultaneous AW/W transactions.
3. AXI-Lite AW-before-W transactions.
4. AXI-Lite W-before-AW transactions.
5. Independent AXI AW/W backpressure handling.
6. AXI write transaction field generation.
7. AXI write response propagation.
8. AXI-Lite read to AXI read conversion.
9. AXI AR backpressure handling.
10. AXI read response propagation.
11. Detection of duplicate AXI AR transactions.

The DUT is expected to convert every AXI-Lite transaction into exactly
one single-beat AXI transaction.

| REVISION | DATE       | AUTHOR   | DESCRIPTION                |
| -------- | ---------- | -------- | -------------------------- |
| 0.1      | 2026-08-31 | ADN-VLSI | Initial directed testbench |

This file is part of ADN-VLSI/adn_axi
Copyright (c) 2026 ADN-VLSI
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

`include "axi/typedef.svh"
`include "axil/typedef.svh"

module tb_axi_lite_to_axi;

// ------------------------------------------------------------
// Parameters
// ------------------------------------------------------------

localparam int ADDR_WIDTH = 32;
localparam int DATA_WIDTH = 32;
localparam int ID_WIDTH   = 4;
localparam int USER_WIDTH = 1;

localparam time CLK_PERIOD = 10ns;

localparam logic [2:0] AXI_SIZE  = $clog2(DATA_WIDTH / 8);
localparam logic [2:0] AXI_INCR  = 3'b001;


// ------------------------------------------------------------
// Interface Type Definitions
//
// These macros come from:
//   include/axil/typedef.svh
//   include/axi/typedef.svh
// ------------------------------------------------------------

`AXIL_T(axil, ADDR_WIDTH, DATA_WIDTH)
`AXI_T (axi,  ID_WIDTH, ADDR_WIDTH, DATA_WIDTH, USER_WIDTH)


// ------------------------------------------------------------
// Clock and Reset
// ------------------------------------------------------------

logic clk_i;
logic rst_ni;


// ------------------------------------------------------------
// AXI-Lite Master -> DUT
// ------------------------------------------------------------

axil_req_t s_req_i;
axil_rsp_t s_rsp_o;


// ------------------------------------------------------------
// DUT -> AXI Slave
// ------------------------------------------------------------

axi_req_t m_req_o;
axi_rsp_t m_rsp_i;


// ------------------------------------------------------------
// Testbench Control / Error Tracking
// ------------------------------------------------------------

int test_count;
int error_count;


// ------------------------------------------------------------
// AXI Slave Model Control
// ------------------------------------------------------------

logic axi_aw_ready;
logic axi_w_ready;
logic axi_ar_ready;

logic axi_b_valid;
logic [1:0] axi_b_resp;

logic axi_r_valid;
logic [DATA_WIDTH-1:0] axi_r_data;
logic [1:0] axi_r_resp;


// ------------------------------------------------------------
// AXI Transaction Counters
//
// Used to verify that one AXI-Lite transaction creates exactly
// one AXI transaction.
// ------------------------------------------------------------

int axi_aw_count;
int axi_w_count;
int axi_b_count;

int axi_ar_count;
int axi_r_count;


// ------------------------------------------------------------
// Captured AXI Write Transaction
// ------------------------------------------------------------

logic [ID_WIDTH-1:0]   captured_aw_id;
logic [ADDR_WIDTH-1:0] captured_aw_addr;
logic [7:0]            captured_aw_len;
logic [2:0]            captured_aw_size;
logic [2:0]            captured_aw_burst;
logic                  captured_aw_lock;
logic [3:0]            captured_aw_cache;
logic [2:0]            captured_aw_prot;
logic [3:0]            captured_aw_qos;
logic [3:0]            captured_aw_region;
logic [USER_WIDTH-1:0] captured_aw_user;

logic [DATA_WIDTH-1:0]   captured_w_data;
logic [DATA_WIDTH/8-1:0] captured_w_strb;
logic                    captured_w_last;
logic [USER_WIDTH-1:0]   captured_w_user;


// ------------------------------------------------------------
// Captured AXI Read Transaction
// ------------------------------------------------------------

logic [ID_WIDTH-1:0]   captured_ar_id;
logic [ADDR_WIDTH-1:0] captured_ar_addr;
logic [7:0]            captured_ar_len;
logic [2:0]            captured_ar_size;
logic [2:0]            captured_ar_burst;
logic                  captured_ar_lock;
logic [3:0]            captured_ar_cache;
logic [2:0]            captured_ar_prot;
logic [3:0]            captured_ar_qos;
logic [3:0]            captured_ar_region;
logic [USER_WIDTH-1:0] captured_ar_user;


// ------------------------------------------------------------
// DUT
// ------------------------------------------------------------

adn_axi_axil_to_axi #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .ID_WIDTH   (ID_WIDTH),
    .USER_WIDTH (USER_WIDTH),

    .axil_req_t (axil_req_t),
    .axil_rsp_t (axil_rsp_t),
    .axi_req_t  (axi_req_t),
    .axi_rsp_t  (axi_rsp_t)
) dut (
    .clk_i   (clk_i),
    .rst_ni  (rst_ni),

    .s_req_i (s_req_i),
    .s_rsp_o (s_rsp_o),

    .m_req_o (m_req_o),
    .m_rsp_i (m_rsp_i)
);


// ------------------------------------------------------------
// Clock Generation
// ------------------------------------------------------------

initial begin
    clk_i = 1'b0;

    forever begin
        #(CLK_PERIOD / 2);
        clk_i = ~clk_i;
    end
end


// ------------------------------------------------------------
// AXI Slave Response Driving
// ------------------------------------------------------------

always_comb begin
    m_rsp_i = '0;

    // Channel ready controls
    m_rsp_i.aw_ready = axi_aw_ready;
    m_rsp_i.w_ready  = axi_w_ready;
    m_rsp_i.ar_ready = axi_ar_ready;

    // Write response
    m_rsp_i.b.resp   = axi_b_resp;
    m_rsp_i.b_valid  = axi_b_valid;

    // Read response
    m_rsp_i.r.data   = axi_r_data;
    m_rsp_i.r.resp   = axi_r_resp;
    m_rsp_i.r.id     = '0;
    m_rsp_i.r.last   = 1'b1;
    m_rsp_i.r.user   = '0;
    m_rsp_i.r_valid  = axi_r_valid;
end


// ------------------------------------------------------------
// AXI Slave Transaction Monitor
// ------------------------------------------------------------

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin

        axi_aw_count <= 0;
        axi_w_count  <= 0;
        axi_b_count  <= 0;

        axi_ar_count <= 0;
        axi_r_count  <= 0;

        captured_aw_id     <= '0;
        captured_aw_addr   <= '0;
        captured_aw_len    <= '0;
        captured_aw_size   <= '0;
        captured_aw_burst  <= '0;
        captured_aw_lock   <= '0;
        captured_aw_cache  <= '0;
        captured_aw_prot   <= '0;
        captured_aw_qos    <= '0;
        captured_aw_region <= '0;
        captured_aw_user   <= '0;

        captured_w_data <= '0;
        captured_w_strb <= '0;
        captured_w_last <= '0;
        captured_w_user <= '0;

        captured_ar_id     <= '0;
        captured_ar_addr   <= '0;
        captured_ar_len    <= '0;
        captured_ar_size   <= '0;
        captured_ar_burst  <= '0;
        captured_ar_lock   <= '0;
        captured_ar_cache  <= '0;
        captured_ar_prot   <= '0;
        captured_ar_qos    <= '0;
        captured_ar_region <= '0;
        captured_ar_user   <= '0;

    end
    else begin

        // AXI AW handshake
        if (m_req_o.aw_valid && m_rsp_i.aw_ready) begin

            axi_aw_count <= axi_aw_count + 1;

            captured_aw_id     <= m_req_o.aw.id;
            captured_aw_addr   <= m_req_o.aw.addr;
            captured_aw_len    <= m_req_o.aw.len;
            captured_aw_size   <= m_req_o.aw.size;
            captured_aw_burst  <= m_req_o.aw.burst;
            captured_aw_lock   <= m_req_o.aw.lock;
            captured_aw_cache  <= m_req_o.aw.cache;
            captured_aw_prot   <= m_req_o.aw.prot;
            captured_aw_qos    <= m_req_o.aw.qos;
            captured_aw_region <= m_req_o.aw.region;
            captured_aw_user   <= m_req_o.aw.user;

            $display(
                "[%0t] AXI AW handshake: addr=0x%08h",
                $time,
                m_req_o.aw.addr
            );
        end


        // AXI W handshake
        if (m_req_o.w_valid && m_rsp_i.w_ready) begin

            axi_w_count <= axi_w_count + 1;

            captured_w_data <= m_req_o.w.data;
            captured_w_strb <= m_req_o.w.strb;
            captured_w_last <= m_req_o.w.last;
            captured_w_user <= m_req_o.w.user;

            $display(
                "[%0t] AXI W handshake: data=0x%08h strb=0x%0h",
                $time,
                m_req_o.w.data,
                m_req_o.w.strb
            );
        end


        // AXI B handshake
        if (m_rsp_i.b_valid && m_req_o.b_ready) begin

            axi_b_count <= axi_b_count + 1;

            $display(
                "[%0t] AXI B handshake: resp=0x%0h",
                $time,
                m_rsp_i.b.resp
            );
        end


        // AXI AR handshake
        if (m_req_o.ar_valid && m_rsp_i.ar_ready) begin

            axi_ar_count <= axi_ar_count + 1;

            captured_ar_id     <= m_req_o.ar.id;
            captured_ar_addr   <= m_req_o.ar.addr;
            captured_ar_len    <= m_req_o.ar.len;
            captured_ar_size   <= m_req_o.ar.size;
            captured_ar_burst  <= m_req_o.ar.burst;
            captured_ar_lock   <= m_req_o.ar.lock;
            captured_ar_cache  <= m_req_o.ar.cache;
            captured_ar_prot   <= m_req_o.ar.prot;
            captured_ar_qos    <= m_req_o.ar.qos;
            captured_ar_region <= m_req_o.ar.region;
            captured_ar_user   <= m_req_o.ar.user;

            $display(
                "[%0t] AXI AR handshake: addr=0x%08h",
                $time,
                m_req_o.ar.addr
            );
        end


        // AXI R handshake
        if (m_rsp_i.r_valid && m_req_o.r_ready) begin

            axi_r_count <= axi_r_count + 1;

            $display(
                "[%0t] AXI R handshake: data=0x%08h resp=0x%0h",
                $time,
                m_rsp_i.r.data,
                m_rsp_i.r.resp
            );
        end

    end
end


// ------------------------------------------------------------
// Utility: Report Test
// ------------------------------------------------------------

task automatic begin_test(
    input string test_name
);
    begin
        test_count = test_count + 1;

        $display("");
        $display("============================================================");
        $display("TEST %0d: %s", test_count, test_name);
        $display("============================================================");
    end
endtask


// ------------------------------------------------------------
// Utility: Check
// ------------------------------------------------------------

task automatic check(
    input bit condition,
    input string message
);
    begin
        if (!condition) begin
            error_count = error_count + 1;

            $error(
                "[%0t] CHECK FAILED: %s",
                $time,
                message
            );
        end
        else begin
            $display(
                "[%0t] CHECK PASSED: %s",
                $time,
                message
            );
        end
    end
endtask


// ------------------------------------------------------------
// Utility: Wait for Clock Cycles
// ------------------------------------------------------------


task automatic wait_cycles(
    input int cycles
);
    begin
        repeat (cycles) @(posedge clk_i);
        #1step;
    end
endtask


// ------------------------------------------------------------
// Reset DUT
// ------------------------------------------------------------

task automatic reset_dut;
    begin

        s_req_i = '0;

        axi_aw_ready = 1'b0;
        axi_w_ready  = 1'b0;
        axi_ar_ready = 1'b0;

        axi_b_valid  = 1'b0;
        axi_b_resp   = 2'b00;

        axi_r_valid  = 1'b0;
        axi_r_data   = '0;
        axi_r_resp   = 2'b00;

        rst_ni = 1'b0;

        wait_cycles(5);

        rst_ni = 1'b1;

        wait_cycles(2);

        check(
            s_rsp_o.b_valid == 1'b0,
            "BVALID is low after reset"
        );

        check(
            s_rsp_o.r_valid == 1'b0,
            "RVALID is low after reset"
        );

        check(
            m_req_o.aw_valid == 1'b0,
            "AXI AWVALID is low after reset"
        );

        check(
            m_req_o.w_valid == 1'b0,
            "AXI WVALID is low after reset"
        );

        check(
            m_req_o.ar_valid == 1'b0,
            "AXI ARVALID is low after reset"
        );

    end
endtask


// ------------------------------------------------------------
// Drive AXI-Lite AW
// ------------------------------------------------------------

task automatic send_axil_aw(
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [2:0]            prot
);
    begin

        @(negedge clk_i);

        s_req_i.aw.addr  = addr;
        s_req_i.aw.prot  = prot;
        s_req_i.aw_valid = 1'b1;

        do begin
            @(posedge clk_i);
        end while (!s_rsp_o.aw_ready);

        @(negedge clk_i);
        s_req_i.aw_valid = 1'b0;

    end
endtask


// ------------------------------------------------------------
// Drive AXI-Lite W
// ------------------------------------------------------------

task automatic send_axil_w(
    input logic [DATA_WIDTH-1:0]   data,
    input logic [DATA_WIDTH/8-1:0] strb
);
    begin

        @(negedge clk_i);

        s_req_i.w.data  = data;
        s_req_i.w.strb  = strb;
        s_req_i.w_valid = 1'b1;

        do begin
            @(posedge clk_i);
        end while (!s_rsp_o.w_ready);

        @(negedge clk_i);
        s_req_i.w_valid = 1'b0;

    end
endtask


// ------------------------------------------------------------
// Drive AXI-Lite AR
// ------------------------------------------------------------

task automatic send_axil_ar(
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [2:0]            prot
);
    begin

        @(negedge clk_i);

        s_req_i.ar.addr  = addr;
        s_req_i.ar.prot  = prot;
        s_req_i.ar_valid = 1'b1;

        do begin
            @(posedge clk_i);
        end while (!s_rsp_o.ar_ready);

        @(negedge clk_i);
        s_req_i.ar_valid = 1'b0;

    end
endtask


// ------------------------------------------------------------
// Receive AXI-Lite B Response
// ------------------------------------------------------------

task automatic receive_axil_b(
    input logic [1:0] expected_resp
);
    begin

        s_req_i.b_ready = 1'b1;

        do begin
            @(posedge clk_i);
        end while (!s_rsp_o.b_valid);

        check(
            s_rsp_o.b.resp == expected_resp,
            $sformatf(
                "AXI-Lite B response is correct: expected=0x%0h actual=0x%0h",
                expected_resp,
                s_rsp_o.b.resp
            )
        );

        @(negedge clk_i);
        s_req_i.b_ready = 1'b0;

    end
endtask


// ------------------------------------------------------------
// Receive AXI-Lite R Response
// ------------------------------------------------------------

task automatic receive_axil_r(
    input logic [DATA_WIDTH-1:0] expected_data,
    input logic [1:0]            expected_resp
);
    begin

        s_req_i.r_ready = 1'b1;

        do begin
            @(posedge clk_i);
        end while (!s_rsp_o.r_valid);

        check(
            s_rsp_o.r.data == expected_data,
            $sformatf(
                "AXI-Lite R data is correct: expected=0x%08h actual=0x%08h",
                expected_data,
                s_rsp_o.r.data
            )
        );

        check(
            s_rsp_o.r.resp == expected_resp,
            $sformatf(
                "AXI-Lite R response is correct: expected=0x%0h actual=0x%0h",
                expected_resp,
                s_rsp_o.r.resp
            )
        );

        @(negedge clk_i);
        s_req_i.r_ready = 1'b0;

    end
endtask


// ------------------------------------------------------------
// AXI Write Response Generator
//
// Wait until DUT is ready for B, then return the requested
// response for one complete handshake.
// ------------------------------------------------------------

task automatic send_axi_b(
    input logic [1:0] resp
);
    begin

        do begin
            @(posedge clk_i);
        end while (!m_req_o.b_ready);

        @(negedge clk_i);

        axi_b_resp  = resp;
        axi_b_valid = 1'b1;

        @(posedge clk_i);

        @(negedge clk_i);

        axi_b_valid = 1'b0;
        axi_b_resp  = '0;

    end
endtask


// ------------------------------------------------------------
// AXI Read Response Generator
// ------------------------------------------------------------

task automatic send_axi_r(
    input logic [DATA_WIDTH-1:0] data,
    input logic [1:0]            resp
);
    begin

        do begin
            @(posedge clk_i);
        end while (!m_req_o.r_ready);

        @(negedge clk_i);

        axi_r_data  = data;
        axi_r_resp  = resp;
        axi_r_valid = 1'b1;

        @(posedge clk_i);

        @(negedge clk_i);

        axi_r_valid = 1'b0;
        axi_r_data  = '0;
        axi_r_resp  = '0;

    end
endtask


// ------------------------------------------------------------
// Verify AXI Write Fields
// ------------------------------------------------------------

task automatic check_axi_write_fields(
    input logic [ADDR_WIDTH-1:0] expected_addr,
    input logic [2:0]            expected_prot,
    input logic [DATA_WIDTH-1:0] expected_data,
    input logic [DATA_WIDTH/8-1:0] expected_strb
);
    begin

        check(captured_aw_id == '0,
              "AXI AW ID is zero");

        check(captured_aw_addr == expected_addr,
              "AXI AW address is correctly propagated");

        check(captured_aw_len == 8'd0,
              "AXI AW LEN is zero for single-beat transaction");

        check(captured_aw_size == AXI_SIZE,
              "AXI AW SIZE matches DATA_WIDTH");

        check(captured_aw_burst == AXI_INCR,
              "AXI AW BURST is INCR");

        check(captured_aw_lock == 1'b0,
              "AXI AW LOCK is zero");

        check(captured_aw_cache == '0,
              "AXI AW CACHE is zero");

        check(captured_aw_prot == expected_prot,
              "AXI AW PROT is propagated");

        check(captured_aw_qos == '0,
              "AXI AW QOS is zero");

        check(captured_aw_region == '0,
              "AXI AW REGION is zero");

        check(captured_aw_user == '0,
              "AXI AW USER is zero");

        check(captured_w_data == expected_data,
              "AXI W DATA is correctly propagated");

        check(captured_w_strb == expected_strb,
              "AXI W STRB is correctly propagated");

        check(captured_w_last == 1'b1,
              "AXI W LAST is asserted for single-beat transaction");

        check(captured_w_user == '0,
              "AXI W USER is zero");

    end
endtask


// ------------------------------------------------------------
// Verify AXI Read Fields
// ------------------------------------------------------------

task automatic check_axi_read_fields(
    input logic [ADDR_WIDTH-1:0] expected_addr,
    input logic [2:0]            expected_prot
);
    begin

        check(captured_ar_id == '0,
              "AXI AR ID is zero");

        check(captured_ar_addr == expected_addr,
              "AXI AR address is correctly propagated");

        check(captured_ar_len == 8'd0,
              "AXI AR LEN is zero for single-beat transaction");

        check(captured_ar_size == AXI_SIZE,
              "AXI AR SIZE matches DATA_WIDTH");

        check(captured_ar_burst == AXI_INCR,
              "AXI AR BURST is INCR");

        check(captured_ar_lock == 1'b0,
              "AXI AR LOCK is zero");

        check(captured_ar_cache == '0,
              "AXI AR CACHE is zero");

        check(captured_ar_prot == expected_prot,
              "AXI AR PROT is propagated");

        check(captured_ar_qos == '0,
              "AXI AR QOS is zero");

        check(captured_ar_region == '0,
              "AXI AR REGION is zero");

        check(captured_ar_user == '0,
              "AXI AR USER is zero");

    end
endtask


// ------------------------------------------------------------
// Test 1: Simultaneous AXI-Lite AW and W
// ------------------------------------------------------------

task automatic test_write_simultaneous;
    int start_aw_count;
    int start_w_count;
    begin

        begin_test("WRITE_SIMULTANEOUS_AW_W");

        start_aw_count = axi_aw_count;
        start_w_count  = axi_w_count;

        axi_aw_ready = 1'b1;
        axi_w_ready  = 1'b1;

        fork
            send_axil_aw(32'h0000_1000, 3'b010);
            send_axil_w (32'hDEAD_BEEF, 4'hF);
        join

        wait_cycles(2);

        check(
            axi_aw_count == start_aw_count + 1,
            "Exactly one AXI AW transaction generated"
        );

        check(
            axi_w_count == start_w_count + 1,
            "Exactly one AXI W transaction generated"
        );

        check_axi_write_fields(
            32'h0000_1000,
            3'b010,
            32'hDEAD_BEEF,
            4'hF
        );

        fork
            send_axi_b(2'b00);
            receive_axil_b(2'b00);
        join

        wait_cycles(2);

    end
endtask


// ------------------------------------------------------------
// Test 2: AW Before W
// ------------------------------------------------------------

task automatic test_write_aw_before_w;
    int start_aw_count;
    int start_w_count;
    begin

        begin_test("WRITE_AW_BEFORE_W");

        start_aw_count = axi_aw_count;
        start_w_count  = axi_w_count;

        axi_aw_ready = 1'b1;
        axi_w_ready  = 1'b1;

        send_axil_aw(32'h0000_2000, 3'b001);

        wait_cycles(3);

        check(
            axi_aw_count == start_aw_count,
            "AXI AW is not issued before AXI-Lite W arrives"
        );

        check(
            axi_w_count == start_w_count,
            "AXI W is not issued before AXI-Lite W arrives"
        );

        send_axil_w(32'h1234_5678, 4'b1100);

        wait_cycles(2);

        check(
            axi_aw_count == start_aw_count + 1,
            "AXI AW issued after complete write request"
        );

        check(
            axi_w_count == start_w_count + 1,
            "AXI W issued after complete write request"
        );

        check_axi_write_fields(
            32'h0000_2000,
            3'b001,
            32'h1234_5678,
            4'b1100
        );

        fork
            send_axi_b(2'b00);
            receive_axil_b(2'b00);
        join

        wait_cycles(2);

    end
endtask


// ------------------------------------------------------------
// Test 3: W Before AW
// ------------------------------------------------------------

task automatic test_write_w_before_aw;
    int start_aw_count;
    int start_w_count;
    begin

        begin_test("WRITE_W_BEFORE_AW");

        start_aw_count = axi_aw_count;
        start_w_count  = axi_w_count;

        axi_aw_ready = 1'b1;
        axi_w_ready  = 1'b1;

        send_axil_w(32'hCAFE_BABE, 4'b0011);

        wait_cycles(3);

        check(
            axi_aw_count == start_aw_count,
            "AXI AW is not issued before AXI-Lite AW arrives"
        );

        check(
            axi_w_count == start_w_count,
            "AXI W is not issued before complete write request"
        );

        send_axil_aw(32'h0000_3000, 3'b000);

        wait_cycles(2);

        check(
            axi_aw_count == start_aw_count + 1,
            "Exactly one AXI AW generated"
        );

        check(
            axi_w_count == start_w_count + 1,
            "Exactly one AXI W generated"
        );

        check_axi_write_fields(
            32'h0000_3000,
            3'b000,
            32'hCAFE_BABE,
            4'b0011
        );

        fork
            send_axi_b(2'b00);
            receive_axil_b(2'b00);
        join

        wait_cycles(2);

    end
endtask


// ------------------------------------------------------------
// Test 4: Independent AXI AW/W Backpressure
// ------------------------------------------------------------

task automatic test_write_axi_backpressure;
    int start_aw_count;
    int start_w_count;
    begin

        begin_test("WRITE_AXI_INDEPENDENT_BACKPRESSURE");

        start_aw_count = axi_aw_count;
        start_w_count  = axi_w_count;

        // Block both AXI channels initially
        axi_aw_ready = 1'b0;
        axi_w_ready  = 1'b0;

        fork
            send_axil_aw(32'h0000_4000, 3'b011);
            send_axil_w (32'hA5A5_5A5A, 4'b1111);
        join

        wait_cycles(2);

        check(
            m_req_o.aw_valid == 1'b1,
            "AWVALID remains asserted while AXI AWREADY is low"
        );

        check(
            m_req_o.w_valid == 1'b1,
            "WVALID remains asserted while AXI WREADY is low"
        );

        check(
            axi_aw_count == start_aw_count,
            "No AXI AW handshake while AWREADY is low"
        );

        check(
            axi_w_count == start_w_count,
            "No AXI W handshake while WREADY is low"
        );

        // Accept AW only
        @(negedge clk_i);
        axi_aw_ready = 1'b1;

        wait_cycles(1);

        check(
            axi_aw_count == start_aw_count + 1,
            "AXI AW accepted independently"
        );

        check(
            axi_w_count == start_w_count,
            "AXI W remains pending"
        );

        check(
            m_req_o.w_valid == 1'b1,
            "WVALID remains asserted until W handshake"
        );

        // Accept W later
        @(negedge clk_i);
        axi_w_ready = 1'b1;

        wait_cycles(1);

        check(
            axi_w_count == start_w_count + 1,
            "AXI W accepted independently"
        );

        check_axi_write_fields(
            32'h0000_4000,
            3'b011,
            32'hA5A5_5A5A,
            4'b1111
        );

        fork
            send_axi_b(2'b10);
            receive_axil_b(2'b10);
        join

        wait_cycles(2);

    end
endtask


// ------------------------------------------------------------
// Test 5: Read Transaction
//
// IMPORTANT:
// This test checks that exactly one AXI AR transaction is issued.
// Your currently supplied RTL is expected to fail this requirement
// because it does not track completion of the AXI AR handshake.
// ------------------------------------------------------------

task automatic test_read_single_transaction;
    int start_ar_count;
    begin

        begin_test("READ_SINGLE_TRANSACTION");

        start_ar_count = axi_ar_count;

        axi_ar_ready = 1'b1;

        send_axil_ar(
            32'h0000_5000,
            3'b101
        );

        // Keep ARREADY high for several cycles.
        // A correct bridge must generate exactly ONE AR handshake.
        wait_cycles(4);

        check(
            axi_ar_count == start_ar_count + 1,
            "Exactly one AXI AR transaction generated per AXI-Lite read"
        );

        check_axi_read_fields(
            32'h0000_5000,
            3'b101
        );

        fork
            send_axi_r(32'hFACE_CAFE, 2'b00);
            receive_axil_r(32'hFACE_CAFE, 2'b00);
        join

        wait_cycles(2);

    end
endtask


// ------------------------------------------------------------
// Test 6: Read AXI Backpressure
// ------------------------------------------------------------

task automatic test_read_axi_backpressure;
    int start_ar_count;
    begin

        begin_test("READ_AXI_BACKPRESSURE");

        start_ar_count = axi_ar_count;

        axi_ar_ready = 1'b0;

        send_axil_ar(
            32'h0000_6000,
            3'b010
        );

        wait_cycles(2);

        check(
            m_req_o.ar_valid == 1'b1,
            "ARVALID remains asserted while AXI ARREADY is low"
        );

        check(
            axi_ar_count == start_ar_count,
            "No AR handshake while AXI ARREADY is low"
        );

        @(negedge clk_i);
        axi_ar_ready = 1'b1;

        wait_cycles(1);

        check(
            axi_ar_count == start_ar_count + 1,
            "AXI AR handshake occurs when ARREADY becomes high"
        );

        // Correct RTL must deassert ARVALID after handshake.
        wait_cycles(1);

        check(
            m_req_o.ar_valid == 1'b0,
            "ARVALID deasserts after AXI AR handshake"
        );

        fork
            send_axi_r(32'h0BAD_F00D, 2'b10);
            receive_axil_r(32'h0BAD_F00D, 2'b10);
        join

        wait_cycles(2);

    end
endtask


// ------------------------------------------------------------
// Test 7: One Outstanding Transaction
//
// While a write transaction is active, a read should not be
// accepted.
// ------------------------------------------------------------

task automatic test_single_outstanding_transaction;
    begin

        begin_test("SINGLE_OUTSTANDING_TRANSACTION");

        axi_aw_ready = 1'b0;
        axi_w_ready  = 1'b0;

        fork
            send_axil_aw(32'h0000_7000, 3'b000);
            send_axil_w (32'h1111_2222, 4'hF);
        join

        wait_cycles(1);

        check(
            s_rsp_o.ar_ready == 1'b0,
            "Read address is blocked while write transaction is active"
        );

        @(negedge clk_i);

        s_req_i.ar.addr  = 32'h0000_8000;
        s_req_i.ar.prot  = 3'b000;
        s_req_i.ar_valid = 1'b1;

        wait_cycles(2);

        check(
            !(s_req_i.ar_valid && s_rsp_o.ar_ready),
            "AXI-Lite read is not accepted during outstanding write"
        );

        // Complete write
        @(negedge clk_i);
        axi_aw_ready = 1'b1;
        axi_w_ready  = 1'b1;

        wait_cycles(2);

        fork
            send_axi_b(2'b00);
            receive_axil_b(2'b00);
        join

        // Read request should now be accepted
        do begin
            @(posedge clk_i);
        end while (!s_rsp_o.ar_ready);

        @(negedge clk_i);
        s_req_i.ar_valid = 1'b0;

        // Complete the read
        axi_ar_ready = 1'b1;

        wait_cycles(2);

        fork
            send_axi_r(32'h3333_4444, 2'b00);
            receive_axil_r(32'h3333_4444, 2'b00);
        join

        wait_cycles(2);

    end
endtask


// ------------------------------------------------------------
// Test 8: Partial Write Strobes
// ------------------------------------------------------------

task automatic test_write_partial_strobe;
    int start_aw_count;
    int start_w_count;
    begin

        begin_test("WRITE_PARTIAL_STROBE");

        start_aw_count = axi_aw_count;
        start_w_count  = axi_w_count;

        axi_aw_ready = 1'b1;
        axi_w_ready  = 1'b1;

        fork
            send_axil_aw(32'h0000_9000, 3'b100);
            send_axil_w (32'h1122_3344, 4'b0101);
        join

        wait_cycles(2);

        check(
            axi_aw_count == start_aw_count + 1,
            "One AXI AW generated for partial strobe write"
        );

        check(
            axi_w_count == start_w_count + 1,
            "One AXI W generated for partial strobe write"
        );

        check(
            captured_w_strb == 4'b0101,
            "AXI-Lite WSTRB is preserved exactly"
        );

        fork
            send_axi_b(2'b11);
            receive_axil_b(2'b11);
        join

        wait_cycles(2);

    end
endtask


// ------------------------------------------------------------
// Main Test Sequence
// ------------------------------------------------------------

initial begin

    test_count  = 0;
    error_count = 0;

    reset_dut();

    // Write path tests
    test_write_simultaneous();
    test_write_aw_before_w();
    test_write_w_before_aw();
    test_write_axi_backpressure();
    test_write_partial_strobe();

    // Read path tests
    test_read_single_transaction();
    test_read_axi_backpressure();

    // Arbitration / outstanding transaction test
    test_single_outstanding_transaction();


    // --------------------------------------------------------
    // Final Result
    // --------------------------------------------------------

    $display("");
    $display("============================================================");
    $display("SIMULATION COMPLETE");
    $display("============================================================");
    $display("TOTAL TESTS : %0d", test_count);
    $display("ERRORS      : %0d", error_count);
    $display("============================================================");

    if (error_count == 0) begin
        $display("");
        $display("############################################");
        $display("#                                          #");
        $display("#              ALL TESTS PASSED            #");
        $display("#                                          #");
        $display("############################################");
    end
    else begin
        $display("");
        $display("############################################");
        $display("#                                          #");
        $display("#              TESTS FAILED                #");
        $display("#         ERROR COUNT = %0d               #", error_count);
        $display("#                                          #");
        $display("############################################");
    end

    wait_cycles(5);

    $finish;

end


// ------------------------------------------------------------
// Global Simulation Timeout
// ------------------------------------------------------------

initial begin
    #(CLK_PERIOD * 2000);

    $fatal(
        1,
        "Simulation timeout: possible DUT deadlock"
    );
end

endmodule
