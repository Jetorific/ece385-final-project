`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/19/2026 07:54:18 PM
// Design Name: 
// Module Name: paper_synth_top_tb
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


module paper_synth_top_tb;

    localparam int NUM_VOICES = 4;
    localparam time CLK_PERIOD = 10ns;  // 100 MHz

    logic Clk = 1'b0;
    logic reset_rtl_0 = 1'b1;
    logic [15:0] sw_i = '0;

    logic [15:0] led_o;
    logic S_BCK;
    logic S_DIN;
    logic S_LRCK;

    // These replace the MicroBlaze GPIO outputs during simulation.
    logic [31:0] simulated_midi_data = '0;
    logic simulated_midi_toggle = 1'b0;

    int error_count = 0;
    int valid_event_count = 0;

    always #(CLK_PERIOD / 2) Clk = ~Clk;

    paper_synth_top dut (
        .Clk                    (Clk),
        .reset_rtl_0            (reset_rtl_0),
        .sw_i                   (sw_i),

        .led_o                  (led_o),

        .gpio_usb_int_tri_i     (1'b1),
        .gpio_usb_rst_tri_o     (),
        .usb_spi_miso           (1'b0),
        .usb_spi_mosi           (),
        .usb_spi_sclk           (),
        .usb_spi_ss             (),

        .uart_rtl_0_rxd         (1'b1),
        .uart_rtl_0_txd         (),

        .hdmi_tmds_clk_n        (),
        .hdmi_tmds_clk_p        (),
        .hdmi_tmds_data_n       (),
        .hdmi_tmds_data_p       (),

        .hex_segA               (),
        .hex_gridA              (),
        .hex_segB               (),
        .hex_gridB              (),

        .S_BCK                  (S_BCK),
        .S_DIN                  (S_DIN),
        .S_LRCK                 (S_LRCK)
    );

    // Observe the same rising edge at which the bank processes MIDI.
    always @(posedge Clk) begin
        if (reset_rtl_0) begin
            valid_event_count = 0;
        end else if (dut.midi_valid) begin
            valid_event_count = valid_event_count + 1;

            $display(
                "[%0t] MIDI accepted: data=%08h "
                //""
                ,
                $time,
                dut.midi_data
            );
        end
    end

    task automatic check(
        input logic condition,
        input string description
    );
        if (condition !== 1'b1) begin
            error_count++;
            $error("[%0t] FAIL: %s", $time, description);
        end else begin
            $display("[%0t] PASS: %s", $time, description);
        end
    endtask

    function automatic int active_voice_count();
        int count;

        count = 0;
        for (int i = 0; i < NUM_VOICES; i++) begin
            if (dut.osc_bank.freelist_free[i] === 1'b0)
                count++;
        end

        return count;
    endfunction

    task automatic expect_note(
        input logic [6:0] note,
        input logic [3:0] channel,
        input bit expected_present
    );
        bit found;

        found = 1'b0;

        for (int i = 0; i < NUM_VOICES; i++) begin
            if ((dut.osc_bank.freelist_free[i] === 1'b0) &&
                (dut.osc_bank.voice_note[i] === note) &&
                (dut.osc_bank.voice_channel[i] === channel) &&
                (dut.osc_bank.voice_velocity[i] != 0)) begin
                found = 1'b1;
            end
        end

        check(
            found == expected_present,
            $sformatf(
                "Note %0d channel %0d present=%0b",
                note, channel, expected_present
            )
        );
    endtask

    task automatic check_list();
        int next_index;
        int previous_index;
        int index;
        bit [NUM_VOICES-1:0] visited;
        bit seen_allocated;

        // Check bidirectional links.
        for (int i = 0; i < NUM_VOICES; i++) begin
            next_index = dut.osc_bank.freelist_next[i];
            previous_index = dut.osc_bank.freelist_prev[i];

            check(
                (next_index >= 0) && (next_index < NUM_VOICES),
                $sformatf("next[%0d] in range", i)
            );

            check(
                (previous_index >= 0) &&
                (previous_index < NUM_VOICES),
                $sformatf("prev[%0d] in range", i)
            );

            if ((next_index >= 0) &&
                (next_index < NUM_VOICES)) begin
                check(
                    dut.osc_bank.freelist_prev[next_index] == i,
                    $sformatf("prev[next[%0d]] == %0d", i, i)
                );
            end

            if ((previous_index >= 0) &&
                (previous_index < NUM_VOICES)) begin
                check(
                    dut.osc_bank.freelist_next[previous_index] == i,
                    $sformatf("next[prev[%0d]] == %0d", i, i)
                );
            end
        end

        // Walk exactly once around the circular list.
        visited = '0;
        seen_allocated = 1'b0;
        index = dut.osc_bank.freelist_head;

        for (int step = 0; step < NUM_VOICES; step++) begin
            if ($isunknown(index) ||
                (index < 0) ||
                (index >= NUM_VOICES)) begin
                check(1'b0, "List traversal encountered invalid index");
                return;
            end

            check(
                !visited[index],
                $sformatf("List visits voice %0d only once", index)
            );

            visited[index] = 1'b1;

            // Free nodes must precede allocated nodes from the head.
            if (dut.osc_bank.freelist_free[index] === 1'b0) begin
                seen_allocated = 1'b1;
            end else if (dut.osc_bank.freelist_free[index] === 1'b1) begin
                check(
                    !seen_allocated,
                    "No free node appears after an allocated node"
                );
            end else begin
                check(1'b0, "Unknown free flag");
            end

            index = dut.osc_bank.freelist_next[index];
        end

        check(
            index == dut.osc_bank.freelist_head,
            "List returns to head after NUM_VOICES steps"
        );

        check(&visited, "List contains every voice");
    endtask

    // Models software writing data first, then the notification GPIO.
    task automatic send_midi(
        input logic [7:0] status,
        input logic [6:0] note,
        input logic [6:0] velocity
    );
        int count_before;

        count_before = valid_event_count;

        @(negedge Clk);
        simulated_midi_data = {
            1'b0, velocity,
            1'b0, note,
            status,
            8'h09
        };

        // Allow the data register to settle before notifying.
        repeat (3) @(negedge Clk);

        simulated_midi_toggle = ~simulated_midi_toggle;

        // Allow the real top-level detector and bank to process it.
        repeat (3) @(negedge Clk);

        check(
            valid_event_count == count_before + 1,
            "Exactly one midi_valid event per notification"
        );

        check_list();
    endtask

    task automatic dump_voices();
        $display("Head = %0d", dut.osc_bank.freelist_head);

        for (int i = 0; i < NUM_VOICES; i++) begin
            $display(
                "voice=%0d free=%b note=%0d velocity=%0d "
                //""
                ,
                i,
                dut.osc_bank.freelist_free[i],
                dut.osc_bank.voice_note[i],
                dut.osc_bank.voice_velocity[i]
            );
        end
    endtask

    initial begin
        // Force only the GPIO outputs; leave the actual detector intact.
        force dut.midi_data = simulated_midi_data;
        force dut.midi_toggle = simulated_midi_toggle;

        // sw[12] = 0 selects sine in the supplied oscillator bank.
        sw_i = '0;

        repeat (10) @(negedge Clk);
        reset_rtl_0 = 1'b0;

        repeat (10) @(negedge Clk);

        check(active_voice_count() == 0, "All voices initially free");
        check_list();

        // First event: this must allocate voice 0 immediately.
        send_midi(8'h90, 7'd60, 7'd100);  // C4

        check(
            dut.osc_bank.freelist_free[0] === 1'b0,
            "First MIDI note allocates voice 0"
        );

        check(
            dut.osc_bank.voice_note[0] === 7'd60,
            "Voice 0 stores the first note"
        );

        check(
            dut.osc_bank.voice_velocity[0] === 8'd100,
            "Voice 0 stores the first velocity"
        );

        check(
            dut.osc_bank.freelist_head == 1,
            "Head advances to voice 1"
        );

        expect_note(7'd60, 4'd0, 1'b1);
        dump_voices();

        // Reproduce C, D, E, F with no releases.
        send_midi(8'h90, 7'd62, 7'd100);  // D4
        send_midi(8'h90, 7'd64, 7'd100);  // E4
        send_midi(8'h90, 7'd65, 7'd100);  // F4

        check(active_voice_count() == 4, "Four voices allocated");

        expect_note(7'd60, 4'd0, 1'b1);
        expect_note(7'd62, 4'd0, 1'b1);
        expect_note(7'd64, 4'd0, 1'b1);
        expect_note(7'd65, 4'd0, 1'b1);

        dump_voices();

        // Fifth distinct note steals voice 0, replacing C4.
        send_midi(8'h90, 7'd67, 7'd100);  // G4

        check(active_voice_count() == 4, "Stealing keeps four active voices");
        expect_note(7'd60, 4'd0, 1'b0);
        expect_note(7'd67, 4'd0, 1'b1);

        // Old C4 note-off must not stop its replacement G4.
        send_midi(8'h80, 7'd60, 7'd0);
        expect_note(7'd67, 4'd0, 1'b1);

        // Free D4, then reuse that free voice for A4.
        send_midi(8'h80, 7'd62, 7'd0);

        check(active_voice_count() == 3, "Note-off frees one voice");
        expect_note(7'd62, 4'd0, 1'b0);

        send_midi(8'h90, 7'd69, 7'd100);

        check(active_voice_count() == 4, "New note reuses free voice");
        expect_note(7'd69, 4'd0, 1'b1);
        expect_note(7'd64, 4'd0, 1'b1);
        expect_note(7'd65, 4'd0, 1'b1);
        expect_note(7'd67, 4'd0, 1'b1);

        // Repeated note-on changes velocity without allocating.
        send_midi(8'h90, 7'd69, 7'd40);
        check(active_voice_count() == 4, "Repeated note does not allocate");

        check(
            dut.osc_bank.voice_velocity[1] === 8'd40,
            "Repeated A4 updates its velocity"
        );

        // Note-on velocity zero is a note-off.
        send_midi(8'h90, 7'd69, 7'd0);
        expect_note(7'd69, 4'd0, 1'b0);
        check(active_voice_count() == 3, "Velocity-zero note-on frees voice");

        // Check that the generated audio is known and nonzero at
        // least once while the remaining notes are held.
        begin : audio_check
            bit saw_nonzero;
            bit saw_unknown;

            saw_nonzero = 1'b0;
            saw_unknown = 1'b0;

            repeat (100_000) begin
                @(negedge Clk);

                if ($isunknown(dut.audio_sig))
                    saw_unknown = 1'b1;
                else if (dut.audio_sig != 16'd0)
                    saw_nonzero = 1'b1;
            end

            check(!saw_unknown, "Mixed audio contains no X/Z samples");
            check(saw_nonzero, "Mixed audio becomes nonzero");
        end

        dump_voices();

        if (error_count == 0) begin
            $display("\nALL TESTS PASSED");
            $finish;
        end else begin
            $fatal(1, "\n%0d CHECKS FAILED", error_count);
        end
    end

    initial begin
        #5ms;
        $fatal(1, "Simulation timeout");
    end

endmodule