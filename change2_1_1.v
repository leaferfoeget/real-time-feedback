`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/08/11 17:06:02
// Design Name: 
// Module Name: change2
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


module change2_1(
	 
	input     wire clk,
	input     wire start2,
	input 	  wire rst,
	output    wire trigger2
	
    );
	
   reg b;	 
	 
	               	 
	assign trigger2 = (!b) && (start2);
	

	always @(posedge clk)begin
			b <= start2;
	end
	
endmodule

