module tt_um_colbywonn_poly_synth (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path
    input  wire       ena,      // goes high when design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // active-low reset
);

  wire audio;

  synth_core core (
      .mosi (ui_in[0]),
      .sclk (ui_in[1]),
      .cs_n (ui_in[2]),
      .clk  (clk),
      .rst_n(rst_n),
      .out  (audio)
  );

  assign uo_out  = {7'b0, audio};  // audio on uo_out[0], rest grounded
  assign uio_out = 8'b0;  // unused, driven low
  assign uio_oe  = 8'b0;  // all bidirectionals as inputs

  // silence unused-signal warnings
  wire _unused = &{ena, ui_in[7:3], uio_in, 1'b0};

endmodule
