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
    input logic req_toggle, // Toggled when audio interface requests a sample
    
    output logic signed [15:0] audio_hold,
    output logic ack_toggle // Toggled when there is a valid sample for the audio interface
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
    
    logic signed [15:0] audio_sig;
    
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
    
    logic match_found_q, note_on_event_q, note_off_event_q;
    logic [6:0] incoming_note_q;
    logic [7:0] incoming_velocity_q;
    logic [3:0] incoming_channel_q;
    logic [NUM_OSC_LOG2-1:0] match_index_q;
    
    // Pipelining match_found, match_index, note_on_event, note_off_event,
    //   incoming_note, incoming_velocity, incoming_channel
    always_ff @(posedge Clk) begin
        if (reset) begin
            match_found_q <= 1'b0;
            note_on_event_q <= 1'b0;
            note_off_event_q <= 1'b0;
            match_index_q <= 'b0;
        end else begin
            match_found_q <= match_found;
            note_on_event_q <= note_on_event;
            note_off_event_q <= note_off_event;
            match_index_q <= match_index;
        end
        
        // Nothing uses these until a MIDI message comes through
        incoming_note_q     <= incoming_note;
        incoming_velocity_q <= incoming_velocity;
        incoming_channel_q  <= incoming_channel;
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
            note_on_event_q &&
            !match_found_q;
        update_existing_request =
            note_on_event_q &&
            match_found_q;
        free_request =
            note_off_event_q &&
            match_found_q;
        freelist_freethis = match_index_q;
        
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
            if (allocate_request) begin
                freelist_free[freelist_head] <= 1'b0;                       // Allocate oscillator at head
                freelist_head <= freelist_next[freelist_head];              // Move head to next free oscillator
            end else if (free_request) begin
                // Unlink the selected node
                freelist_next[freelist_previous] <= freelist_following;     // Update previous oscillator's next
                freelist_prev[freelist_following] <= freelist_previous;     // Update next oscillators prev
                
                // Insert it before oldhead
                freelist_next[freelist_previous2] <= freelist_freethis;     // Update previous2's next to newly freed oscillator
                freelist_prev[freelist_freethis] <= freelist_previous2;     // Update newly freed oscillator's prev to previous2
                freelist_next[freelist_freethis] <= freelist_oldhead;       // Update newly freed oscillator's next to oldhead
                freelist_prev[freelist_oldhead] <= freelist_freethis;       // Update oldhead's prev to newly freed oscillator
                
                freelist_head <= freelist_freethis;                         // Head moves to newly freed oscillator
                freelist_free[freelist_freethis] <= 1'b1;                   // Free oscillator
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
                voice_note[freelist_head]     <= incoming_note_q;
                voice_velocity[freelist_head] <= incoming_velocity_q;
                voice_channel[freelist_head]  <= incoming_channel_q;
    
            end else if (update_existing_request) begin
                voice_velocity[match_index_q] <= incoming_velocity_q;
    
            end else if (free_request) begin
                voice_velocity[match_index_q] <= 8'h00;
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
    
    logic [15:0] audio_mix_q;          // registered mixed sample
    (* ASYNC_REG = "TRUE" *) logic [2:0] req_sync; // Prevent unwanted optimizations for the CDC (Clock Domain Crossing)
    
    always_ff @(posedge Clk) begin
        if (reset) begin
            ack_toggle <= 1'b0;
            req_sync <= 3'b0;
        end else begin
            audio_mix_q <= audio_sig;              // optionally pipeline further
            req_sync    <= {req_sync[1:0], req_toggle};   // req_toggle from audio domain. May be metastable, so req_sync[1] has the settled value and req_sync[2] has the previous settled value.
            if (req_sync[2] ^ req_sync[1]) begin
                audio_hold <= audio_mix_q;
                ack_toggle <= ~ack_toggle;
            end
        end
    end

endmodule
