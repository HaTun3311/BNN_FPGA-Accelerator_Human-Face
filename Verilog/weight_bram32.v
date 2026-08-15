`include "bnn_defs.vh"
module weight_bram32_1tile #(
    parameter FILE = ""
)(
    input  wire        clk,
    input  wire [8:0]  addr,
    output wire [31:0] rdata
);
    bram32x512 #(.FILE(FILE)) u_bram (
        .clk(clk), .we(1'b0), .waddr(9'd0), .wdata(32'd0),
        .raddr(addr), .rdata(rdata));
endmodule
module weight_bram32_16tile #(
    parameter T0="",  parameter T1="",  parameter T2="",  parameter T3="",
    parameter T4="",  parameter T5="",  parameter T6="",  parameter T7="",
    parameter T8="",  parameter T9="",  parameter T10="", parameter T11="",
    parameter T12="", parameter T13="", parameter T14="", parameter T15=""
)(
    input  wire         clk,
    input  wire [12:0]  addr,
    output wire [31:0]  rdata
);
    wire [8:0] a    = addr[8:0];
    wire [3:0] tsel = addr[12:9];
    wire [31:0] d0, d1, d2,  d3,  d4,  d5,  d6,  d7,
                d8, d9, d10, d11, d12, d13, d14, d15;
    weight_bram32_1tile #(.FILE(T0))  u_tile0  (.clk(clk), .addr(a), .rdata(d0));
    weight_bram32_1tile #(.FILE(T1))  u_tile1  (.clk(clk), .addr(a), .rdata(d1));
    weight_bram32_1tile #(.FILE(T2))  u_tile2  (.clk(clk), .addr(a), .rdata(d2));
    weight_bram32_1tile #(.FILE(T3))  u_tile3  (.clk(clk), .addr(a), .rdata(d3));
    weight_bram32_1tile #(.FILE(T4))  u_tile4  (.clk(clk), .addr(a), .rdata(d4));
    weight_bram32_1tile #(.FILE(T5))  u_tile5  (.clk(clk), .addr(a), .rdata(d5));
    weight_bram32_1tile #(.FILE(T6))  u_tile6  (.clk(clk), .addr(a), .rdata(d6));
    weight_bram32_1tile #(.FILE(T7))  u_tile7  (.clk(clk), .addr(a), .rdata(d7));
    weight_bram32_1tile #(.FILE(T8))  u_tile8  (.clk(clk), .addr(a), .rdata(d8));
    weight_bram32_1tile #(.FILE(T9))  u_tile9  (.clk(clk), .addr(a), .rdata(d9));
    weight_bram32_1tile #(.FILE(T10)) u_tile10 (.clk(clk), .addr(a), .rdata(d10));
    weight_bram32_1tile #(.FILE(T11)) u_tile11 (.clk(clk), .addr(a), .rdata(d11));
    weight_bram32_1tile #(.FILE(T12)) u_tile12 (.clk(clk), .addr(a), .rdata(d12));
    weight_bram32_1tile #(.FILE(T13)) u_tile13 (.clk(clk), .addr(a), .rdata(d13));
    weight_bram32_1tile #(.FILE(T14)) u_tile14 (.clk(clk), .addr(a), .rdata(d14));
    weight_bram32_1tile #(.FILE(T15)) u_tile15 (.clk(clk), .addr(a), .rdata(d15));
    assign rdata = (tsel == 4'd0)  ? d0  :
                   (tsel == 4'd1)  ? d1  :
                   (tsel == 4'd2)  ? d2  :
                   (tsel == 4'd3)  ? d3  :
                   (tsel == 4'd4)  ? d4  :
                   (tsel == 4'd5)  ? d5  :
                   (tsel == 4'd6)  ? d6  :
                   (tsel == 4'd7)  ? d7  :
                   (tsel == 4'd8)  ? d8  :
                   (tsel == 4'd9)  ? d9  :
                   (tsel == 4'd10) ? d10 :
                   (tsel == 4'd11) ? d11 :
                   (tsel == 4'd12) ? d12 :
                   (tsel == 4'd13) ? d13 :
                   (tsel == 4'd14) ? d14 : d15;
endmodule
