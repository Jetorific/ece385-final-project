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
    logic [22:0] midi_rom [0:127];
    
    logic [7:0] midi_velocity, midi_note, midi_status;
    logic note_begin;
    
    logic [22:0] counter, counter_end;
    logic sq_high;
    
    
    initial begin
        $readmemh("midi_terminal_counts.mem", midi_rom, 0, 127);
    end
    
    always_ff @(posedge Clk) begin
        if (reset)
            counter_end <= '0;
        else if (note_begin)
            counter_end <= midi_rom[midi_note];
    end

    
    always_ff @(posedge Clk) begin
        if (reset) begin
            midi_velocity <= 8'h00;
            midi_note <= 8'h00;
            midi_status <= 8'h80; // note off
            note_begin <= 1'b0;
        end else begin
            if (midi_data[15:8] == 8'h90 && midi_data[31:24] != 8'h00) begin //note on; always change pitch
                if (midi_status == 8'h80 || midi_velocity == 8'h00 || (midi_data[23:16] != midi_note))
                    note_begin <= 1'b1;
                    
                midi_velocity <= midi_data[31:24];
                midi_note <= midi_data[23:16];
                midi_status <= midi_data[15:8];
            end else if (midi_data[15:8] == 8'h80 || (midi_data[15:8] == 8'h90 && midi_data[31:24] == 8'h00)) begin // note off; only stop note if same as current note
                if (midi_data[23:16] == midi_note) begin
                    midi_velocity <= 8'h00;
                    midi_note <= midi_note;
                    midi_status <= 8'h80;
                end
            end
        end
        
        if (note_begin)
            note_begin <= 1'b0;
    end
    
    
    always_ff @(posedge Clk) begin
        if (reset || note_begin) begin
            sq_high <= 1'b0;
            counter <= 16'b0;
        end else begin
            if (counter == counter_end) begin
                counter <= 0;
                sq_high <= ~sq_high;
            end else
                counter <= counter + 23'b1;
        end
    end
    
    assign audio_sig = (midi_velocity != 8'h00) ? (sq_high ? 16'h7FFF : 16'h8000) : 16'h0000;

endmodule
