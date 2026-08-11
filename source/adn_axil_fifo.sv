module adn_axil_fifo #(
    parameter type axil_req_t   = logic,
    parameter type axil_resp_t  = logic,
    parameter int  FIFO_SIZE    = 2,
    parameter int  AW_FIFO_SIZE = FIFO_SIZE,
    parameter int  W_FIFO_SIZE  = FIFO_SIZE,
    parameter int  B_FIFO_SIZE  = FIFO_SIZE,
    parameter int  AR_FIFO_SIZE = FIFO_SIZE,
    parameter int  R_FIFO_SIZE  = FIFO_SIZE
) (
    input  logic clk_i,
    input  logic arst_ni,

    // Slv side (from Master / CPU)
    input  axil_req_t  axil_req_i,
    output axil_resp_t axil_resp_o,

    // Mst side (to Bridge / Register logic)
    output axil_req_t  mst_req_o,
    input  axil_resp_t mst_resp_i
);

  // Correct way to get member widths/types without hierarchical type errors
  // We extract bits using dummy variables or standard struct typing
  axil_req_t dummy_req;
  axil_resp_t dummy_resp;

  localparam int AW_BITS = $bits(dummy_req.aw);
  localparam int W_BITS  = $bits(dummy_req.w);
  localparam int B_BITS  = $bits(dummy_resp.b);
  localparam int AR_BITS = $bits(dummy_req.ar);
  localparam int R_BITS  = $bits(dummy_resp.r);

  logic [AW_BITS-1:0] aw_in, aw_out;
  logic [W_BITS-1:0]  w_in,  w_out;
  logic [B_BITS-1:0]  b_in,  b_out;
  logic [AR_BITS-1:0] ar_in, ar_out;
  logic [R_BITS-1:0]  r_in,  r_out;

  always_comb begin
    aw_in = axil_req_i.aw;
    mst_req_o.aw = aw_out;

    w_in  = axil_req_i.w;
    mst_req_o.w  = w_out;

    b_in  = mst_resp_i.b;
    axil_resp_o.b = b_out;

    ar_in = axil_req_i.ar;
    mst_req_o.ar = ar_out;

    r_in  = mst_resp_i.r;
    axil_resp_o.r = r_out;
  end

  // 1. AW FIFO
  adn_common_fifo #(.DATA_WIDTH(AW_BITS), .FIFO_SIZE(AW_FIFO_SIZE), .PIPELINED(1)) u_aw_fifo (
      .arst_ni(arst_ni), .clk_i(clk_i),
      .data_in_i(aw_in), .data_in_valid_i(axil_req_i.aw_valid), .data_in_ready_o(axil_resp_o.aw_ready),
      .count_o(),
      .data_out_o(aw_out), .data_out_valid_o(mst_req_o.aw_valid), .data_out_ready_i(mst_resp_i.aw_ready)
  );

  // 2. W FIFO
  adn_common_fifo #(.DATA_WIDTH(W_BITS), .FIFO_SIZE(W_FIFO_SIZE), .PIPELINED(1)) u_w_fifo (
      .arst_ni(arst_ni), .clk_i(clk_i),
      .data_in_i(w_in), .data_in_valid_i(axil_req_i.w_valid), .data_in_ready_o(axil_resp_o.w_ready),
      .count_o(),
      .data_out_o(w_out), .data_out_valid_o(mst_req_o.w_valid), .data_out_ready_i(mst_resp_i.w_ready)
  );

  // 3. B FIFO (Reversed: mst -> slv)
  adn_common_fifo #(.DATA_WIDTH(B_BITS), .FIFO_SIZE(B_FIFO_SIZE), .PIPELINED(1)) u_b_fifo (
      .arst_ni(arst_ni), .clk_i(clk_i),
      .data_in_i(b_in), .data_in_valid_i(mst_resp_i.b_valid), .data_in_ready_o(mst_req_o.b_ready),
      .count_o(),
      .data_out_o(b_out), .data_out_valid_o(axil_resp_o.b_valid), .data_out_ready_i(axil_req_i.b_ready)
  );

  // 4. AR FIFO
  adn_common_fifo #(.DATA_WIDTH(AR_BITS), .FIFO_SIZE(AR_FIFO_SIZE), .PIPELINED(1)) u_ar_fifo (
      .arst_ni(arst_ni), .clk_i(clk_i),
      .data_in_i(ar_in), .data_in_valid_i(axil_req_i.ar_valid), .data_in_ready_o(axil_resp_o.ar_ready),
      .count_o(),
      .data_out_o(ar_out), .data_out_valid_o(mst_req_o.ar_valid), .data_out_ready_i(mst_resp_i.ar_ready)
  );

  // 5. R FIFO (Reversed: mst -> slv)
  adn_common_fifo #(.DATA_WIDTH(R_BITS), .FIFO_SIZE(R_FIFO_SIZE), .PIPELINED(1)) u_r_fifo (
      .arst_ni(arst_ni), .clk_i(clk_i),
      .data_in_i(r_in), .data_in_valid_i(mst_resp_i.r_valid), .data_in_ready_o(mst_req_o.r_ready),
      .count_o(),
      .data_out_o(r_out), .data_out_valid_o(axil_resp_o.r_valid), .data_out_ready_i(axil_req_i.r_ready)
  );

endmodule