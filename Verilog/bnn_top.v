`include "bnn_defs.vh"
module bnn_top (
    input  wire clk,
    input  wire rst_n,
    input  wire uart_rxd,
    output wire uart_txd,
    output reg  LED_BUSY,
    output reg  LED_DONE
);
    wire rst = ~rst_n;
    always @(posedge clk) begin
        if (rst) begin
            LED_BUSY <= 1'b0;
            LED_DONE <= 1'b0;
        end else begin
            if (rx_valid)              LED_BUSY <= 1'b1;
            if (state == S_TX0_GO)     LED_DONE <= 1'b1;
        end
    end
    wire [7:0] rx_data;
    wire        rx_valid;
    uart_rx #(.CLK_FREQ(`CLK_FREQ_HZ), .BAUD(`BAUD_RATE)) u_rx (
        .clk(clk), .rst(rst), .rxd(uart_rxd), .data(rx_data), .valid(rx_valid)
    );
    reg  [7:0] tx_data;
    reg         tx_start;
    wire         tx_busy;
    uart_tx #(.CLK_FREQ(`CLK_FREQ_HZ), .BAUD(`BAUD_RATE)) u_tx (
        .clk(clk), .rst(rst), .data(tx_data), .start(tx_start),
        .txd(uart_txd), .busy(tx_busy)
    );
    reg  [9:0] img_waddr;
    reg         img_we;
    wire [7:0] img_rdata;
    wire [9:0] c1_img_raddr;
    img_ram u_img_ram (
        .clk(clk), .we(img_we), .waddr(img_waddr), .wdata(rx_data),
        .raddr(c1_img_raddr), .rdata(img_rdata)
    );
    wire [`C1_W_AW-1:0] w1_addr; wire [31:0] w1_data;
    weight_bram32_1tile #(
        .FILE("layer0_conv1.mem")
    ) u_w1 (
        .clk(clk), .addr({{(9-`C1_W_AW){1'b0}}, w1_addr}), .rdata(w1_data));
    wire [3:0]  t1_addr; wire [13:0] t1_data;
    thresh_rom #(.DEPTH(16), .AW(4), .WIDTH(14), .FILE("layer0_conv1_thresh.mem")) u_t1 (
        .clk(clk), .addr(t1_addr), .data(t1_data));
    wire [`C2_W_AW-1:0] w2_addr; wire [31:0] w2_data;
    weight_bram32_1tile #(
        .FILE("layer1_conv2.mem")
    ) u_w2 (
        .clk(clk), .addr({{(9-`C2_W_AW){1'b0}}, w2_addr}), .rdata(w2_data));
    wire [4:0]  t2_addr; wire [9:0] t2_data;
    thresh_rom #(.DEPTH(32), .AW(5), .WIDTH(10), .FILE("layer1_conv2_thresh.mem")) u_t2 (
        .clk(clk), .addr(t2_addr), .data(t2_data));
    wire [`FC1_W_AW-1:0] wfc1_addr; wire [31:0] wfc1_data;
    weight_bram32_16tile #(
        .T0 ("layer2_fc1_g0_t0.mem"), .T1 ("layer2_fc1_g0_t1.mem"),
        .T2 ("layer2_fc1_g0_t2.mem"), .T3 ("layer2_fc1_g0_t3.mem"),
        .T4 ("layer2_fc1_g1_t0.mem"), .T5 ("layer2_fc1_g1_t1.mem"),
        .T6 ("layer2_fc1_g1_t2.mem"), .T7 ("layer2_fc1_g1_t3.mem"),
        .T8 ("layer2_fc1_g2_t0.mem"), .T9 ("layer2_fc1_g2_t1.mem"),
        .T10("layer2_fc1_g2_t2.mem"), .T11("layer2_fc1_g2_t3.mem"),
        .T12("layer2_fc1_g3_t0.mem"), .T13("layer2_fc1_g3_t1.mem"),
        .T14("layer2_fc1_g3_t2.mem"), .T15("layer2_fc1_g3_t3.mem")
    ) u_wfc1 (
        .clk(clk), .addr(wfc1_addr), .rdata(wfc1_data));
    wire [6:0]  tfc1_addr; wire [13:0] tfc1_data;
    thresh_rom #(.DEPTH(128), .AW(7), .WIDTH(14), .FILE("layer2_fc1_thresh.mem")) u_tfc1 (
        .clk(clk), .addr(tfc1_addr), .data(tfc1_data));
    wire [`FCOUT_W_AW-1:0] wfcout_addr; wire [31:0] wfcout_data;
    weight_bram32_1tile #(
        .FILE("layer3_fc_out.mem")
    ) u_wfcout (
        .clk(clk), .addr({{(9-`FCOUT_W_AW){1'b0}}, wfcout_addr}), .rdata(wfcout_data));
    wire         f1_we; wire [13:0] f1_waddr; wire f1_wdata;
    wire [13:0] f1_raddr; wire f1_rdata;
    feat_ram #(.DEPTH(16384), .AW(14)) u_feat1 (
        .clk(clk), .we(f1_we), .waddr(f1_waddr), .wdata(f1_wdata),
        .raddr(f1_raddr), .rdata(f1_rdata));
    wire         p1_we; wire [11:0] p1_waddr; wire p1_wdata;
    wire [11:0] p1_raddr; wire p1_rdata;
    feat_ram #(.DEPTH(4096), .AW(12)) u_pool1 (
        .clk(clk), .we(p1_we), .waddr(p1_waddr), .wdata(p1_wdata),
        .raddr(p1_raddr), .rdata(p1_rdata));
    wire         f2_we; wire [12:0] f2_waddr; wire f2_wdata;
    wire [12:0] f2_raddr; wire f2_rdata;
    feat_ram #(.DEPTH(8192), .AW(13)) u_feat2 (
        .clk(clk), .we(f2_we), .waddr(f2_waddr), .wdata(f2_wdata),
        .raddr(f2_raddr), .rdata(f2_rdata));
    wire         p2_we; wire [10:0] p2_waddr; wire p2_wdata;
    wire [10:0] p2_raddr; wire p2_rdata;
    feat_ram #(.DEPTH(2048), .AW(11)) u_pool2 (
        .clk(clk), .we(p2_we), .waddr(p2_waddr), .wdata(p2_wdata),
        .raddr(p2_raddr), .rdata(p2_rdata));
    wire         fc1_we; wire [6:0] fc1_waddr; wire fc1_wdata;
    wire [6:0]  fc1_raddr; wire fc1_rdata;
    feat_ram #(.DEPTH(128), .AW(7)) u_fc1out (
        .clk(clk), .we(fc1_we), .waddr(fc1_waddr), .wdata(fc1_wdata),
        .raddr(fc1_raddr), .rdata(fc1_rdata));
    wire         lg_we; wire [4:0] lg_waddr; wire signed [8:0] lg_wdata;
    wire [4:0]  lg_raddr; wire signed [8:0] lg_rdata;
    logit_ram u_logit (
        .clk(clk), .we(lg_we), .waddr(lg_waddr), .wdata(lg_wdata),
        .raddr(lg_raddr), .rdata(lg_rdata));
    reg  c1_start, p1_start, c2_start, p2_start, fc1_start, fco_start, am_start;
    wire c1_done, p1_done, c2_done, p2_done, fc1_done, fco_done, am_done;
    conv1_engine u_conv1 (
        .clk(clk), .rst(rst), .start(c1_start), .done(c1_done),
        .img_raddr(c1_img_raddr), .img_rdata(img_rdata),
        .w_addr(w1_addr), .w_data(w1_data),
        .t_addr(t1_addr), .t_data(t1_data),
        .f_we(f1_we), .f_waddr(f1_waddr), .f_wdata(f1_wdata)
    );
    pool_engine #(.CH(16), .IN_SIZE(32), .IN_AW(14), .OUT_AW(12)) u_pool1_eng (
        .clk(clk), .rst(rst), .start(p1_start), .done(p1_done),
        .in_raddr(f1_raddr), .in_rdata(f1_rdata),
        .f_we(p1_we), .f_waddr(p1_waddr), .f_wdata(p1_wdata)
    );
    conv2_engine u_conv2 (
        .clk(clk), .rst(rst), .start(c2_start), .done(c2_done),
        .in_raddr(p1_raddr), .in_rdata(p1_rdata),
        .w_addr(w2_addr), .w_data(w2_data),
        .t_addr(t2_addr), .t_data(t2_data),
        .f_we(f2_we), .f_waddr(f2_waddr), .f_wdata(f2_wdata)
    );
    pool_engine #(.CH(32), .IN_SIZE(16), .IN_AW(13), .OUT_AW(11)) u_pool2_eng (
        .clk(clk), .rst(rst), .start(p2_start), .done(p2_done),
        .in_raddr(f2_raddr), .in_rdata(f2_rdata),
        .f_we(p2_we), .f_waddr(p2_waddr), .f_wdata(p2_wdata)
    );
    fc1_engine u_fc1 (
        .clk(clk), .rst(rst), .start(fc1_start), .done(fc1_done),
        .in_raddr(p2_raddr), .in_rdata(p2_rdata),
        .w_addr(wfc1_addr), .w_data(wfc1_data),
        .t_addr(tfc1_addr), .t_data(tfc1_data),
        .f_we(fc1_we), .f_waddr(fc1_waddr), .f_wdata(fc1_wdata)
    );
    fc_out_engine u_fcout (
        .clk(clk), .rst(rst), .start(fco_start), .done(fco_done),
        .in_raddr(fc1_raddr), .in_rdata(fc1_rdata),
        .w_addr(wfcout_addr), .w_data(wfcout_data),
        .l_we(lg_we), .l_waddr(lg_waddr), .l_wdata(lg_wdata)
    );
    wire [4:0] am_cls;
    wire        am_valid;
    argmax u_argmax (
        .clk(clk), .rst(rst), .start(am_start), .done(am_done),
        .l_raddr(lg_raddr), .l_rdata(lg_rdata),
        .cls(am_cls), .valid(am_valid)
    );
    localparam S_RESET     = 0,
               S_RX        = 1,
               S_C1_GO     = 2,  S_C1_WAIT     = 3,
               S_P1_GO     = 4,  S_P1_WAIT     = 5,
               S_C2_GO     = 6,  S_C2_WAIT     = 7,
               S_P2_GO     = 8,  S_P2_WAIT     = 9,
               S_FC1_GO    = 10, S_FC1_WAIT    = 11,
               S_FCO_GO    = 12, S_FCO_WAIT    = 13,
               S_AM_GO     = 14, S_AM_WAIT     = 15,
               S_TX0_GO    = 16, S_TX0_WAIT    = 17,
               S_TX1_GO    = 18, S_TX1_WAIT    = 19;
    reg [4:0] state;
    reg        res_valid;
    reg [4:0] res_cls;
    always @(posedge clk) begin
        if (rst) begin
            state     <= S_RESET;
            img_we    <= 1'b0;
            img_waddr <= 10'd0;
            c1_start<=0; p1_start<=0; c2_start<=0; p2_start<=0;
            fc1_start<=0; fco_start<=0; am_start<=0; tx_start<=0;
        end else begin
            img_we   <= 1'b0;
            c1_start <= 1'b0; p1_start <= 1'b0; c2_start <= 1'b0; p2_start <= 1'b0;
            fc1_start<= 1'b0; fco_start<= 1'b0; am_start <= 1'b0; tx_start <= 1'b0;
            case (state)
                S_RESET: begin
                    img_waddr <= 10'd0;
                    state <= S_RX;
                end
                S_RX: begin
                    if (rx_valid) begin
                        img_we    <= 1'b1;
                        if (img_waddr == `IMG_PIXELS - 1) begin
                            img_waddr <= 10'd0;
                            state <= S_C1_GO;
                        end else begin
                            img_waddr <= img_waddr + 1'b1;
                        end
                    end
                end
                S_C1_GO:   begin c1_start  <= 1'b1; state <= S_C1_WAIT;  end
                S_C1_WAIT: if (c1_done)  state <= S_P1_GO;
                S_P1_GO:   begin p1_start  <= 1'b1; state <= S_P1_WAIT;  end
                S_P1_WAIT: if (p1_done)  state <= S_C2_GO;
                S_C2_GO:   begin c2_start  <= 1'b1; state <= S_C2_WAIT;  end
                S_C2_WAIT: if (c2_done)  state <= S_P2_GO;
                S_P2_GO:   begin p2_start  <= 1'b1; state <= S_P2_WAIT;  end
                S_P2_WAIT: if (p2_done)  state <= S_FC1_GO;
                S_FC1_GO:  begin fc1_start <= 1'b1; state <= S_FC1_WAIT; end
                S_FC1_WAIT:if (fc1_done) state <= S_FCO_GO;
                S_FCO_GO:  begin fco_start <= 1'b1; state <= S_FCO_WAIT; end
                S_FCO_WAIT:if (fco_done) state <= S_AM_GO;
                S_AM_GO:   begin am_start  <= 1'b1; state <= S_AM_WAIT;  end
                S_AM_WAIT: if (am_done) begin
                    res_valid <= am_valid;
                    res_cls   <= am_cls;
                    state <= S_TX0_GO;
                end
                S_TX0_GO: begin
                    tx_data  <= res_valid ? 8'h01 : 8'h00;
                    tx_start <= 1'b1;
                    state    <= S_TX0_WAIT;
                end
                S_TX0_WAIT: if (!tx_busy && !tx_start) state <= S_TX1_GO;
                S_TX1_GO: begin
                    tx_data  <= {3'b000, res_cls};
                    tx_start <= 1'b1;
                    state    <= S_TX1_WAIT;
                end
                S_TX1_WAIT: if (!tx_busy && !tx_start) state <= S_RX;
                default: state <= S_RESET;
            endcase
        end
    end
endmodule
