module adn_axil_to_dual_port_pmi #(
    parameter type axil_req_t   = logic,
    parameter type axil_resp_t  = logic,
    parameter int  FIFO_SIZE    = 2,
    parameter type pmi_req_t    = logic,
    parameter type pmi_resp_t   = logic
) (
    input  logic clk_i,
    input  logic arst_ni,

    // AXI4-Lite slave side
    input  axil_req_t  axil_req_i,
    output axil_resp_t axil_resp_o,

    // PMI Write & Read Ports
    output pmi_req_t   pmi_wr_req_o,
    input  pmi_resp_t  pmi_wr_resp_i,
    output pmi_req_t   pmi_rd_req_o,
    input  pmi_resp_t  pmi_rd_resp_i
);

  localparam int DEPTH = 2 ** FIFO_SIZE;

  // Internal buffered AXI signals coming out of the 5-channel FIFO wrapper
  axil_req_t  mst_req_buffered;
  axil_resp_t mst_resp_buffered;

  // Instantiate the 5-channel AXI FIFO wrapper
  adn_axil_fifo #(
      .axil_req_t  (axil_req_t),
      .axil_resp_t (axil_resp_t),
      .FIFO_SIZE   (FIFO_SIZE)
  ) u_axil_fifo_block (
      .clk_i      (clk_i),
      .arst_ni    (arst_ni),
      .axil_req_i  (axil_req_i),
      .axil_resp_o (axil_resp_o),
      .mst_req_o  (mst_req_buffered),
      .mst_resp_i (mst_resp_buffered)
  );

  // =====================================================================
  // WRITE PATH: AW & W Merging (Using buffered signals from the FIFO block)
  // =====================================================================
  localparam int AW = $bits(axil_req_i.aw.addr);
  localparam int DW = $bits(axil_req_i.w.data);

  logic [FIFO_SIZE:0] wr_outstanding_q;
  wire                wr_resp_has_room = (wr_outstanding_q < DEPTH[FIFO_SIZE:0]);

  logic [1:0] hs_valid_in, hs_ready_out;
  logic       write_req_valid, write_req_ready, write_fire;

  assign hs_valid_in = {mst_req_buffered.w_valid, mst_req_buffered.aw_valid};
  assign {mst_resp_buffered.w_ready, mst_resp_buffered.aw_ready} = hs_ready_out;

  adn_common_hs_combiner #(.NUM_TX(2), .NUM_RX(1)) u_write_hs_combiner (
      .valid_i (hs_valid_in),
      .ready_o (hs_ready_out),
      .valid_o (write_req_valid),
      .ready_i (write_req_ready)
  );

  assign write_req_ready = pmi_wr_resp_i.mgnt && wr_resp_has_room;
  assign write_fire      = write_req_valid && write_req_ready;

  // PMI Write Request Outputs
  assign pmi_wr_req_o.mreq   = write_fire;
  assign pmi_wr_req_o.maddr  = mst_req_buffered.aw.addr;
  assign pmi_wr_req_o.mwe    = 1'b1;
  assign pmi_wr_req_o.mwdata = mst_req_buffered.w.data;
  assign pmi_wr_req_o.mstrb  = mst_req_buffered.w.strb;

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) wr_outstanding_q <= '0;
    else begin
      wr_outstanding_q <= wr_outstanding_q + (FIFO_SIZE+1)'(write_fire) - (FIFO_SIZE+1)'(pmi_wr_resp_i.mack);
    end
  end

  // Write Response (B channel feedback to wrapper)
  assign mst_resp_buffered.b_valid  = pmi_wr_resp_i.mack;
  assign mst_resp_buffered.b.resp   = pmi_wr_resp_i.mresp ? 2'b10 : 2'b00;


  // =====================================================================
  // READ PATH: AR Channel
  // =====================================================================
  logic [FIFO_SIZE:0] rd_outstanding_q;
  wire                rd_resp_has_room = (rd_outstanding_q < DEPTH[FIFO_SIZE:0]);

  logic read_fire;
  assign read_fire = mst_req_buffered.ar_valid && pmi_rd_resp_i.mgnt && rd_resp_has_room;
  assign mst_resp_buffered.ar_ready = read_fire;

  // PMI Read Request Outputs
  assign pmi_rd_req_o.mreq   = read_fire;
  assign pmi_rd_req_o.maddr  = mst_req_buffered.ar.addr;
  assign pmi_rd_req_o.mwe    = 1'b0;
  assign pmi_rd_req_o.mwdata = '0;
  assign pmi_rd_req_o.mstrb  = '0;

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) rd_outstanding_q <= '0;
    else begin
      rd_outstanding_q <= rd_outstanding_q + (FIFO_SIZE+1)'(read_fire) - (FIFO_SIZE+1)'(pmi_rd_resp_i.mack);
    end
  end

  // Read Response (R channel feedback to wrapper)
  assign mst_resp_buffered.r_valid   = pmi_rd_resp_i.mack;
  assign mst_resp_buffered.r.data    = pmi_rd_resp_i.mrdata;
  assign mst_resp_buffered.r.resp    = pmi_rd_resp_i.mresp ? 2'b10 : 2'b00;

endmodule
