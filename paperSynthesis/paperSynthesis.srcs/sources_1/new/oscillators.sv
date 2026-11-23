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
    input logic [31:0] midi_data,
    
    output logic [15:0] audio_sig
);
    logic [23:0] midi_rom [0:127];
    logic [15:0] sine_wavetable [0:2047];
    
    logic [7:0] midi_velocity, midi_note, midi_status;
    logic note_begin;
    
    logic [31:0] counter;
    logic [23:0] count_increment;
    logic [15:0] sample;
    
    initial begin
        $readmemh("midi_wavetable_counts.mem", midi_rom, 0, 127);
        $readmemh("sine_2048x16.mem", sine_wavetable, 0, 2047);
    end
    
    always_ff @(posedge Clk) begin
        if (reset)
            count_increment <= '0;
        else if (note_begin)
            count_increment <= midi_rom[midi_note];
    end

    
    always_ff @(posedge Clk) begin
        if (reset) begin
            midi_velocity <= 8'h00;
            midi_note <= 8'h00;
            midi_status <= 8'h80; // note off
            note_begin <= 1'b0;
        end else begin
            note_begin <= 1'b0;
            
            if (midi_data[15:8] == 8'h90 && midi_data[31:24] != 8'h00) begin //note on; always change pitch
                if (midi_status == 8'h80 || midi_velocity == 8'h00 || (midi_data[23:16] != midi_note))
                    note_begin <= 1'b1;
                    
                midi_velocity <= midi_data[31:24];
                midi_note <= midi_data[23:16];
                midi_status <= midi_data[15:8];
            end else if (midi_data[15:8] == 8'h80 || (midi_data[15:8] == 8'h90 && midi_data[31:24] == 8'h00)) begin // note off; only stop note if same as current note
                if (midi_data[23:16] == midi_note) begin
                    midi_velocity <= 8'h00;
                    midi_status <= 8'h80;
                end
            end
        end
        
        if (note_begin)
            note_begin <= 1'b0;
    end
    
    
    always_ff @(posedge Clk) begin
        if (reset || note_begin) begin
            counter <= 32'b0;
        end else begin
            counter <= counter + count_increment;
        end
    end
    
    assign sample = sine_wavetable[counter[31:21]]; // Grabs top 11 bits of counter and uses them to index the sine wavetable
    assign audio_sig = (midi_velocity != 8'h00) ? sample : 16'h0000;

endmodule
