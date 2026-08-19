/*
Date: 08-19-2026
Author: Colby Miller
TinyTapeout Sky26c Frozen Version

This module takes an input in the form of a tuning word, and then sums it in a phase accumulator.
*/

module phase_acc (
    input clk,
    input rst_n, // Synchronous active-low reset
    input [31:0] inc, 
    output [13:0] tap // Essentially, this outputs as a sawtooth wave.
);
  reg [31:0] phase; // 32-bit depth gives me sub-cent accuracy.


  always @(posedge clk) begin
    if (!rst_n) begin
      phase <= 32'b0; 
    end else begin
      phase <= phase + inc;
    end
  end
  assign tap = phase[31:18]; // Top 14 bits because it's the coarse phase position, and the other 18 bits are fine precision that always accumulate.
endmodule

