# Tên đề tài: Binarized Neural Network - FPGA Accelerator
## Danh sách file
| File | Vai trò |
|---|---|
| `bnn_defs.vh` | Tham số chung: tần số clock (50MHz), baud UART (921600), kích thước ảnh, số kênh, độ rộng weight từng lớp, đường dẫn thư mục chứa file `.mem` (`MEM_DIR`), ngưỡng margin cho argmax. |
| `bnn_top.v` | Module top: nối UART, các BRAM ảnh/weight/threshold/feature/logit, các engine tính toán, và FSM điều phối toàn bộ quá trình inference. |
| `uart_rx.v` / `uart_tx.v` | UART nhận/gửi 8N1, baud rate cấu hình theo tham số, dùng bộ đếm chia clock. |
| `conv1_engine.v` | Lớp conv nhị phân đầu tiên: input ảnh 8-bit, weight nhị phân (XNOR-popcount kiểu tích lũy +/- theo bit weight), so sánh với ngưỡng (threshold ROM) để nhị phân hoá output từng kênh. 16 kênh song song (LANES). |
| `pool_engine.v` | Max-pool 2x2 tổng quát (tham số hoá CH/IN_SIZE/AW), vì feature là nhị phân nên "max" thực hiện bằng phép OR 4 bit lân cận. Dùng chung cho cả pool1 và pool2. |
| `conv2_engine.v` | Lớp conv nhị phân thứ hai: input nhị phân (16 kênh) x weight nhị phân, tích lũy bằng XNOR (so khớp bit), so ngưỡng ra 32 kênh output nhị phân. |
| `fc1_engine.v` | Lớp fully-connected ẩn (2048 -> 128), input/weight nhị phân, tích lũy theo nhóm (4 groups x 32 lanes) để giảm số BRAM port cần song song, so ngưỡng ra 128 bit. |
| `fc_out_engine.v` | Lớp FC cuối (128 -> 30), input/weight nhị phân, output là **logit có dấu 9-bit** (không nhị phân hoá) cho 30 lớp, ghi vào `logit_ram`. |
| `argmax.v` | Duyệt 30 logit trong `logit_ram`, tìm giá trị lớn nhất (top1) và nhì (top2); kết quả chỉ "valid" nếu chênh lệch top1-top2 >= `MARGIN_THR` (chống nhận diện mơ hồ). |
| `ram_modules.v` | Các BRAM dùng chung: `img_ram` (ảnh vào), `feat_ram` (feature map 1-bit, tham số hoá DEPTH/AW), `thresh_rom` (ROM ngưỡng, nạp từ file `.mem` bằng `$readmemh`). |
| `bram32x512.v` | BRAM 512x32-bit cơ bản, tuỳ chọn nạp sẵn từ file `.mem`. |
| `weight_bram32.v` | `weight_bram32_1tile`: wrapper 1 BRAM 32-bit chứa weight của 1 lớp. `weight_bram32_16tile`: ghép 16 BRAM (dùng cho FC1 vì có 2048x128 bit weight, chia thành 4 group x 4 tile) và mux theo địa chỉ. |
| `logit_ram.v` | RAM nhỏ (30 x 9-bit có dấu) lưu logit đầu ra lớp cuối, đọc bởi `argmax`. |
