`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/08/11 16:21:42
// Design Name: 
// Module Name: change1
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


module change1_1(
	 
	input     wire clk,
	input     wire start1,
	input 	  wire rst,
	output    wire trigger1
	
    );
	
   reg a;	 
	 
	               	 
	assign trigger1 = (!a) && (start1);
	

	always @(posedge clk)begin
			a <= start1;
	end
	
endmodule
