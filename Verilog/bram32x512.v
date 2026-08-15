`include "bnn_defs.vh"
module bram32x512 #(
    parameter FILE = ""
)(
    input  wire        clk,
    input  wire        we,
    input  wire [8:0]  waddr,
    input  wire [31:0] wdata,
    input  wire [8:0]  raddr,
    output wire [31:0] rdata
);
    reg [31:0] mem [0:511];
    initial begin
        if (FILE != "") $readmemh({`MEM_DIR, FILE}, mem);
    end
    always @(posedge clk) if (we) mem[waddr] <= wdata;
    assign rdata = mem[raddr];
endmodule
