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
      .tap  (tap)
  );
  shaper shaper (
      .tap(tap),
      .in_cfg(in_cfg),
      .shaped_out(shaped_signal)
  );
  assign out = {~shaped_signal[13], shaped_signal[12:0]};
endmodule
