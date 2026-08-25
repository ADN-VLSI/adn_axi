/*

### Purpose
This module serves as a bridge interface that converts PMI (Processor Memory Interface) protocol requests into AXI4-Lite master transactions. It manages address steering, write/read data handling, and response tracking using an internal FIFO to maintain transaction ordering and completion status.

### Use Case
The `adn_axi_pmi_to_axil` module is designed for SoC architectures where a processor or IP core utilizing the PMI protocol needs to interface with AXI4-Lite compliant peripherals or memory-mapped registers. It acts as a protocol translator, allowing the system to bridge lightweight, low-latency PMI requests into standard AXI4-Lite bus transactions. By incorporating an internal FIFO, it ensures that transaction ordering is preserved, making it suitable for systems requiring strict memory consistency or sequential completion of read/write operations across the bridge.

| REVISION | DATE       | AUTHOR         | DESCRIPTION                                            |
|----------|------------|----------------|--------------------------------------------------------|
| 1.0      | 2026-08-13 | Motasim Faiyaz | Initial version                                        |
| 1.1      | 2026-08-23 | Motasim Faiyaz | Added response tracking                                |
| 1.2      | 2026-08-24 | Motasim Faiyaz | Uses pre-built subcomponents  utility                  |

Author : Motasim Faiyaz (motasimfaiyaz@gmail.com)
This file is part of ADN-VLSI/adn_axi
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/


module adn_axi_pmi_to_axil #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter type pmi_req_t = logic,
    parameter type pmi_rsp_t = logic,
    parameter type axil_req_t = logic,
    parameter type axil_rsp_t = logic,
    parameter int OP_FIFO_SIZE = 2   // log2 depth of the op-type tracking FIFO
) (
    input logic clk_i,
    input logic arst_ni,
 
    // ------------------------------------------------------------------------
    // PMI slave interface
    // ------------------------------------------------------------------------
    input  pmi_req_t pmi_req_i,
    output pmi_rsp_t pmi_rsp_o,
 
    // ------------------------------------------------------------------------
    // AXI4-Lite master interface
    // ------------------------------------------------------------------------
    output axil_req_t axil_req_o,
    input  axil_rsp_t axil_rsp_i
);
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  // HS COMN #1 (req side): TX=mreq, RX={addr-path ready, FIFO-push ready}
  logic       req_valid;          // broadcast valid_o from u_req_hs_comn (all bits equal)
  logic [1:0] req_hs_valid_o;
  logic [1:0] req_hs_ready_i;
 
  // address-channel steering (demux on mwe)
  logic wr_select_valid, rd_addr_valid;
  logic addr_path_ready;     // selected address path's accept signal (raw, unlooped)
 
  // HS COMN #2 (write side): TX=wr_select_valid, RX={aw_ready, w_ready}
  logic [1:0] wr_hs_valid_o;
 
  // op-type FIFO (push side)
  logic fifo_push_valid, fifo_push_ready;
 
  // op-type FIFO (pop side)
  logic fifo_pop_valid, fifo_pop_ready;
  logic op_type_head;        // 1 = head-of-line outstanding txn is a write
 
  // response join
  logic resp_fire;
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  // HS COMN #1 : mreq/mgnt joined against {addr-path ready, FIFO-push ready}
  adn_common_hs_combiner #(
      .NUM_TX(1),
      .NUM_RX(2)
  ) u_req_hs_comn (
      .valid_i(pmi_req_i.mreq),
      .ready_o(pmi_rsp_o.mgnt),
      .valid_o(req_hs_valid_o),
      .ready_i(req_hs_ready_i)
  );
 
  assign req_valid         = req_hs_valid_o[0];  // both bits equal by construction
  assign req_hs_ready_i[0] = addr_path_ready;
  assign req_hs_ready_i[1] = fifo_push_ready;
 
  // HS COMN #2 : joins aw_valid/w_valid against {aw_ready, w_ready}.
  // ready_o is intentionally left unconnected: it would just re-derive
  // "wr_select_valid & aw_ready & w_ready", and feeding it back into
  // u_req_hs_comn's ready_i (below) would close a combinational loop
  // through wr_select_valid, which is itself derived from req_valid.
  adn_common_hs_combiner #(
      .NUM_TX(1),
      .NUM_RX(2)
  ) u_wr_hs_comn (
      .valid_i(wr_select_valid),
      .ready_o(),
      .valid_o(wr_hs_valid_o),
      .ready_i({axil_rsp_i.aw_ready, axil_rsp_i.w_ready})
  );
 
  // FIFO : op-type tracker (1-bit payload = mwe), drives the response-side
  // mux/demux for mresp/mrdata/mack and b_ready/r_ready routing
  adn_common_fifo #(
      .DATA_WIDTH(1),
      .FIFO_SIZE (OP_FIFO_SIZE),
      .PIPELINED (1)
  ) u_op_type_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       (pmi_req_i.mwe),
      .data_in_valid_i (fifo_push_valid),
      .data_in_ready_o (fifo_push_ready),
      .count_o         (),
      .data_out_o      (op_type_head),
      .data_out_valid_o(fifo_pop_valid),
      .data_out_ready_i(fifo_pop_ready)
  );
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS - demux (addr, sel = mwe) + FIFO push
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  // selected address path's own accept signal, fed back into HS COMN #1.
  // Built from the raw AXI readies (same signals HS COMN #2 reads) so
  // there is no combinational path back through HS COMN #2's own output.
  assign addr_path_ready = pmi_req_i.mwe
      ? (axil_rsp_i.aw_ready & axil_rsp_i.w_ready)
      : axil_rsp_i.ar_ready;
 
  // req_valid is already qualified (by HS COMN #1) against both branches'
  // readiness, so it can fan out to whichever branch mwe selects, and to
  // the FIFO push, without any further gating.
  assign wr_select_valid  = req_valid &  pmi_req_i.mwe;
  assign rd_addr_valid    = req_valid & ~pmi_req_i.mwe;
  assign fifo_push_valid  = req_valid;
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS - AXI4-Lite write channels (AW/W driven together by HS COMN #2)
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  assign axil_req_o.aw.addr = pmi_req_i.maddr;
  assign axil_req_o.aw.prot = 3'b000;
  assign axil_req_o.aw_valid = wr_hs_valid_o[0];
 
  assign axil_req_o.w.data = pmi_req_i.mwdata;
  assign axil_req_o.w.strb = pmi_req_i.mstrb;
  assign axil_req_o.w_valid = wr_hs_valid_o[1];
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS - AXI4-Lite read address channel
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  assign axil_req_o.ar.addr = pmi_req_i.maddr;
  assign axil_req_o.ar.prot = 3'b000;
  assign axil_req_o.ar_valid = rd_addr_valid;
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS - response-side demux (b_ready/r_ready, sel = op_type_head)
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  assign axil_req_o.b_ready = fifo_pop_valid &  op_type_head;
  assign axil_req_o.r_ready = fifo_pop_valid & ~op_type_head;
 
  assign resp_fire = op_type_head
      ? (axil_rsp_i.b_valid & axil_req_o.b_ready)
      : (axil_rsp_i.r_valid & axil_req_o.r_ready);
 
  assign fifo_pop_ready = resp_fire;
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS - response-side mux (mresp/mrdata/mack, sel = op_type_head)
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  assign pmi_rsp_o.mack   = resp_fire;
  assign pmi_rsp_o.mrdata = op_type_head ? '0 : axil_rsp_i.r.data;
  assign pmi_rsp_o.mresp   = op_type_head ? axil_rsp_i.b.resp[1] : axil_rsp_i.r.resp[1];
 
endmodule