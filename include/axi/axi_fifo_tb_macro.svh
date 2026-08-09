`ifndef __GUARD_AXI_TB_MACROS_SVH__
`define __GUARD_AXI_TB_MACROS_SVH__ 0

//==================================================================
// REQUEST-DIRECTION DRIVER  (AW, W, AR)
//==================================================================
`define GEN_DRIVE_REQ_TASK(CH, TYPE)                                \
  task automatic drive_``CH``(TYPE item);                           \
    @(posedge clk_i);                                               \
    slv_req_i.``CH``       <= item;                                 \
    slv_req_i.``CH``_valid <= 1'b1;                                 \
    ``CH``_ref_q.push_back(item);                                   \
    wait (slv_resp_o.``CH``_ready === 1'b1);                        \
    @(posedge clk_i);                                               \
    slv_req_i.``CH``_valid <= 1'b0;                                 \
  endtask

//==================================================================
// RESPONSE-DIRECTION DRIVER  (B, R channel)
//==================================================================
`define GEN_DRIVE_RESP_TASK(CH, TYPE)                               \
  task automatic drive_``CH``(TYPE item);                           \
    @(posedge clk_i);                                               \
    mst_resp_i.``CH``       <= item;                                \
    mst_resp_i.``CH``_valid <= 1'b1;                                \
    ``CH``_ref_q.push_back(item);                                   \
    wait (mst_req_o.``CH``_ready === 1'b1);                         \
    @(posedge clk_i);                                               \
    mst_resp_i.``CH``_valid <= 1'b0;                                \
  endtask

//==================================================================
// REQUEST-DIRECTION CHECKER  (output side = mst_req_o, AW/W/AR)
//==================================================================
`define GEN_CHECK_REQ_TASK(CH, TYPE)                                 \
  task automatic check_``CH``();                                     \
    forever begin                                                    \
      @(posedge clk_i);                                              \
      if (mst_req_o.``CH``_valid && mst_resp_i.``CH``_ready) begin   \
        TYPE expected;                                               \
        expected = ``CH``_ref_q.pop_front();                         \
        if (mst_req_o.``CH`` !== expected)                           \
          $error("[%s] mismatch: got %p expected %p",                \
                  `"CH`", mst_req_o.``CH``, expected);               \
      end                                                            \
    end                                                              \
  endtask

//==================================================================
// RESPONSE-DIRECTION CHECKER  (output side = slv_resp_o, B/R)
//==================================================================
`define GEN_CHECK_RESP_TASK(CH, TYPE)                               \
  task automatic check_``CH``();                                    \
    forever begin                                                   \
      @(posedge clk_i);                                             \
      if (slv_resp_o.``CH``_valid && slv_req_i.``CH``_ready) begin  \
        TYPE expected;                                              \
        expected = ``CH``_ref_q.pop_front();                        \
        if (slv_resp_o.``CH`` !== expected)                         \
          $error("[%s] mismatch: got %p expected %p",               \
                  `"CH`", slv_resp_o.``CH``, expected);             \
      end                                                           \
    end                                                             \
  endtask

`endif