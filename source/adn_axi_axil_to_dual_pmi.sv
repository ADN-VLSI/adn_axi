/*

@foez-bhai, write the purpose of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

@foez-bhai, describe the use case of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

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

// @foez-bhai, add comments to the parameters, ports
module adn_axi_axil_to_dual_pmi #(
    // PARAMETERS
    parameter type  axil_req_t      = logic,
    parameter type  axil_rsp_t      = logic,
    parameter type  pmi_req_t       = logic,
    parameter type  pmi_rsp_t       = logic,
    parameter int   PIPELINE_DEPTH  = 8,
    parameter int   FIFO_SIZE       = $clog2(PIPELINE_DEPTH)
) (
    // PORTS
    input  logic       clk_i,
    input  logic       arst_ni,

    input  axil_req_t  axil_req_i,
    output axil_rsp_t  axil_rsp_o,

    output pmi_req_t   pmi_req_wr_o,
    input  pmi_rsp_t   pmi_rsp_wr_i,

    output pmi_req_t   pmi_req_rd_i,   
    input  pmi_rsp_t   pmi_rsp_rd_i    
);

  // @foez-bhai, add comments to the functional blocks, signals, and submodules

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Internal signals for Write path handshaking and FIFO
  logic wr_hs1_comb_valid_o, wr_hs_coun_ready_o, wr_hs_coun_valid_o, wr_hs_coun_ready_i;

  logic w_fifo_pop_valid_o, w_fifo_pop_ready_i;

  // Internal signals for Read path handshaking and FIFO
  logic rd_hs1_comb_valid_o, rd_hs_coun_ready_o, rd_hs_coun_valid_o, rd_hs_coun_ready_i;

  logic r_fifo_pop_valid_o, r_fifo_pop_ready_i;

  // instantiated with a data width other than 32.
  localparam int RD_FIFO_DATA_WIDTH = $bits(pmi_rsp_rd_i.mrdata) + 2;
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb pmi_req_wr_o.maddr  = axil_req_i.aw.addr;
  always_comb pmi_req_wr_o.mwdata = axil_req_i.w.data;
  always_comb pmi_req_wr_o.mstrb  = axil_req_i.w.strb;
  always_comb pmi_req_wr_o.mwe    = '1;

// ASSIGNMENTS: Mapping AXI Read Address to PMI Read Request port
  always_comb pmi_req_rd_i.maddr  = axil_req_i.ar.addr;
  always_comb pmi_req_rd_i.mwdata = '0;   
  always_comb pmi_req_rd_i.mstrb  = '0;   
  always_comb pmi_req_rd_i.mwe    = 1'b0;


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////
adn_common_hs_combiner #(
    .NUM_TX(2),
    .NUM_RX(2)
) wr_hs1 (
    .valid_i({axil_req_i.aw_valid, axil_req_i.w_valid }),
    .ready_o({axil_rsp_o.aw_ready, axil_rsp_o.w_ready }),
    .valid_o({pmi_req_wr_o.mreq  , wr_hs1_comb_valid_o}),
    .ready_i({pmi_rsp_wr_i.mgnt  , wr_hs_coun_ready_o })
  );


adn_common_hs_counter #(
    .DEPTH(PIPELINE_DEPTH)  // FIX (1.1): was hardcoded 8, now tracks the same
                             // in-flight limit the module is parameterized for
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

adn_common_hs_combiner #(
    .NUM_TX(2),
    .NUM_RX(1)
) wr_hs2 (
    .valid_i({w_fifo_pop_valid_o, wr_hs_coun_valid_o }),
    .ready_o({w_fifo_pop_ready_i, wr_hs_coun_ready_i }),
    .valid_o({axil_rsp_o.b_valid}),
    .ready_i({axil_req_i.b_ready})
);


adn_common_fifo #(
    .DATA_WIDTH (2),  
    .FIFO_SIZE  (FIFO_SIZE),
    .PIPELINED  (0)
)wr_fifo (
    .arst_ni         (arst_ni),
    .clk_i           (clk_i  ),
    .data_in_i       (pmi_rsp_wr_i.mresp? 2'b10:2'b00),
    .data_in_valid_i (pmi_rsp_wr_i.mack),
    .data_in_ready_o (),
    .count_o         (),
    .data_out_o      (axil_rsp_o.b.resp), // FIX (1.2): was axil_rsp_o.b_resp - b is a nested sub-struct
    .data_out_valid_o(w_fifo_pop_valid_o),
    .data_out_ready_i(w_fifo_pop_ready_i)
);



// For Read Path
// First Handshake Combiner for Read Address (AR) Channel
  adn_common_hs_combiner #(
      .NUM_TX(1),
      .NUM_RX(2)
  ) rd_hs1 (
      .valid_i({axil_req_i.ar_valid}),
      .ready_o({axil_rsp_o.ar_ready}),
      .valid_o({pmi_req_rd_i.mreq, rd_hs1_comb_valid_o}),
      .ready_i({pmi_rsp_rd_i.mgnt, rd_hs_coun_ready_o})
  );

  // Handshake Counter: Tracks outstanding in-flight read transactions
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

  // Second Handshake Combiner for Read Response (R) Channel
  adn_common_hs_combiner #(
      .NUM_TX(2),
      .NUM_RX(1)
  ) rd_hs2 (
      .valid_i({r_fifo_pop_valid_o, rd_hs_coun_valid_o}),
      .ready_o({r_fifo_pop_ready_i, rd_hs_coun_ready_i}),
      .valid_o({axil_rsp_o.r_valid}),
      .ready_i({axil_req_i.r_ready})
  );

  // Read Response Data FIFO: Buffers incoming read data & response status from PMI side
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
