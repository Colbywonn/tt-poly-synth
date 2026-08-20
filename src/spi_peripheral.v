/*
Copyright (c) 2026 Colby Miller
SPDX-License-Identifier: Apache-2.0

TinyTapeout SKY26c frozen version, 2026-08-19

This module defines the behavior and registers for the rest of the chip. It is designed to take an input from an SPI Master, most likely a microcontroller.
It expects a 35-bit frame, all malformed frames will be rejected. This module expects SPI Mode 0, and MSB-first. Commits happen on CS-rising.
The format is as follows:
34-32: Addresses, 31-0: Data.

The addresses work as follows:
| Address | Register | Contents            |
|    0    |   inc0   | voice 0 tuning word | (32 bits)
|    1    |   inc1   | voice 1 tuning word |
|    2    |   inc2   | voice 2 tuning word |

|    3    |   cfg0   | voice 0 config      | (4 bits, [3:2] wave select, [1:0] PWM width)
|    4    |   cfg1   | voice 1 config      |
|    5    |   cfg2   | voice 2 config      |
|  6, 7   |    XX    | unused              |

This module also handles a clock domain crossover between the SCLK (defined by the SPI master) and the internal CLK.
The solution was to pass MOSI through two flip-flops, to give it a cycle to recover from metastability.

CS_N and SCLK are handled by 3. Two for metastability, one for holding the previous edge for comparison.

NOTE: The maximum frequency of SCLK can be 1/6th that of CLK. so, if CLK is clocked at 12MHz, SCLK can only be clocked at 2MHz. For updating notes, that should be no problem at all. 
2MHz is blisteringly fast compared to how fast songs play notes.
NOTE: CS must stay low for a few cycles after the last SCLK edge so that bit_cnt can propagate.

*/
module spi_peripheral (
    input clk,
    input rst_n,
    input mosi,
    input sclk,
    input cs_n,
    output reg [31:0] inc0,
    output reg [31:0] inc1,
    output reg [31:0] inc2,
    output reg [3:0] cfg0,
    output reg [3:0] cfg1,
    output reg [3:0] cfg2
);
  reg [ 5:0] bit_cnt;
  reg [34:0] shift_reg;
  reg sclk_on_clk, cs_n_on_clk, mosi_on_clk;
  reg prev_sclk, prev_cs_n;
  reg ff_sclk, ff_cs_n, ff_mosi;


  always @(posedge clk) begin
    if (!rst_n) begin
      inc0 <= 32'b0;
      inc1 <= 32'b0;
      inc2 <= 32'b0;
      cfg0 <= 4'b0;
      cfg1 <= 4'b0;
      cfg2 <= 4'b0;
      bit_cnt <= 6'b0;
      shift_reg <= 35'b0;
      sclk_on_clk <= 1'b0;
      cs_n_on_clk <= 1'b1; // Idles high because active-low
      mosi_on_clk <= 1'b0;
      prev_sclk <= 1'b0;
      prev_cs_n <= 1'b1; // Idles high because active-low
      ff_sclk <= 1'b0;
      ff_cs_n <= 1'b1; // Idles high because active-low
      ff_mosi <= 1'b0;
    end else begin
      // Flip-flops handle domain crossing and store last value for comparison.
      sclk_on_clk <= sclk;
      ff_sclk <= sclk_on_clk;
      prev_sclk <= ff_sclk;

      cs_n_on_clk <= cs_n;
      ff_cs_n <= cs_n_on_clk;
      prev_cs_n <= ff_cs_n;

      mosi_on_clk <= mosi;
      ff_mosi <= mosi_on_clk;

        
      if (prev_cs_n && !ff_cs_n) bit_cnt <= 6'b0; //Starts the count fresh when CS signals an incoming frame.
      else if (!prev_sclk && !ff_cs_n && ff_sclk) begin
        shift_reg <= {shift_reg[33:0], ff_mosi}; //Using a shift reg because it's cheaper in silicon than a system with a decoder.
        bit_cnt   <= (bit_cnt > 35) ? 6'd36 : bit_cnt + 1'b1; // It stops rather than wrapping because a malformed frame could cause unwanted inputs.
      end
      if ((!prev_cs_n && ff_cs_n) && (bit_cnt == 35)) begin // If bit_cnt != 35, it means the frame was malformed and it should just wait for another.
        case (shift_reg[34:32])
          3'd0: inc0 <= shift_reg[31:0];
          3'd1: inc1 <= shift_reg[31:0];
          3'd2: inc2 <= shift_reg[31:0];
          3'd3: cfg0 <= shift_reg[3:0];
          3'd4: cfg1 <= shift_reg[3:0];
          3'd5: cfg2 <= shift_reg[3:0];
          default: ;
        endcase
      end
    end
  end
endmodule
