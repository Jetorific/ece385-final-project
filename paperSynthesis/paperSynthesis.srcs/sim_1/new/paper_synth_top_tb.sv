`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/19/2026 07:54:18 PM
// Design Name: 
// Module Name: paper_synth_top_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module paper_synth_top_tb();
    logic Clk;
    logic reset;
    logic [15:0] sw;
    
    logic S_BCK;
    logic S_DIN;
    logic S_LRCK;
    
    paper_synth_top top_level (
        .Clk(Clk),
        .reset_rtl_0(reset),
        .sw_i(sw),
        .gpio_usb_int_tri_i(1'b0),
        .usb_spi_miso(1'b0),
        .uart_rtl_0_rxd(1'b0),
        
        .S_BCK(S_BCK),
        .S_DIN(S_DIN),
        .S_LRCK(S_LRCK)
    );
    
    always #5 Clk = ~Clk;
    
    initial begin
        Clk = 1'b0;
        reset = 1'b0;
        sw = 16'h2;
    end
    
    initial begin
        #5
        reset = 1'b1;
        #5
        reset = 1'b0;
        #10000000
        $finish;
    end

endmodule
