
`timescale 1ns/1ps
//`default_nettype none

module ddr3_test
	(
					   input  wire          clk,
	//contrl signal from pc				   
	(* KEEP = "TRUE" *)input  wire          sdramctrl_reset, //DDR_rst   
	(* KEEP = "TRUE" *)input  wire          tt_reset,      //光子存储复位 
	(* KEEP = "TRUE" *)input  wire          addr_rd_rst,   //脉冲输出复位
	(* KEEP = "TRUE" *)input  wire          addr_wr_rst2,  //序列存储复位
	(* KEEP = "TRUE" *)input  wire          addr_wr_rst3,
	(* KEEP = "TRUE" *)input  wire          addr_wr_rst4,
	(* KEEP = "TRUE" *)input  wire          addr_wr_rst5,
	(* KEEP = "TRUE" *)input  wire          addr_wr_rst6,
	(* KEEP = "TRUE" *)input  wire          addr_wr_rst7,
	
	(* KEEP = "TRUE" *)input  wire          writes_en,    //脉冲加载
	(* KEEP = "TRUE" *)input  wire          tt_write,     //光子探测使能
	(* KEEP = "TRUE" *)input  wire          reads_en,     //光子信息读出
	(* KEEP = "TRUE" *)input  wire          work_en,      //工作模式
	
	//DDR Input Buffer (ib_)
	(* KEEP = "TRUE" *)input  wire [255:0]  ib_data,
	(* KEEP = "TRUE" *)input  wire          ib_valid,
	(* KEEP = "TRUE" *)input  wire [9:0]    ib_count,
	(* KEEP = "TRUE" *)output reg           ib_re,
	
	(* KEEP = "TRUE" *)input  wire [255:0]  ib_tt_data0,
	(* KEEP = "TRUE" *)input  wire          ib_tt_valid0,
	(* KEEP = "TRUE" *)input  wire [9:0]    ib_tt_count0,
	(* KEEP = "TRUE" *)output reg           ib_tt_re0,
	
	//DDR Output Buffer (ob_)
	(* KEEP = "TRUE" *)output reg           ob_we,
	(* KEEP = "TRUE" *)output reg  [255:0]  ob_pg_data,
	(* KEEP = "TRUE" *)input  wire [9:0]    ob_pg_count,
	
	(* KEEP = "TRUE" *)output reg           ob_tt_we0,
	(* KEEP = "TRUE" *)output reg  [255:0]  ob_tt_data0,
	(* KEEP = "TRUE" *)input  wire [9:0]   ob_tt_count0,
		
	(* KEEP = "TRUE" *)input  wire [2:0]    load_file,
	(* KEEP = "TRUE" *)input  wire [2:0]    read_file,
	(* KEEP = "TRUE" *)output reg  [29:0]  	cmd_byte_addr_wr0=28'b0000000000000000000000000000,
	(* KEEP = "TRUE" *)output reg  [29:0]  	cmd_byte_addr_wr2,
	(* KEEP = "TRUE" *)output reg  [29:0]  	cmd_byte_addr_wr3,
	(* KEEP = "TRUE" *)output reg  [29:0]  	cmd_byte_addr_wr4,
	(* KEEP = "TRUE" *)output reg  [29:0]  	cmd_byte_addr_wr5,
	(* KEEP = "TRUE" *)output reg  [29:0]  	cmd_byte_addr_wr6,
	(* KEEP = "TRUE" *)output reg  [29:0]  	cmd_byte_addr_wr7,
	(* KEEP = "TRUE" *)output reg  [2:0]    woking_file,
	(* KEEP = "TRUE" *)output reg  [4:0]    state,
	
	(* KEEP = "TRUE" *)input  wire          app_rdy,
	(* KEEP = "TRUE" *)output reg           app_en,
	(* KEEP = "TRUE" *)output reg  [2:0]    app_cmd,
	(* KEEP = "TRUE" *)output reg  [29:0]   app_addr,
	
	(* KEEP = "TRUE" *)input  wire          calib_done,
	(* KEEP = "TRUE" *)input  wire [255:0]  app_rd_data,
	(* KEEP = "TRUE" *)input  wire          app_rd_data_end,
	(* KEEP = "TRUE" *)input  wire          app_rd_data_valid,
	(* KEEP = "TRUE" *)input  wire          app_wdf_rdy,
	(* KEEP = "TRUE" *)output reg           app_wdf_wren,
	(* KEEP = "TRUE" *)output reg  [255:0]  app_wdf_data,
	(* KEEP = "TRUE" *)output reg           app_wdf_end,
	(* KEEP = "TRUE" *)output wire [31:0]   app_wdf_mask
	);

