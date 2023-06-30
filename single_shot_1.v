`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/05/27 09:08:55
// Design Name: 
// Module Name: single_shot
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
module single_shot (
input wire clk,
input wire [23:0] cnt_start,   //当前切片光子计数值
input wire  start_rst,         //探测开始
input wire  stop_singleshot,         //探测结束根据阈值触发
input wire [4*size-1:0] cnt0_weight, //光子数权重
input wire [4*size-1:0] cnt1_weight, //光子数权重
input wire [4*size-1:0] cnt2_weight, //光子数权重
input wire [4*size-1:0] cnt3_weight, //光子数权重
input wire [4*size-1:0] cnt4_weight, //光子数权重
input wire [4*size-1:0] cnt5_weight, //光子数权重

input wire [31:0]       accuracy_max_min,//概率阈值
input wire [31:0]       accuracy_num_thre,//探测周期、结束阈值选择

output reg[size-1:0] last_matrix_0_L0,
output reg[size-1:0] last_matrix_1_L0,  
output reg[size-1:0] last_matrix_0_L1, 
output reg[size-1:0] last_matrix_1_L1,

output wire trigger1, 
output wire trigger2
  
); 

//产生周期信号

reg period_en=0;//周期使能

always@(posedge clk) begin
	if(trigger1|trigger2)begin
		period_en<=0;
	end else if(rst_pos)begin
		period_en<=1;
	end else begin
		period_en<=period_en;
	end
end 

reg [23:0]period_num;//周期间隔=10ns*num*number
reg [23:0]select_choose;
parameter num=8'd1;//10ns*10

always@(posedge clk) begin
	period_num<=accuracy_num_thre[30:16]*num;//15位
	select_choose<=accuracy_num_thre[31];//高电平选择NV-
end 

reg [23:0]period_num_cnt=0;//周期触发
reg period_det;
always@(posedge clk) begin
	if(period_en)begin
		if(period_num_cnt==period_num)begin
			period_num_cnt<=24'b0;
			period_det    <=1;
		end else begin
			period_num_cnt<=period_num_cnt+1;
			period_det    <=0;
		end
	end else begin
		period_num_cnt<=24'b0;
		period_det<=0;
	end
end

reg period_det_pos;//周期探测
reg period_det0;
reg period_det1;

always@(posedge clk) begin
	if(rst_pos) begin
		period_det0 <= 1'b0;
		period_det1 <= 1'b0;
	end else begin
		period_det0<= period_det;
		period_det1<= period_det0;
	end 
end 

assign start_det = period_det0&(~period_det1);
wire start_det;
always @(posedge clk) begin 
	period_det_pos <= start_det;
end


reg rst_pos;//探测开始
reg rst_det0;
reg rst_det1;
reg rst_det2;

always@(posedge clk) begin
	rst_det0<= start_rst;
	rst_det1<= rst_det0;
	rst_det2<= rst_det1;
end 
assign rst_det = rst_det0&rst_det1&(~rst_det2);
wire rst_det;
always @(posedge clk) begin 
	rst_pos <= rst_det;
end
reg stop_pos;//探测结束
reg stop_det0;
reg stop_det1;

always@(posedge clk) begin
	stop_det0<= stop_singleshot;
	stop_det1<= stop_det0;
end 
assign stop_det = stop_det0&(~stop_det1);
wire stop_det;
always @(posedge clk) begin 
	stop_pos <= stop_det;
end

parameter size = 32;
reg [2:0]   cur_cnt;
reg [2:0]   last_cnt;
reg         cnt_update;
reg         weight_update;
reg [23:0]  period_cnt;

always @(posedge clk) begin
	if(rst_pos) begin
		cur_cnt          <= 3'b0;//初始计数
		last_cnt         <= 0;
		cnt_update       <= 1'b0;
		period_cnt       <= 24'b0;
		last_matrix_0_L0 <= 0;
		last_matrix_1_L0 <= 0;
		last_matrix_0_L1 <= 0;
		last_matrix_1_L1 <= 0;
	end else if(period_det_pos)begin
		cur_cnt          <= cnt_start-last_cnt;
		last_cnt         <= cnt_start;
		period_cnt       <= period_cnt+1;
		last_matrix_0_L0 <= curr_matrix_0_L0_buf;
		last_matrix_1_L0 <= curr_matrix_1_L0_buf;
		last_matrix_0_L1 <= curr_matrix_0_L1_buf;
		last_matrix_1_L1 <= curr_matrix_1_L1_buf;
		
		cnt_update       <= 1'b1;
	end else begin
		cur_cnt          <= cur_cnt;
		last_cnt         <= last_cnt;
		period_cnt       <= period_cnt;
		
		last_matrix_0_L0 <= last_matrix_0_L0;
		last_matrix_1_L0 <= last_matrix_1_L0;
		last_matrix_0_L1 <= last_matrix_0_L1;
		last_matrix_1_L1 <= last_matrix_1_L1;
		
		cnt_update       <= 1'b0;
	end
end

reg [size-1:0]weight0;//2*2
reg [size-1:0]weight1;
reg [size-1:0]weight2;
reg [size-1:0]weight3;

//选择权重系数
always @(posedge clk) begin
	if(cnt_update)begin
		case(cur_cnt)
			3'b000:begin
				weight0        <= cnt0_weight[1*size-1:0*size];
				weight1        <= cnt0_weight[2*size-1:1*size];
				weight2        <= cnt0_weight[3*size-1:2*size];
				weight3        <= cnt0_weight[4*size-1:3*size];
				weight_update  <= 1'b1;
			end
			3'b001:begin
				weight0        <= cnt1_weight[1*size-1:0*size];
				weight1        <= cnt1_weight[2*size-1:1*size];
				weight2        <= cnt1_weight[3*size-1:2*size];
				weight3        <= cnt1_weight[4*size-1:3*size];
				weight_update <= 1'b1;
			end
			3'b010:begin
				weight0        <= cnt2_weight[1*size-1:0*size];
				weight1        <= cnt2_weight[2*size-1:1*size];
				weight2        <= cnt2_weight[3*size-1:2*size];
				weight3        <= cnt2_weight[4*size-1:3*size];
				weight_update <= 1'b1;
			end
			3'b011:begin
				weight0        <= cnt3_weight[1*size-1:0*size];
				weight1        <= cnt3_weight[2*size-1:1*size];
				weight2        <= cnt3_weight[3*size-1:2*size];
				weight3        <= cnt3_weight[4*size-1:3*size];
				weight_update <= 1'b1;
			end
			3'b100:begin
				weight0        <= cnt4_weight[1*size-1:0*size];
				weight1        <= cnt4_weight[2*size-1:1*size];
				weight2        <= cnt4_weight[3*size-1:2*size];
				weight3        <= cnt4_weight[4*size-1:3*size];
				weight_update <= 1'b1;
			end
			3'b101:begin
				weight0        <= cnt5_weight[1*size-1:0*size];
				weight1        <= cnt5_weight[2*size-1:1*size];
				weight2        <= cnt5_weight[3*size-1:2*size];
				weight3        <= cnt5_weight[4*size-1:3*size];
				weight_update <= 1'b1;
			end
			default:begin
				weight0        <= cnt5_weight[1*size-1:0*size];
				weight1        <= cnt5_weight[2*size-1:1*size];
				weight2        <= cnt5_weight[3*size-1:2*size];
				weight3        <= cnt5_weight[4*size-1:3*size];
				weight_update <= 1'b1;
			end
		endcase
	end else begin
		weight0        <= weight0;
		weight1        <= weight1;
		weight2        <= weight2;
		weight3        <= weight3;
		weight_update <= 1'b0;
	end
end

//L0矩阵计算

wire [size-1:0]weight0;//2*2
wire [size-1:0]weight1;
wire [size-1:0]weight2;
wire [size-1:0]weight3;

reg [size-1:0]last_matrix_0_L0;
reg [size-1:0]last_matrix_1_L0;

reg [2*size-1:0]p0_L0;
reg [2*size-1:0]p1_L0;
reg [2*size-1:0]p2_L0;
reg [2*size-1:0]p3_L0;

reg [2*size:0]curr_matrix_0_L0;
reg [2*size:0]curr_matrix_1_L0;	

reg [size-1:0]curr_matrix_0_L0_buf;
reg [size-1:0]curr_matrix_1_L0_buf;
reg add_0;
always @(posedge clk) begin
	if(weight_update)begin
		p0_L0<=weight0*last_matrix_0_L0;
		p1_L0<=weight1*last_matrix_1_L0;
		p2_L0<=weight2*last_matrix_0_L0;
		p3_L0<=weight3*last_matrix_1_L0;
		add_0<=1'b1;
	end else begin
		p0_L0<=p0_L0;
		p1_L0<=p1_L0;
		p2_L0<=p2_L0;
		p3_L0<=p3_L0;
		add_0<=1'b0;
	end
end	
always @(posedge clk) begin
	if(rst_pos)begin
		curr_matrix_0_L0<=65'b0;
		curr_matrix_1_L0<=65'b0;
	end else if(add_0)begin
		if(period_cnt==24'b1)begin
			curr_matrix_0_L0<={weight0,32'b0};
			curr_matrix_1_L0<={weight2,32'b0};
		end else begin
			curr_matrix_0_L0<=p0_L0+p1_L0;
			curr_matrix_1_L0<=p2_L0+p3_L0;
		end
	end else begin
		curr_matrix_0_L0<=curr_matrix_0_L0;
	end
end


		

//L1矩阵计算
reg [size-1:0]last_matrix_0_L1;
reg [size-1:0]last_matrix_1_L1;

reg [2*size-1:0]p0_L1;
reg [2*size-1:0]p1_L1;
reg [2*size-1:0]p2_L1;
reg [2*size-1:0]p3_L1;

reg [2*size:0]curr_matrix_0_L1;
reg [2*size:0]curr_matrix_1_L1;	

reg [size-1:0]curr_matrix_0_L1_buf;
reg [size-1:0]curr_matrix_1_L1_buf;
reg add_1;
always @(posedge clk) begin
	if(weight_update)begin
		p0_L1<=weight0*last_matrix_0_L1;
		p1_L1<=weight1*last_matrix_1_L1;
		p2_L1<=weight2*last_matrix_0_L1;
		p3_L1<=weight3*last_matrix_1_L1;
		add_1<=1'b1;
	end else begin
		p0_L1<=p0_L1;
		p1_L1<=p1_L1;
		p2_L1<=p2_L1;
		p3_L1<=p3_L1;
		add_1<=1'b0;
	end
end	

always @(posedge clk) begin
	if(rst_pos)begin
		curr_matrix_0_L1<=65'b0;
		curr_matrix_1_L1<=65'b0;
	end else if(add_1)begin
		if(period_cnt==1)begin
			curr_matrix_0_L1<={weight1,32'b0};
			curr_matrix_1_L1<={weight3,32'b0};
		end else begin
			curr_matrix_0_L1<=p0_L1+p1_L1;
			curr_matrix_1_L1<=p2_L1+p3_L1;
		end
	end else begin
		curr_matrix_0_L1<=curr_matrix_0_L1;
		curr_matrix_1_L1<=curr_matrix_1_L1;
	end
end
//保留有效位
always @(posedge clk) begin
	if(curr_matrix_0_L0[2*size-1]|curr_matrix_1_L0[2*size-1]|curr_matrix_0_L1[2*size-1]|curr_matrix_1_L1[2*size-1])begin
		curr_matrix_0_L0_buf<=curr_matrix_0_L0[2*size-1:size];
		curr_matrix_1_L0_buf<=curr_matrix_1_L0[2*size-1:size];
		curr_matrix_0_L1_buf<=curr_matrix_0_L1[2*size-1:size];
		curr_matrix_1_L1_buf<=curr_matrix_1_L1[2*size-1:size];
	end else if(curr_matrix_0_L0[2*size-2]|curr_matrix_1_L0[2*size-2]|curr_matrix_0_L1[2*size-2]|curr_matrix_1_L1[2*size-2])begin
		curr_matrix_0_L0_buf<=curr_matrix_0_L0[2*size-2:size-1];
		curr_matrix_1_L0_buf<=curr_matrix_1_L0[2*size-2:size-1];
		curr_matrix_0_L1_buf<=curr_matrix_0_L1[2*size-2:size-1];
		curr_matrix_1_L1_buf<=curr_matrix_1_L1[2*size-2:size-1];
	end else begin
		curr_matrix_0_L0_buf<=curr_matrix_0_L0[2*size-3:size-2];
		curr_matrix_1_L0_buf<=curr_matrix_1_L0[2*size-3:size-2];
		curr_matrix_0_L1_buf<=curr_matrix_0_L1[2*size-3:size-2];
		curr_matrix_1_L1_buf<=curr_matrix_1_L1[2*size-3:size-2];
	end
end	
//阈值计算


reg [size:0]   left_equation_buf  ;// 
reg [size:0]   right_equation_buf ;//

reg [size+1:0]   left_equation  ;// L0*P0
reg [size+1:0]   right_equation ;//(L0+L1)*P1

reg [size+1+8:0]   max_left  ;
reg [size+1+8:0]   max_right ;
reg [size+1+8:0]   min_left  ;
reg [size+1+8:0]   min_right ;
reg [size+1+8:0]   threshold_left ;
reg [size+1+8:0]   threshold_right;
always @(posedge clk) begin
	left_equation_buf  <= curr_matrix_0_L0_buf+curr_matrix_1_L0_buf;
	right_equation_buf <= curr_matrix_0_L1_buf+curr_matrix_1_L1_buf;
	
	left_equation  <= {1'b0,left_equation_buf};
	right_equation <= left_equation_buf + right_equation_buf;
	
	max_left        <= accuracy_max_min[7:0]   *left_equation;
	max_right       <= accuracy_max_min[15:8]  *right_equation;
	min_left        <= accuracy_max_min[23:16] *left_equation;
	min_right       <= accuracy_max_min[31:24] *right_equation;
	threshold_left  <= accuracy_num_thre[7:0]  *left_equation;
	threshold_right <= accuracy_num_thre[15:8] *right_equation;
end

reg trigger1_buf=0;
reg trigger2_buf=0;

always @(posedge clk) begin
	if(rst_pos)begin
		trigger1_buf<=0;
		trigger2_buf<=0;
	end else if(period_cnt>1)begin
		if(select_choose)begin
			if(max_left>max_right)begin
				trigger1_buf<=1;
				trigger2_buf<=0;
			end else if(min_left<min_right)begin
				trigger1_buf<=0;
				trigger2_buf<=1;
			end else if(stop_pos)begin
				if(threshold_left>threshold_right)begin
					trigger1_buf<=1;
					trigger2_buf<=0;
				end else begin
					trigger1_buf<=0;
					trigger2_buf<=1;
				end	
			end else begin
				trigger1_buf<=trigger1_buf;
				trigger2_buf<=trigger2_buf;
			end
		end else begin
			if(max_left>max_right)begin
				trigger1_buf<=0;
				trigger2_buf<=1;
			end else if(min_left<min_right)begin
				trigger1_buf<=1;
				trigger2_buf<=0;
			end else if(stop_pos)begin
				if(threshold_left>threshold_right)begin
					trigger1_buf<=0;
					trigger2_buf<=1;
				end else begin
					trigger1_buf<=1;
					trigger2_buf<=0;
				end	
			end else begin
				trigger1_buf<=trigger1_buf;
				trigger2_buf<=trigger2_buf;
			end
		end
	end else begin
			trigger1_buf<=trigger1_buf;
			trigger2_buf<=trigger2_buf;
	end
end

reg trigger1_buf0;
reg trigger1_buf1;
reg trigger2_buf0;
reg trigger2_buf1;

always @(posedge clk) begin
	trigger1_buf0<= trigger1_buf;
	trigger1_buf1<= trigger1_buf0;
	trigger2_buf0<= trigger2_buf;
	trigger2_buf1<= trigger2_buf0;
end

assign trigger1 = trigger1_buf0&(~trigger1_buf1);
assign trigger2 = trigger2_buf0&(~trigger2_buf1);


endmodule   
