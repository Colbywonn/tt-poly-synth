/*
Date: 08-19-2026
Author: Colby Miller
TinyTapeout Sky26c Frozen Version

This module defines the behavior of the DDS. It takes tap from the phase accumulator module and applies a shape to the wave based off of the config settings.
The settings are as follows:

| Wave Select |       Output       |
------------------------------------
|      00     | off (voice silent) |
|      01     | sawtooth           |
|      10     | square (PWM)       |
|      11     | triangle           |

| PWM Select | Duty Value |
---------------------------
|     00     | 12.5% duty |
|     01     | 25% duty   |
|     10     | 50% duty   |
|     11     | 75% duty   |

The data is input as Mode as the 2 MSB, and PWM as the 2 LSB.
For example,
4'b1100 would be triangle mode, with the duty cycle set to 12.5%. However, the duty cycle setting has no bearing on the output for the triangle wave.
PWM's value only matters when the output is a square wave.

*/

module shaper (
    input [13:0] tap,
    input [3:0] in_cfg,
    output reg [13:0] shaped_out
);
  wire [13:0] saw_to_mux;
  reg  [13:0] sqr_to_mux;
  wire [13:0] tri_to_mux;
  wire [ 1:0] pwm;
  wire [ 1:0] mode;
  assign mode = in_cfg[3:2];
  assign pwm  = in_cfg[1:0];
  reg [13:0] pwm_threshold;

  // Sawtooth Wave
  assign saw_to_mux = tap;  // Tap comes in as a sawtooth wave. pass it along.


  /* Square Wave
  cutoffs: 12.5%, 25%, 50%, 75%
  The output is HIGH while tap is below the threshold, so a larger threshold means a longer high time.
  100% is 16384, or 14 bits. each value is calculated off of that. for example, 12.5% of 16384 is 2048. */
  always @(*) begin
    case (pwm)
      2'b00:   pwm_threshold = 14'd2048;  // 12.5% Duty
      2'b01:   pwm_threshold = 14'd4096;  // 25% Duty
      2'b10:   pwm_threshold = 14'd8192;  // 50% Duty
      2'b11:   pwm_threshold = 14'd12288;  // 75% Duty
      default: pwm_threshold = 14'd8192;  // IE: 50% duty.
    endcase
    sqr_to_mux = (tap < pwm_threshold) ? {14{1'b1}} : 14'b0;
  end


  /* Triangle Wave
This function is a teeny bit asymmetric, by 1-LSB on the peak. Saves like 40 cells, though. */
  assign tri_to_mux = {
    (tap[13] ? ~tap[12:0] : tap[12:0]), 1'b0
  };  // IE: follow tap on the first half, invert it on the second half.


  // Handle output via MUX. The output emits offset binary, which is converted in dds.v to be signed.
  always @(*) begin
    case (mode)
      2'b00:   shaped_out = 14'b0;  // Voice mode = off
      2'b01:   shaped_out = saw_to_mux;  // Voice mode = sawtooth
      2'b10:   shaped_out = sqr_to_mux;  // Voice mode = square
      2'b11:   shaped_out = tri_to_mux;  // Voice mode = triangle
      default: shaped_out = 14'b0;
    endcase
  end
endmodule
