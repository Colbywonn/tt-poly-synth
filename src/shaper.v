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

  //Sawtooth Wave
  assign saw_to_mux = tap;  //literally tap comes in as a sawtooth wave. pass it along.


  //Square Wave
  // cutoffs: 12.5%, 25%, 50%, 75%
  // if cutoff is larger, set output to HIGH, if smaller output to LOW.
  always @(*) begin
    case (pwm)
      2'b00:   pwm_threshold = 14'd2048;  //~12.5% Duty
      2'b01:   pwm_threshold = 14'd4096;  // 25% Duty
      2'b10:   pwm_threshold = 14'd8192;  // 50% Duty
      2'b11:   pwm_threshold = 14'd12288;  // 75% Duty
      default: pwm_threshold = 14'd8192;
    endcase
    sqr_to_mux = (tap < pwm_threshold) ? {14{1'b1}} : 14'b0;
  end

  //Triangle Wave
  //This function is a teeny bit asymetric, by 1-LSB on the peak. Saves like 40 cells, though.
  assign tri_to_mux = {(tap[13] ? ~tap[12:0] : tap[12:0]), 1'b0};



  //Handle output via MUX.

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
