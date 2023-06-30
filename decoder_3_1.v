`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/08/12 08:41:24
// Design Name: 
// Module Name: decoder
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module decoder_3(
	input wire [39:0]data_in1,
	input wire [39:0]data_in2,
	input wire clk,
	output reg[5:0]out1,
	output reg[5:0]out2
);
 
reg [62:0] reg1;
reg [30:0] reg2;
reg [14:0] reg3;
reg [6:0] reg4;
reg [2:0] reg5;
reg  reg6;

wire sel1;
wire sel2;
wire sel3;
wire sel4;
wire sel5;

reg [62:0] reg7;
reg [30:0] reg8;
reg [14:0] reg9;
reg [6:0] reg10;
reg [2:0] reg11;
reg  reg12;

wire sel6;
wire sel7;
wire sel8;
wire sel9;
wire sel10;

reg [62:0] reg13;
reg [30:0] reg14;
reg [14:0] reg15;
reg [6:0] reg16;
reg [2:0] reg17;
reg  reg18;

wire sel11;
wire sel12;
wire sel13;
wire sel14;
wire sel15;

reg      pos1_buf1;
reg [1:0]pos1_buf2;
reg [2:0]pos1_buf3;
reg [3:0]pos1_buf4;
reg [4:0]pos1;

reg      pos2_buf1;
reg [1:0]pos2_buf2;
reg [2:0]pos2_buf3;
reg [3:0]pos2_buf4;
reg [4:0]pos2;

reg      pos3_buf1;
reg [1:0]pos3_buf2;
reg [2:0]pos3_buf3;
reg [3:0]pos3_buf4;
reg [4:0]pos3;

assign sel1=reg1[31];
assign sel2=reg2[15];
assign sel3=reg3[7];
assign sel4=reg4[3];
assign sel5=reg5[1];


assign sel6=reg7[31];
assign sel7=reg8[15];
assign sel8=reg9[7];
assign sel9=reg10[3];
assign sel10=reg11[1];

assign sel11=reg13[31];
assign sel12=reg14[15];
assign sel13=reg15[7];
assign sel14=reg16[3];
assign sel15=reg17[1];


always @(posedge clk)begin
	reg1<={23'b0,data_in1};
end
always @(posedge clk)begin
	{reg2,pos1_buf1}<=(sel1==1'b1)?{reg1[62:32],1'b1}:{reg1[30:0],1'b0};
end
always @(posedge clk)begin
	{reg3,pos1_buf2}<=(sel2==1'b1)?{reg2[30:16],pos1_buf1,1'b1}:{reg2[14:0],pos1_buf1,1'b0};
end
always @(posedge clk)begin
	{reg4,pos1_buf3}<=(sel3==1'b1)?{reg3[14:8],pos1_buf2,1'b1}:{reg3[6:0],pos1_buf2,1'b0};
end
always @(posedge clk)begin
	{reg5,pos1_buf4}<=(sel4==1'b1)?{reg4[6:4],pos1_buf3,1'b1}:{reg4[2:0],pos1_buf3,1'b0};
end
always @(posedge clk)begin
	{reg6,pos1}<=(sel5==1'b1)?{reg5[2],pos1_buf4,1'b1}:{reg5[0],pos1_buf4,1'b0};		
end
always @(posedge clk)begin
(* KEEP = "TRUE" *)out1<={pos1[4:0],reg6};
end            


always @(posedge clk)begin
	reg7<={23'b0,data_in2};
end
always @(posedge clk)begin
	{reg8,pos2_buf1}<=(sel6==1'b1)?{reg7[62:32],1'b1}:{reg7[30:0],1'b0};
end
always @(posedge clk)begin
	{reg9,pos2_buf2}<=(sel7==1'b1)?{reg8[30:16],pos2_buf1,1'b1}:{reg8[14:0],pos2_buf1,1'b0};
end
always @(posedge clk)begin
	{reg10,pos2_buf3}<=(sel8==1'b1)?{reg9[14:8],pos2_buf2,1'b1}:{reg9[6:0],pos2_buf2,1'b0};
end
always @(posedge clk)begin
	{reg11,pos2_buf4}<=(sel9==1'b1)?{reg10[6:4],pos2_buf3,1'b1}:{reg10[2:0],pos2_buf3,1'b0};
end
always @(posedge clk)begin
	{reg12,pos2}<=(sel10==1'b1)?{reg11[2],pos2_buf4,1'b1}:{reg11[0],pos2_buf4,1'b0};		
end
always @(posedge clk)begin
	out2<={pos2[4:0],reg12};
end  
			
            		
endmodule
