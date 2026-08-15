`include "bnn_defs.vh"
module fc_out_engine (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    output reg          done,
    output reg  [6:0]  in_raddr,
    input  wire         in_rdata,
    output reg  [`FCOUT_W_AW-1:0] w_addr,
    input  wire [31:0]               w_data,
    output reg           l_we,
    output reg  [4:0]   l_waddr,
    output reg  signed [8:0] l_wdata
);
    localparam LANES = `NUM_CLASSES;
    localparam S_IDLE=0, S_INIT=1, S_TAP=2, S_ACC=3, S_WRITE=4, S_NEXT=5, S_DONE=6;
    reg [2:0] state;
    reg [7:0] tap;
    reg [5:0] unit;
    reg signed [8:0] acc [0:LANES-1];
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE; done <= 1'b0; l_we <= 1'b0;
        end else begin
            l_we <= 1'b0;
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) state <= S_INIT;
                end
                S_INIT: begin
                    for (i = 0; i < LANES; i = i + 1) acc[i] <= 9'sd0;
                    tap <= 8'd0;
                    state <= S_TAP;
                end
                S_TAP: begin
                    in_raddr <= tap[6:0];
                    w_addr   <= tap[`FCOUT_W_AW-1:0];
                    state    <= S_ACC;
                end
                S_ACC: begin
                    for (i = 0; i < LANES; i = i + 1) begin
                        if (in_rdata == w_data[i]) acc[i] <= acc[i] + 9'sd1;
                        else                        acc[i] <= acc[i] - 9'sd1;
                    end
                    if (tap == `FCOUT_IN - 1) begin
                        unit <= 0;
                        state <= S_WRITE;
                    end else begin
                        tap <= tap + 1'b1;
                        state <= S_TAP;
                    end
                end
                S_WRITE: begin
                    l_wdata <= acc[unit];
                    l_waddr <= unit[4:0];
                    l_we    <= 1'b1;
                    state   <= S_NEXT;
                end
                S_NEXT: begin
                    if (unit == LANES - 1) state <= S_DONE;
                    else begin
                        unit <= unit + 1'b1;
                        state <= S_WRITE;
                    end
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
