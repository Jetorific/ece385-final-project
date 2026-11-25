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
    parameter int NUM_OSCILLATORS = 4
)(
    input logic Clk,
    input logic reset,
    input logic [15:0] sw,
    input logic [31:0] midi_data,
    input logic midi_valid, // High for one clock cycle when new valid midi_data is first valid
    
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
    
    // Oscillator data
    logic [6:0] voice_note     [0:NUM_OSCILLATORS-1];
    logic [7:0] voice_velocity [0:NUM_OSCILLATORS-1];
    logic [3:0] voice_channel  [0:NUM_OSCILLATORS-1];
    
    logic [31:0] counter [0:NUM_OSCILLATORS-1];
    logic signed [15:0] osc_sample [0:NUM_OSCILLATORS-1];
    logic signed [15:0] osc_audio  [0:NUM_OSCILLATORS-1];
    
    initial begin
        $readmemh("midi_wavetable_counts.mem", midi_rom, 0, 127);
        $readmemh("smth2_2048x16.mem", wavetable_0, 0, 2047);
        $readmemh("sine_2048x16.mem", wavetable_1, 0, 2047);
    end
    
    
    // MIDI input parsing
    logic [7:0] incoming_status;
    logic [6:0] incoming_note;
    logic [7:0] incoming_velocity;
    logic [3:0] incoming_channel;
    
    logic note_on_event;
    logic note_off_event;
    
    assign incoming_status   = midi_data[15:8];
    assign incoming_note     = midi_data[22:16];
    assign incoming_velocity = midi_data[31:24];
    assign incoming_channel  = incoming_status[3:0];
    
    assign note_on_event =
        midi_valid &&
        (incoming_status[7:4] == 4'h9) &&
        (incoming_velocity != 8'h00);
    
    assign note_off_event =
        midi_valid &&
        (
            (incoming_status[7:4] == 4'h8) ||
            (
                (incoming_status[7:4] == 4'h9) &&
                (incoming_velocity == 8'h00)
            )
        );
    
    // Find existing match for incoming note (to turn it off or update its velocity)
    logic match_found;
    logic [NUM_OSC_LOG2-1:0] match_index;
    
    always_comb begin
        match_found = 1'b0;
        match_index = '0;
    
        for (int i = 0; i < NUM_OSCILLATORS; i++) begin
            if (!match_found &&
                !freelist_free[i] &&
                (voice_note[i] == incoming_note) &&
                (voice_channel[i] == incoming_channel)) begin
    
                match_found = 1'b1;
                match_index = NUM_OSC_LOG2'(i);
            end
        end
    end
    
    // freelist logic
    logic allocate_request;
    logic free_request;
    logic update_existing_request;
    
    logic [NUM_OSC_LOG2-1:0] freelist_freethis;
    logic [NUM_OSC_LOG2-1:0] freelist_following;
    logic [NUM_OSC_LOG2-1:0] freelist_previous;
    logic [NUM_OSC_LOG2-1:0] freelist_oldhead;
    logic [NUM_OSC_LOG2-1:0] freelist_previous2;
    
    always_comb begin
        // freelist drivers
        allocate_request =
            note_on_event &&
            !match_found;
        update_existing_request =
            note_on_event &&
            match_found;
        free_request =
            note_off_event &&
            match_found;
        freelist_freethis = match_index;
        
        // Helper variables
        freelist_previous = freelist_prev[freelist_freethis];
        freelist_following = freelist_next[freelist_freethis];
        freelist_oldhead =
            (freelist_freethis == freelist_head)
            ? freelist_following
            : freelist_head;
        freelist_previous2 =
            (freelist_oldhead == freelist_following)
            ? freelist_previous
            : freelist_prev[freelist_oldhead];
    end
    
    always_ff @(posedge Clk) begin
        if (reset) begin
            freelist_head <= 'b0;
            for (int i = 0; i < NUM_OSCILLATORS; i++) begin
                freelist_free[i] <= 1'b1;
                freelist_next[i] <= (i+1 == NUM_OSCILLATORS) ? 'b0 : (i+1);
                freelist_prev[i] <= (i == 'b0) ? (NUM_OSCILLATORS-1) : (i-1);
            end
        end else begin
//        USE OSCILLATOR PYTHON CODE
//            oscillator_index = self.head
//            oscillator = self.oscillators[oscillator_index]
//            self.head = oscillator.next
//            oscillator.free = False
            if (allocate_request) begin
                freelist_free[freelist_head] <= 1'b0;
                freelist_head <= freelist_next[freelist_head];
            
//        FREE OSCILLATOR PYTHON CODE
//            oscillator = self.oscillators[oscillator_index]
//            previous = oscillator.prev
//            following = oscillator.next
    
//            self.oscillators[previous].next = following
//            self.oscillators[following].prev = previous
    
//            old_head = following if oscillator_index == self.head else self.head
//            previous = self.oscillators[old_head].prev
//            self.oscillators[previous].next = oscillator_index
//            oscillator.prev = previous
//            oscillator.next = old_head
//            self.oscillators[old_head].prev = oscillator_index
//            self.head = oscillator_index
//            oscillator.free = True
            end else if (free_request) begin
                // Unlink the selected node
                freelist_next[freelist_previous] <= freelist_following;
                freelist_prev[freelist_following] <= freelist_previous;
                
                // Insert it before oldhead
                freelist_next[freelist_previous2] <= freelist_freethis;
                freelist_prev[freelist_freethis] <= freelist_previous2;
                freelist_next[freelist_freethis] <= freelist_oldhead;
                freelist_prev[freelist_oldhead] <= freelist_freethis;
                
                freelist_head <= freelist_freethis;
                freelist_free[freelist_freethis] <= 1'b1;
            end
        end
    end
    
    // MIDI control logic
    always_ff @(posedge Clk) begin
        if (reset) begin
            for (int i = 0; i < NUM_OSCILLATORS; i++) begin
                voice_note[i]     <= '0;
                voice_velocity[i] <= '0;
                voice_channel[i]  <= '0;
            end
    
        end else begin
            if (allocate_request) begin
                voice_note[freelist_head]     <= incoming_note;
                voice_velocity[freelist_head] <= incoming_velocity;
                voice_channel[freelist_head]  <= incoming_channel;
    
            end else if (update_existing_request) begin
                voice_velocity[match_index] <= incoming_velocity;
    
            end else if (free_request) begin
                voice_velocity[match_index] <= 8'h00;
            end
        end
    end
    
    assign wavetable = sw[12] ? wavetable_0 : wavetable_1;

    generate
        for (genvar i = 0; i < NUM_OSCILLATORS; i++) begin : gen_oscillators
    
            // Each oscillator reads the shared wavetable with its own counter/phase
    //            assign osc_sample[i] = wavetable[counter[i][31:21]];
            assign osc_sample[i] = wavetable[counter[i][31:21]];
            oscillator u_oscillator (
                .Clk             (Clk),
                .reset           (reset),
                .count_increment (midi_rom[voice_note[i]]),
                .sample          (osc_sample[i]),
                .midi_velocity   (voice_velocity[i]),
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
