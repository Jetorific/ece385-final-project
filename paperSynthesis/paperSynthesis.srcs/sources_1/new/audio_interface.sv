`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/19/2026 03:46:30 PM
// Design Name: 
// Module Name: audio_interface
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


module audio_interface(
    input logic     bck, // Clock input. freq(BCK) = 64 * sample_rate
    input logic     reset,
    input logic     [31:0] ch0, // 32-bit audio inputs (left, right)
    input logic     [31:0] ch1, //  ...
    
    output logic    S_BCK,  // Clocks for every bit transfer
    output logic    S_DIN,  // Data input to DAC
    output logic    S_LRCK, // Clocks for each new sample
    output logic    sample_en
);
    // Define signals
    logic din;
    logic lrck;
    logic [5:0] counter;
    logic [5:0] next_counter;
    logic [31:0] ch0_sample;
    logic [31:0] ch1_sample;
    
    assign S_BCK = bck;
    assign S_DIN = din;
    assign S_LRCK = lrck;
    
    assign next_counter = counter - 1;
    assign lrck = next_counter[5];
    
    always_ff @(negedge bck or posedge reset) begin
        if (reset) begin
            // Reset counter, lrck, and din since we are starting a new "frame"
            counter <= 6'd63;
            ch0_sample <= 32'b0;
            ch1_sample <= 32'b0;
        end else begin
            counter <= next_counter;
            
            if (sample_en) begin
                ch0_sample <= ch0;
                ch1_sample <= ch1;
            end
        end
    end
    
    always_comb begin
        sample_en = (counter == 32'b0);
    
        if (~counter[5])
            din = ch0_sample[counter[4:0]];
        else
            din = ch1_sample[counter[4:0]];
    end

endmodule
