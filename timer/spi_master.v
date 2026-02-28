module spi_master (
    input wire clk,              // 系统时钟 (50MHz)
    input wire rst_n,            // 异步复位，低有效
    
    // 用户接口
    input wire start,            // 开始发送
    input wire [15:0] tx_data,   // 要发送的16位数据
    output reg busy,             // 忙标志
    output reg done,             // 发送完成标志
    
    // SPI物理接口
    output reg sclk,             // SPI时钟
    output reg mosi,             // 主出从入
    output reg cs_n              // 片选 (低有效)
);

// 参数定义
parameter CLK_DIV = 10;           // 时钟分频系数 
localparam IDLE      = 3'd0;
localparam CS_SETUP  = 3'd1;     // 片选建立时间
localparam SEND_BITS = 3'd2;     // 发送数据位
localparam CS_HOLD   = 3'd3;     // 片选保持时间
localparam FINISH    = 3'd4;

// 状态机
reg [2:0] state, next_state;
reg [3:0] bit_cnt;               // 位计数 (0-15)
reg [15:0] shift_reg;            // 移位寄存器
reg [7:0] delay_cnt,delay_cnt2;             // 延时计数器
reg sclk_en;                     // SPI时钟使能
reg sclk_internal;               // 内部SPI时钟
reg rising_edge,falling_edge;//识别sclk_internal的上升沿和下降沿
reg sclk_internal_dly,sclk_dly;// 用于存储信号的前一状态
// 时钟分频：产生SPI时钟
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        delay_cnt <= 8'd0;
        sclk_internal <= 1'b0;
    end else if (sclk_en) begin
        if (delay_cnt == CLK_DIV/2 - 1) begin
            delay_cnt <= 8'd0;
            sclk_internal <= ~sclk_internal;
        end else begin
            delay_cnt <= delay_cnt + 1'b1;
        end
    end else begin
        delay_cnt <= 8'd0;
        sclk_internal <= 1'b0;
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sclk_internal_dly <= 1'b0;
        rising_edge <= 1'b0;
        falling_edge <= 1'b0;
    end else begin
        // 延迟一拍，用于边沿检测
        sclk_internal_dly <= sclk_internal;
        // 上升沿检测：当前为高，前一周期为低
        rising_edge <= sclk_internal & ~sclk_internal_dly;
        // 下降沿检测：当前为低，前一周期为高
        falling_edge <= ~sclk_internal & sclk_internal_dly;
    end
end

// 状态机主流程
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        busy <= 1'b0;
        done <= 1'b0;
        cs_n <= 1'b1;
        sclk <= 1'b0;
        mosi <= 1'b0;
        bit_cnt <= 4'd0;
        shift_reg <= 16'd0;
        sclk_en <= 1'b0;
        delay_cnt2 <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                cs_n <= 1'b1;
                sclk <= 1'b0;
                mosi <= 1'b0;
                busy <= 1'b0;
                done <= 1'b0;
                sclk_en <= 1'b0;
                sclk_dly<=1'b0;
                if (start) begin
                    busy <= 1'b1;
                    shift_reg <= tx_data;      // 锁存要发送的数据
                    bit_cnt <= 4'd15;           // 从最高位开始
                    state <= CS_SETUP;
                end
            end
            
            CS_SETUP: begin
                cs_n <= 1'b0;                   // 拉低片选，开始通信
                // 等待至少50ns (这里用时钟周期计数)
                if (delay_cnt2 < 8'd3) begin     // 50MHz时钟，3周期=60ns
                    delay_cnt2 <= delay_cnt2 + 1'b1;
                end else begin
                    delay_cnt2 <= 8'd0;
                    sclk_en <= 1'b1;             // 使能SPI时钟
                    state <= SEND_BITS;
                end
            end
            
            SEND_BITS: begin
                /*// 使用sclk_internal的上升沿作为时钟基准
                if (sclk_internal) begin
                    case (sclk_en)
                        1: begin  // sclk上升沿：设置数据
                            mosi <= shift_reg[bit_cnt];
                            sclk <= 1'b1;
                        end
                        0: begin  // sclk下降沿：准备下一位
                            sclk <= 1'b0;
                            if (bit_cnt > 0) begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end else begin
                                sclk_en <= 1'b0;  // 关闭SPI时钟
                                state <= CS_HOLD;
                            end
                        end
                    endcase
                end*/
                if(rising_edge) begin
                    mosi <= shift_reg[bit_cnt];
                    sclk_dly<=1'b1;
                    sclk<=sclk_dly;//等一拍再sclk上升沿：设置数据
                end
                if(falling_edge) begin
                    sclk_dly<=1'b0;
                    sclk<=sclk_dly;//等一拍再sclk下降沿：准备下一位
                    if (bit_cnt > 0) begin
                        bit_cnt <= bit_cnt - 1'b1;
                    end else begin
                        sclk_en <= 1'b0;  // 关闭SPI时钟
                        state <= CS_HOLD;
                    end
                end
            end
            
            CS_HOLD: begin
                sclk <= 1'b0;
                // 最后一个SCLK下降沿后等待至少50ns
                if (delay_cnt2 < 8'd3) begin
                    delay_cnt2 <= delay_cnt2 + 1'b1;
                end else begin
                    delay_cnt2 <= 8'd0;
                    cs_n <= 1'b1;                 // 拉高片选，数据锁存到MAX7219
                    state <= FINISH;
                end
            end
            
            FINISH: begin
                busy <= 1'b0;
                done <= 1'b1;                     // 发送完成标志
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule