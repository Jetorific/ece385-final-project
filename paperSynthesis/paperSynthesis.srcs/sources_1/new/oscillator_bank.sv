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


module oscillator_bank #(
    parameter int NUM_OSCILLATORS = 1
)(
    input logic Clk,
    input logic reset,
    input logic [15:0] sw,
    input logic [31:0] midi_data,
    
    output logic signed [15:0] audio_sig
);
    // Requires NUM_OSCILLATORS >= 1.
    localparam int NUM_OSC_LOG2 = $clog2(NUM_OSCILLATORS);

    // freelist variables
    logic [NUM_OSC_LOG2-1:0] freelist_head;
    logic freelist_free [NUM_OSCILLATORS];
    logic [NUM_OSC_LOG2-1:0] freelist_next [NUM_OSCILLATORS];
    logic [NUM_OSC_LOG2-1:0] freelist_prev [NUM_OSCILLATORS];

    logic [23:0] midi_rom [0:127];
    logic signed [15:0] wavetable_0 [0:2047];
    logic signed [15:0] wavetable_1 [0:2047];
    
    logic signed [15:0] wavetable [0:2047];
    
    logic [7:0] midi_velocity, midi_note, midi_status;
    logic note_begin;
    
    logic [31:0] counter [0:NUM_OSCILLATORS-1];
    logic signed [15:0] osc_sample [0:NUM_OSCILLATORS-1];
    logic signed [15:0] osc_audio  [0:NUM_OSCILLATORS-1];
    
    initial begin
        $readmemh("midi_wavetable_counts.mem", midi_rom, 0, 127);
        $readmemh("smth2_2048x16.mem", wavetable_0, 0, 2047);
        $readmemh("sine_2048x16.mem", wavetable_1, 0, 2047);
    end
    
    // MIDI control logic
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
    
    // freelist logic
    always_ff @(posedge Clk) begin
        if (reset) begin
            for (int i = 0; i < NUM_OSCILLATORS; i++) begin
                freelist_head <= 'b0;
                freelist_free[i] <= 1'b1;
                freelist_next[i] <= (i+1 == NUM_OSCILLATORS) ? 'b0 : (i+1);
                freelist_prev[i] <= (i == 'b0) ? (NUM_OSCILLATORS-1) : (i-1);
            end
        end else begin
            
        end
    end
    
    assign wavetable = sw[12] ? wavetable_0 : wavetable_1;

    generate
        for (genvar i = 0; i < NUM_OSCILLATORS; i++) begin : gen_oscillators
    
            // Each oscillator reads the shared wavetable with its own counter/phase
    //            assign osc_sample[i] = wavetable[counter[i][31:21]];
            assign osc_sample[i] = i ? wavetable_0[counter[i][31:21]] : wavetable[counter[i][31:21]];
            oscillator u_oscillator (
                .Clk             (Clk),
                .reset           (reset),
                .count_increment (midi_rom[midi_note]),
                .sample          (osc_sample[i]),
                .midi_velocity   (midi_velocity),
                .audio_sig       (osc_audio[i]),
                .counter         (counter[i])
            );
    
        end
    endgenerate

    localparam int MIX_SHIFT = NUM_OSC_LOG2;
    localparam int MIX_WIDTH = 16 + MIX_SHIFT;
    
    logic signed [MIX_WIDTH-1:0] mix_sum;
    logic signed [MIX_WIDTH-1:0] mix_scaled;
    
    always_comb begin
        mix_sum = '0;
    
        for (int i = 0; i < NUM_OSCILLATORS; i++) begin
            mix_sum = mix_sum
                    + $signed({
                        {MIX_SHIFT{osc_audio[i][15]}},
                        osc_audio[i]
                      });
        end
    
        mix_scaled = mix_sum >>> MIX_SHIFT;
    end
    
    assign audio_sig = mix_scaled[15:0];

endmodule
