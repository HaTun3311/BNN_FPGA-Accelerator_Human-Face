module uart_rx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD     = 921600
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       rxd,
    output reg  [7:0] data,
    output reg        valid
);
    localparam integer BAUD_DIV      = CLK_FREQ / BAUD;
    localparam integer BAUD_DIV_HALF = BAUD_DIV / 2;
    reg rxd_ff1, rxd_ff2;
    always @(posedge clk) begin
        rxd_ff1 <= rxd;
        rxd_ff2 <= rxd_ff1;
    end
    localparam S_IDLE = 0, S_START = 1, S_DATA = 2, S_STOP = 3;
    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shift;
    always @(posedge clk) begin
        if (rst) begin
            state   <= S_IDLE;
            valid   <= 1'b0;
            clk_cnt <= 0;
            bit_idx <= 0;
        end else begin
            valid <= 1'b0;
            case (state)
                S_IDLE: begin
                    if (rxd_ff2 == 1'b0) begin
                        clk_cnt <= BAUD_DIV_HALF;
                        state   <= S_START;
                    end
                end
                S_START: begin
                    if (clk_cnt == 0) begin
                        if (rxd_ff2 == 1'b0) begin
                            clk_cnt <= BAUD_DIV;
                            bit_idx <= 0;
                            state   <= S_DATA;
                        end else begin
                            state <= S_IDLE;
                        end
                    end else begin
                        clk_cnt <= clk_cnt - 1'b1;
                    end
                end
                S_DATA: begin
                    if (clk_cnt == 0) begin
                        shift[bit_idx] <= rxd_ff2;
                        clk_cnt <= BAUD_DIV;
                        if (bit_idx == 3'd7) begin
                            state <= S_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt - 1'b1;
                    end
                end
                S_STOP: begin
                    if (clk_cnt == 0) begin
                        data  <= shift;
                        valid <= 1'b1;
                        state <= S_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt - 1'b1;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
