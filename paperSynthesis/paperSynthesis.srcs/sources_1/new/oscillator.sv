`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/24/2026 06:45:02 PM
// Design Name: 
// Module Name: oscillator
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


module oscillator(
    input logic Clk,
    input logic reset,
    input logic [23:0] count_increment,
    input logic signed [15:0] sample,
    input logic [7:0] midi_velocity,

    output logic signed [15:0] audio_sig,
    output logic [31:0] counter
);
    logic signed [7:0] velocity_gain;
    logic signed [32:0] scaled_sample;

    // Update counter
    always_ff @(posedge Clk) begin
        if (reset) begin
            counter <= 32'b0;
        end else begin
            counter <= counter + count_increment;
        end
    end
    
    // Zero-extend MIDI velocity
    assign velocity_gain = $signed({1'b0, midi_velocity[6:0]});
    
    // Scale sample by velocity
    assign scaled_sample = sample * velocity_gain;
    
    // Divide by 128 to rescale sample to 16 bits
    assign audio_sig = scaled_sample >>> 7;
endmodule
