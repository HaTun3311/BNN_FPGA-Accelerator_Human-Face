`include "bnn_defs.vh"
module fc1_engine (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    output reg          done,
    output reg  [10:0] in_raddr,
    input  wire         in_rdata,
    output reg  [`FC1_W_AW-1:0] w_addr,
    input  wire [31:0]            w_data,
    output reg  [6:0]  t_addr,
    input  wire [13:0] t_data,
    output reg          f_we,
    output reg  [6:0]  f_waddr,
    output reg           f_wdata
);
    localparam LANES = `FC1_LANES;
    localparam S_IDLE=0, S_INIT=1, S_TAP=2, S_ACC=3,
               S_CMPSET=4, S_CMPWR=5, S_NEXT=6, S_GNEXT=7, S_DONE=8;
    reg [3:0] state;
    reg [1:0]  grp;
    reg [10:0] tap;
    reg [4:0]  unit;
    wire [6:0] gunit = {grp, unit};
    reg signed [12:0] acc [0:LANES-1];
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE; done <= 1'b0; f_we <= 1'b0;
        end else begin
            f_we <= 1'b0;
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        grp <= 2'd0;
                        state <= S_INIT;
                    end
                end
                S_INIT: begin
                    for (i = 0; i < LANES; i = i + 1) acc[i] <= 13'sd0;
                    tap <= 11'd0;
                    state <= S_TAP;
                end
                S_TAP: begin
                    in_raddr <= tap;
                    w_addr   <= {grp, tap};
                    state    <= S_ACC;
                end
                S_ACC: begin
                    for (i = 0; i < LANES; i = i + 1) begin
                        if (in_rdata == w_data[i]) acc[i] <= acc[i] + 13'sd1;
                        else                        acc[i] <= acc[i] - 13'sd1;
                    end
                    if (tap == `FC1_IN - 1) begin
                        unit <= 0;
                        state <= S_CMPSET;
                    end else begin
                        tap <= tap + 1'b1;
                        state <= S_TAP;
                    end
                end
                S_CMPSET: begin
                    t_addr <= gunit;
                    state  <= S_CMPWR;
                end
                S_CMPWR: begin
                    f_wdata <= t_data[13] ? (acc[unit] < $signed(t_data[12:0]))
                                          : (acc[unit] > $signed(t_data[12:0]));
                    f_waddr <= gunit;
                    f_we    <= 1'b1;
                    state   <= S_NEXT;
                end
                S_NEXT: begin
                    if (unit == LANES - 1) state <= S_GNEXT;
                    else begin
                        unit <= unit + 1'b1;
                        state <= S_CMPSET;
                    end
                end
                S_GNEXT: begin
                    if (grp == `FC1_GROUPS - 1) begin
                        state <= S_DONE;
                    end else begin
                        grp   <= grp + 1'b1;
                        state <= S_INIT;
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
