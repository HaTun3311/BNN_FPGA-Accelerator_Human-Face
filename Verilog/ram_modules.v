`include "bnn_defs.vh"
module img_ram (
    input  wire        clk,
    input  wire        we,
    input  wire [9:0]  waddr,
    input  wire [7:0]  wdata,
    input  wire [9:0]  raddr,
    output wire [7:0]  rdata
);
    reg [7:0] mem [0:1023];
    always @(posedge clk) if (we) mem[waddr] <= wdata;
    assign rdata = mem[raddr];
endmodule
module feat_ram #(
    parameter DEPTH = 16384,
    parameter AW    = 14
)(
    input  wire            clk,
    input  wire            we,
    input  wire [AW-1:0]   waddr,
    input  wire            wdata,
    input  wire [AW-1:0]   raddr,
    output wire            rdata
);
    reg mem [0:DEPTH-1];
    always @(posedge clk) if (we) mem[waddr] <= wdata;
    assign rdata = mem[raddr];
endmodule
module thresh_rom #(
    parameter DEPTH = 16,
    parameter AW    = 4,
    parameter WIDTH = 14,
    parameter FILE  = "t1.mem"
)(
    input  wire              clk,
    input  wire [AW-1:0]     addr,
    output wire [WIDTH-1:0]  data
);
    reg [WIDTH-1:0] mem [0:DEPTH-1];
    initial $readmemh({`MEM_DIR, FILE}, mem);
    assign data = mem[addr];
endmodule
