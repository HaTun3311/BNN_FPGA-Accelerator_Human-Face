`include "bnn_defs.vh"
module logit_ram (
    input  wire              clk,
    input  wire              we,
    input  wire [4:0]        waddr,
    input  wire signed [8:0] wdata,
    input  wire [4:0]        raddr,
    output wire signed [8:0] rdata
);
    reg signed [8:0] mem [0:`NUM_CLASSES-1];
    always @(posedge clk) if (we) mem[waddr] <= wdata;
    assign rdata = mem[raddr];
endmodule
