module oscillator(
    input  logic Clk,
    input  logic reset,
    input  logic [23:0] count_increment,
    input  logic signed [15:0] sample,
    input  logic [7:0] midi_velocity,

    output logic signed [15:0] audio_sig,
    output logic [31:0] counter
);
    logic signed [7:0]  velocity_gain;
    logic signed [23:0] scaled_sample;
    logic signed [23:0] scaled_sample_q;

    // Update phase
    always_ff @(posedge Clk) begin
        if (reset)
            counter <= 32'b0;
        else
            counter <= counter + count_increment;
    end

    // Scale sample by velocity
    assign velocity_gain = $signed({1'b0, midi_velocity[6:0]});
    assign scaled_sample = sample * velocity_gain;

    // Pipelining DSP operation
    always_ff @(posedge Clk) begin
        scaled_sample_q <= scaled_sample;
    end

    assign audio_sig = scaled_sample_q >>> 7;  // arithmetic shift is trivial
endmodule