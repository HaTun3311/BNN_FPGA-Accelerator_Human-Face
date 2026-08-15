`include "bnn_defs.vh"
module argmax (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    output reg          done,
    output reg  [4:0]  l_raddr,
    input  wire signed [8:0] l_rdata,
    output reg  [4:0]  cls,
    output reg          valid
);
    localparam S_IDLE=0, S_INIT=1, S_READ=2, S_EVAL=3, S_NEXT=4, S_FINAL=5, S_DONE=6;
    reg [2:0] state;
    reg [4:0]        idx;
    reg signed [8:0] top1_val, top2_val;
    reg [4:0]        top1_idx;
    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE; done <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        idx      <= 0;
                        top1_val <= -9'sd256;
                        top2_val <= -9'sd256;
                        top1_idx <= 0;
                        state    <= S_INIT;
                    end
                end
                S_INIT: begin
                    l_raddr <= idx;
                    state   <= S_READ;
                end
                S_READ: begin
                    state <= S_EVAL;
                end
                S_EVAL: begin
                    if (l_rdata > top1_val) begin
                        top2_val <= top1_val;
                        top1_val <= l_rdata;
                        top1_idx <= idx;
                    end else if (l_rdata > top2_val) begin
                        top2_val <= l_rdata;
                    end
                    state <= S_NEXT;
                end
                S_NEXT: begin
                    if (idx == `NUM_CLASSES - 1) state <= S_FINAL;
                    else begin idx <= idx + 1'b1; state <= S_INIT; end
                end
                S_FINAL: begin
                    cls   <= top1_idx;
                    valid <= ((top1_val - top2_val) >= `MARGIN_THR) ? 1'b1 : 1'b0;
                    state <= S_DONE;
                end
                S_DONE: begin
                    done <= 1'b1;
                    if (!start) state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
