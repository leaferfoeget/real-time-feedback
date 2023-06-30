`default_nettype none

module Serializer8 ( clk1x, clk2x, clk4x, din, dout);
	// 8:1 serializer

input wire			clk1x; // slow clock
input wire			clk2x; // 2x clock
input wire			clk4x; // 4x clock
//input wire			clk4x180; // 4x clock phase shifted
input wire [7:0]	din;
output wire			dout;

wire [7:0]	d8;
wire [3:0]	d4;
wire [1:0]	d2;

reg	[1:0]	pipe_1;
reg	[1:0]	pipe_2;
reg			shift;

wire		ddr_out;

// input data alignment
assign d8 = {din[7], din[3], din[5], din[1], din[6], din[2], din[4], din[0]};

// stage 0
Interleave s0_0 ( .clk(clk1x), .din(d8[1:0]), .dout(d4[0]) );
Interleave s0_1 ( .clk(clk1x), .din(d8[3:2]), .dout(d4[1]) );
Interleave s0_2 ( .clk(clk1x), .din(d8[5:4]), .dout(d4[2]) );
Interleave s0_3 ( .clk(clk1x), .din(d8[7:6]), .dout(d4[3]) );

// stage 1
Interleave s1_0 ( .clk(clk2x), .din(d4[1:0]), .dout(d2[0]) );
Interleave s1_1 ( .clk(clk2x), .din(d4[3:2]), .dout(d2[1]) );

// stage 2 buffer
always @(posedge clk4x) begin
	pipe_1 <= d2;
	pipe_2 <= pipe_1;
end

// stage 2 phase shift
always @(negedge clk4x) begin
	shift <= pipe_2[1];
end

ODDR2 #(.DDR_ALIGNMENT("NONE")) ddr (.C0(clk4x), .C1(~clk4x), .D0(pipe_2[0]), .D1(shift), .CE(1'b1), .R(1'b0), .S(1'b0), .Q(ddr_out));

OBUF #(
	.DRIVE(12),
	.IOSTANDARD("DEFAULT"),
	.SLEW("FAST") )
OBUF_inst (
	.O(dout),
	.I(ddr_out) );

endmodule

module Serializer4 ( clk1x, clk2x, din, dout);
	// 4:1 serializer

input wire			clk1x; // slow clock
input wire			clk2x; // 2x clock
input wire [3:0]	din;
output wire			dout;

wire [3:0]	d4;
wire [1:0]	d2;

reg	[1:0]	pipe_1;
reg	[1:0]	pipe_2;
reg			shift;

wire		ddr_out;

// input data alignment
assign d4 = {din[3], din[1], din[2], din[0]};

// stage 1
Interleave s1_0 ( .clk(clk1x), .din(d4[1:0]), .dout(d2[0]) );
Interleave s1_1 ( .clk(clk1x), .din(d4[3:2]), .dout(d2[1]) );

// stage 2 buffer
always @(posedge clk2x) begin
	pipe_1 <= d2;
	pipe_2 <= pipe_1;
end

// stage 2 phase shift
always @(negedge clk2x) begin
	shift <= pipe_2[1];
end

// ODDR2#(.DDR_ALIGNMENT("NONE")) ddr (.C0(clk2x), .C1(~clk2x), .D0(pipe_2[0]), .D1(shift), .CE(1'b1), .R(1'b0), .S(1'b0), .Q(ddr_out));
ODDR#(
	.DDR_CLK_EDGE("OPPOSITE_EDGE"),
	.INIT(1'b0),
	.SRTYPE("SYNC")
)ODDR_inst(
	.Q(ddr_out),
	.C(clk2x),
	.CE(1'b1),
	.D1(pipe_2[0]),
	.D2(shift),
	.R(1'b0),
	.S(1'b0)
);
OBUF #(
	.DRIVE(12),
	.IOSTANDARD("DEFAULT"),
	.SLEW("FAST") )
OBUF_inst (
	.O(dout),
	.I(ddr_out)
);

endmodule

