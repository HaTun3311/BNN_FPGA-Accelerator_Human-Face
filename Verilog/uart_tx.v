module uart_tx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD     = 921600
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data,
    input  wire        start,
    output reg          txd,
    output reg          busy
);
    localparam integer BAUD_DIV = CLK_FREQ / BAUD;
    localparam S_IDLE = 0, S_START = 1, S_DATA = 2, S_STOP = 3;
    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shift;
    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            txd   <= 1'b1;
            busy  <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    txd  <= 1'b1;
                    busy <= 1'b0;
                    if (start) begin
                        shift   <= data;
                        clk_cnt <= BAUD_DIV;
                        state   <= S_START;
                        busy    <= 1'b1;
                    end
                end
                S_START: begin
                    txd <= 1'b0;
                    if (clk_cnt == 0) begin
                        clk_cnt <= BAUD_DIV;
                        bit_idx <= 0;
                        state   <= S_DATA;
                    end else clk_cnt <= clk_cnt - 1'b1;
                end
                S_DATA: begin
                    txd <= shift[bit_idx];
                    if (clk_cnt == 0) begin
                        clk_cnt <= BAUD_DIV;
                        if (bit_idx == 3'd7) state <= S_STOP;
                        else bit_idx <= bit_idx + 1'b1;
                    end else clk_cnt <= clk_cnt - 1'b1;
                end
                S_STOP: begin
                    txd <= 1'b1;
                    if (clk_cnt == 0) begin
                        state <= S_IDLE;
                        busy  <= 1'b0;
                    end else clk_cnt <= clk_cnt - 1'b1;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
