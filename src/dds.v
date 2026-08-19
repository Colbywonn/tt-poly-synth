/*
Copyright (c) 2026 Colby Miller
SPDX-License-Identifier: Apache-2.0

TinyTapeout SKY26c frozen version, 2026-08-19

This module ties together the entirety of the single-voice DDS core, and its two main sections.
It has a phase accumulator and a shaper. The output of DDS is signed.
*/

module dds (
    input [31:0] inc,
    input rst_n,  //active-low reset
    input clk,
    input [3:0] in_cfg,
    output signed [13:0] out  //signed output for the mixer.
);
  wire [13:0] tap;
  wire [13:0] shaped_signal;

  phase_acc accumulator (
      .clk  (clk),
      .rst_n(rst_n),
      .inc  (inc),
      .tap  (tap) // The top 14 bits of the accumulation.
  );
  shaper shaper (
      .tap(tap),
      .in_cfg(in_cfg),
      .shaped_out(shaped_signal)
  );
  assign out = {~shaped_signal[13], shaped_signal[12:0]}; // The shaper outputs offset binary, but the mixer needs two's complement. flipping the MSB here converts between the two of them.
endmodule

