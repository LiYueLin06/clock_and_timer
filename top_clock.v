`timescale 1ns / 1ps


module top_clock(
    input wire clk,          // 50MHz系统时钟
    input wire rst_n,            // 复位按键
    input wire key1_in,
    input wire key2_in,
    // MAX7219接口
    output wire cs_n,
    output wire sclk,
    output wire mosi
    );
wire [31:0] time_data;
wire start,clear;

key_ctrl u_key_ctrl(
    .clk        (clk),
    .rst_n      (rst_n),
    .key1_in    (key1_in),           // 按键1：开始或暂停
    .key2_in    (key2_in),           // 按键2：清零
    .start      (start),              // 开始信号（时间运行时为1）
    .clear      (clear)              // 归零信号
);

stopwatch u_stopwatch(
    .clk        (clk),          // 系统时钟
    .rst_n      (rst_n),        // 复位信号，低有效
    .start      (start),        // 开始信号
    .clear      (clear),        // 清零信号
    .time_data  (time_data)     // BCD格式时间数据 [31:0]
);

max7219_ctrl u_max7219_ctrl (
    .clk        (clk),
    .rst_n      (rst_n),
    .time_data  (time_data),
    .spi_sclk   (sclk),
    .spi_mosi   (mosi),
    .spi_cs_n   (cs_n),
    .init_done  ()
);   
endmodule
