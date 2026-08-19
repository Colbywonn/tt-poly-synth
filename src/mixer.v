/*
Date: 08-19-2026
Author: Colby Miller
TinyTapeout Sky26c Frozen Version

This module is very simple. It adds together the outputs of the three voices, and outputs it.
*/

module mixer (
    input  signed [13:0] in_0,
    in_1,
    in_2,
    output signed [15:0] out //16-bits ensures no overflow is possible, three signed inputs need 2 bits of overhead total.
);
  assign out = in_0 + in_1 + in_2;

endmodule