localparam PG_FIFO_SIZE           = 1024;
localparam TT_FIFO_SIZE           = 1024;
localparam BURST_UI_WORD_COUNT = 2'd1; //(WORD_SIZE*BURST_MODE/UI_SIZE) = BURST_UI_WORD_COUNT : 32*8/256 = 1
localparam ADDRESS_INCREMENT   = 5'd8; // UI Address is a word address. BL8 Burst Mode = 8.

(* KEEP = "TRUE" *)reg [4:0] state;

(* KEEP = "TRUE" *)reg  [29:0] cmd_byte_addr_rd0=28'b0000000000000000000000000000;
(* KEEP = "TRUE" *)reg  [29:0] cmd_byte_addr_rd2;
(* KEEP = "TRUE" *)reg  [29:0] cmd_byte_addr_rd3;
(* KEEP = "TRUE" *)reg  [29:0] cmd_byte_addr_rd4;
(* KEEP = "TRUE" *)reg  [29:0] cmd_byte_addr_rd5;
(* KEEP = "TRUE" *)reg  [29:0] cmd_byte_addr_rd6;
(* KEEP = "TRUE" *)reg  [29:0] cmd_byte_addr_rd7;

(* KEEP = "TRUE" *)reg  [1:0]  burst_count;
(* KEEP = "TRUE" *)reg         reset_d;

assign app_wdf_mask = 16'h0000;

reg tt_rst;
reg addr_rd;
reg addr_wr0;
reg addr_wr1;
reg addr_wr2;
reg addr_wr3;
reg addr_wr4;
reg addr_wr5;
reg addr_wr6;
reg addr_wr7;

always @(posedge clk) reset_d <= sdramctrl_reset;
always @(posedge clk) addr_rd <= addr_rd_rst;
always @(posedge clk) tt_rst  <= tt_reset;

always @(posedge clk) addr_wr2 <= addr_wr_rst2;
always @(posedge clk) addr_wr3 <= addr_wr_rst3;
always @(posedge clk) addr_wr4 <= addr_wr_rst4;
always @(posedge clk) addr_wr5 <= addr_wr_rst5;
always @(posedge clk) addr_wr6 <= addr_wr_rst6;
always @(posedge clk) addr_wr7 <= addr_wr_rst7;

//distribute DDR address
parameter  file0     = 28'b0000000000000000000000000000;
parameter  file1     = 28'b0000000000000000000000000000;
parameter  file2     = 28'b0100000000000000000000000000;
parameter  file3     = 28'b1110000000000000000000000000;
parameter  file4     = 28'b1110010000000000000000000000;
parameter  file5     = 28'b1110100000000000000000000000;
parameter  file6     = 28'b1110110000000000000000000000;
parameter  file7     = 28'b1111000000000000000000000000;

reg file0_empty;
reg file1_empty;
reg file2_empty;
reg file3_empty;
reg file4_empty;
reg file5_empty;
reg file6_empty;
reg file7_empty;

reg channel;

always @(posedge clk)begin
	if(cmd_byte_addr_wr2==file2)begin
		file2_empty<=1'b1;
	end else begin
		file2_empty<=1'b0;
	end
end
always @(posedge clk)begin
	if(cmd_byte_addr_wr3==file3)begin
		file3_empty<=1'b1;
	end else begin
		file3_empty<=1'b0;
	end
end
always @(posedge clk)begin
	if(cmd_byte_addr_wr4==file4)begin
		file4_empty<=1'b1;
	end else begin
		file4_empty<=1'b0;
	end
end
always @(posedge clk)begin
	if(cmd_byte_addr_wr5==file5)begin
		file5_empty<=1'b1;
	end else begin
		file5_empty<=1'b0;
	end
end
always @(posedge clk)begin
	if(cmd_byte_addr_wr6==file6)begin
		file6_empty<=1'b1;
	end else begin
		file6_empty<=1'b0;
	end
end
always @(posedge clk)begin
	if(cmd_byte_addr_wr7==file7)begin
		file7_empty<=1'b1;
	end else begin
		file7_empty<=1'b0;
	end
end

parameter  s_idle       = 0;
parameter  s_write_0    = 1;
parameter  s_write_1    = 2;
parameter  s_write_2    = 3;
parameter  s_write_3    = 4;
parameter  s_write_4    = 5;

parameter  s_tt_write_0 = 6;
parameter  s_tt_write_1 = 7;
parameter  s_tt_write_2 = 8;
parameter  s_tt_write_3 = 9;
parameter  s_tt_write_4 = 10;

