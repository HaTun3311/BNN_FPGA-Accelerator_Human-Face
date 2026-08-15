`ifndef BNN_DEFS_VH
`define BNN_DEFS_VH
`define MEM_DIR "/home/ise/Xilinx-Project/DATT/"
`define CLK_FREQ_HZ   50_000_000
`define BAUD_RATE     921600
`define BAUD_DIV      54
`define N_LANES        32
`define BRAM_DEPTH     512
`define BRAM_WIDTH     32
`define BRAM_LANES     1
`define IMG_SIZE       32
`define IMG_PIXELS     1024
`define C1_OUT_CH      16
`define C1_TAPS        9
`define C1_W_AW        4
`define P1_SIZE        16
`define C2_OUT_CH      32
`define C2_IN_CH       16
`define C2_TAPS        144
`define C2_W_AW        8
`define P2_SIZE        8
`define FC1_IN         2048
`define FC1_OUT        128
`define FC1_LANES      32
`define FC1_GROUPS     4
`define FC1_W_AW        13
`define FCOUT_IN       128
`define NUM_CLASSES    30
`define FCOUT_W_AW      7
`define MARGIN_THR     3
`endif
