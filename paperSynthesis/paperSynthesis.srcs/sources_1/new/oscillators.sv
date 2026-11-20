`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/20/2026 04:41:00 AM
// Design Name: 
// Module Name: oscillators
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


module oscillators (
    input logic Clk,
    input logic bck,
    input logic sample_en,
    input logic reset,
    input logic [15:0] sw,
    
    output logic [15:0] audio_sig
);
    
//    logic [15:0] counter;
//    always_ff @(negedge S_BCK or posedge reset_ah) begin
//        if (reset_ah)
//            counter <= 32'b0;
//        else if (sample_en)
//            counter <= counter + (16'b1 << 7);
//    end
    
//    assign audio_sig = counter;
    
    logic [15:0] counter, value;
    logic sq_o;
    always_ff @(negedge bck or posedge reset) begin
        if (reset) begin
            sq_o <= 1'b0;
            counter <= 16'b0;
        end else if (sample_en) begin
            if (counter >= sw) begin
                counter <= 0;
                sq_o <= ~sq_o;
            end else
                counter <= counter + 1;
        end
    end
    
    assign audio_sig = sq_o ? 16'h7FFF : 16'h8000;

endmodule
