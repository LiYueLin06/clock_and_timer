`timescale 1ns / 1ps
module tb_top_clock();
reg clk;
reg rst_n;
reg key1_in,key2_in;
wire cs_n,sclk,mosi;
always #10 clk=~clk;
initial begin
    clk=1'b0;
    rst_n=1'b0;
    key1_in=1'b1;
    key2_in=1'b1;
    #20 rst_n=1'b1;
    #30 key1_in=1'b0;//抖动
    #40 key1_in=1'b1;
    #40 key1_in=1'b0;//开始秒表
    #3000 key1_in=1'b1;
    #30000000 key1_in=1'b0;//等30ms,暂停秒表
    #3000 key1_in=1'b1;
    #20 key2_in=1'b0;//归零
    #3000 key2_in=1'b1;
end
top_clock u_top_clock(
    .clk(clk),          // 50MHz系统时钟
    .rst_n(rst_n),            // 复位按键
    .key1_in(key1_in),
    .key2_in(key2_in),
    // MAX7219接口
    .cs_n(cs_n),
    .sclk(sclk),
    .mosi(mosi)
);
endmodule
