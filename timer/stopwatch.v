module stopwatch (
    input  wire        clk,          // 系统时钟
    input  wire        rst_n,        // 复位信号，低有效
    input  wire        start,        // 开始信号(保持)
    input  wire        clear,        // 清零信号(保持)
    output reg  [31:0] time_data     // BCD格式时间数据 [31:0]
);

// 参数定义
parameter CLK_FREQ = 50_000_000;  // 系统时钟频率，默认50MHz

// 内部信号
reg [31:0] clk_div_cnt;
reg        clk_100hz;
reg        running;
//reg [31:0] time_count;

// BCD码计数器
reg [3:0] hundredth_low;   // 0.01秒个位 (0-9)
reg [3:0] hundredth_high;  // 0.01秒十位 (0-9)
reg [3:0] second_low;      // 秒个位 (0-9)
reg [3:0] second_high;     // 秒十位 (0-5)
reg [3:0] minute_low;      // 分个位 (0-9)
reg [3:0] minute_high;     // 分十位 (0-5)
reg [3:0] hour_low;        // 时个位 (0-9)
reg [3:0] hour_high;       // 时十位 (0-2)

// 时钟分频：产生100Hz时钟（0.01秒周期）
localparam DIV_CNT_MAX = CLK_FREQ / 200 - 1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clk_div_cnt <= 32'd0;
        clk_100hz <= 1'b0;
    end else begin
        if (clk_div_cnt >= DIV_CNT_MAX) begin
            clk_div_cnt <= 32'd0;
            clk_100hz <= ~clk_100hz;  
        end else begin
            clk_div_cnt <= clk_div_cnt + 1;
        end
    end
end
/*
//同步时钟域
wire clear_pulse;
reg clear_ff1,clear_ff0;
always @(posedge clk_100hz or negedge rst_n) begin
    if(!rst_n) begin
        clear_ff1<=1'b0;
        clear_ff0<=1'b0;
    end
    else begin
        clear_ff0<=clear;
        clear_ff1<=clear_ff0;
    end
end
assign clear_pulse=clear_ff1&(~clear_ff0);*/

// 状态控制
always @(posedge clk_100hz or negedge rst_n) begin
    if (!rst_n) begin
        running <= 1'b0;
    end else begin
        if (clear) begin
            running <= 1'b0;
        end else begin
            if(start) running<=1'b1;
            else running<=1'b0;
        end
    end
end
// BCD计数器逻辑
always @(posedge clk_100hz or negedge rst_n) begin
    if (!rst_n) begin
        // 复位所有计数器
        hundredth_low  <= 4'd0;
        hundredth_high <= 4'd0;
        second_low     <= 4'd0;
        second_high    <= 4'd0;
        minute_low     <= 4'd0;
        minute_high    <= 4'd0;
        hour_low       <= 4'd0;
        hour_high      <= 4'd0;
    end else if (clear) begin
        // 清零所有计数器
        hundredth_low  <= 4'd0;
        hundredth_high <= 4'd0;
        second_low     <= 4'd0;
        second_high    <= 4'd0;
        minute_low     <= 4'd0;
        minute_high    <= 4'd0;
        hour_low       <= 4'd0;
        hour_high      <= 4'd0;
    end else if (running) begin
        // 0.01秒个位计数
        if (hundredth_low == 4'd9) begin
            hundredth_low <= 4'd0;
            // 0.01秒十位计数
            if (hundredth_high == 4'd9) begin
                hundredth_high <= 4'd0;
                // 秒个位计数
                if (second_low == 4'd9) begin
                    second_low <= 4'd0;
                    // 秒十位计数
                    if (second_high == 4'd5) begin
                        second_high <= 4'd0;
                        // 分个位计数
                        if (minute_low == 4'd9) begin
                            minute_low <= 4'd0;
                            // 分十位计数
                            if (minute_high == 4'd5) begin
                                minute_high <= 4'd0;
                                // 时个位计数
                                if (hour_low == 4'd9) begin
                                    hour_low <= 4'd0;
                                    // 时十位计数 (最大23)
                                    if (hour_high == 4'd2) begin
                                        hour_high <= 4'd0;
                                    end else begin
                                        hour_high <= hour_high + 1'b1;
                                    end
                                end else begin
                                    hour_low <= hour_low + 1'b1;
                                end
                            end else begin
                                minute_high <= minute_high + 1'b1;
                            end
                        end else begin
                            minute_low <= minute_low + 1'b1;
                        end
                    end else begin
                        second_high <= second_high + 1'b1;
                    end
                end else begin
                    second_low <= second_low + 1'b1;
                end
            end else begin
                hundredth_high <= hundredth_high + 1'b1;
            end
        end else begin
            hundredth_low <= hundredth_low + 1'b1;
        end
    end
end

// 组合BCD数据
always @(*) begin
    time_data[3:0]   = hundredth_low;
    time_data[7:4]   = hundredth_high;
    time_data[11:8]  = second_low;
    time_data[15:12] = second_high;
    time_data[19:16] = minute_low;
    time_data[23:20] = minute_high;
    time_data[27:24] = hour_low;
    time_data[31:28] = hour_high;
end

/*
// 时间计数逻辑
always @(posedge clk_100hz or negedge rst_n) begin
    if (!rst_n) begin
        time_count <= 32'd0;
        time_data <= 32'd0;
    end else if (clear) begin
        time_count <= 32'd0;
        time_data <= 32'd0;
    end else if (running) begin
        time_count <= time_count + 1;
        // BCD转换函数调用
        time_data <= bcd_converter(time_count);
    end
end

// BCD转换函数
function [31:0] bcd_converter;
    input [31:0] cnt;
    reg  [31:0] bcd_result;
    reg  [7:0]  hundredth;   // 0.01秒
    reg  [7:0]  second;      // 秒
    reg  [7:0]  minute;      // 分
    reg  [7:0]  hour;        // 时
begin
    hundredth = cnt % 100;
    second    = (cnt / 100) % 60;
    minute    = (cnt / 6000) % 60;
    hour      = (cnt / 360000) % 24;
    
    bcd_result[3:0]   = hundredth % 10;
    bcd_result[7:4]   = hundredth / 10;
    bcd_result[11:8]  = second % 10;
    bcd_result[15:12] = second / 10;
    bcd_result[19:16] = minute % 10;
    bcd_result[23:20] = minute / 10;
    bcd_result[27:24] = hour % 10;
    bcd_result[31:28] = hour / 10;
    
    bcd_converter = bcd_result;
end
endfunction
*/
endmodule