`include "bnn_defs.vh"
module conv2_engine (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    output reg          done,
    output reg  [11:0] in_raddr,
    input  wire         in_rdata,
    output reg  [`C2_W_AW-1:0] w_addr,
    input  wire [31:0]           w_data,
    output reg  [4:0]  t_addr,
    input  wire [9:0]  t_data,
    output reg          f_we,
    output reg  [12:0]  f_waddr,
    output reg           f_wdata
);
    localparam LANES = `C2_OUT_CH;
    localparam S_IDLE=0, S_INIT=1, S_TAP=2, S_ACC=3,
               S_CMPSET=4, S_CMPWR=5, S_NEXT=6, S_DONE=7;
    reg [2:0] state;
    reg [4:0] y, x;
    reg [7:0] tap;
    reg [5:0] unit;
    reg signed [8:0] acc [0:LANES-1];
    integer i;
    wire [3:0] ic  = tap / 9;
    wire [3:0] sub = tap % 9;
    wire signed [6:0] ky = sub / 3;
    wire signed [6:0] kx = sub % 3;
    wire signed [7:0] iy = {2'b00, y} + ky - 7'sd1;
    wire signed [7:0] ix = {2'b00, x} + kx - 7'sd1;
    wire tap_valid = (iy >= 0) && (iy < `P1_SIZE) && (ix >= 0) && (ix < `P1_SIZE);
    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE; done <= 1'b0; f_we <= 1'b0;
        end else begin
            f_we <= 1'b0;
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        y <= 0; x <= 0;
                        state <= S_INIT;
                    end
                end
                S_INIT: begin
                    for (i = 0; i < LANES; i = i + 1) acc[i] <= 9'sd0;
                    tap <= 8'd0;
                    state <= S_TAP;
                end
                S_TAP: begin
                    in_raddr <= tap_valid ? (ic * (`P1_SIZE * `P1_SIZE) + iy * `P1_SIZE + ix) : 12'd0;
                    w_addr   <= tap[`C2_W_AW-1:0];
                    state    <= S_ACC;
                end
                S_ACC: begin
                    if (tap_valid) begin
                        for (i = 0; i < LANES; i = i + 1) begin
                            if (in_rdata == w_data[i]) acc[i] <= acc[i] + 9'sd1;
                            else                        acc[i] <= acc[i] - 9'sd1;
                        end
                    end
                    if (tap == `C2_TAPS - 1) begin
                        unit <= 0;
                        state <= S_CMPSET;
                    end else begin
                        tap <= tap + 1'b1;
                        state <= S_TAP;
                    end
                end
                S_CMPSET: begin
                    t_addr <= unit[4:0];
                    state  <= S_CMPWR;
                end
                S_CMPWR: begin
                    f_wdata <= t_data[9] ? (acc[unit] < $signed(t_data[8:0]))
                                         : (acc[unit] > $signed(t_data[8:0]));
                    f_waddr <= unit * (`P1_SIZE * `P1_SIZE) + y * `P1_SIZE + x;
                    f_we    <= 1'b1;
                    state   <= S_NEXT;
                end
                S_NEXT: begin
                    if (unit == LANES - 1) begin
                        if (x == `P1_SIZE - 1) begin
                            x <= 0;
                            if (y == `P1_SIZE - 1) state <= S_DONE;
                            else begin y <= y + 1'b1; state <= S_INIT; end
                        end else begin x <= x + 1'b1; state <= S_INIT; end
                    end else begin
                        unit <= unit + 1'b1;
                        state <= S_CMPSET;
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
