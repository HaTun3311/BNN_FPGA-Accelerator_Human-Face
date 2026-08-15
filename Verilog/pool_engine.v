module pool_engine #(
    parameter CH       = 16,
    parameter IN_SIZE  = 32,
    parameter IN_AW    = 14,
    parameter OUT_AW   = 12
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              start,
    output reg                done,
    output reg  [IN_AW-1:0]  in_raddr,
    input  wire                in_rdata,
    output reg                f_we,
    output reg  [OUT_AW-1:0]  f_waddr,
    output reg                 f_wdata
);
    localparam OUT_SIZE = IN_SIZE / 2;
    localparam S_IDLE=0, S_INIT=1, S_R0=2, S_R1=3, S_R2=4, S_R3=5, S_LATCH=6, S_WRITE=7, S_NEXT=8, S_DONE=9;
    reg [3:0] state;
    reg [$clog2(CH)-1:0]      ch;
    reg [$clog2(OUT_SIZE)-1:0] oy, ox;
    reg v0, v1, v2, v3;
    wire [IN_AW-1:0] base = ch * (IN_SIZE*IN_SIZE) + (oy*2) * IN_SIZE + (ox*2);
    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE; done <= 1'b0; f_we <= 1'b0;
        end else begin
            f_we <= 1'b0;
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin ch <= 0; oy <= 0; ox <= 0; state <= S_INIT; end
                end
                S_INIT: begin
                    in_raddr <= base;
                    state <= S_R0;
                end
                S_R0: begin
                    v0 <= in_rdata;
                    in_raddr <= base + 1;
                    state <= S_R1;
                end
                S_R1: begin
                    v1 <= in_rdata;
                    in_raddr <= base + IN_SIZE;
                    state <= S_R2;
                end
                S_R2: begin
                    v2 <= in_rdata;
                    in_raddr <= base + IN_SIZE + 1;
                    state <= S_R3;
                end
                S_R3: begin
                    v3 <= in_rdata;
                    state <= S_WRITE;
                end
                S_WRITE: begin
                    f_wdata <= v0 | v1 | v2 | v3;
                    f_waddr <= ch * (OUT_SIZE*OUT_SIZE) + oy * OUT_SIZE + ox;
                    f_we    <= 1'b1;
                    state   <= S_NEXT;
                end
                S_NEXT: begin
                    if (ox == OUT_SIZE-1) begin
                        ox <= 0;
                        if (oy == OUT_SIZE-1) begin
                            oy <= 0;
                            if (ch == CH-1) state <= S_DONE;
                            else begin ch <= ch + 1'b1; state <= S_INIT; end
                        end else begin oy <= oy + 1'b1; state <= S_INIT; end
                    end else begin ox <= ox + 1'b1; state <= S_INIT; end
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
