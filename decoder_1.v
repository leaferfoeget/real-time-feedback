`default_nettype none

module Decoder ( clk, reset, cmd, pattern, rd_en, dout, trigger_max,trigger_min,led,reset_value);

parameter N_CHANNELS = 24;
parameter CHANNEL_WIDTH = 4;
parameter CMD_WIDTH = 32;

input wire 						clk;
input wire 						reset;
input wire [CMD_WIDTH-1:0] 		cmd;
input wire [N_CHANNELS*CHANNEL_WIDTH-1:0] 	pattern;
output wire						rd_en;
output reg [N_CHANNELS*CHANNEL_WIDTH-1:0]	dout;
output reg [1:0]	                         led;
input wire        				trigger_max;
input wire 		                trigger_min;
input wire [N_CHANNELS-1:0]		reset_value;
reg [CMD_WIDTH-2:0]				count;
reg [CMD_WIDTH-2:0]				loop_count;
reg stop;

wire [N_CHANNELS*CHANNEL_WIDTH-1:0]		reset_bus; // help construction to expand reset values to N*8 bit

assign rd_en = (count == 0 | load_buf == 1) ? 1 : 0; // Read the next instruction when count is 0.
												  // If stop is high, prevent reading next instruction.
//parameter reset_value=24'b0;
genvar chan;
generate
	for (chan=0; chan<N_CHANNELS; chan=chan+1)
		begin:reset_block
			assign reset_bus[CHANNEL_WIDTH*(chan+1)-1:CHANNEL_WIDTH*chan] = {CHANNEL_WIDTH{reset_value[chan]}};		    
		end
endgenerate

reg [3:0] load_count=0;
reg [3:0] read_count=0;
reg load_buf;
reg [CMD_WIDTH-2:0]count_buf0;
reg [CMD_WIDTH-2:0]count_buf1;
reg [CMD_WIDTH-2:0]count_buf2;
reg [CMD_WIDTH-2:0]count_buf3;
reg [N_CHANNELS*CHANNEL_WIDTH-1:0] dout_buf0;
reg [N_CHANNELS*CHANNEL_WIDTH-1:0] dout_buf1;
reg [N_CHANNELS*CHANNEL_WIDTH-1:0] dout_buf2;
reg [N_CHANNELS*CHANNEL_WIDTH-1:0] dout_buf3;

reg period_start;//start信号拉高检测信号
reg period_det0;
reg period_det1;
reg period_det2;
always@(posedge clk) begin
	if(reset) begin
		period_det0 <= 1'b0;
		period_det1 <= 1'b0;
		period_det2 <= 1'b0;
	end else begin
		period_det0<= trigger_min;
		period_det1<= period_det0;
		period_det2<= period_det1;
	end 
end 

assign start_det = period_det0&period_det1&(~period_det2);
wire start_det;
always @(posedge clk) begin 
	period_start <= start_det;
end

////加载计数,缓存读使能,缓存
reg load_en;
always @(posedge clk) begin
	if(load_count==4)begin
		count_buf0 <= cmd[CMD_WIDTH-2:0];
		dout_buf0  <= pattern;
		load_buf   <= 1'b1;
		load_count <=load_count-1;
		load_en    <= 0;
	end else if(load_count==3)begin
		count_buf1 <= cmd[CMD_WIDTH-2:0];
		dout_buf1  <= pattern;
		load_buf   <= 1'b1;
		load_count <=load_count-1;
		load_en    <= 0;
	end else if(load_count==2)begin
		count_buf2 <= cmd[CMD_WIDTH-2:0];
		dout_buf2  <= pattern;
		load_buf   <= 1'b1;
		load_count <=load_count-1;
		load_en    <= 0;
	end else if(load_count==1)begin
		count_buf3 <= cmd[CMD_WIDTH-2:0];
		dout_buf3  <= pattern;
		load_buf   <= 1'b1;
		load_count <=load_count-1;
		load_en    <= 1'b1;
	end else if(stop)begin
		load_count <= 3'b100;
		count_buf0 <= 0;
		dout_buf0  <= 0;
		count_buf1 <= 0;
		dout_buf1  <= 0;
		count_buf2 <= 0;
		dout_buf2  <= 0;
		count_buf3 <= 0;
		dout_buf3  <= 0;
		load_en    <= 0;
	end else if(load_count==0)begin
		load_buf<=0;
		load_en    <= 0;
	end else begin
		load_buf   <= 0;
		load_count <= 0;
		load_en    <= 0;
	end
end

reg period_skip;
reg [1:0]read_dat;
reg load_en_buf;

always @(posedge clk) begin
	load_en_buf<=load_en;
end

always @(posedge clk) begin
	if(trigger_max|reset)begin
		period_skip<=1;
	end else if(load_en)begin
		period_skip<=0;
	end else begin
		period_skip<=period_skip;
	end
end
	
always @(posedge clk) begin
	if ( reset ) begin
	    count <= 1; 
	    dout <= reset_bus;
	//连续载入脉冲
	end else if(period_skip)begin
		if ( count == 0 ) begin
		    dout  <= pattern; // Update the output to the new pattern.
		    				 // As long as stop is low, pattern will contain
		    				 // the next pattern, if stop is high, pattern is not updated
		    				 // such that the same pattern will be shifted out repeatedly.
			stop  <= cmd[CMD_WIDTH-1];
		    count <= cmd[CMD_WIDTH-2:0];
		end else begin
		    count <= count - 1;
			dout  <= dout;
			stop  <= stop;
		end
	//初始化循环缓存脉冲
	end else if(load_en_buf|period_start)begin
		dout         <= dout_buf0;
		loop_count   <= count_buf0;
		read_dat     <= 0;
		count        <= 1;
		led          <=2'b00;		
	end else begin
		case(read_dat)
			0:begin
				if ( loop_count == 0 ) begin
					dout          <= dout_buf1;
					loop_count    <= count_buf1;
					read_dat      <= 1;
				end else begin
					loop_count    <= loop_count - 1;
					dout          <= dout;
					led           <=2'b01;
				end 
			end
			1:begin
				if ( loop_count == 0 ) begin
					dout          <= dout_buf2;
					loop_count    <= count_buf2;
					read_dat      <= 2;
				end else begin
					loop_count    <= loop_count - 1;
					dout          <= dout;
					led           <=2'b10;
				end
			end
			2:begin
				if ( loop_count == 0 ) begin
					dout          <= dout_buf3;
					loop_count    <= count_buf3;
					read_dat      <= 3;
				end else begin
					loop_count    <= loop_count - 1;
					dout          <= dout;
					led           <=2'b11;
				end 
			end
			3:begin
				if ( loop_count == 0 ) begin
					dout          <= dout_buf0;
					loop_count    <= count_buf0;
					read_dat      <= 0;
				end else begin
					loop_count    <= loop_count - 1;
					dout          <= dout;
					led           <=2'b00;
				end
			end
		endcase
	end
end

endmodule
