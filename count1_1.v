`timescale 1ns / 1ps
module count1 (
input wire clk500,
input wire count_rst,//计数模块复位信号
input wire start_rst,//外部输入信号，start计数复位信号
input wire photo_rst1,//外部输入信号，start计数复位信号

input wire start,
input wire photo,//光子到达

input wire [23:0] cntstart ,//pc端控制的start计数上限值
input wire [31:0] cntstop ,//pc端控制的start计数上限值
output reg [31:0] cnt_stop,//500M时钟下的stop计数值
output reg [23:0] cnt_start,//start的计数值
output reg [31:0] sequence_count,//start_rst的计数值
output reg [23:0] cnt_photo,//光子计数值
output reg  ready//start的计数值
); 


reg start_pos;//start信号拉高检测信号
reg start_rst_pos;//start信号拉高检测信号
reg start_1;
reg start_2;
reg start_3;


reg start_rst_1;
reg start_rst_2;
reg start_rst_3;
always@(posedge clk500 ) begin
	if( count_rst) begin
		start_1 <= 1'b0;
		start_2 <= 1'b0;
		start_3 <= 1'b0;
		//start_4 <= 1'b0;
		//start_5 <= 1'b0;
	end else begin
		start_1<= start;
		start_2<= start_1;
		start_3<= start_2;
		//start_4<= start_3;
	//	start_5<= start_4;
	end 
end 

reg photo_rst_pos;//
reg photo_rst1;
reg photo_rst2;
reg photo_rst3;
always@(posedge clk500 ) begin
	if( count_rst) begin
		photo_rst2 <= 1'b0;
		photo_rst3 <= 1'b0;		
	end else begin
		photo_rst2<= photo_rst1;
		photo_rst3<= photo_rst2;
	end 
end 

wire photo_rst_det;
assign photo_rst_det = photo_rst2&(~photo_rst3);

always @(posedge clk500) begin 
	photo_rst_pos <= photo_rst_det;
end

reg photo_pos;//
reg photo_1;
reg photo_2;
reg photo_3;
always@(posedge clk500 ) begin
	if( count_rst) begin
		photo_1 <= 1'b0;
		photo_2 <= 1'b0;		
	end else begin
		photo_1<= photo;
		photo_2<= photo_1;
	end 
end 

wire photo_det;
assign photo_det = photo_1&(~photo_2);

always @(posedge clk500) begin 
	photo_pos <= photo_det;
end
//记录光子数
always @(posedge clk500  ) begin
	if ( count_rst|photo_rst_pos )begin
		cnt_photo <= 1'b0;
	end else if(photo_pos)begin
		cnt_photo <= cnt_photo +1;
	end else begin
		cnt_photo <= cnt_photo;
	end
end


assign start_rst_det = start_rst_1&start_rst_2&(~start_rst_3);

always @(posedge clk500) begin 
	start_rst_pos <= start_rst_det;
end
always@(posedge clk500 ) begin
	if( count_rst) begin
		start_rst_1 <= 1'b0;
		start_rst_2 <= 1'b0;
		start_rst_3 <= 1'b0;
		
	end else begin
		start_rst_1<= start_rst;
		start_rst_2<= start_rst_1;
		start_rst_3<= start_rst_2;
	end 
end 
wire start_det;
wire start_rst_det;

assign start_det = start_1&start_2&(~start_3);

always @(posedge clk500) begin 
	start_pos <= start_det;
end


//BUFG start1_BUFG (
	//.I(start_pos),
	//.O(cnt_rst)
//);
wire cnt_rst;

assign start_rst_det = start_rst_1&start_rst_2&(~start_rst_3);

always @(posedge clk500) begin 
	start_rst_pos <= start_rst_det;
end


always @(posedge clk500) begin
	if (start_pos) begin
		cnt_stop <= 32'b0;
	end else begin
		cnt_stop <= cnt_stop + 1'b1;
	end
end


always @(posedge clk500  ) begin
	if ( count_rst )begin
		ready <= 1'b1;
	end else begin
		if(cnt_stop >= cntstop) begin
			ready <= 1'b0;
		end else begin
			ready <= 1'b1;
		end
	end
end

always @(posedge clk500 ) begin
	if ( count_rst )begin
		cnt_start <=24'b0;
		sequence_count <=32'b0;
	end else begin 
		if(start_rst_pos)begin
			cnt_start <= 24'b0;
			sequence_count <= sequence_count + 1'b1;
		end else begin
			if (start_pos) begin
				if( cnt_start >= cntstart  ) begin 
					cnt_start <= 24'b1;
				end else begin 
					cnt_start <= cnt_start + 1'b1;
				end
			end
		end
	end
end
endmodule   			