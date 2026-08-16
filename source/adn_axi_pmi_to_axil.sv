/*
Module: adn_axi_pmi_to_axil
Purpose:
This module acts as a protocol bridge, converting simple PMI-style (Processor Memory Interface) 
slave requests into AXI4-Lite master transactions. It enables legacy or simplified 
peripheral interfaces to communicate with AXI4-Lite compliant interconnects or slaves.

Use Case:
This is intended for system-on-chip (SoC) designs where a lightweight, non-pipelined 
register access bus (PMI) needs to interface with standard AXI4-Lite peripherals. 
It is ideal for control-plane register access where transaction throughput is 
secondary to simplicity and compatibility.

Purpose
-------
Bridge from a simple PMI-style slave port (mreq/mwe/maddr/...) to an
AXI4-Lite master port. The original implementation lives in this file and
has been refactored to use the project's AXI4-Lite packed `request` and
`response` structs (see include/axil/typedef.svh) while preserving the
original scalar port interface for backwards compatibility.

Use Case
--------
Used where a PMI-style register access bus must be translated to an
AXI4-Lite master to talk to peripheral registers.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-13 | Motasim Faiyaz | Initial version (refactor to use typedef structs)      |
| 0.2      | 2026-08-14 | Motasim Faiyaz | Updated documentation and parameter descriptions       |

Author : Motasim Faiyaz (motasimfaiyaz@gmail.com)
This file is part of ADN-VLSI/adn_axi
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

`include "axil/typedef.svh"
`include "pmi/typedef.svh"

// =============================================================================
// adn_axi_pmi_to_axil
// -----------------------------------------------------------------------------
// PMI slave port (mreq/mgnt/maddr/mwe/mwdata/mstrb -> mack/mrsp/mrdata)
// bridged to an AXI4-Lite master port.
//
// Single transaction outstanding at a time: a new PMI request is only
// granted once the previous transaction's AXI response has been fully
// consumed. See the design note at the bottom of this file for why this
// is the safe choice given the source diagram's shared-FIFO response
// arbitration.
// =============================================================================

module adn_axi_pmi_to_axil #(
  parameter int ADDR_WIDTH = 32,          // Width of the address bus
  parameter int DATA_WIDTH = 32,          // Width of the data bus
  parameter int STRB_WIDTH = DATA_WIDTH / 8 // Width of the write strobe signal
) (
  input  logic                  clk,      // System clock
  input  logic                  rst_n,    // Asynchronous, active-low reset

  // ---------------- PMI slave port ----------------
  input  logic                  mreq,     // Request signal from PMI master
  input  logic                  mwe,      // Write enable: 1 for write, 0 for read
  input  logic [ADDR_WIDTH-1:0] maddr,    // Address bus
  input  logic [DATA_WIDTH-1:0] mwdata,   // Write data bus
  input  logic [STRB_WIDTH-1:0] mstrb,    // Write strobe
  output logic                  mgnt,     // Grant signal to PMI master
  output logic                  mack,     // Acknowledge signal to PMI master
  output logic [           1:0] mrsp,    // Response status (OKAY, SLVERR, etc.)
  output logic [DATA_WIDTH-1:0] mrdata,   // Read data bus

  // ---------------- AXI4-Lite master port : AW ----------------
  output logic [ADDR_WIDTH-1:0] aw_addr,  // AXI write address
  output logic [           2:0] aw_prot,  // AXI protection type
  output logic                  aw_valid, // AXI write address valid
  input  logic                  aw_ready, // AXI write address ready

  // ---------------- AXI4-Lite master port : W ----------------
  output logic [DATA_WIDTH-1:0] w_data,   // AXI write data
  output logic [STRB_WIDTH-1:0] w_strb,   // AXI write strobe
  output logic                  w_valid,  // AXI write valid
  input  logic                  w_ready,  // AXI write ready

  // ---------------- AXI4-Lite master port : B ----------------
  input  logic [           1:0] b_rsp,   // AXI write response
  input  logic                  b_valid,  // AXI write response valid
  output logic                  b_ready,  // AXI write response ready

  // ---------------- AXI4-Lite master port : AR ----------------
  output logic [ADDR_WIDTH-1:0] ar_addr,  // AXI read address
  output logic [           2:0] ar_prot,  // AXI read protection type
  output logic                  ar_valid, // AXI read address valid
  input  logic                  ar_ready, // AXI read address ready

  // ---------------- AXI4-Lite master port : R ----------------
  input  logic [DATA_WIDTH-1:0] r_data,   // AXI read data
  input  logic [           1:0] r_rsp,   // AXI read response
  input  logic                  r_valid,  // AXI read valid
  output logic                  r_ready   // AXI read ready
);

  // Instantiate common request/response typedefs for use inside the module
  `AXIL_T(axil_m, ADDR_WIDTH, DATA_WIDTH)
  `PMI_T(pmi, ADDR_WIDTH, DATA_WIDTH)

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS GENERATED
  //////////////////////////////////////////////////////////////////////////////////////////////////
  localparam logic [1:0] S_IDLE      = 2'd0;
  localparam logic [1:0] S_ADDR_DATA = 2'd1;  // AW/W (write) or AR (read) outstanding
  localparam logic [1:0] S_RESP      = 2'd2;  // waiting on B (write) or R (read)

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  logic [1:0]             state_q, state_d; // FSM state registers

  logic                   is_write_q;          // Latched transaction type: 1=Write, 0=Read
  logic [ADDR_WIDTH-1:0]  addr_q;              // Latched address
  logic [DATA_WIDTH-1:0]  wdata_q;             // Latched write data
  logic [STRB_WIDTH-1:0]  wstrb_q;             // Latched write strobe

  logic                   aw_pend_q, aw_pend_d; // Sticky-valid for AW channel
  logic                   w_pend_q,  w_pend_d;  // Sticky-valid for W channel
  logic                   ar_pend_q, ar_pend_d; // Sticky-valid for AR channel

  // AXI4-Lite and PMI request / response structs (internal usage)
  axil_m_req_t            axil_req_s;
  axil_m_rsp_t           axil_rsp_s;
  pmi_req_t               pmi_req_s;
  pmi_rsp_t              pmi_rsp_s;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  logic accept;           // Handshake: mreq & mgnt this cycle
  logic addr_phase_done;  // Address/Data phase completion status
  logic rsp_done;        // Response phase completion status

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  assign mgnt   = (state_q == S_IDLE);
  assign accept = mreq & mgnt;

  assign addr_phase_done = is_write_q ? (~aw_pend_q & ~w_pend_q)
                                       : (~ar_pend_q);

  // AW channel
  // Build internal AXI4-Lite request struct from latched values
  assign axil_req_s.aw.addr  = addr_q;
  assign axil_req_s.aw.prot  = 3'b000;
  assign axil_req_s.aw_valid = aw_pend_q;

  assign axil_req_s.w.data   = wdata_q;
  assign axil_req_s.w.strb   = wstrb_q;
  assign axil_req_s.w_valid  = w_pend_q;

  assign axil_req_s.ar.addr  = addr_q;
  assign axil_req_s.ar.prot  = 3'b000;
  assign axil_req_s.ar_valid = ar_pend_q;

  // Use the common PMI request/response structs for the host-side payloads.
  assign pmi_req_s.maddr  = addr_q;
  assign pmi_req_s.mwe    = is_write_q;
  assign pmi_req_s.mwdata = wdata_q;
  assign pmi_req_s.mstrb  = wstrb_q;
  assign pmi_req_s.mreq   = accept;

  assign pmi_rsp_s.mgnt  = mgnt;
  assign pmi_rsp_s.mack  = mack;
  assign pmi_rsp_s.mrdata = mrdata;
  assign pmi_rsp_s.mrsp = mrsp[0];

  // B / R channel readiness - driven by bridge state
  assign axil_req_s.b_ready  = (state_q == S_RESP) &  is_write_q;
  assign axil_req_s.r_ready  = (state_q == S_RESP) & ~is_write_q;

  // Map scalar response ports into the internal AXIL response struct
  assign axil_rsp_s.aw_ready = aw_ready;
  assign axil_rsp_s.w_ready  = w_ready;
  assign axil_rsp_s.b.rsp   = b_rsp;
  assign axil_rsp_s.b_valid  = b_valid;
  assign axil_rsp_s.ar_ready = ar_ready;
  assign axil_rsp_s.r.data   = r_data;
  assign axil_rsp_s.r.rsp   = r_rsp;
  assign axil_rsp_s.r_valid  = r_valid;

  // PMI response port (driven from internal AXIL response struct)
  assign rsp_done = is_write_q ? (axil_rsp_s.b_valid & axil_req_s.b_ready)
                               : (axil_rsp_s.r_valid & axil_req_s.r_ready);

  assign mack   = (state_q == S_RESP) & rsp_done;
  assign mrsp  = is_write_q ? axil_rsp_s.b.rsp : axil_rsp_s.r.rsp;
  assign mrdata = axil_rsp_s.r.data;  // don't-care / 0 during writes, real data during reads

  // Map internal request struct fields to scalar AXIL master output ports
  assign aw_addr  = axil_req_s.aw.addr;
  assign aw_prot  = axil_req_s.aw.prot;
  assign aw_valid = axil_req_s.aw_valid;

  assign w_data  = axil_req_s.w.data;
  assign w_strb  = axil_req_s.w.strb;
  assign w_valid = axil_req_s.w_valid;

  assign ar_addr  = axil_req_s.ar.addr;
  assign ar_prot  = axil_req_s.ar.prot;
  assign ar_valid = axil_req_s.ar_valid;

  // Map host-ready signals from struct to scalar ports
  assign b_ready = axil_req_s.b_ready;
  assign r_ready = axil_req_s.r_ready;

  // next-state logic
  always_comb begin
    state_d = state_q;
    unique case (state_q)
      S_IDLE:      if (accept)          state_d = S_ADDR_DATA;
      S_ADDR_DATA: if (addr_phase_done) state_d = S_RESP;
      S_RESP:      if (rsp_done)       state_d = S_IDLE;
      default:                          state_d = S_IDLE;
    endcase
  end

  // sticky AW/W/AR valid tracking
  always_comb begin
    aw_pend_d = aw_pend_q;
    w_pend_d  = w_pend_q;
    ar_pend_d = ar_pend_q;

    if (accept) begin
      aw_pend_d =  mwe;
      w_pend_d  =  mwe;
      ar_pend_d = ~mwe;
    end else begin
      if (aw_pend_q & aw_ready) aw_pend_d = 1'b0;
      if (w_pend_q  & w_ready)  w_pend_d  = 1'b0;
      if (ar_pend_q & ar_ready) ar_pend_d = 1'b0;
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIAL LOGIC
  //////////////////////////////////////////////////////////////////////////////////////////////////
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q    <= S_IDLE;
      is_write_q <= 1'b0;
      addr_q     <= '0;
      wdata_q    <= '0;
      wstrb_q    <= '0;
      aw_pend_q  <= 1'b0;
      w_pend_q   <= 1'b0;
      ar_pend_q  <= 1'b0;
    end else begin
      state_q   <= state_d;
      aw_pend_q <= aw_pend_d;
      w_pend_q  <= w_pend_d;
      ar_pend_q <= ar_pend_d;

      if (accept) begin
        is_write_q <= mwe;
        addr_q     <= maddr;
        wdata_q    <= mwdata;
        wstrb_q    <= mstrb;
      end
    end
  end

endmodule

// =============================================================================
// DESIGN NOTE - why the diagram's shared response FIFO needed to change
// -----------------------------------------------------------------------------
// The source diagram queues the request "type" (read/write) bit into a FIFO
// so that, later, whichever response arrives can be routed back onto the
// single PMI response port. That works ONLY if requests are still completed
// strictly in order - but AXI4-Lite gives NO ordering guarantee between the
// B and R channels. If the bridge is allowed to have a write and a read
// outstanding at the same time (write's address phase finishes, its B
// response is still pending, and a read is then issued), the read's R
// response can legally arrive before the write's B response. Gating
// b_ready/r_ready off a single shared FIFO head (as drawn) would then
// withhold r_ready while waiting for a B response that hasn't shown up yet,
// stalling - and on a shared interconnect, potentially deadlocking - the
// read channel.
//
// This implementation removes the hazard by only ever allowing one
// transaction in flight at a time (mgnt is only asserted from S_IDLE, after
// the previous transaction's response has been consumed), so "the FIFO"
// collapses to a single is_write_q register and b_ready/r_ready can safely
// be gated on it.
//
// If multiple outstanding transactions are actually needed for throughput,
// the correct extension is two independent outstanding-counters (one per
// AXI channel, not one shared FIFO) to generate b_ready/r_ready, plus a
// small in-order completion buffer in front of mack/mrsp/mrdata so that
// an early response can be held until it's actually its turn to be
// reported on the single, non-tagged PMI response port. Happy to write that
// version if you need the extra pipelining.
// =============================================================================
