`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UIUC ECE385
// Engineers: Jet Trommer & Michael Bauer
// 
// Create Date: 11/14/2026 08:59:01 PM
// Design Name: 
// Module Name: paper_synth_top
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


module paper_synth_top(
    input logic Clk,
    input logic reset_rtl_0,
    
    // USB signals
    input logic [0:0] gpio_usb_int_tri_i,
    output logic gpio_usb_rst_tri_o,
    input logic usb_spi_miso,
    output logic usb_spi_mosi,
    output logic usb_spi_sclk,
    output logic usb_spi_ss,
    
    // UART
    input logic uart_rtl_0_rxd,
    output logic uart_rtl_0_txd,
    
    // HDMI
    output logic hdmi_tmds_clk_n,
    output logic hdmi_tmds_clk_p,
    output logic [2:0]hdmi_tmds_data_n,
    output logic [2:0]hdmi_tmds_data_p,
        
    // HEX displays
    output logic [7:0] hex_segA,
    output logic [3:0] hex_gridA,
    output logic [7:0] hex_segB,
    output logic [3:0] hex_gridB,
    
    // I2S outputs
    output logic S_BCK,
    output logic S_DIN,
    output logic S_LRCK
);
    
//    logic [31:0] keycode0_gpio, keycode1_gpio;
    logic clk_25MHz, clk_125MHz, clk_6MHz, clk_3MHz;
    logic locked;
    logic [9:0] drawX, drawY;

    logic hsync, vsync, vde;
    logic [11:0] rgb;
    logic reset_ah;
    
    assign reset_ah = reset_rtl_0;
    
    always_comb begin
        if (drawX[4] ^ drawY[4])
            rgb = 12'hF60;
        else
            rgb = 12'h135;
    end
    
    //Keycode HEX drivers
    hex_driver HexA (
        .clk(Clk),
        .reset(reset_ah),
//        .in({keycode0_gpio[31:28], keycode0_gpio[27:24], keycode0_gpio[23:20], keycode0_gpio[19:16]}),
        .in({4'hE, 4'hC, 4'hE, 4'hB}),
        .hex_seg(hex_segA),
        .hex_grid(hex_gridA)
    );
    
    hex_driver HexB (
        .clk(Clk),
        .reset(reset_ah),
//        .in({keycode0_gpio[15:12], keycode0_gpio[11:8], keycode0_gpio[7:4], keycode0_gpio[3:0]}),
        .in({4'hB, 4'hE, 4'hC, 4'hE}),
        .hex_seg(hex_segB),
        .hex_grid(hex_gridB)
    );
    
    mb_block mb_block_i (
        .clk_100MHz(Clk),
        .gpio_usb_int_tri_i(gpio_usb_int_tri_i),
//        .gpio_usb_keycode_0_tri_o(keycode0_gpio),
//        .gpio_usb_keycode_1_tri_o(keycode1_gpio),
        .gpio_usb_rst_tri_o(gpio_usb_rst_tri_o),
        .reset_rtl_0(~reset_ah), //Block designs expect active low reset, all other modules are active high
        .uart_rtl_0_rxd(uart_rtl_0_rxd),
        .uart_rtl_0_txd(uart_rtl_0_txd),
        .usb_spi_miso(usb_spi_miso),
        .usb_spi_mosi(usb_spi_mosi),
        .usb_spi_sclk(usb_spi_sclk),
        .usb_spi_ss(usb_spi_ss)
    );
        
    //clock wizard configured with a 1x and 5x clock for HDMI. Also generating sample clock for audio interface.
    clk_wiz_0 clk_wiz (
        .clk_out1(clk_25MHz),
        .clk_out2(clk_125MHz),
        .clk_out3(clk_6MHz), // Intended to be around 6.144MHz, actually 6.14754MHz.
        .reset(reset_ah),
        .locked(locked),
        .clk_in1(Clk)
    );
    
    // Simple 1/2 frequency divider
    always_ff @(posedge clk_6MHz or posedge reset_ah) begin
        if (reset_ah)
            clk_3MHz <= 1'b0;
        else
            clk_3MHz <= ~clk_3MHz;
    end
    
    logic [31:0] audio_sig;
    always_ff @(posedge clk_3MHz or posedge reset_ah) begin
        if (reset_ah)
            audio_sig = 32'b0;
        else
            audio_sig = audio_sig + (32'b1 << 17);
    end
    
    audio_interface audio (
        .bck(clk_3MHz),
        .reset(reset_ah),
        .ch0(audio_sig), // Left channel
        .ch1(audio_sig), // Right channel
        
        .S_BCK(S_BCK),
        .S_DIN(S_DIN),
        .S_LRCK(S_LRCK)
    );
    
    //VGA Sync signal generator
    vga_controller vga (
        .pixel_clk(clk_25MHz),
        .reset(reset_ah),
        .hs(hsync),
        .vs(vsync),
        .active_nblank(vde),
        .drawX(drawX),
        .drawY(drawY)
    );    

    //Real Digital VGA to HDMI converter
    hdmi_tx_0 vga_to_hdmi (
        //Clocking and Reset
        .pix_clk(clk_25MHz),
        .pix_clkx5(clk_125MHz),
        .pix_clk_locked(locked),
        .rst(reset_ah),
        //Color and Sync Signals
        .red(rgb[11:8]),
        .green(rgb[7:4]),
        .blue(rgb[3:0]),
        .hsync(hsync),
        .vsync(vsync),
        .vde(vde),
        
        //aux Data (unused)
        .aux0_din(4'b0),
        .aux1_din(4'b0),
        .aux2_din(4'b0),
        .ade(1'b0),
        
        //Differential outputs
        .TMDS_CLK_P(hdmi_tmds_clk_p),          
        .TMDS_CLK_N(hdmi_tmds_clk_n),          
        .TMDS_DATA_P(hdmi_tmds_data_p),         
        .TMDS_DATA_N(hdmi_tmds_data_n)          
    );
    
endmodule