module sigma_delta (
    input [15:0] in,
    input rst_n,  //active-low reset
    input clk,
    output out
);
  wire [15:0] sample = {~in[15], in[14:0]};
  reg  [16:0] acc;

  always @(posedge clk) begin
    if (!rst_n) begin  // synchronous active-low reset
      acc <= 17'b0;
    end else begin
      acc <= acc[15:0] + sample;
    end
  end
  assign out = acc[16];
endmodule
