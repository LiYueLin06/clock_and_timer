/*
 * 按键消抖和长按检测模块
 * 支持短按和长按检测
 */

module key_debounce (
    input wire clk,
    input wire rst_n,
    input wire key_in,           // 按键输入 0是按下
    output reg key_short,        // 短按脉冲
    output reg key_long,         // 长按
    output key_long_pos      // 长按上升沿检测
);

parameter KEY_DELAY = 500000;     // 10ms @50MHz
parameter LONG_PRESS_CNT = 25000000; // 0.5秒长按阈值
//parameter KEY_DELAY = 100;//仿真用
//5324dparameter LONG_PRESS_CNT = 500000;//仿真用 10ms长按

reg key_ff0, key_ff1;

reg [31:0] key_cnt;
reg key_press;
reg key_long_dly;

// 同步和边沿检测
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        key_ff0 <= 1'b1;
        key_ff1 <= 1'b1;
    end else begin
        key_ff0 <= key_in;
        key_ff1 <= key_ff0;
    end
end

assign key_pos = key_ff1 & ~key_ff0;
assign key_neg = ~key_ff1 & key_ff0;

// 消抖和长按检测
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        key_cnt <= 32'd0;
        key_press <= 1'b0;
        key_short <= 1'b0;
        key_long <= 1'b0;
        key_long_dly<=1'b0;
    end else begin
        key_short <= 1'b0;
        key_long_dly <= key_long;//延迟一拍用于边沿检测
        
        if (!key_ff1) begin
            if (key_cnt < LONG_PRESS_CNT) begin
                key_cnt <= key_cnt + 1'b1;
                key_press <= 1'b1;// 标记进入过按下状态
                key_long<=1'b0;
            end else begin
                key_long <= 1'b1;
            end
        end else begin// 按键释放
            if (key_press) begin 
                if (key_cnt < LONG_PRESS_CNT && key_cnt > KEY_DELAY) begin
                    key_short <= 1'b1;  // 短按条件：计数小于长按阈值，大于消抖阈值
                end  
            end
            key_cnt <= 32'd0;
            key_press <= 1'b0;
            key_long <= 1'b0;
        end
    end
end

assign key_long_pos=key_long & (~key_long_dly);//长按上升沿检测

endmodule