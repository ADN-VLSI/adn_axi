/*

@foez-bhai, write the purpose of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

@foez-bhai, describe the use case of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-09-03 | Motasim Faiyaz | Initial version                                        |
| 1.0      | 2026-09-03 | Motasim Faiyaz | Stable release                                         |

Author : Motasim Faiyaz (motasimfaiyaz@gmail.com)
This file is part of ADN-VLSI/adn_axi
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

// =============================================================================
// Module      : adn_axi_agu_burst_splitter
// Description : Address Generation Unit (AGU) that splits a single AXI4 (full)
//               write burst (FIXED / INCR / WRAP) into a sequence of single-
//               beat AXI4-Lite write transactions.
//
//               Mirrors the block diagram exactly:
//                 - a 2:1:0 MUX (on AWBURST) selects one of three
//                   "address decipheral" lanes (WRAP / INCR / FIXED) which
//                   compute ADDR_L / ADDR_U / LEN / size once per burst.
//                 - each lane's counter (W_COUNTER / I_COUNTER / F_COUNTER)
//                   walks the per-beat address `i` per the pseudo-code in the
//                   diagram.
//                 - a DEMUX (same select) drives the single AXI4-Lite AWADDR
//                   with whichever lane is active.
//               The three lanes are implemented as one shared datapath
//               (case-selected adder/mask) rather than three physical mux/
//               demux-fed blocks -- functionally identical, far cheaper.
//
//               The diagram's hs_comb_axi4l() call (the block that was
//               missing from the picture) is implemented below as the
//               HANDSHAKE COMBINER section: it independently tracks
//               completion of the AXI4-Lite AW channel and W channel for the
//               current beat and only lets the loop advance once BOTH have
//               fired -- AXI4/AXI4-Lite do not guarantee AW/W completing on
//               the same cycle, so they cannot be advanced blindly together.
//
// Assumptions (per spec given):
//   - WDATA is the same width on the AXI4 and AXI4-Lite side -> no width
//     conversion, WDATA/WSTRB are passed through combinationally beat-by-beat.
//   - AWPROT/AWCACHE/AWLOCK/AWQOS/AWID/AWUSER are don't-care on the AXI4-Lite
//     side (AXI4-Lite doesn't have most of these anyway); AWID is only
//     latched so it can be echoed back on BID.
//   - Only the write burst path (AW/W/B) is built, matching the diagram.
//     A mirrored AR/R AGU would be needed for read bursts.
// =============================================================================



module adn_axi_agu_burst_splitter #(
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // PARAMETERS
    //////////////////////////////////////////////////////////////////////////////////////////////////
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int ID_WIDTH   = 4,
    parameter int STRB_WIDTH = DATA_WIDTH/8,
    parameter type axi_req_t  = logic,
    parameter type axi_rsp_t  = logic,
    parameter type axil_req_t = logic,
    parameter type axil_rsp_t = logic
) (
    input  logic                    clk_i,
    input  logic                    arst_ni,

    //////////////////////////////////////////////////////////////////////////////////////////////////
    // INTERFACES : AXI4 (full) slave -- burst side
    //////////////////////////////////////////////////////////////////////////////////////////////////
    input  axi_req_t                axi_req_i,
    output axi_rsp_t                axi_rsp_o,

    //////////////////////////////////////////////////////////////////////////////////////////////////
    // INTERFACES : AXI4-Lite master -- split single-beat side
    //////////////////////////////////////////////////////////////////////////////////////////////////
    output axil_req_t               axil_req_o,
    input  axil_rsp_t                axil_rsp_i
);

  // @foez-bhai, add comments to the functional blocks, signals, and submodules

    //////////////////////////////////////////////////////////////////////////////////////////////////
    // LOCALPARAMS
    //////////////////////////////////////////////////////////////////////////////////////////////////
    localparam logic [2:0] AXBURST_FIXED = 3'b000;
    localparam logic [2:0] AXBURST_INCR  = 3'b001;
    localparam logic [2:0] AXBURST_WRAP  = 3'b010;

    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_EXOKAY = 2'b01;
    localparam logic [1:0] RESP_SLVERR = 2'b10;
    localparam logic [1:0] RESP_DECERR = 2'b11;

    //////////////////////////////////////////////////////////////////////////////////////////////////
    // TYPEDEFS
    //////////////////////////////////////////////////////////////////////////////////////////////////
    typedef enum logic [2:0] {
        S_IDLE,       // wait for a new AXI4 write burst
        S_DECODE,     // "address decipheral": compute ADDR_L/ADDR_U/size/LEN
        S_BEAT,       // drive one AXI4-Lite AW+W beat, run handshake combiner
        S_WAIT_BRESP, // wait for that beat's BRESP
        S_NEXT_BEAT,  // advance address/loop counter per burst type
        S_RESP        // return the aggregated response to the AXI4 master
    } state_e;

    //////////////////////////////////////////////////////////////////////////////////////////////////
    // SIGNALS / VARIABLES
    //////////////////////////////////////////////////////////////////////////////////////////////////
    state_e                    state_q, state_d;

    // Latched burst request ("address decipheral" inputs)
    logic [ID_WIDTH-1:0]       awid_q;
    logic [ADDR_WIDTH-1:0]     awaddr_q;
    logic [7:0]                awlen_q;
    logic [2:0]                awsize_q;
    logic [2:0]                awburst_q;

    // Address-decipheral outputs (computed once in S_DECODE)
    logic [ADDR_WIDTH-1:0]     addr_l_q, addr_u_q;
    logic [ADDR_WIDTH-1:0]     capacity;         // WRAP boundary window size
    logic [ADDR_WIDTH-1:0]     wrap_mask;

    // Counter ("W_COUNTER/I_COUNTER/F_COUNTER") state
    logic [8:0]                beat_cnt_q;       // j : 0 .. awlen_q (up to 256)
    logic [ADDR_WIDTH-1:0]     cur_addr_q;       // i : current beat address
    logic [ADDR_WIDTH-1:0]     next_addr;        // i+2^size, pre-wrap-check
    logic                      last_beat;        // j == awlen_q

    // Response aggregation across all split beats
    logic [1:0]                bresp_q;

    // HANDSHAKE COMBINER state -- per-beat AW/W completion tracking
    logic                      aw_done_q, w_done_q;
    logic                      aw_fire, w_fire;
    logic                      beat_hs_done;      // == hs_comb_axi4l()
    logic [1:0]                hs_valid_i, hs_ready_i, hs_valid_o;

    //////////////////////////////////////////////////////////////////////////////////////////////////
    // ASSIGNMENTS
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Address-decipheral: capacity/mask only meaningful for WRAP, computed
    // combinationally off the latched request during S_DECODE.
    assign capacity  = ({{(ADDR_WIDTH-8){1'b0}}, awlen_q} + 1'b1) << awsize_q;
    assign wrap_mask = capacity - 1'b1;

    assign next_addr = cur_addr_q + ({{(ADDR_WIDTH-1){1'b0}}, 1'b1} << awsize_q);
    assign last_beat = (beat_cnt_q == {1'b0, awlen_q});

    // ---- HANDSHAKE COMBINER (hs_comb_axi4l) ----------------------------
    // Fires each channel's valid independently, latches "done" the cycle it
    // is accepted, and only declares the beat complete once BOTH the AW and
    // W channels have completed -- they are not guaranteed to accept on the
    // same cycle.
    always_comb begin
        axil_req_o      = '0;
        axil_req_o.aw.addr  = cur_addr_q;
        axil_req_o.aw.prot  = 3'b000;
        axil_req_o.aw_valid = (state_q == S_BEAT) && !aw_done_q;
        axil_req_o.w.data   = axi_req_i.w.data;
        axil_req_o.w.strb   = axi_req_i.w.strb;
        axil_req_o.w_valid  = (state_q == S_BEAT) && !w_done_q && axi_req_i.w_valid;
        axil_req_o.b_ready  = (state_q == S_WAIT_BRESP);
    end

    always_comb begin
        axi_rsp_o      = '0;
        axi_rsp_o.aw_ready = (state_q == S_IDLE);
        axi_rsp_o.w_ready  = axil_req_o.w_valid && axil_rsp_i.w_ready;
        axi_rsp_o.b.id     = awid_q;
        axi_rsp_o.b.resp   = bresp_q;
        axi_rsp_o.b_valid  = (state_q == S_RESP);
    end

    assign aw_fire       = axil_req_o.aw_valid && axil_rsp_i.aw_ready;
    assign w_fire        = axil_req_o.w_valid  && axil_rsp_i.w_ready;

    // Treat a previously completed channel as valid and ready so the
    // combinator joins it with the channel that completes this cycle.
    assign hs_valid_i = {axil_req_o.aw_valid || aw_done_q,
                         axil_req_o.w_valid  || w_done_q};
    assign hs_ready_i = {axil_rsp_i.aw_ready || aw_done_q,
                         axil_rsp_i.w_ready  || w_done_q};

    adn_common_hs_combiner #(
        .NUM_TX(2),
        .NUM_RX(2)
    ) u_beat_hs_combiner (
        .valid_i(hs_valid_i),
        .ready_o(),
        .valid_o(hs_valid_o),
        .ready_i(hs_ready_i)
    );

    assign beat_hs_done = hs_valid_o[0];

    //////////////////////////////////////////////////////////////////////////////////////////////////
    // RTLS : next-state logic
    //////////////////////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        state_d = state_q;
        unique case (state_q)
            S_IDLE:       if (axi_req_i.aw_valid && axi_rsp_o.aw_ready) state_d = S_DECODE;
            S_DECODE:     state_d = S_BEAT;
            S_BEAT:       if (beat_hs_done) state_d = S_WAIT_BRESP;
            S_WAIT_BRESP: if (axil_rsp_i.b_valid && axil_req_o.b_ready) state_d = S_NEXT_BEAT;
            S_NEXT_BEAT:  state_d = last_beat ? S_RESP : S_BEAT;
            S_RESP:       if (axi_rsp_o.b_valid && axi_req_i.b_ready) state_d = S_IDLE;
            default:      state_d = S_IDLE;
        endcase
    end

    //////////////////////////////////////////////////////////////////////////////////////////////////
    // SEQUENTIALS
    //////////////////////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            state_q    <= S_IDLE;
            awid_q     <= '0;
            awaddr_q   <= '0;
            awlen_q    <= '0;
            awsize_q   <= '0;
            awburst_q  <= '0;
            addr_l_q   <= '0;
            addr_u_q   <= '0;
            beat_cnt_q <= '0;
            cur_addr_q <= '0;
            bresp_q    <= RESP_OKAY;
            aw_done_q  <= 1'b0;
            w_done_q   <= 1'b0;
        end else begin
            state_q <= state_d;

            unique case (state_q)
                // Latch the incoming burst request
                S_IDLE: begin
                    if (axi_req_i.aw_valid && axi_rsp_o.aw_ready) begin
                        awid_q    <= axi_req_i.aw.id;
                        awaddr_q  <= axi_req_i.aw.addr;
                        awlen_q   <= axi_req_i.aw.len;
                        awsize_q  <= axi_req_i.aw.size;
                        awburst_q <= axi_req_i.aw.burst;
                        bresp_q   <= RESP_OKAY;
                    end
                end

                // "address decipheral": one-shot per-burst-type decode,
                // equivalent to the MUX-selected lane in the diagram
                S_DECODE: begin
                    unique case (awburst_q)
                        AXBURST_WRAP: begin
                            addr_l_q   <= awaddr_q & ~wrap_mask;
                            addr_u_q   <= (awaddr_q & ~wrap_mask) + capacity;
                            cur_addr_q <= awaddr_q;
                        end
                        AXBURST_FIXED: begin
                            addr_l_q   <= awaddr_q;
                            cur_addr_q <= awaddr_q;
                        end
                        default: begin // AXBURST_INCR
                            addr_l_q   <= awaddr_q;
                            cur_addr_q <= awaddr_q;
                        end
                    endcase
                    beat_cnt_q <= '0;
                    aw_done_q  <= 1'b0;
                    w_done_q   <= 1'b0;
                end

                // Drive the beat; handshake combiner latches per-channel
                // completion until both fire
                S_BEAT: begin
                    if (aw_fire) aw_done_q <= 1'b1;
                    if (w_fire)  w_done_q  <= 1'b1;
                end

                // Capture this beat's response, sticky-OR the worst case
                // (SLVERR/DECERR outrank OKAY/EXOKAY) into the aggregate
                S_WAIT_BRESP: begin
                    if (axil_rsp_i.b_valid && axil_req_o.b_ready) begin
                        if (axil_rsp_i.b.resp > bresp_q) bresp_q <= axil_rsp_i.b.resp;
                    end
                end

                // Advance the loop counter / per-beat address exactly as
                // the counter pseudo-code in the diagram does
                S_NEXT_BEAT: begin
                    aw_done_q  <= 1'b0;
                    w_done_q   <= 1'b0;
                    beat_cnt_q <= beat_cnt_q + 1'b1;
                    unique case (awburst_q)
                        AXBURST_FIXED: cur_addr_q <= cur_addr_q; // i = i
                        AXBURST_WRAP:  cur_addr_q <= (next_addr == addr_u_q) ? addr_l_q : next_addr;
                        default:       cur_addr_q <= next_addr; // AXBURST_INCR
                    endcase
                end

                default: ;
            endcase
        end
    end

endmodule