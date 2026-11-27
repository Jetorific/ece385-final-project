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
    input logic [15:0] sw_i,
    
    output logic [15:0] led_o,
    
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
    logic sys_clk_100;
    logic sys_aresetn;
    logic sys_reset_ah;
    assign sys_reset_ah = ~sys_aresetn;

    logic [31:0] midi_data;
    logic midi_toggle_previous, midi_toggle;
    logic midi_valid;
    logic [15:0] audio_hold;
    
    logic req_toggle;
    logic ack_toggle;
    
//    logic [31:0] keycode0_gpio, keycode1_gpio;
    logic clk_25MHz, clk_125MHz, clk_12MHz;
    logic locked;
    logic [9:0] drawX, drawY;
    logic [31:0] ch0, ch1;
    logic sample_en;

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
    
    // MIDI is valid if midi_toggle has changed
    always_ff @(posedge sys_clk_100) begin
        if (sys_reset_ah)
            midi_toggle_previous <= 1'b0;
        else
            midi_toggle_previous <= midi_toggle;
    end
    assign midi_valid = !sys_reset_ah && (midi_toggle ^ midi_toggle_previous);
    
    //Keycode HEX drivers
    hex_driver HexA (
        .clk(Clk),
        .reset(reset_ah),
        .in({midi_data[31:28], midi_data[27:24], midi_data[23:20], midi_data[19:16]}),
        .hex_seg(hex_segA),
        .hex_grid(hex_gridA)
    );
    
    hex_driver HexB (
        .clk(Clk),
        .reset(reset_ah),
        .in({midi_data[15:12], midi_data[11:8], midi_data[7:4], midi_data[3:0]}),
        .hex_seg(hex_segB),
        .hex_grid(hex_gridB)
    );
    
//    assign led_o = audio_hold;
    logic midi_seen;
    logic [7:0] midi_event_count;
    
    always_ff @(posedge sys_clk_100) begin
        if (sys_reset_ah) begin
            midi_seen        <= 1'b0;
            midi_event_count <= '0;
        end else if (midi_valid) begin
            midi_seen        <= 1'b1;
            midi_event_count <= midi_event_count + 1'b1;
        end
    end
    
    assign led_o = {
        6'b0,
        midi_toggle,
        midi_seen,
        midi_event_count
    };
    
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
        .usb_spi_ss(usb_spi_ss),
        .gpio_midi_o_tri_o(midi_data),
        .gpio_midi_toggle_tri_o(midi_toggle),
        .sys_clk_100(sys_clk_100),
        .sys_aresetn(sys_aresetn)
    );
        
    //clock wizard configured with a 1x and 5x clock for HDMI. Also generating sample clock for audio interface.
    clk_wiz_0 clk_wiz (
        .clk_out1(clk_25MHz),
        .clk_out2(clk_125MHz),
        .clk_out3(clk_12MHz), // Intended to be around 6.144MHz, actually 6.14754MHz.
        .reset(reset_ah),
        .locked(locked),
        .clk_in1(Clk) //Sync with MicroBlaze peripheral clock
    );
    
    oscillator_bank #(
        .NUM_OSCILLATORS(8)
    ) osc_bank (
        .Clk(sys_clk_100),
        .reset(sys_reset_ah),
        .sw(sw_i),
        .midi_data(midi_data),
        .midi_valid(midi_valid),
        .req_toggle(req_toggle),
        
        .audio_hold(audio_hold),
        .ack_toggle(ack_toggle)
    );
    
    assign ch0 = {{2{audio_hold[15]}}, audio_hold, 14'b0};
    assign ch1 = ch0;
    
    audio_interface audio (
        .bck(clk_12MHz), // Choosing 6MHz instead of the generated 3MHz gets a 96kHz sample rate
        .reset(sys_reset_ah),
        .ch0(ch0), // Left channel
        .ch1(ch1), // Right channel
        .ack_toggle(ack_toggle),
        
        .S_BCK(S_BCK),
        .S_DIN(S_DIN),
        .S_LRCK(S_LRCK),
        .req_toggle(req_toggle)
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