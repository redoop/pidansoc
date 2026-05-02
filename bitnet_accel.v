// BitNet 加速器核心 v3
// 1-bit 量化矩阵向量乘法加速器
// 支持最大 64×64 矩阵，2-bit 编码权重 (0→00, +1→01, -1→10)

module bitnet_accel #(
    parameter MAX_DIM = 64,
    parameter ADDR_WIDTH = 12  // 4KB 地址空间
)(
    // 系统信号
    input wire clk,
    input wire rst,

    // Wishbone 从接口
    input wire [ADDR_WIDTH-1:0] wb_adr_i,
    input wire [31:0] wb_dat_i,
    output reg [31:0] wb_dat_o,
    input wire wb_we_i,
    input wire wb_stb_i,
    input wire wb_cyc_i,
    output reg wb_ack_o
);

    // 寄存器地址定义
    localparam ADDR_CTRL      = 12'h000;  // 控制寄存器
    localparam ADDR_STATUS    = 12'h004;  // 状态寄存器
    localparam ADDR_SIZE_M    = 12'h008;  // 矩阵行数
    localparam ADDR_SIZE_N    = 12'h00C;  // 矩阵列数
    localparam ADDR_WEIGHT    = 12'h010;  // 权重区起始 (256 words)
    localparam ADDR_INPUT     = 12'h410;  // 输入区起始 (16 words)
    localparam ADDR_OUTPUT    = 12'h450;  // 输出区起始 (64 words)

    // 状态机
    localparam STATE_IDLE    = 2'd0;
    localparam STATE_COMPUTE = 2'd1;
    localparam STATE_DONE    = 2'd2;

    reg [1:0] state;
    reg [5:0] size_m;  // 1~64
    reg [5:0] size_n;  // 1~64

    // 存储器
    reg [31:0] weight_mem [0:255];   // 256 words (每个 word 存储 16 个 2-bit 权重)
    reg [31:0] input_mem  [0:15];    // 16 words (每个 word 存储 4 个 8-bit 输入)
    reg [31:0] output_mem [0:63];    // 64 words (32-bit 有符号结果)

    // 计算单元
    reg [5:0] row_idx;     // 当前处理的行
    reg [5:0] col_idx;     // 当前处理的列
    reg signed [31:0] accumulator;

    // 控制信号
    wire start = wb_stb_i && wb_cyc_i && wb_we_i && (wb_adr_i == ADDR_CTRL) && wb_dat_i[0];
    wire clear = wb_stb_i && wb_cyc_i && wb_we_i && (wb_adr_i == ADDR_CTRL) && wb_dat_i[1];

    wire done = (state == STATE_DONE);
    wire busy = (state == STATE_COMPUTE);

    // 计算逻辑（组合逻辑）
    wire [11:0] weight_bit_idx = (row_idx * MAX_DIM) + col_idx;
    wire [7:0]  weight_word_idx = weight_bit_idx[11:4];  // 除以 16
    wire [4:0]  weight_bit_offset = {weight_bit_idx[3:0], 1'b0};  // (idx % 16) * 2
    wire [31:0] weight_word = weight_mem[weight_word_idx];
    wire [1:0]  weight_2bit = weight_word[weight_bit_offset +: 2];

    wire signed [1:0] weight_value = (weight_2bit == 2'b00) ? 2'sd0 :
                                      (weight_2bit == 2'b01) ? 2'sd1 :
                                      (weight_2bit == 2'b10) ? -2'sd1 : 2'sd0;

    wire [3:0] input_word_idx = col_idx[5:2];  // 除以 4
    wire [1:0] input_byte_offset = col_idx[1:0];
    wire [31:0] input_word = input_mem[input_word_idx];
    wire signed [7:0] input_value = input_word[input_byte_offset*8 +: 8];

    wire signed [31:0] compute_mac = weight_value * input_value;

    // 地址解码
    wire addr_is_ctrl   = (wb_adr_i == ADDR_CTRL);
    wire addr_is_status = (wb_adr_i == ADDR_STATUS);
    wire addr_is_size_m = (wb_adr_i == ADDR_SIZE_M);
    wire addr_is_size_n = (wb_adr_i == ADDR_SIZE_N);
    wire addr_is_weight = (wb_adr_i >= ADDR_WEIGHT) && (wb_adr_i < ADDR_INPUT);
    wire addr_is_input  = (wb_adr_i >= ADDR_INPUT)  && (wb_adr_i < ADDR_OUTPUT);
    wire addr_is_output = (wb_adr_i >= ADDR_OUTPUT) && (wb_adr_i < (ADDR_OUTPUT + 12'h100));

    wire [7:0] weight_idx = wb_adr_i[9:2];  // 权重区索引 (0~255)
    wire [3:0] input_idx  = wb_adr_i[5:2];  // 输入区索引 (0~15)
    wire [5:0] output_idx = wb_adr_i[7:2];  // 输出区索引 (0~63)

    // Wishbone 读操作
    always @(posedge clk) begin
        if (rst) begin
            wb_dat_o <= 32'h0;
        end else if (wb_stb_i && wb_cyc_i && !wb_we_i) begin
            if (addr_is_status)
                wb_dat_o <= {30'h0, busy, done};
            else if (addr_is_size_m)
                wb_dat_o <= {26'h0, size_m};
            else if (addr_is_size_n)
                wb_dat_o <= {26'h0, size_n};
            else if (addr_is_weight)
                wb_dat_o <= weight_mem[weight_idx];
            else if (addr_is_input)
                wb_dat_o <= input_mem[input_idx];
            else if (addr_is_output)
                wb_dat_o <= output_mem[output_idx];
            else
                wb_dat_o <= 32'h0;
        end
    end

    // Wishbone 确认信号
    always @(posedge clk) begin
        if (rst)
            wb_ack_o <= 1'b0;
        else
            wb_ack_o <= wb_stb_i && wb_cyc_i && !wb_ack_o;
    end

    // Wishbone 写操作和配置寄存器
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            size_m <= 6'd1;
            size_n <= 6'd1;
            for (i = 0; i < 256; i = i + 1)
                weight_mem[i] <= 32'h0;
            for (i = 0; i < 16; i = i + 1)
                input_mem[i] <= 32'h0;
        end else if (wb_stb_i && wb_cyc_i && wb_we_i) begin
            if (addr_is_size_m)
                size_m <= wb_dat_i[5:0];
            else if (addr_is_size_n)
                size_n <= wb_dat_i[5:0];
            else if (addr_is_weight)
                weight_mem[weight_idx] <= wb_dat_i;
            else if (addr_is_input)
                input_mem[input_idx] <= wb_dat_i;
        end
    end

    // 状态机和计算逻辑
    always @(posedge clk) begin
        if (rst || clear) begin
            state <= STATE_IDLE;
            row_idx <= 6'd0;
            col_idx <= 6'd0;
            accumulator <= 32'sd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (start) begin
                        state <= STATE_COMPUTE;
                        row_idx <= 6'd0;
                        col_idx <= 6'd0;
                        accumulator <= 32'sd0;
                    end
                end

                STATE_COMPUTE: begin
                    if (col_idx < size_n) begin
                        // 累加计算，下一个周期完成
                        col_idx <= col_idx + 1;
                        accumulator <= accumulator + compute_mac;
                    end else begin
                        // 当前行计算完成，保存结果
                        output_mem[row_idx] <= accumulator;

                        if (row_idx < size_m - 1) begin
                            // 继续下一行
                            row_idx <= row_idx + 1;
                            col_idx <= 6'd0;
                            accumulator <= 32'sd0;
                        end else begin
                            // 所有行计算完成
                            state <= STATE_DONE;
                        end
                    end
                end

                STATE_DONE: begin
                    // 等待 clear 或新的 start
                    if (start) begin
                        state <= STATE_COMPUTE;
                        row_idx <= 6'd0;
                        col_idx <= 6'd0;
                        accumulator <= 32'sd0;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