parameter  s_pg_read_0     = 11;
parameter  s_pg_read_1     = 12;
parameter  s_pg_read_2     = 13;

parameter  s_tt_read_0	= 14;
parameter  s_tt_read_1  = 15;
parameter  s_tt_read_2	= 16;
	   
		   
always @(posedge clk) begin	
	if (addr_wr2 == 1'b1) begin
		cmd_byte_addr_wr2  <= file2;
	end else if (addr_wr3 == 1'b1) begin
		cmd_byte_addr_wr3  <= file3;
	end else if (addr_wr4 == 1'b1) begin
		cmd_byte_addr_wr4  <= file4;
	end else if (addr_wr5 == 1'b1) begin
		cmd_byte_addr_wr5  <= file5;
	end else if (addr_wr6 == 1'b1) begin
		cmd_byte_addr_wr6  <= file6;
	end else if (addr_wr7 == 1'b1) begin
		cmd_byte_addr_wr7  <= file7;		
	end else if (addr_rd == 1'b1) begin
		cmd_byte_addr_rd2  <= file2;	
		cmd_byte_addr_rd3  <= file3;
		cmd_byte_addr_rd4  <= file4;	
		cmd_byte_addr_rd5  <= file5;
		cmd_byte_addr_rd6  <= file6;	
		cmd_byte_addr_rd7  <= file7;
	end else if (tt_rst == 1'b1) begin
		cmd_byte_addr_wr0  <= file0;
		cmd_byte_addr_rd0  <= file0;		
	end else if (reset_d) begin
		state             <= s_idle;
		burst_count       <= 2'b00;
		app_en            <= 1'b0;
		app_cmd           <= 3'b0;
		app_addr          <= 28'b0;
		app_wdf_wren      <= 1'b0;
		app_wdf_end       <= 1'b0;
		woking_file       <= 3'b0;
	end else begin
		app_en            <= 1'b0;
		app_wdf_wren      <= 1'b0;
		app_wdf_end       <= 1'b0;
		ib_re             <= 1'b0;
		ob_we             <= 1'b0;
		ib_tt_re0         <= 1'b0;
		ob_tt_we0         <= 1'b0;
		case (state)
			s_idle: begin
				burst_count <= BURST_UI_WORD_COUNT-1;
				// Only start writing when initialization done
				// Check to ensure that the input buffer has enough data for
				// a burst
				if (calib_done==1 && writes_en==1 && (ib_count >= BURST_UI_WORD_COUNT)) begin
					case (load_file)
						3'b000: begin
							app_addr <= app_addr;
							state    <= s_idle;
						end
						3'b001: begin
							app_addr <= app_addr;
							state    <= s_idle;
						end
						3'b010: begin
							app_addr <= cmd_byte_addr_wr2;
							state    <= s_write_0;
									
						end
						3'b011: begin
							app_addr <= cmd_byte_addr_wr3;
							state    <= s_write_0;
						end
						3'b100: begin
							app_addr <= cmd_byte_addr_wr4;
							state    <= s_write_0;
						end
						3'b101: begin
							app_addr <= cmd_byte_addr_wr5;
							state    <= s_write_0;
						end
						3'b110: begin
							app_addr <= cmd_byte_addr_wr6;
							state    <= s_write_0;
						end
						3'b111: begin
							app_addr <= cmd_byte_addr_wr7;
							state    <= s_write_0;
						end
					endcase
				end else if (calib_done==1 && work_en) begin
					if ((ib_tt_count0 >= BURST_UI_WORD_COUNT)&&tt_write)begin
						if(cmd_byte_addr_wr0>=file2)begin//channel0 over write
							state    <= s_idle;
						end else begin 
							app_addr <= cmd_byte_addr_wr0;
							state    <= s_tt_write_0;
						end
					end else if(ob_pg_count<(PG_FIFO_SIZE-2-BURST_UI_WORD_COUNT))begin
						case (read_file)
						//time data
							3'b000: begin
								state<=s_idle;
							end
							3'b001: begin
								state<=s_idle;
							end
						//pulse generator
							3'b010: begin
								if(file2_empty)begin
									state    <=s_idle;
								end else begin
									app_addr <= cmd_byte_addr_rd2;
									state    <= s_pg_read_0;
								end
							end
							3'b011: begin
								if(file3_empty)begin
									state    <=s_idle;
								end else begin
									app_addr <= cmd_byte_addr_rd3;
									state    <= s_pg_read_0;
								end
							end
							3'b100: begin
								if(file4_empty)begin
									state    <=s_idle;
								end else begin
									app_addr <= cmd_byte_addr_rd4;
									state    <= s_pg_read_0;
								end
							end
							3'b101: begin
								if(file5_empty)begin
									state<=s_idle;
								end else begin
									app_addr <= cmd_byte_addr_rd5;
									state    <= s_pg_read_0;
								end
							end
							3'b110: begin
								if(file6_empty)begin
									state    <=s_idle;
								end else begin
									app_addr <= cmd_byte_addr_rd6;
									state    <= s_pg_read_0;
								end
							end
							3'b111: begin
								if(file7_empty)begin
									state    <=s_idle;
								end else begin
									app_addr <= cmd_byte_addr_rd7;
									state    <= s_pg_read_0;
								end
							end
						endcase
					end
				end else if (calib_done==1 && reads_en==1) begin
					if (ob_tt_count0<(TT_FIFO_SIZE-2-BURST_UI_WORD_COUNT))begin
						app_addr <= cmd_byte_addr_rd0;
						state    <= s_tt_read_0;
					end else begin
						state    <= s_idle;
					end
				end
			end

			s_write_0: begin
				state <= s_write_1;
				ib_re <= 1'b1;
			end

			s_write_1: begin
				if(ib_valid==1) begin
					app_wdf_data <= ib_data;
					state <= s_write_2;
				end
			end

			s_write_2: begin
				if (app_wdf_rdy == 1'b1) begin
					state <= s_write_3;
				end
			end

			s_write_3: begin
				app_wdf_wren <= 1'b1;
				if (burst_count == 3'd0) begin
					app_wdf_end <= 1'b1;
				end
				if ( (app_wdf_rdy == 1'b1) & (burst_count == 3'd0) ) begin
					app_en    <= 1'b1;
					app_cmd <= 3'b000;
					state <= s_write_4;
				end else if (app_wdf_rdy == 1'b1) begin
					burst_count <= burst_count - 1'b1;
					state <= s_write_0;
				end
			end

			s_write_4: begin
				if (app_rdy == 1'b1) begin
					case (load_file)
						3'b000: begin
							state <= s_idle;
						end
						3'b001: begin
							state <= s_idle;
						end
						3'b010: begin
							cmd_byte_addr_wr2 <= cmd_byte_addr_wr2 + ADDRESS_INCREMENT;
							state <= s_idle;

						end
						3'b011: begin
							cmd_byte_addr_wr3 <= cmd_byte_addr_wr3 + ADDRESS_INCREMENT;
							state <= s_idle;
						end
						3'b100: begin
							cmd_byte_addr_wr4 <= cmd_byte_addr_wr4 + ADDRESS_INCREMENT;
							state <= s_idle;
						end
						3'b101: begin
							cmd_byte_addr_wr5 <= cmd_byte_addr_wr5 + ADDRESS_INCREMENT;
							state <= s_idle;
						end
						3'b110: begin
							cmd_byte_addr_wr6 <= cmd_byte_addr_wr6 + ADDRESS_INCREMENT;
							state <= s_idle;
						end
						3'b111: begin
							cmd_byte_addr_wr7 <= cmd_byte_addr_wr7 + ADDRESS_INCREMENT;
							state <= s_idle;
						end						
					endcase						
				end else begin
					app_en    <= 1'b1;
					app_cmd <= 3'b000;
				end
			end
			s_tt_write_0: begin
					ib_tt_re0<=1'b1;
					state <= s_tt_write_1;
			end
			s_tt_write_1: begin
				if(ib_tt_valid0==1) begin
					app_wdf_data <= ib_tt_data0;
					state <= s_tt_write_2;
				end
			end

			s_tt_write_2: begin
				if (app_wdf_rdy == 1'b1) begin
					state <= s_tt_write_3;
				end
			end

			s_tt_write_3: begin
				app_wdf_wren <= 1'b1;
				if (burst_count == 3'd0) begin
					app_wdf_end <= 1'b1;
				end
				if ( (app_wdf_rdy == 1'b1) & (burst_count == 3'd0) ) begin
					app_en    <= 1'b1;
					app_cmd <= 3'b000;
					state <= s_tt_write_4;
				end else if (app_wdf_rdy == 1'b1) begin
					burst_count <= burst_count - 1'b1;
					state <= s_tt_write_0;
				end
			end

			s_tt_write_4: begin
				if (app_rdy == 1'b1) begin
					cmd_byte_addr_wr0 <= cmd_byte_addr_wr0 + ADDRESS_INCREMENT;
					state <= s_idle;
				end else begin
					app_en    <= 1'b1;
					app_cmd <= 3'b000;
				end
			end
			
			s_tt_read_0: begin
				app_en    <= 1'b1;
				app_cmd <= 3'b001;
				state <= s_tt_read_1;
			end

			s_tt_read_1: begin
				if (app_rdy == 1'b1) begin
					cmd_byte_addr_rd0 <= cmd_byte_addr_rd0 + ADDRESS_INCREMENT;
					state <= s_tt_read_2;
				end else begin
					app_en    <= 1'b1;
					app_cmd   <= 3'b001;
				end
			end

			s_tt_read_2: begin
				if (app_rd_data_valid == 1'b1) begin
					ob_tt_data0 <= app_rd_data;
					ob_tt_we0   <= 1'b1;
					if (burst_count == 3'd0) begin
						state <= s_idle;
					end else begin
						burst_count <= burst_count - 1'b1;
					end
				end
			end
			s_pg_read_0: begin
				app_en    <= 1'b1;
				app_cmd <= 3'b001;
				state <= s_pg_read_1;
			end

			s_pg_read_1: begin
				if (app_rdy == 1'b1) begin
					case (read_file)
						3'b000: begin
							woking_file<=3'b000;
							state <= s_idle;
						end
						3'b001: begin
							woking_file<=3'b001;
							state <= s_idle;
						end
						3'b010: begin
							woking_file<=3'b010;
							if (cmd_byte_addr_rd2 == cmd_byte_addr_wr2-ADDRESS_INCREMENT) begin
								cmd_byte_addr_rd2 <= file2;
								state <= s_pg_read_2;
							end else begin
								cmd_byte_addr_rd2 <= cmd_byte_addr_rd2 + ADDRESS_INCREMENT;
								state <= s_pg_read_2;
							end
						end
						3'b011: begin
							woking_file<=3'b011;
							if (cmd_byte_addr_rd3 == cmd_byte_addr_wr3-ADDRESS_INCREMENT) begin
								cmd_byte_addr_rd3 <= file3;
								state <= s_pg_read_2;
							end else begin
								cmd_byte_addr_rd3 <= cmd_byte_addr_rd3 + ADDRESS_INCREMENT;
								state <= s_pg_read_2;
							end
						end
						3'b100: begin
							woking_file<=3'b100;
							if (cmd_byte_addr_rd4 == cmd_byte_addr_wr4-ADDRESS_INCREMENT) begin
								cmd_byte_addr_rd4 <= file4;
								state <= s_pg_read_2;
							end else begin
								cmd_byte_addr_rd4 <= cmd_byte_addr_rd4 + ADDRESS_INCREMENT;
								state <= s_pg_read_2;
							end
						end
						3'b101: begin
							woking_file<=3'b101;
							if (cmd_byte_addr_rd5 == cmd_byte_addr_wr5-ADDRESS_INCREMENT) begin
								cmd_byte_addr_rd5 <= file5;
								state <= s_pg_read_2;
							end else begin
								cmd_byte_addr_rd5 <= cmd_byte_addr_rd5 + ADDRESS_INCREMENT;
								state <= s_pg_read_2;
							end
						end
						3'b110: begin
							woking_file<=3'b110;
							if (cmd_byte_addr_rd6 == cmd_byte_addr_wr6-ADDRESS_INCREMENT) begin
								cmd_byte_addr_rd6 <= file6;
								state <= s_pg_read_2;
							end else begin
								cmd_byte_addr_rd6 <= cmd_byte_addr_rd6 + ADDRESS_INCREMENT;
								state <= s_pg_read_2;
							end
						end
						3'b111: begin
							woking_file<=3'b111;
							if (cmd_byte_addr_rd7 == cmd_byte_addr_wr7-ADDRESS_INCREMENT) begin
								cmd_byte_addr_rd7 <= file7;
								state <= s_pg_read_2;
							end else begin
								cmd_byte_addr_rd7 <= cmd_byte_addr_rd7 + ADDRESS_INCREMENT;
								state <= s_pg_read_2;
							end
						end
					endcase
				end else begin
					app_en    <= 1'b1;
					app_cmd   <= 3'b001;
				end
			end

			s_pg_read_2: begin
				if (app_rd_data_valid == 1'b1) begin
					ob_pg_data <= app_rd_data;
					ob_we <= 1'b1;
					if (burst_count == 3'd0) begin
						state <= s_idle;
					end else begin
						burst_count <= burst_count - 1'b1;
					end
				end
			end
			default:
				state<=s_idle;
		endcase
	end
end
endmodule
