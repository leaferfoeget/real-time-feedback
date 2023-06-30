`default_nettype none

module Interleave (clk, din, dout);
	// 2:1 serializer

input wire 			clk;
input wire [1:0]	din;
output wire			dout;

reg	[1:0]	hold;
reg			shift;

always @(posedge clk) begin
	hold <= din;    
end

always @(negedge clk) begin
	shift <= hold[1];    
end

assign dout = clk ? shift : hold[0];

endmodule
`default_nettype wire

