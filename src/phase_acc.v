module phase_acc (
    input clk,
    input rst_n,
    input [31:0] inc,
    output [13:0] tap
);
  reg [31:0] phase;


  always @(posedge clk) begin
    if (!rst_n) begin  // synchronous active-low reset
      phase <= 32'b0;
    end else begin
      phase <= phase + inc;  //ACCUMULATE
    end
  end
  assign tap = phase[31:18];
endmodule
