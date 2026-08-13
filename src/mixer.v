module mixer (
    input  signed [13:0] in_0,
    in_1,
    in_2,
    output signed [15:0] out
);
  assign out = in_0 + in_1 + in_2;

endmodule
