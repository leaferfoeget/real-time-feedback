module Controller(
	input wire sdramclk,
	input wire [3:0] command,
	input wire [6:0]ib_count,
	input wire 		app_wdf_end,
	output reg cmd_pagewrite,         //ddr3_test读使能
	output reg cmd_pageread,		  //ddr3_test写使能
	output reg [3:0] state,
	output reg pipe_fifo_rst,      
	output reg decoder_fifo_rst,
	output reg sdramctrl_reset
);



parameter CMD_RUN         = 4'd1;	//sdram read
parameter CMD_LOAD        = 4'd2;   //sdram write
parameter CMD_RESET_READ  = 4'd3;	//read  fifo
parameter CMD_RESET_SDRAM = 4'd4;	//sdram  reset
parameter CMD_RESET_WRITE = 4'd5;	//write  fifo
parameter CMD_RETURN      = 4'd6;

parameter IDLE          = 4'd0;
parameter RESET_READ    = 4'd1;
parameter RESET_SDRAM   = 4'd2;
parameter RESET_WRITE   = 4'd3;
parameter LOAD_0        = 4'd4;
parameter LOAD_1		= 4'd5;
parameter READ_0        = 4'd6;                        
parameter CNT_RESET_SDRAM = 16'd10000;
parameter CNT_RESET_READ  = 16'd64;
parameter CNT_RESET_WRITE = 16'd128;

reg [15:0]      state_ctr;




always @( posedge sdramclk ) begin
	cmd_pagewrite <= 1'b0;//ddr3_test  写使能
	cmd_pageread <= 1'b0;//dr33_test  读使能

	case( state )
		IDLE : begin
			pipe_fifo_rst <= 1'b0;
			decoder_fifo_rst <= 1'b0;
			sdramctrl_reset <= 1'b0;
			
			case( command )
				CMD_RESET_SDRAM: begin
					sdramctrl_reset <= 1'b1;
					state_ctr  <= CNT_RESET_SDRAM;//复位周期
					state <= RESET_SDRAM;
					
				end
				
				CMD_RESET_WRITE: begin
					pipe_fifo_rst <= 1'b1;
					state_ctr <= CNT_RESET_WRITE;
					state <= RESET_WRITE;
				end
				
				CMD_RESET_READ: begin
					decoder_fifo_rst <= 1'b1;
					state_ctr <= CNT_RESET_READ;
					state <= RESET_READ;
				end
				
				CMD_LOAD: begin
					state <= LOAD_0;
				end
				
				CMD_RUN: begin
					state <= READ_0;
				end
				
				default:
					state <= IDLE;
			endcase
		end
		
		
		RESET_SDRAM: begin                    
			if ( state_ctr == 0 ) begin
				state <= IDLE;
			end else begin
				state_ctr <= state_ctr - 1;
				state <= RESET_SDRAM;
			end 
		end 
		
		
		RESET_WRITE: begin                    //pipe_fifo复位
			if ( state_ctr == 0 ) begin
				pipe_fifo_rst <= 1'b0;
				state <= IDLE;
			end else begin
				pipe_fifo_rst <= 1'b1;
				state_ctr <= state_ctr - 1;
				state <= RESET_WRITE;
			end
		end
		
		RESET_READ: begin              //decoder_fifo复位
			if ( state_ctr == 0 ) begin
				decoder_fifo_rst <= 1'b0;
				state <= IDLE;
			end else begin
				decoder_fifo_rst <= 1'b1;
				state_ctr <= state_ctr - 1;
				state <= IDLE;
			end
		end 
	
	
		LOAD_0: begin
			state <= LOAD_0;
			if (command == CMD_RETURN ) begin
				state <= IDLE;
			end else begin
				cmd_pagewrite <= 1'b1;
				state <= LOAD_0;
			end
		end 
		
		
		// LOAD_1: begin
			// state = LOAD_1;
			// cmd_pagewrite <= 1'b1;
			// if ( app_wdf_end == 1'b1  ) begin
				// state <= LOAD_0;
			// end else begin
				// state <= LOAD_1;	
			// end
		// end
		
		// LOAD_2: begin
			// state <= LOAD_2;
			// if ( cmd_done == 1 ) begin
				// state <= LOAD_0;
			// end 
		// end
		
		READ_0: begin
			if ( command == CMD_RETURN ) begin
				state <= IDLE;
			end else begin
				cmd_pageread <= 1'b1;
			end
		end
		

	
	endcase
	
end 
endmodule



	