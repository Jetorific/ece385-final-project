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
    input  logic        bck,
    input  logic        reset,
    input  logic [31:0] ch0,
    input  logic [31:0] ch1,
    input  logic        ack_toggle,

    output logic        S_BCK,
    output logic        S_DIN,
    output logic        S_LRCK,
    output logic        req_toggle
);
    logic        din, lrck;
    logic [5:0]  counter, next_counter;
    logic [31:0] ch0_sample, ch1_sample;     // active (being shifted out)
    logic [31:0] ch0_pending, ch1_pending;   // loaded when ack arrives
    logic        sample_request;
    (* ASYNC_REG = "TRUE" *) logic [1:0] ack_sync;

    assign S_BCK = bck;
    assign S_DIN = din;
    assign S_LRCK = lrck;

    assign next_counter = counter - 1;
    assign lrck = next_counter[5];
    
    // Fix for async reset path timing issues
    logic reset_bck;
    xpm_cdc_async_rst #(
        .DEST_SYNC_FF(4),
        .RST_ACTIVE_HIGH(1)
    ) reset_sync (
        .src_arst  (reset),
        .dest_clk  (bck),
        .dest_arst (reset_bck)
    );
    
    // Request a new sample mid-frame so it arrives well before the boundary
    assign sample_request = (counter == 6'd32);

    always_ff @(negedge bck or posedge reset_bck) begin
        if (reset_bck) begin
            counter     <= 6'd63;
            req_toggle  <= 1'b0;
            ack_sync    <= 2'b00;
            ch0_pending <= 32'b0;
            ch1_pending <= 32'b0;
            ch0_sample  <= 32'b0;
            ch1_sample  <= 32'b0;
        end else begin
            counter  <= next_counter;
            ack_sync <= {ack_sync[0], ack_toggle};

            if (sample_request)
                req_toggle <= ~req_toggle;

            if (ack_sync[1] ^ ack_sync[0]) begin   // held sample is ready
                ch0_pending <= ch0;
                ch1_pending <= ch1;
            end

            if (counter == 6'd0) begin             // frame boundary
                ch0_sample <= ch0_pending;
                ch1_sample <= ch1_pending;
            end
        end
    end

    always_comb begin
        if (~counter[5])
            din = ch0_sample[counter[4:0]];
        else
            din = ch1_sample[counter[4:0]];
    end
endmodule
