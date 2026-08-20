/*
Copyright (c) 2026 Colby Miller
SPDX-License-Identifier: Apache-2.0

TinyTapeout SKY26c frozen version, 2026-08-19

Sigma-delta output. Takes the summed output of the mixer and reduces it to a bitstream.
The input is accumulated. When it overflows, the carry-out is handed over as the output.
The density of 1s defines the amplitude of the signal. So, the pin toggles when idle. zero change in amplitude = zero sound.
*/

module sigma_delta (
    input [15:0] in,
    input rst_n,  // Active-low reset
    input clk,
    output out
);
  wire [15:0] sample = {
    ~in[15], in[14:0]
  };  // The MSB is inverted, because in two's complement the most negative values have the largest raw bit patterns. By flipping the MSB, sample becomes monotonic.
  reg [16:0] acc;  // 17 bits because it's 16 bits plus the carry.

  always @(posedge clk) begin
    if (!rst_n) begin  // Synchronous active-low reset.
      acc <= 17'b0;
    end else begin
      acc <= acc[15:0] + sample; // The carry doesn't enter, or else it wouldn't signify "acc overflowed this cycle".
    end
  end
  assign out = acc[16];  // Reads on a register, which means the RC filter gets a full cycle of each value. no glitches.
endmodule
