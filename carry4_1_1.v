`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/08/12 08:52:00
// Design Name: 
// Module Name: carry4
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


module carry4_1(
	input   wire trigger1,
	input   wire trigger2,
	input   wire reset,
	input   wire clk,
	input   wire stop1,
	input   wire stop2,
	output  wire[39:0] latched_output10,
	output  wire[39:0] latched_output20,
	output wire[39:0] latched_output11,
	output wire[39:0] latched_output21,
	output wire[39:0] latched_output12,
	output wire[39:0] latched_output22,
	output wire[39:0] latched_output13,
	output wire[39:0] latched_output23

 );
 
   parameter           STAGES = 40;
   wire [4*STAGES-1:0]   unreg1;
   wire [STAGES-1:0]   reg_xhdl0;
   wire [STAGES-1:0]   reg_xhdl1;
   wire [STAGES-1:0]   reg_xhdl2;
   wire [STAGES-1:0]   reg_xhdl3;

	
   wire [4*STAGES-1:0]   unreg2;
   wire [STAGES-1:0]   reg_xhd20;
   wire [STAGES-1:0]   reg_xhd21;
   wire [STAGES-1:0]   reg_xhd22;
   wire [STAGES-1:0]   reg_xhd23;
   
   generate
      begin : xhdl1
         genvar              i;
         for (i = 0; i <= STAGES - 1; i = i + 1)
         begin : carry_delay_line
            
            if (i == 0)
            begin : first1_carry4
               
               
               CARRY4 delayblock1(
					.CO(unreg1[3:0]),
					.O(),
					.CI(1'b0), 
					.CYINIT(trigger1), 
					.DI(4'b0000), 
					.S(4'b1111)
					);
            end
            
            if (i > 0)
            begin : next_1carry4
               
               
               CARRY4 delayblock1(
					.CO(unreg1[4 * (i + 1) - 1:4 * i]),
					.O(),
					.CI(unreg1[4 * i - 1]), 
					.CYINIT(1'b0),
					.DI(4'b0000),
					.S(4'b1111)
					);
            end
         end
      end
   endgenerate
   
   generate
      begin : xhdl2
         genvar              j;
         for (j = 0; j <= STAGES - 1; j = j + 1 )
         begin : latch1
            
            
            FDR #(1'b0) FDR13(.C(stop1), .R(reset), .D(unreg1[4*j+3]), .Q(reg_xhdl3[j]));
			FDR #(1'b0) FDR12(.C(stop1), .R(reset), .D(unreg1[4*j+2]), .Q(reg_xhdl2[j]));
			FDR #(1'b0) FDR11(.C(stop1), .R(reset), .D(unreg1[4*j+1]), .Q(reg_xhdl1[j]));
			FDR #(1'b0) FDR10(.C(stop1), .R(reset), .D(unreg1[4*j+0]), .Q(reg_xhdl0[j]));
            
            FDR #(1'b0) FDR23(.C(clk), .R(reset), .D(reg_xhdl3[j]), .Q(latched_output13[j]));
			FDR #(1'b0) FDR22(.C(clk), .R(reset), .D(reg_xhdl2[j]), .Q(latched_output12[j]));
			FDR #(1'b0) FDR21(.C(clk), .R(reset), .D(reg_xhdl1[j]), .Q(latched_output11[j]));
			FDR #(1'b0) FDR20(.C(clk), .R(reset), .D(reg_xhdl0[j]), .Q(latched_output10[j]));
         end
      end
   endgenerate
   

//trigger1

 generate
      begin : xhdl3
         genvar              k;
         for (k = 0; k <= STAGES - 1; k = k + 1)
         begin : carry_delay_line
            
            if (k == 0)
            begin : first2_carry4
               
               
               CARRY4 delayblock2(
					.CO(unreg2[3:0]),
					.O(),
					.CI(1'b0), 
					.CYINIT(trigger2), 
					.DI(4'b0000), 
					.S(4'b1111)
					);
            end
            
            if (k > 0)
            begin : next_2carry4
               
               
               CARRY4 delayblock2(
					.CO(unreg2[4 * (k + 1) - 1:4 * k]),
					.O(),
					.CI(unreg2[4 * k - 1]), 
					.CYINIT(1'b0),
					.DI(4'b0000),
					.S(4'b1111)
					);
            end
         end
      end
   endgenerate
   
   generate
      begin : xhdl4
         genvar              h;
         for (h = 0; h <= STAGES - 1; h = h + 1 )
         begin : latch2          
            
            FDR #(1'b0) FDR33(.C(stop2), .R(reset), .D(unreg2[4*h+3]), .Q(reg_xhd23[h]));
			FDR #(1'b0) FDR32(.C(stop2), .R(reset), .D(unreg2[4*h+2]), .Q(reg_xhd22[h]));
			FDR #(1'b0) FDR31(.C(stop2), .R(reset), .D(unreg2[4*h+1]), .Q(reg_xhd21[h]));
			FDR #(1'b0) FDR30(.C(stop2), .R(reset), .D(unreg2[4*h+0]), .Q(reg_xhd20[h]));
            
            FDR #(1'b0) FDR43(.C(clk), .R(reset), .D(reg_xhd23[h]), .Q(latched_output23[h]));
			FDR #(1'b0) FDR42(.C(clk), .R(reset), .D(reg_xhd22[h]), .Q(latched_output22[h]));
			FDR #(1'b0) FDR41(.C(clk), .R(reset), .D(reg_xhd21[h]), .Q(latched_output21[h]));
			FDR #(1'b0) FDR40(.C(clk), .R(reset), .D(reg_xhd20[h]), .Q(latched_output20[h]));
         end
      end
   endgenerate
   
   
endmodule

//trigger2
