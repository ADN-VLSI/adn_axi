/*

### Purpose
The `adn_common_axil_to_pmi` module acts as a bridge interface that converts AXI-Lite transactions into a custom PMI (Private Memory Interface) protocol. It manages request buffering, transaction ordering, and response synchronization to ensure reliable data transfer between an AXI-Lite master and a PMI-compliant slave.

### Use Case
This module is designed for systems where an AXI-Lite master (such as a CPU or DMA controller) needs to communicate with a proprietary memory or peripheral subsystem that utilizes the Private Memory Interface (PMI). It handles the protocol translation, allowing the AXI-Lite master to perform standard read and write operations while the module manages the complexities of PMI handshaking, request queuing, and response reordering.

| REVISION | DATE       | AUTHOR                 | DESCRIPTION                                     |
|----------|------------|------------------------|-------------------------------------------------|
| 0.1      | 2026-08-09 | Md. Sakib Hasan Shawon | Initial version                                 |
| 1.0      | YYYY-MM-DD | Md. Sakib Hasan Shawon | Stable release                                  |

Author : Md. Sakib Hasan Shawon (mdsakibhasanshawon20@gmail.com)
This file is part of ADN-VLSI/adn_axi
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_axi_axil_to_pmi #(
    parameter type axil_req_t = logic,
    parameter type axil_rsp_t = logic,
    parameter type pmi_req_t  = logic,
    parameter type pmi_rsp_t  = logic,
    parameter int  FIFO_DEPTH = 8
) (
    //////////////////////////////////////////////////////////////////////////////////////////////
    // GLOBAL
    //////////////////////////////////////////////////////////////////////////////////////////////

    // Clock input
    input logic clk,
    // Active-low asynchronous reset
    input logic arst_n,


    //////////////////////////////////////////////////////////////////////////////////////////////
    // AXI-LITE SLAVE INTERFACE
    //////////////////////////////////////////////////////////////////////////////////////////////

    // AXI-Lite slave request interface
    input  axil_req_t s_axil_req,
    // AXI-Lite slave response interface
    output axil_rsp_t s_axil_rsp,


    //////////////////////////////////////////////////////////////////////////////////////////////
    // PMI MASTER INTERFACE
    //////////////////////////////////////////////////////////////////////////////////////////////

    // PMI master request interface
    output pmi_req_t m_pmi_req,
    // PMI master response interface
    input  pmi_rsp_t m_pmi_rsp

);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS GENERATED
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Address width
  localparam int ADDR_WIDTH = $bits(s_axil_req.aw.addr);


  // Data width
  localparam int DATA_WIDTH = $bits(s_axil_req.w.data);

  // Byte strobe width
  localparam int STRB_WIDTH = DATA_WIDTH / 8;


  // FIFO pointer width
  localparam int PTR_WIDTH = (FIFO_DEPTH <= 1) ? 1 : $clog2(FIFO_DEPTH);


  // FIFO count width
  localparam int COUNT_WIDTH = (FIFO_DEPTH <= 1) ? 1 : $clog2(FIFO_DEPTH + 1);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // PMI transaction descriptor
  typedef struct packed {

    // Transaction direction
    logic write;

    // Transaction address
    logic [ADDR_WIDTH-1:0] addr;

    // Write data
    logic [DATA_WIDTH-1:0] data;

    // Byte enable mask
    logic [STRB_WIDTH-1:0] strb;

  } txn_t;



  // Outstanding transaction descriptor
  typedef struct packed {

    // Transaction direction
    // 1 = write response
    // 0 = read response
    logic write;

    // Original transaction address
    logic [ADDR_WIDTH-1:0] addr;

  } outstanding_t;



  // AXI response storage descriptor
  typedef struct packed {

    // Response transaction type
    logic write;

    // Read response data
    logic [DATA_WIDTH-1:0] data;

    // AXI response code
    logic [1:0] resp;

  } response_t;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Request FIFO storage
  txn_t                           txn_fifo           [FIFO_DEPTH];


  // Request FIFO pointers and counter
  logic         [  PTR_WIDTH-1:0] txn_wr_ptr;
  logic         [  PTR_WIDTH-1:0] txn_rd_ptr;
  logic         [COUNT_WIDTH-1:0] txn_count;


  // Request FIFO status
  logic                           txn_full;
  logic                           txn_empty;



  // AXI-Lite write address holding register
  logic                           aw_valid_hold;
  logic         [ ADDR_WIDTH-1:0] aw_addr_hold;


  // AXI-Lite write data holding register
  logic                           w_valid_hold;
  logic         [ DATA_WIDTH-1:0] w_data_hold;
  logic         [ STRB_WIDTH-1:0] w_strb_hold;



  // AXI handshake signals
  logic                           aw_accept;
  logic                           w_accept;
  logic                           ar_accept;


  // Transaction push controls
  logic                           write_push;
  logic                           read_push;

  logic         [            1:0] request_push_count;



  // PMI transaction controls
  logic                           txn_load;

  logic                           pmi_can_issue;
  logic                           pmi_accept;

  // PMI request holding register
  logic                           pmi_req_valid;
  logic                           pmi_req_write;
  logic         [ ADDR_WIDTH-1:0] pmi_req_addr;
  logic         [ DATA_WIDTH-1:0] pmi_req_data;
  logic         [ STRB_WIDTH-1:0] pmi_req_strb;



  // Outstanding PMI transaction FIFO
  outstanding_t                   outstanding_fifo   [FIFO_DEPTH];

  logic         [  PTR_WIDTH-1:0] out_wr_ptr;
  logic         [  PTR_WIDTH-1:0] out_rd_ptr;

  logic         [COUNT_WIDTH-1:0] out_count;

  logic                           out_push;
  logic                           out_pop;



  // PMI response FIFO
  response_t                      response_fifo      [FIFO_DEPTH];

  logic         [  PTR_WIDTH-1:0] rsp_wr_ptr;
  logic         [  PTR_WIDTH-1:0] rsp_rd_ptr;

  logic         [COUNT_WIDTH-1:0] rsp_count;

  logic                           rsp_full;
  logic                           rsp_empty;


  logic                           response_pop;

  logic                           response_write;

  logic                           response_do_push;

  // Number of accepted PMI transactions without consumed AXI response
  logic         [  COUNT_WIDTH:0] unconsumed_count;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Request FIFO empty/full status
  assign txn_full = (txn_count == COUNT_WIDTH'(FIFO_DEPTH));


  assign txn_empty = (txn_count == 0);


  // Response FIFO empty/full status
  assign rsp_full = (rsp_count == COUNT_WIDTH'(FIFO_DEPTH));


  assign rsp_empty = (rsp_count == 0);


  // Track accepted PMI transactions which have not yet generated
  // AXI-consumed responses
  assign unconsumed_count = {1'b0, out_count} + {1'b0, rsp_count};



  // AXI-Lite handshake generation
  assign aw_accept = arst_n && s_axil_req.aw_valid && s_axil_rsp.aw_ready;


  assign w_accept = arst_n && s_axil_req.w_valid && s_axil_rsp.w_ready;


  assign ar_accept = arst_n && s_axil_req.ar_valid && s_axil_rsp.ar_ready;



  // Generate write transaction insertion into request FIFO
  assign write_push = aw_valid_hold && w_valid_hold && !txn_full;



  // Generate read transaction insertion into request FIFO
  assign read_push = ar_accept;



  // Number of transactions inserted into request FIFO
  assign request_push_count = {1'b0, write_push} + {1'b0, read_push};



  // PMI resource availability
  assign pmi_can_issue = (unconsumed_count < COUNT_WIDTH'(FIFO_DEPTH)) || response_pop;



  // PMI request generation
  assign m_pmi_req.mreq = arst_n && pmi_req_valid;



  // PMI request acceptance
  assign pmi_accept = arst_n && pmi_req_valid && m_pmi_rsp.mgnt;



  // Request FIFO pop occurs only after PMI grant
  assign txn_load = arst_n && !pmi_req_valid && !txn_empty && pmi_can_issue;



  // Outstanding transaction FIFO control
  assign out_push = pmi_accept;



  assign out_pop = arst_n && m_pmi_rsp.mack && (out_count != 0) && (!rsp_full || response_pop);



  // PMI response is stored only when the response FIFO can accept it.
  assign response_do_push = arst_n && m_pmi_rsp.mack && (out_count != 0) &&
                            (!rsp_full || response_pop);

  // AXI response FIFO consumption
  assign response_pop = !rsp_empty && (
      (response_fifo[rsp_rd_ptr].write && s_axil_rsp.b_valid && s_axil_req.b_ready) ||
      (!response_fifo[rsp_rd_ptr].write && s_axil_rsp.r_valid && s_axil_req.r_ready)
    );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // FIFO pointer increment function
  //
  // Supports non power-of-two FIFO depths by explicitly wrapping
  // the pointer at FIFO_DEPTH-1.
  function automatic logic [PTR_WIDTH-1:0] ptr_inc(input logic [PTR_WIDTH-1:0] ptr);

    if (ptr == PTR_WIDTH'(FIFO_DEPTH - 1)) ptr_inc = '0;
    else ptr_inc = ptr + 1'b1;

  endfunction



  //////////////////////////////////////////////////////////////////////////////////////////////////
  // COMBINATIONAL LOGIC
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // AXI-Lite ready and response generation
  always_comb begin

    s_axil_rsp = '0;


    if (arst_n) begin


      // Accept AXI write address when no address is buffered
      s_axil_rsp.aw_ready = !aw_valid_hold;



      // Accept AXI write data when no data is buffered
      s_axil_rsp.w_ready  = !w_valid_hold;



      // AXI read channel.
      //
      // A read may be accepted only when the request FIFO has at least
      // one free entry after accounting for a simultaneous completed write.
      // Do not use txn_load as a FIFO pop condition because txn_count is
      // decremented only when the PMI request is actually granted.
      if (txn_full) begin

        s_axil_rsp.ar_ready = 1'b0;

      end else if (write_push && (txn_count == COUNT_WIDTH'(FIFO_DEPTH - 1))) begin

        // Reserve the final request FIFO entry for the completed write.
        s_axil_rsp.ar_ready = 1'b0;

      end else begin

        s_axil_rsp.ar_ready = 1'b1;

      end



      // Generate AXI responses from response FIFO head
      if (!rsp_empty) begin


        if (response_fifo[rsp_rd_ptr].write) begin


          // PMI write completion -> AXI B response
          s_axil_rsp.b_valid = 1'b1;


          s_axil_rsp.b.resp  = response_fifo[rsp_rd_ptr].resp;


        end else begin


          // PMI read completion -> AXI R response
          s_axil_rsp.r_valid = 1'b1;


          s_axil_rsp.r.data  = response_fifo[rsp_rd_ptr].data;


          s_axil_rsp.r.resp  = response_fifo[rsp_rd_ptr].resp;


        end

      end

    end

  end



  // PMI request payload.
  //
  // The payload is driven from registered signals rather than directly
  // from txn_fifo[txn_rd_ptr]. This prevents txn_rd_ptr from changing
  // the PMI address/data associated with an active request.
  assign m_pmi_req.maddr  = arst_n && pmi_req_valid ? pmi_req_addr  : '0;
  assign m_pmi_req.mwe    = arst_n && pmi_req_valid ? pmi_req_write : 1'b0;
  assign m_pmi_req.mwdata = arst_n && pmi_req_valid ? pmi_req_data  : '0;
  assign m_pmi_req.mstrb  = arst_n && pmi_req_valid ? pmi_req_strb  : '0;



  // Determine response transaction type
  always_comb begin

    response_write = 1'b0;

    if (out_count != 0) begin

      response_write = outstanding_fifo[out_rd_ptr].write;

    end

  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////


  //================================================================================================
  // AXI REQUEST CAPTURE AND REQUEST FIFO WRITE
  //================================================================================================

  always_ff @(posedge clk or negedge arst_n) begin

    if (!arst_n) begin


      aw_valid_hold <= 1'b0;
      aw_addr_hold <= '0;


      w_valid_hold <= 1'b0;
      w_data_hold <= '0;
      w_strb_hold <= '0;


      txn_wr_ptr <= '0;
      txn_count <= '0;


    end else begin


      // Capture AXI write address
      if (aw_accept) begin

        aw_valid_hold <= 1'b1;

        aw_addr_hold  <= s_axil_req.aw.addr;

      end



      // Capture AXI write data
      if (w_accept) begin

        w_valid_hold <= 1'b1;

        w_data_hold  <= s_axil_req.w.data;


        w_strb_hold  <= s_axil_req.w.strb;

      end



      // Store completed AXI write transaction
      if (write_push) begin


        txn_fifo[txn_wr_ptr].write <= 1'b1;


        txn_fifo[txn_wr_ptr].addr <= aw_addr_hold;


        txn_fifo[txn_wr_ptr].data <= w_data_hold;


        txn_fifo[txn_wr_ptr].strb <= w_strb_hold;



        aw_valid_hold <= 1'b0;


        w_valid_hold <= 1'b0;

      end



      // Store AXI read transaction
      if (read_push) begin


        if (write_push) begin


          txn_fifo[ptr_inc(txn_wr_ptr)].write <= 1'b0;


          txn_fifo[ptr_inc(txn_wr_ptr)].addr  <= s_axil_req.ar.addr;


          txn_fifo[ptr_inc(txn_wr_ptr)].data  <= '0;


          txn_fifo[ptr_inc(txn_wr_ptr)].strb  <= '0;


        end else begin


          txn_fifo[txn_wr_ptr].write <= 1'b0;


          txn_fifo[txn_wr_ptr].addr  <= s_axil_req.ar.addr;


          txn_fifo[txn_wr_ptr].data  <= '0;


          txn_fifo[txn_wr_ptr].strb  <= '0;


        end

      end



      // Update request FIFO write pointer
      case (request_push_count)

        2'd1: txn_wr_ptr <= ptr_inc(txn_wr_ptr);


        2'd2: txn_wr_ptr <= ptr_inc(ptr_inc(txn_wr_ptr));



      endcase



      // Request FIFO count update
      case ({
        request_push_count, pmi_accept
      })

        3'b001: txn_count <= txn_count - 1;

        3'b010: txn_count <= txn_count + 1;

        3'b011: txn_count <= txn_count;

        3'b100: txn_count <= txn_count + 2;

        3'b101: txn_count <= txn_count + 1;


      endcase

    end

  end


  //================================================================================================
  // PMI REQUEST HOLDING REGISTER
  //================================================================================================
  //
  // Loads one request from the request FIFO and holds it stable until
  // PMI grants the request.
  //
  // The request FIFO is popped when the transaction is loaded into
  // this holding register. This guarantees that the same FIFO entry
  // cannot be loaded more than once.
  //

  always_ff @(posedge clk or negedge arst_n) begin

    if (!arst_n) begin

      pmi_req_valid <= 1'b0;

      pmi_req_write <= 1'b0;
      pmi_req_addr  <= '0;
      pmi_req_data  <= '0;
      pmi_req_strb  <= '0;

    end else begin

      // PMI request was accepted.
      // Remove the active request from the holding register.
      if (pmi_accept) begin

        pmi_req_valid <= 1'b0;

      end  // Load the next request from the request FIFO.
      else if (txn_load) begin

        pmi_req_valid <= 1'b1;

        pmi_req_write <= txn_fifo[txn_rd_ptr].write;
        pmi_req_addr  <= txn_fifo[txn_rd_ptr].addr;
        pmi_req_data  <= txn_fifo[txn_rd_ptr].data;
        pmi_req_strb  <= txn_fifo[txn_rd_ptr].strb;

      end

    end

  end


  //================================================================================================
  // REQUEST FIFO POP AND OUTSTANDING TRANSACTION FIFO
  //================================================================================================

  always_ff @(posedge clk or negedge arst_n) begin

    if (!arst_n) begin

      txn_rd_ptr <= '0;

      out_wr_ptr <= '0;
      out_rd_ptr <= '0;
      out_count  <= '0;


    end else begin


      // Remove granted PMI request
      if (pmi_accept) begin

        txn_rd_ptr <= ptr_inc(txn_rd_ptr);

      end



      // Store outstanding transaction
      if (out_push) begin

        outstanding_fifo[out_wr_ptr].write <= pmi_req_write;
        outstanding_fifo[out_wr_ptr].addr <= pmi_req_addr;

        out_wr_ptr <= ptr_inc(out_wr_ptr);

      end



      // Remove completed outstanding transaction
      if (out_pop) begin

        out_rd_ptr <= ptr_inc(out_rd_ptr);

      end



      // Outstanding transaction count
      case ({
        out_push, out_pop
      })


        2'b10: out_count <= out_count + 1'b1;


        2'b01: out_count <= out_count - 1'b1;




      endcase

    end

  end




  //================================================================================================
  // RESPONSE FIFO
  //================================================================================================

  always_ff @(posedge clk or negedge arst_n) begin

    if (!arst_n) begin


      rsp_wr_ptr <= '0;
      rsp_rd_ptr <= '0;
      rsp_count  <= '0;


    end else begin


      // Store PMI completion response
      if (response_do_push) begin

        response_fifo[rsp_wr_ptr].write <= response_write;
        response_fifo[rsp_wr_ptr].data <= m_pmi_rsp.mrdata;
        response_fifo[rsp_wr_ptr].resp <= m_pmi_rsp.mresp ? 2'b10 : 2'b00;

        rsp_wr_ptr <= ptr_inc(rsp_wr_ptr);

      end



      // Remove AXI consumed response
      if (response_pop) begin


        rsp_rd_ptr <= ptr_inc(rsp_rd_ptr);


      end



      // Response FIFO count
      case ({
        response_do_push, response_pop
      })


        2'b10: rsp_count <= rsp_count + 1'b1;


        2'b01: rsp_count <= rsp_count - 1'b1;




      endcase

    end

  end


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PMI ADDRESS ALIGNMENT CHECK
  //////////////////////////////////////////////////////////////////////////////////////////////////

  generate

    if (STRB_WIDTH > 1) begin : gen_alignment_check

      always_ff @(posedge clk) begin

        if (arst_n && pmi_accept) begin

          if (m_pmi_req.maddr[$clog2(STRB_WIDTH)-1:0] != '0) begin

            $error("PMI address alignment violation: maddr=0x%0h DATA_WIDTH=%0d", m_pmi_req.maddr,
                   DATA_WIDTH);

          end

        end

      end

    end

  endgenerate


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INITIAL CHECKS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin


    if ((ADDR_WIDTH < 1) || (ADDR_WIDTH > 32)) begin

      $error("ADDR_WIDTH must be between 1 and 32");

    end



    if ((DATA_WIDTH != 8) && (DATA_WIDTH != 16) && (DATA_WIDTH != 32) && (DATA_WIDTH != 64)) begin

      $error("DATA_WIDTH must be 8,16,32,64");

    end



    if ((DATA_WIDTH % 8) != 0) begin

      $error("DATA_WIDTH must be byte aligned");

    end



    if (FIFO_DEPTH < 1) begin

      $error("FIFO_DEPTH must be >= 1");

    end


  end


endmodule
