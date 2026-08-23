/*

@foez-bhai, write the purpose of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

@foez-bhai, describe the use case of this module in markdown format here. This is already in multi-line comment, so don't add any additional comment syntax.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-23 | Motasim Faiyaz | Initial version                                        |
| 1.0      | 2026-08-23 | Motasim Faiyaz | Stable release                                         |

Author : Motasim Faiyaz (motasimfaiyaz@gmail.com)
This file is part of ADN-VLSI/adn_axi
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

`include "axil/typedef.svh"
`include "pmi/typedef.svh"

`AXIL_T(adn_axi_pmi_to_axil_default, 32, 32)
`PMI_T(adn_axi_pmi_to_axil_pmi_default, 32, 32)

// @foez-bhai, add comments to the parameters, ports
module adn_axi_pmi_to_axil #(
  // PARAMETERS
  parameter type pmi_req_t  = adn_axi_pmi_to_axil_pmi_default_req_t,
  parameter type pmi_rsp_t  = adn_axi_pmi_to_axil_pmi_default_rsp_t,
  parameter type axil_req_t = adn_axi_pmi_to_axil_default_req_t,
  parameter type axil_rsp_t = adn_axi_pmi_to_axil_default_rsp_t,
  parameter int FIFO_DEPTH  = 4                    // outstanding-txn tracking depth
) (
  
  // PORTS

  input  logic                     clk,
  input  logic                     rst_n,
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PMI slave interface
  //////////////////////////////////////////////////////////////////////////////////////////////////
  input  pmi_req_t                 s_pmi_req,
  output pmi_rsp_t                 s_pmi_rsp,
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // AXI4-Lite master interface
  //////////////////////////////////////////////////////////////////////////////////////////////////
  output axil_req_t                m_axil_req,
  input  axil_rsp_t                m_axil_rsp
);
 
  // @foez-bhai, add comments to the functional blocks, signals, and submodules

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  localparam int ADDR_WIDTH = $bits(s_pmi_req.maddr);
  localparam int DATA_WIDTH = $bits(s_pmi_req.mwdata);
  localparam int STRB_WIDTH = DATA_WIDTH / 8;
  localparam int FIFO_PTR_W = (FIFO_DEPTH <= 1) ? 1 : $clog2(FIFO_DEPTH);
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // FIFO (op-type tracker: 1 = write, 0 = read)
  
  logic                   fifo_push_valid;
  logic                   fifo_push_ready;
  logic                   fifo_push_data;
 
  logic                   fifo_pop_valid;
  logic                   fifo_pop_ready;
  logic                   fifo_pop_data;
 
  logic [FIFO_DEPTH-1:0]  fifo_mem;
  logic [FIFO_PTR_W-1:0]  fifo_wr_ptr, fifo_rd_ptr;
  logic [FIFO_PTR_W:0]    fifo_count;

  // HS COMN #1 (request-side handshake glue: mreq/mgnt <-> FIFO push)
  logic req_fire;
 
  
  // demux/mux (address channel steering on mwe)
  logic aw_valid_i;
  logic ar_valid_i;
 
  
  // HS COMN #2 (write-side joint AW/W handshake)
  logic aw_seen_q, w_seen_q;     // per-channel "accepted this txn already" bits
  logic write_hs_done;           // both AW and W have now been accepted
  logic write_pending_q;
  logic read_pending_q;
  logic [ADDR_WIDTH-1:0] write_addr_q, read_addr_q;
  logic [DATA_WIDTH-1:0] write_data_q;
  logic [STRB_WIDTH-1:0] write_strb_q;
 
  
  // response-side mux/demux (driven by fifo_pop_data = op type)
  logic op_type_head;            // 1 = head-of-line txn is a write
  logic resp_fire;
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  
  // RTLS - HS COMN #1 : PMI request handshake
  
  // mgnt is asserted whenever the FIFO has room to accept a new
  // outstanding transaction. Accepting a request pushes its op-type
  // (mwe) into the FIFO in the same cycle.
  assign fifo_push_ready = (fifo_count < FIFO_DEPTH) &&
                           !write_pending_q && !read_pending_q;
  assign s_pmi_rsp.mgnt   = fifo_push_ready;
  assign req_fire         = s_pmi_req.mreq & s_pmi_rsp.mgnt;
 
  assign fifo_push_valid  = req_fire;
  assign fifo_push_data   = s_pmi_req.mwe;
 
  
  // RTLS - demux/mux : address channel steering
  
  assign m_axil_req.aw.addr = write_addr_q;
  assign m_axil_req.ar.addr = read_addr_q;
  assign m_axil_req.aw.prot = 3'b000;
  assign m_axil_req.ar.prot = 3'b000;
 
  assign aw_valid_i  = write_pending_q;
  assign ar_valid_i  = read_pending_q;
 
  assign m_axil_req.w.data = write_data_q;
  assign m_axil_req.w.strb = write_strb_q;
 
  
  // RTLS - HS COMN #2 : joint AW + W handshake
  
  // aw_valid/w_valid are driven together from the same request pulse and
  // are held individually until each side has been accepted by the slave
  // (aw_ready / w_ready seen), so a fast channel doesn't drop valid before
  // the slow channel has fired.
  assign m_axil_req.aw_valid = aw_valid_i & ~aw_seen_q;
  assign m_axil_req.w_valid  = aw_valid_i & ~w_seen_q;
  assign write_hs_done = (aw_seen_q | m_axil_rsp.aw_ready) &
                         (w_seen_q | m_axil_rsp.w_ready) & write_pending_q;


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_seen_q <= 1'b0;
      w_seen_q  <= 1'b0;
      write_pending_q <= 1'b0;
      read_pending_q  <= 1'b0;
      write_addr_q <= '0;
      read_addr_q  <= '0;
      write_data_q <= '0;
      write_strb_q <= '0;
    end else if (write_hs_done) begin
      aw_seen_q <= 1'b0;
      w_seen_q  <= 1'b0;
      write_pending_q <= 1'b0;
    end else begin
      if (req_fire) begin
        if (s_pmi_req.mwe) begin
          write_pending_q <= 1'b1;
          write_addr_q <= s_pmi_req.maddr;
          write_data_q <= s_pmi_req.mwdata;
          write_strb_q <= s_pmi_req.mstrb;
        end else begin
          read_pending_q <= 1'b1;
          read_addr_q <= s_pmi_req.maddr;
        end
      end
      if (read_pending_q && m_axil_rsp.ar_ready)
        read_pending_q <= 1'b0;
      if (m_axil_req.aw_valid & m_axil_rsp.aw_ready) aw_seen_q <= 1'b1;
      if (m_axil_req.w_valid  & m_axil_rsp.w_ready ) w_seen_q  <= 1'b1;
    end
  end
 
  assign m_axil_req.ar_valid = ar_valid_i;
 
  
  // RTLS - FIFO : op-type tracker (V/R/D on push side, V/R/D on pop side)
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fifo_wr_ptr <= '0;
      fifo_rd_ptr <= '0;
      fifo_count  <= '0;
    end else begin
      if (fifo_push_valid & fifo_push_ready) begin
        fifo_mem[fifo_wr_ptr] <= fifo_push_data;
        fifo_wr_ptr           <= fifo_wr_ptr + 1'b1;
      end
      if (fifo_pop_valid & fifo_pop_ready) begin
        fifo_rd_ptr <= fifo_rd_ptr + 1'b1;
      end
 
      case ({fifo_push_valid & fifo_push_ready, fifo_pop_valid & fifo_pop_ready})
        2'b10:   fifo_count <= fifo_count + 1'b1;
        2'b01:   fifo_count <= fifo_count - 1'b1;
        default: fifo_count <= fifo_count;
      endcase
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  assign fifo_pop_valid = (fifo_count != 0);
  assign fifo_pop_data  = fifo_mem[fifo_rd_ptr];
  
  // RTLS - response mux/demux (steered by op_type_head = fifo_pop_data)
  
  assign op_type_head = fifo_pop_data;
 
  // demux: route a single downstream-ready line to b_ready or r_ready
  assign m_axil_req.b_ready = fifo_pop_valid &  op_type_head;
  assign m_axil_req.r_ready = fifo_pop_valid & ~op_type_head;
 
  assign resp_fire = op_type_head ? (m_axil_rsp.b_valid & m_axil_req.b_ready) :
                                   (m_axil_rsp.r_valid & m_axil_req.r_ready);
  assign fifo_pop_ready = resp_fire;
 
  // mux: mresp / mrdata selected by op type (writes carry no read data)
  assign s_pmi_rsp.mrsp   = op_type_head ? m_axil_rsp.b.rsp : m_axil_rsp.r.rsp;
  assign s_pmi_rsp.mrdata = op_type_head ? '0 : m_axil_rsp.r.data;
  assign s_pmi_rsp.mack   = resp_fire;
 
endmodule
