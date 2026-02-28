module key_ctrl (
    input wire clk,
    input wire rst_n,
    input wire key1_in,           // 按键1：开始或暂停
    input wire key2_in,           // 按键2：清零
    output reg start,              // 开始信号（保持）
    output reg clear              // 归零信号（保持）
);

// 按键消抖模块实例化
wire key1_short, key1_long;
wire key2_short, key2_long;
wire key1_long_pos, key2_long_pos;

// 实例化按键1消抖模块
key_debounce u_key_debounce1 (
    .clk        (clk),
    .rst_n      (rst_n),
    .key_in     (key1_in),
    .key_short  (key1_short),
    .key_long   (key1_long),
    .key_long_pos(key1_long_pos)
);

// 实例化按键2消抖模块
key_debounce u_key_debounce2 (
    .clk        (clk),
    .rst_n      (rst_n),
    .key_in     (key2_in),
    .key_short  (key2_short),
    .key_long   (key2_long),
    .key_long_pos(key2_long_pos)
);

// 内部寄存器
reg stopwatch_state;//开始或暂停

// 秒表状态控制
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        stopwatch_state<=1'b0;
        start<=1'b0;
        clear <= 1'b0;
    end else begin
        case (stopwatch_state)
            1'b0 : begin//停止时可以清零，运行时不行
                if (key2_short) begin
                    clear <= 1'b1;
                end
                if(key1_short)begin
                    stopwatch_state<=1'b1;
                    start<=1'b1;
                    clear <= 1'b0;//关闭清零状态
                end
            end
            1'b1:begin
                if(key1_short)begin
                    stopwatch_state<=1'b0;
                    start<=1'b0;
                end
            end    
            endcase
    end
end
endmodule