/*

# Purpose
This module acts as a bridge between the AXI4-Lite protocol and a dual-port PMI (Parallel Memory Interface) system. It translates AXI4-Lite read and write transactions into PMI-compliant requests, managing handshake synchronization, transaction pipelining, and response buffering to ensure data integrity and protocol compliance.

### Use Case
The `adn_axi_axil_to_dual_pmi` module is designed for SoC architectures where an AXI4-Lite master (such as a CPU or DMA controller) needs to interface with a high-performance memory subsystem or peripheral that utilizes the PMI protocol. By decoupling the AXI4-Lite handshake from the PMI request/acknowledge cycle, this module allows for pipelined memory access, effectively hiding memory latency and preventing bus stalls during high-throughput operations.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-13 | Adnan Sami Anirban | Initial version                                        |
| 1.0      | 2026-08-13 | Adnan Sami Anirban | Stable release                                         |

Author : Adnan Sami Anirban (adnananirban259@gmail.com)
This file is part of ADN-VLSI/adn_axi
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_axi_axil_to_dual_pmi #(
    // PARAMETERS
    parameter type  axil_req_t      = logic, // AXI4-Lite request struct type
    parameter type  axil_rsp_t      = logic, // AXI4-Lite response struct type
    parameter type  pmi_req_t       = logic, // PMI request struct type
    parameter type  pmi_rsp_t       = logic, // PMI response struct type
    parameter int   PIPELINE_DEPTH  = 8,     // Max number of in-flight transactions
    parameter int   FIFO_SIZE       = $clog2(PIPELINE_DEPTH) // FIFO depth based on pipeline
) (
    // PORTS
    input  logic       clk_i,        // System clock
    input  logic       arst_ni,      // Active-low asynchronous reset

    input  axil_req_t  axil_req_i,   // AXI4-Lite input request
    output axil_rsp_t  axil_rsp_o,   // AXI4-Lite output response

    output pmi_req_t   pmi_req_wr_o, // PMI write request output
    input  pmi_rsp_t   pmi_rsp_wr_i, // PMI write response input

    output pmi_req_t   pmi_req_rd_i, // PMI read request output
    input  pmi_rsp_t   pmi_rsp_rd_i  // PMI read response input
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Internal signals for Write path handshaking and FIFO
  // wr_hs1_comb_valid_o: Valid signal from first write handshake combiner
  // wr_hs_coun_ready_o/i: Ready signals for write handshake counter
  // wr_hs_coun_valid_o: Valid signal from write handshake counter
  logic wr_hs1_comb_valid_o, wr_hs_coun_ready_o, wr_hs_coun_valid_o, wr_hs_coun_ready_i;

  // w_fifo_pop_valid_o/ready_i: Handshake signals for write response FIFO output
  logic w_fifo_pop_valid_o, w_fifo_pop_ready_i;

  // Internal signals for Read path handshaking and FIFO
  // rd_hs1_comb_valid_o: Valid signal from first read handshake combiner
  // rd_hs_coun_ready_o/i: Ready signals for read handshake counter
  // rd_hs_coun_valid_o: Valid signal from read handshake counter
  logic rd_hs1_comb_valid_o, rd_hs_coun_ready_o, rd_hs_coun_valid_o, rd_hs_coun_ready_i;

  // r_fifo_pop_valid_o/ready_i: Handshake signals for read response FIFO output
  logic r_fifo_pop_valid_o, r_fifo_pop_ready_i;

  // Local parameter for read FIFO data width calculation
  localparam int RD_FIFO_DATA_WIDTH = $bits(pmi_rsp_rd_i.mrdata) + 2;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  
  // Mapping AXI Write Address/Data to PMI Write Request port
  always_comb pmi_req_wr_o.maddr  = axil_req_i.aw.addr;
  always_comb pmi_req_wr_o.mwdata = axil_req_i.w.data;
  always_comb pmi_req_wr_o.mstrb  = axil_req_i.w.strb;
  always_comb pmi_req_wr_o.mwe    = '1;

  // Mapping AXI Read Address to PMI Read Request port
  always_comb pmi_req_rd_i.maddr  = axil_req_i.ar.addr;
  always_comb pmi_req_rd_i.mwdata = '0;   
  always_comb pmi_req_rd_i.mstrb  = '0;   
  always_comb pmi_req_rd_i.mwe    = 1'b0;


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Write Path: First Handshake Combiner (AW + W channels)
  adn_common_hs_combiner #(
      .NUM_TX(2),
      .NUM_RX(2)
  ) wr_hs1 (
      .valid_i({axil_req_i.aw_valid, axil_req_i.w_valid }),
      .ready_o({axil_rsp_o.aw_ready, axil_rsp_o.w_ready }),
      .valid_o({pmi_req_wr_o.mreq  , wr_hs1_comb_valid_o}),
      .ready_i({pmi_rsp_wr_i.mgnt  , wr_hs_coun_ready_o })
  );

  // Write Path: Handshake Counter (Tracks outstanding write transactions)
  adn_common_hs_counter #(
      .DEPTH(PIPELINE_DEPTH)
  ) wr_hs_cnt(
      .clk_i            (clk_i           ),
      .arst_ni          (arst_ni         ),
      .data_in_valid_i  (wr_hs1_comb_valid_o),
      .data_in_ready_o  (wr_hs_coun_ready_o ),
      .count_o          (),
      .data_out_valid_o (wr_hs_coun_valid_o),
      .data_out_ready_i (wr_hs_coun_ready_i),
      .passing_through_o()
  );

  // Write Path: Second Handshake Combiner (B channel)
  adn_common_hs_combiner #(
      .NUM_TX(2),
      .NUM_RX(1)
  ) wr_hs2 (
      .valid_i({w_fifo_pop_valid_o, wr_hs_coun_valid_o }),
      .ready_o({w_fifo_pop_ready_i, wr_hs_coun_ready_i }),
      .valid_o({axil_rsp_o.b_valid}),
      .ready_i({axil_req_i.b_ready})
  );

  // Write Path: Response FIFO (Buffers PMI write completion status)
  adn_common_fifo #(
      .DATA_WIDTH (2),  
      .FIFO_SIZE  (FIFO_SIZE),
      .PIPELINED  (0)
  ) wr_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i  ),
      .data_in_i       (pmi_rsp_wr_i.mresp? 2'b10:2'b00),
      .data_in_valid_i (pmi_rsp_wr_i.mack),
      .data_in_ready_o (),
      .count_o         (),
      .data_out_o      (axil_rsp_o.b.resp),
      .data_out_valid_o(w_fifo_pop_valid_o),
      .data_out_ready_i(w_fifo_pop_ready_i)
  );

  // Read Path: First Handshake Combiner (AR channel)
  adn_common_hs_combiner #(
      .NUM_TX(1),
      .NUM_RX(2)
  ) rd_hs1 (
      .valid_i({axil_req_i.ar_valid}),
      .ready_o({axil_rsp_o.ar_ready}),
      .valid_o({pmi_req_rd_i.mreq, rd_hs1_comb_valid_o}),
      .ready_i({pmi_rsp_rd_i.mgnt, rd_hs_coun_ready_o})
  );

  // Read Path: Handshake Counter (Tracks outstanding read transactions)
  adn_common_hs_counter #(
      .DEPTH(PIPELINE_DEPTH)
  ) rd_hs_cnt (
      .clk_i            (clk_i),
      .arst_ni          (arst_ni),
      .data_in_valid_i  (rd_hs1_comb_valid_o),
      .data_in_ready_o  (rd_hs_coun_ready_o),
      .count_o          (),
      .data_out_valid_o (rd_hs_coun_valid_o),
      .data_out_ready_i (rd_hs_coun_ready_i),
      .passing_through_o()
  );

  // Read Path: Second Handshake Combiner (R channel)
  adn_common_hs_combiner #(
      .NUM_TX(2),
      .NUM_RX(1)
  ) rd_hs2 (
      .valid_i({r_fifo_pop_valid_o, rd_hs_coun_valid_o}),
      .ready_o({r_fifo_pop_ready_i, rd_hs_coun_ready_i}),
      .valid_o({axil_rsp_o.r_valid}),
      .ready_i({axil_req_i.r_ready})
  );

  // Read Path: Response FIFO (Buffers incoming read data & response status)
  adn_common_fifo #(
      .DATA_WIDTH (RD_FIFO_DATA_WIDTH),
      .FIFO_SIZE  (FIFO_SIZE),
      .PIPELINED  (0)
  ) rd_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       ({pmi_rsp_rd_i.mrdata, (pmi_rsp_rd_i.mresp ? 2'b10 : 2'b00)}),
      .data_in_valid_i (pmi_rsp_rd_i.mack),
      .data_in_ready_o (),
      .count_o         (),
      .data_out_o      ({axil_rsp_o.r.data, axil_rsp_o.r.resp}),
      .data_out_valid_o(r_fifo_pop_valid_o),
      .data_out_ready_i(r_fifo_pop_ready_i)
  );
endmodule
