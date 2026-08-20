/*
Copyright (c) 2026 Colby Miller
SPDX-License-Identifier: Apache-2.0

TinyTapeout SKY26c frozen version, 2026-08-19

Top module for the Synth. Defines the entire composition of the chip, including inputs, outputs, and internal nets.

  mosi ──┐
  sclk ──┤   ┌──────────────────┐
  cs_n ──┴──>│  spi_peripheral  │
             └───┬──────────┬───┘
       inc0/1/2  │          │  cfg0/1/2
        (32b)    │          │   (4b)
                 v          v
        ┌────────────────────────────┐
        │  dds0    dds1    dds2      │   phase_acc -> shaper
        └────┬───────┬───────┬───────┘
             │       │       │   signed [13:0]
             v       v       v
           ┌────────────────────┐
           │       mixer        │
           └─────────┬──────────┘
                     │ signed [15:0]
                     v
           ┌────────────────────┐
           │    sigma_delta     │
           └─────────┬──────────┘
                     │ 1-bit stream
                     v
                    out   -> external RC filter -> audio

*/

module synth_core (
    //SPI inputs
    input mosi,
    input sclk,
    input cs_n,  // Active-low

    // Other inputs
    input  clk,    // 12MHz
    input  rst_n,  // Active-low reset
    output out
);
  // wires
  wire [31:0] spi_to_dds0, spi_to_dds1, spi_to_dds2;
  wire [13:0] dds_to_mixer0, dds_to_mixer1, dds_to_mixer2;  // These are signed
  wire [15:0] mixer_to_sd;  // This is signed
  wire [3:0] cfg0, cfg1, cfg2;  // Wave type select and PWM control
  // SPI Module
  spi_peripheral spi (
      .clk  (clk),
      .rst_n(rst_n),
      .mosi (mosi),
      .sclk (sclk),
      .cs_n (cs_n),
      .inc0 (spi_to_dds0),
      .inc1 (spi_to_dds1),
      .inc2 (spi_to_dds2),
      .cfg0 (cfg0),
      .cfg1 (cfg1),
      .cfg2 (cfg2)
  );
  // DDS Modules
  dds dds0 (
      .inc(spi_to_dds0),
      .rst_n(rst_n),
      .clk(clk),
      .in_cfg(cfg0),
      .out(dds_to_mixer0)
  );
  dds dds1 (
      .inc(spi_to_dds1),
      .rst_n(rst_n),
      .clk(clk),
      .in_cfg(cfg1),
      .out(dds_to_mixer1)
  );
  dds dds2 (
      .inc(spi_to_dds2),
      .rst_n(rst_n),
      .clk(clk),
      .in_cfg(cfg2),
      .out(dds_to_mixer2)
  );
  // Mixer Module
  mixer mix (
      .in_0(dds_to_mixer0),
      .in_1(dds_to_mixer1),
      .in_2(dds_to_mixer2),
      .out (mixer_to_sd)
  );
  // 1st-order Sigma-Delta Module
  sigma_delta sd (
      .in(mixer_to_sd),
      .rst_n(rst_n),
      .clk(clk),
      .out(out)
  );

endmodule
