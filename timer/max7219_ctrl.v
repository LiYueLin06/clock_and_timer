module max7219_ctrl (
    input wire clk,              // 系统时钟 (50MHz)
    input wire rst_n,            // 异步复位，低有效
    input wire [31:0] time_data, // BCD格式时间数据 [31:0]
    
    // SPI接口
    output wire spi_sclk,        // SPI时钟
    output wire spi_mosi,        // SPI数据
    output wire spi_cs_n,        // SPI片选
    
    // 调试输出（可选）
    output reg init_done         // 初始化完成标志
);

// 参数定义
localparam IDLE         = 4'd0;
localparam INIT_START   = 4'd1;
localparam INIT_WAIT    = 4'd2;
localparam INIT_SEND    = 4'd3;
localparam INIT_NEXT    = 4'd4;
localparam DISP_START   = 4'd5;
localparam DISP_SEND    = 4'd6;
localparam DISP_NEXT    = 4'd7;
localparam WAIT_NEXT    = 4'd8;

// MAX7219寄存器地址
localparam REG_NO_OP     = 8'h00;
localparam REG_DIGIT0    = 8'h01;
localparam REG_DIGIT1    = 8'h02;
localparam REG_DIGIT2    = 8'h03;
localparam REG_DIGIT3    = 8'h04;
localparam REG_DIGIT4    = 8'h05;
localparam REG_DIGIT5    = 8'h06;
localparam REG_DIGIT6    = 8'h07;
localparam REG_DIGIT7    = 8'h08;
localparam REG_DECODE_MODE = 8'h09;
localparam REG_INTENSITY = 8'h0A;
localparam REG_SCAN_LIMIT = 8'h0B;
localparam REG_SHUTDOWN  = 8'h0C;
localparam REG_DISPLAY_TEST = 8'h0F;

// 内部信号
reg [3:0] state, next_state;
reg [2:0] init_step;            // 初始化步骤
reg [2:0] digit_idx;            // 数码管索引 (0-7)
reg [15:0] spi_tx_data;         // 发送给SPI模块的数据
reg spi_start;                   // 启动SPI发送
wire spi_busy;
wire spi_done;

// 实例化SPI主控模块
spi_master #(
    .CLK_DIV(10)                   
) u_spi_master (
    .clk        (clk),
    .rst_n      (rst_n),
    .start      (spi_start),
    .tx_data    (spi_tx_data),
    .busy       (spi_busy),
    .done       (spi_done),
    .sclk       (spi_sclk),
    .mosi       (spi_mosi),
    .cs_n       (spi_cs_n)
);

// 状态机主流程
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        init_step <= 3'd0;
        digit_idx <= 3'd0;
        spi_start <= 1'b0;
        init_done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                spi_start <= 1'b0;
                if (!init_done) begin
                    state <= INIT_START;
                end else begin
                    state <= DISP_START;
                end
            end
            
            // ============ 初始化流程 ============
            INIT_START: begin
                init_step <= 3'd0;
                state <= INIT_SEND;
            end
            
            INIT_SEND: begin
                if (!spi_busy && !spi_start) begin
                    // 准备初始化数据: {8'h地址, 8'h数据}
                    case (init_step)
                        3'd0:spi_tx_data<={8'h09, 8'hFF};// 所有位BCD解码
                        3'd1:spi_tx_data <= {8'h0B, 8'h07};// 扫描所有8位数码管
                        3'd2:spi_tx_data <= {8'h0A, 8'h08};// 中等亮度
                        3'd3:spi_tx_data <= {8'h0C, 8'h01};// 正常操作模式 
                        3'd4:spi_tx_data <= {8'h0F, 8'h00};//关闭测试模式
                    endcase
                    spi_start <= 1'b1;           // 启动SPI发送
                    state <= INIT_WAIT;
                end
            end
            
            INIT_WAIT: begin
                spi_start <= 1'b0;                // 清除启动信号
                if (spi_done) begin
                    state <= INIT_NEXT;
                end
            end
            
            INIT_NEXT: begin
                if (init_step < 3'd4) begin
                    init_step <= init_step + 1'b1;
                    state <= INIT_SEND;
                end else begin
                    init_done <= 1'b1;            // 初始化完成
                    state <= IDLE;
                end
            end
            
            // ============ 显示数据更新 ============
            DISP_START: begin
                digit_idx <= 3'd0;
                state <= DISP_SEND;
            end
            
            DISP_SEND: begin
                if (!spi_busy && !spi_start) begin
                    // 准备显示数据
                    case (digit_idx)
                        0: spi_tx_data <= {REG_DIGIT0,  4'b0000, time_data[3:0]};
                        1: spi_tx_data <= {REG_DIGIT1,  4'b0000, time_data[7:4]};
                        2: spi_tx_data <= {REG_DIGIT2,  4'b1000, time_data[11:8]};  // 带小数点
                        3: spi_tx_data <= {REG_DIGIT3,  4'b0000, time_data[15:12]};
                        4: spi_tx_data <= {REG_DIGIT4,  4'b1000, time_data[19:16]};  // 带小数点
                        5: spi_tx_data <= {REG_DIGIT5,  4'b0000, time_data[23:20]};
                        6: spi_tx_data <= {REG_DIGIT6,  4'b1000, time_data[27:24]};  // 带小数点
                        7: spi_tx_data <= {REG_DIGIT7,  4'b0000, time_data[31:28]};
                        default: spi_tx_data <= 16'd0;
                    endcase
                    spi_start <= 1'b1;
                    state <= WAIT_NEXT;
                end
            end
            
            WAIT_NEXT: begin
                spi_start <= 1'b0;
                if (spi_done) begin
                    if (digit_idx < 3'd7) begin
                        digit_idx <= digit_idx + 1'b1;
                        state <= DISP_SEND;
                    end else begin
                        state <= IDLE;            // 一轮显示更新完成
                    end
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule