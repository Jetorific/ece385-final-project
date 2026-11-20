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
    input logic     [31:0] ch0, ch1, // 32-bit audio inputs (left, right)
    
    output logic    S_BCK, // Clocks for every bit transfer
    output logic    S_DIN, // Data input to DAC
    output logic    S_LRCK // Clocks for each new sample
);
    // Define signals
    logic din;
    logic lrck;
    logic [4:0] counter;
    
    assign S_BCK = bck;
    assign S_DIN = din;
    assign S_LRCK = lrck;
    
    always_ff @(posedge bck or posedge reset) begin
        if (reset) begin
            // Reset counter, lrck, and din since we are starting a new "frame"
            counter <= 5'h1F;
            lrck <= 1'b0;
            din <= 1'b0;
        end else begin
            if (~lrck)
                din <= ch0[counter];
            else
                din <= ch1[counter];
            
            // Switch channel
            if (counter == 5'h0)
                lrck <= ~lrck;
                
            counter <= counter - 1;
        end
    end

endmodule
