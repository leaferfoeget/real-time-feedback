// ------------------------------------------------------------------------
// ------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

	module PG_TT (
	input  wire [4:0]   okUH,
	output wire [2:0]   okHU,
	inout  wire [31:0]  okUHU,
	inout  wire         okAA,
	input  wire         sys_clk_p,
	input  wire         sys_clk_n,

	input  wire         stop_in1,
	input  wire         stop_singleshot,
	input  wire         start1,
	input  wire         start_rst1,
	input  wire         photo_rst1,

	output wire [7:0]   led,
	inout  wire [31:0]  ddr3_dq,
	output wire [14:0]  ddr3_addr,
	output wire [2 :0]  ddr3_ba,
	output wire [0 :0]  ddr3_ck_p,
	output wire [0 :0]  ddr3_ck_n,
	output wire [0 :0]  ddr3_cke,
	output wire         ddr3_cas_n,
	output wire         ddr3_ras_n,
	output wire         ddr3_we_n,
	output wire [0 :0]  ddr3_odt,
	output wire [3 :0]  ddr3_dm,
	output wire	[N_CHANNELS-1-tt_channel:0] 	dout,
	inout  wire [3 :0]  ddr3_dqs_p,
	inout  wire [3 :0]  ddr3_dqs_n,
	output wire         ddr3_reset_n
	);
	
// DCM clocks
wire			clk2x; //  (200 MHz) DCM clock: serializer stage 1 clock
wire			clk4x; // (400 MHz) DCM clock: serializer stage 2 clock
parameter N_CHANNELS = 8'd24;
parameter CHANNEL_WIDTH = 8'd4;
parameter COMMAND_WIDTH = 32; 
parameter tt_channel = 5; 

/* serial output */


reg  		  sys_rst;
wire          init_calib_complete;
// reg           sdramctrl_reset_pipe;

wire [29 :0]  app_addr;
wire   addr_rd_rst;
wire   addr_wr_rst0;
wire   addr_wr_rst1;
wire   addr_wr_rst2;
wire   addr_wr_rst3;
wire   addr_wr_rst4;
wire   addr_wr_rst5;
wire   addr_wr_rst6;
wire   addr_wr_rst7;
wire [2  :0]  app_cmd;
wire          app_en;
wire          app_rdy;
wire [255:0]  app_rd_data;
wire          app_rd_data_end;
wire          app_rd_data_valid;
wire [255:0]  app_wdf_data;
wire          app_wdf_end;
wire [31 :0]  app_wdf_mask;
wire          app_wdf_rdy;
wire          app_wdf_wren;

wire          clk;
wire          rst;
reg stop;
// Front Panel

// Target interface bus:
wire         okClk;
wire [112:0] okHE;
wire [64:0]  okEH;

//wire [31:0]  ep00wire;

wire         pipe_in_read;
wire [255:0] pipe_in_data;
wire [9:0]   pipe_in_rd_count;
wire [12:0]  pipe_in_wr_count;
wire         pipe_in_valid;
wire         pipe_in_full;
wire         pipe_in_empty;

reg          pipe_in_ready;
reg          pipe_in_ready0;


wire         pipe_out_write;
wire [255:0] pipe_out_data;
wire [10:0]  pipe_out_rd_count;
wire [9:0]   pipe_out_wr_count;
wire         pipe_out_full;
wire         pipe_out_empty;


// Pipe Fifos
wire         pi0_ep_write;
wire [31:0]  pi0_ep_dataout;

wire         po0_ep_read1;
wire         po0_ep_read2;
wire [31:0]  po0_ep_datain;
wire [31:0]  po1_ep_datain;
// FIFOs
wire			pipe_fifo_rst;
wire			pipe_fifo_wr_en;
wire			pipe_fifo_rd_en;
wire			pipe_fifo_empty;

wire			decoder_fifo_rst;
wire			decoder_fifo_rd_en;
wire			decoder_fifo_wr_en;
wire [N_CHANNELS*CHANNEL_WIDTH + COMMAND_WIDTH - 1 : 0]		decoder_fifo_dout;
// wire [31 : 0]		decoder_fifo_dout;
wire			decoder_fifo_full;
wire			decoder_fifo_underflow;

// trigger management
wire			reset_request;
wire			use_trigger;

wire [31:0] LOOP_COUNT;

// decoder
reg			decoder_reset;
wire [N_CHANNELS*CHANNEL_WIDTH-1:0]		decoder_dout;

// sdramctrl
wire            sdramctrl_reset;

wire            cmd_pagewrite;
wire            cmd_pageread;
wire            cmd_tt_write;
wire            cmd_work;
wire            cmd_data0;

// controller
wire  [13:0]     command;
wire  [3:0]     state;
wire [31:0] lOOP_COUNT;



function [7:0] xem7310_led;
input [7:0] a;
integer i;
begin
	for(i=0; i<8; i=i+1) begin:u 
		xem7310_led[i] = (a[i]==1'b1) ? (1'b0) : (1'bz);
	end
end
endfunction

wire [2:0]working_file;

assign led = xem7310_led({decoder_fifo_underflow,ddr_state,2'b0});

always @(posedge clk2x ) begin
	if (reset_request||use_trigger) begin
		decoder_reset <= 1;
	end else begin
		decoder_reset <= 0;
	end		
end	

clk_wiz_0 mmcm
   (
    // Clock out ports
    .clk2x(clk2x),
	.clk4x(clk4x),
    // Status and control signals
    .reset(1'b0), // input reset
    .locked(),       // output locked
   // Clock in ports
    .clk_in1(clk));      // input clk_in1


reg [31:0] rst_cnt;
initial rst_cnt = 32'b0;
always @(posedge okClk) begin
	if(rst_cnt < 32'h0080_0000) begin
		rst_cnt <= rst_cnt + 1;
		sys_rst <= 1'b1;
	end
	else begin
		sys_rst <= 1'b0;
	end
end	
//MIG User Interface instantiation
u_ddr3_256_32 u_ddr3_256_32 (
	// Memory interface ports
	.ddr3_addr                      (ddr3_addr),
	.ddr3_ba                        (ddr3_ba),
	.ddr3_cas_n                     (ddr3_cas_n),
	.ddr3_ck_n                      (ddr3_ck_n),
	.ddr3_ck_p                      (ddr3_ck_p),
	.ddr3_cke                       (ddr3_cke),
	.ddr3_ras_n                     (ddr3_ras_n),
	.ddr3_reset_n                   (ddr3_reset_n),
	.ddr3_we_n                      (ddr3_we_n),
	.ddr3_dq                        (ddr3_dq),
	.ddr3_dqs_n                     (ddr3_dqs_n),
	.ddr3_dqs_p                     (ddr3_dqs_p),
	.init_calib_complete            (init_calib_complete),
	
	.ddr3_dm                        (ddr3_dm),
	.ddr3_odt                       (ddr3_odt),
	// Application interface ports
	.app_addr                       (app_addr),
	.app_cmd                        (app_cmd),
	.app_en                         (app_en),
	.app_wdf_data                   (app_wdf_data),
	.app_wdf_end                    (app_wdf_end),
	.app_wdf_wren                   (app_wdf_wren),
	.app_rd_data                    (app_rd_data) ,
	.app_rd_data_end                (app_rd_data_end),
	.app_rd_data_valid              (app_rd_data_valid),
	.app_rdy                        (app_rdy),
	.app_wdf_rdy                    (app_wdf_rdy),
	.app_sr_req                     (1'b0),
	.app_sr_active                  (),
	.app_ref_req                    (1'b0),
	.app_ref_ack                    (),
	.app_zq_req                     (1'b0),
	.app_zq_ack                     (),
	.ui_clk                         (clk),
	.ui_clk_sync_rst                (rst),
	
	.app_wdf_mask                   (app_wdf_mask),
	
	// System Clock Ports
	.sys_clk_p                      (sys_clk_p),
	.sys_clk_n                      (sys_clk_n),
	.sys_rst                        (sys_rst)
	);


// OK MIG DDR3 Testbench Instatiation
wire [29 :0]  cmd_byte_addr_wr0;
wire [29 :0]  cmd_byte_addr_wr1;
wire [29 :0]  cmd_byte_addr_wr2;
wire [29 :0]  cmd_byte_addr_wr3;
wire [29 :0]  cmd_byte_addr_wr4;
wire [29 :0]  cmd_byte_addr_wr5;
wire [29 :0]  cmd_byte_addr_wr6;
wire [29 :0]  cmd_byte_addr_wr7;

wire reset;
wire [255:0]ib_tt_data0;
wire ib_tt_valid0;
wire [9:0]ib_tt_count0;
wire ib_tt_re0;
wire ob_tt_we0;
wire [255:0]ob_tt_data0;
wire [9:0]ob_tt_count0;

wire [4:0]ddr_state;

ddr3_test ddr3_tb (
	.clk                (clk),
	.sdramctrl_reset    (sdramctrl_reset),
	.tt_reset           (reset),
	.addr_rd_rst        (addr_rd_rst),
	.addr_wr_rst2       (addr_wr_rst2),
	.addr_wr_rst3       (addr_wr_rst3),
	.addr_wr_rst4       (addr_wr_rst4),
	.addr_wr_rst5       (addr_wr_rst5),
	.addr_wr_rst6       (addr_wr_rst6),
	.addr_wr_rst7       (addr_wr_rst7),
	
	.writes_en          (cmd_pagewrite),
	.work_en            (cmd_work),
	.reads_en           (cmd_pageread),
	.tt_write           (cmd_tt_write),
	.state              (ddr_state),
	
	.ib_re              (pipe_in_read),
	.ib_data            (pipe_in_data),
	.ib_count           (pipe_in_rd_count),
	.ib_valid           (pipe_in_valid),
	.ib_tt_data0        (ib_tt_data0),
	.ib_tt_valid0       (ib_tt_valid0),
	.ib_tt_count0       (ib_tt_count0),
	.ib_tt_re0          (ib_tt_re0),
	
	.ob_we              (pipe_out_write),
	.ob_pg_data         (pipe_out_data),
	.ob_pg_count        (pipe_out_wr_count),
    .ob_tt_we0          (ob_tt_we0),
	.ob_tt_data0        (ob_tt_data0),
	.ob_tt_count0       (ob_tt_count0),

	.load_file         	(load_file),
	.read_file          (read_file),
	.cmd_byte_addr_wr0  (cmd_byte_addr_wr0),
	.cmd_byte_addr_wr2  (cmd_byte_addr_wr2),
	.cmd_byte_addr_wr3  (cmd_byte_addr_wr3),
	.cmd_byte_addr_wr4  (cmd_byte_addr_wr4),
	.cmd_byte_addr_wr5  (cmd_byte_addr_wr5),
	.cmd_byte_addr_wr6  (cmd_byte_addr_wr6),
	.cmd_byte_addr_wr7  (cmd_byte_addr_wr7),
	.woking_file        (working_file),
	
	.app_rdy            (app_rdy),
	.app_en             (app_en),
	.app_cmd            (app_cmd),
	.app_addr           (app_addr),	
	.calib_done         (init_calib_complete),
	.app_rd_data        (app_rd_data),
	.app_rd_data_end    (app_rd_data_end),
	.app_rd_data_valid  (app_rd_data_valid),
	.app_wdf_rdy        (app_wdf_rdy),
	.app_wdf_wren       (app_wdf_wren),
	.app_wdf_data       (app_wdf_data),
	.app_wdf_end        (app_wdf_end),
	.app_wdf_mask       (app_wdf_mask)
	);

Controller controller (
    .sdramclk( clk ),	
    .pg_command( command ),
	.tt_command(tt_command),
    .state( state ),
	.tt_state( tt_state ),
	
    .pipe_fifo_rst( pipe_fifo_rst ),
    .decoder_fifo_rst( decoder_fifo_rst ),
    .sdramctrl_reset( sdramctrl_reset ),
	.tt_reset( reset ),
	
	.addr_rd_rst ( addr_rd_rst ),
	.addr_wr_rst2( addr_wr_rst2 ),
	.addr_wr_rst3( addr_wr_rst3 ),
	.addr_wr_rst4( addr_wr_rst4 ),
	.addr_wr_rst5( addr_wr_rst5 ),
	.addr_wr_rst6( addr_wr_rst6 ),
	.addr_wr_rst7( addr_wr_rst7 ),
	
	.pg_writes_en(cmd_pagewrite),
	.work_en(cmd_work),
	.tt_reading(cmd_pageread),
	.tt_write(cmd_tt_write),
	.tt_fifo_write(write_en)
	);
	
//Block Throttle
always @(posedge okClk) begin
	// Check for enough space in input FIFO to pipe in another block
	if(pipe_in_wr_count <= 4096 ) begin
		pipe_in_ready <= 1'b1;
	end
	else begin
		pipe_in_ready <= 1'b0;
	end
end

always @(posedge okClk) begin
	// Check for enough space in input FIFO to pipe in another block
	if(pipe_in_wr_count0 <= 2048-128 ) begin
		pipe_in_ready0 <= 1'b1;
	end
	else begin
		pipe_in_ready0 <= 1'b0;
	end
end

//timetagger data out
reg          pipe_out1_ready;
wire         [12:0]pipe_out1_rd_count;

always @(posedge okClk) begin
	// Check for enough space in output FIFO to pipe out another block
	if(pipe_out1_rd_count >= 128) begin
		pipe_out1_ready <= 1'b1;
	end
	else begin
		pipe_out1_ready <= 1'b0;
	end
end

// Instantiate the okHost and connect endpoints.
wire [23:0] cnt_photo;
single_shot single_shot (
	.clk            (clk),
	.start_rst      (photo_rst1),
	.stop_singleshot(stop_singleshot),
	.cnt_start  (cnt_photo),
	.cnt0_weight({cnt0_weight3,cnt0_weight2,cnt0_weight1,cnt0_weight0}),
	.cnt1_weight({cnt1_weight3,cnt1_weight2,cnt1_weight1,cnt1_weight0}),
	.cnt2_weight({cnt2_weight3,cnt2_weight2,cnt2_weight1,cnt2_weight0}),
	.cnt3_weight({cnt3_weight3,cnt3_weight2,cnt3_weight1,cnt3_weight0}),
	.cnt4_weight({cnt4_weight3,cnt4_weight2,cnt4_weight1,cnt4_weight0}),
	.cnt5_weight({cnt5_weight3,cnt5_weight2,cnt5_weight1,cnt5_weight0}),
	.accuracy_max_min (accuracy_max_min),
	.accuracy_num_thre(accuracy_num_thre),
	.last_matrix_0_L0 (curr_matrix_0_L0),
	.last_matrix_1_L0 (curr_matrix_1_L0),
	.last_matrix_0_L1 (curr_matrix_0_L1),
	.last_matrix_1_L1 (curr_matrix_1_L1),
	.trigger1 (trigger_skip),
	.trigger2 (trigger_cycle)
);
wire trigger_skip;
wire trigger_cycle;

wire [1:0]leda;
wire [23:0]decoder_reset_value;
Decoder #(
	.N_CHANNELS( N_CHANNELS ),
	.CMD_WIDTH( COMMAND_WIDTH ) )
decoder (
	.clk( clk2x ),
	.trigger_max(trigger_skip),
	.trigger_min(trigger_cycle),
	.led( leda ),
	.reset( decoder_reset ),
	.cmd( {decoder_fifo_dout[111:96],decoder_fifo_dout[127:112]} ), // ToDo: change byte order
	.pattern(  {decoder_fifo_dout[79:64],decoder_fifo_dout[95:80],decoder_fifo_dout[47:32],decoder_fifo_dout[63:48],decoder_fifo_dout[15:0],decoder_fifo_dout[31:16]} ),
	.reset_value( decoder_reset_value),
	.rd_en( decoder_fifo_rd_en ),
	.dout( decoder_dout )
	);
//pg out
genvar chan;
generate
  for (chan=0; chan<N_CHANNELS-tt_channel; chan=chan+1)
    begin:serializer_block
      Serializer4 ser (
        .clk1x(clk2x),
        .clk2x(clk4x),
        .din(decoder_dout[(chan+1)*CHANNEL_WIDTH-1:chan*CHANNEL_WIDTH]),
        .dout(dout[chan])
        );
    end
endgenerate



reg stop1_1;
reg stop1_2;
reg stop1_3;
reg stop1_4;
reg stop1_5;
reg stop1_6;
reg stop1_7;
reg stop1_8;
reg stop1_9;
reg stop1_10;
reg stop1_11;
reg stop1_12;
reg stop1_13;
reg stop1_14;


reg start1_1;
reg start1_2;
reg start1_3;
reg start1_4;
reg start1_5;
reg start1_6;
reg start1_7;
reg start1_8;

always @(posedge clk4x) begin
	stop1_1 <= stop_in1;
	stop1_2 <= stop1_1;
	stop1_3 <= stop1_2;
	stop1_4 <= stop1_3;
	stop1_5 <= stop1_4;	
	stop1_6 <= stop1_5;
	stop1_7 <= stop1_6;
	stop1_8 <= stop1_7;
	stop1_9 <= stop1_8;
	stop1_10 <= stop1_9;
	stop1_11 <= stop1_10;
	stop1_12 <= stop1_11;
	stop1_13 <= stop1_12;
	stop1_14 <= stop1_13;	
	
end

always @(posedge clk4x) begin
	start1_1 <= start1;
	start1_2 <= start1_1;
	start1_3 <= start1_2;
	start1_4 <= start1_3;
	start1_5 <= start1_4;
	start1_6 <= start1_5;
	start1_7 <= start1_6;
	start1_8 <= start1_7;
	
end



BUFG start_clk11 (
	.I(start1_8),
	.O(rst_clk1)
);


BUFG stop_clk11 (
	.I(stop1_11),
	.O(start_clk1)
);

wire rst_clk1;
wire start_clk1;


reg [31:0]rst_start1;
reg [31:0]cnt_stop_1;
always @(posedge rst_clk1) begin
	rst_start1 <= cnt_stop1;
end

always @(posedge clk4x) begin
	cnt_stop_1 <= cnt_stop1 - rst_start1;//消除计数偏差
end
wire [31:0] cnt_stop1;
wire [31:0] cntstop2;
reg [31:0] cntstop1_buf;
reg [31:0] cntstop1;

always @(posedge clk4x) begin
	cntstop1_buf <= cntstop2;
	cntstop1     <= cntstop1_buf;
end

wire ready1;
wire [23:0] cnt_start1;
wire [23:0] cntstart1;
count1 count_inst1 (
	.clk500(clk4x),
	.count_rst(reset),
	.start_rst(start_rst1),
	.photo_rst1(photo_rst1),
	.start(start1),
	.cntstart(cntstart1),
	.cntstop(cntstop1),
	.cnt_stop(cnt_stop1),
	.cnt_start(cnt_start1),
	.cnt_photo(cnt_photo),
	.photo    (start_clk1),
	.sequence_count(sequence_rst1),
	.ready(ready1)
);


parameter size=32;
wire [size-1:0]cnt0_weight0;
wire [size-1:0]cnt0_weight1;
wire [size-1:0]cnt0_weight2;
wire [size-1:0]cnt0_weight3;

wire [size-1:0]cnt1_weight0;
wire [size-1:0]cnt1_weight1;
wire [size-1:0]cnt1_weight2;
wire [size-1:0]cnt1_weight3;

wire [size-1:0]cnt2_weight0;
wire [size-1:0]cnt2_weight1;
wire [size-1:0]cnt2_weight2;
wire [size-1:0]cnt2_weight3;

wire [size-1:0]cnt3_weight0;
wire [size-1:0]cnt3_weight1;
wire [size-1:0]cnt3_weight2;
wire [size-1:0]cnt3_weight3;

wire [size-1:0]cnt4_weight0;
wire [size-1:0]cnt4_weight1;
wire [size-1:0]cnt4_weight2;
wire [size-1:0]cnt4_weight3;

wire [size-1:0]cnt5_weight0;
wire [size-1:0]cnt5_weight1;
wire [size-1:0]cnt5_weight2;
wire [size-1:0]cnt5_weight3;

wire [size-1:0]accuracy_max_min;
wire [size-1:0]accuracy_num_thre;

wire [23:0]trigger;

wire[size-1:0] curr_matrix_0_L0;
wire[size-1:0] curr_matrix_1_L0; 
wire[size-1:0] curr_matrix_0_L1; 
wire[size-1:0] curr_matrix_1_L1; 

wire [4:0] command_in;
wire [31:0]sequence_rst1;
reg [4:0]command1;
reg [4:0]tt_command;

always @(posedge clk) begin
  command1 <= command_in;
  tt_command <= command1;
end


	

wire [3:0]tt_state;

wire ddr_read1;
wire ddr_write;
wire write_en;
reg  fifo_write1;
reg [127:0] fifo_in1;


always @(posedge clk4x) begin
	// ready <= 1'b0;
	if ( ready1 )begin
			if (write_en == 1 && pipe_in_ready0 == 1) begin
			// if (write_en == 1) begin
				fifo_write1 <= 1'b1;
			end else begin 
				fifo_write1 <= 1'b0;
			end
	end else begin
		fifo_write1 <= 1'b0;
	end
end


//delay short pulse
change1_1  change1_1
    (
    .start1(start1),
    .trigger1(trigger_start1_buf),
    .rst(reset),
	.clk(clk4x)
    );
change2_1  change2_1
    (
    .start2(stop_in1),
    .trigger2(trigger_stop1_buf),
    .rst(reset),
	.clk(clk4x)
);

//choose key
	
wire trigger_start1_buf;
wire trigger_stop1_buf;
wire trigger_start1;
wire trigger_stop1;

BUFG trigger11_BUFG (
	.I(trigger_start1_buf),
	.O(trigger_start1)
);
BUFG trigger12_BUFG (
	.I(trigger_stop1_buf),
	.O(trigger_stop1)
);

//tdc_36*70ps	 
carry4_1  tdc1
	 (
	 .trigger1(trigger_start1),
	 .trigger2(trigger_stop1),
	 .clk(clk4x),
	 .reset(reset),
	 .stop1(!trigger_start1),
	 .stop2(!trigger_stop1),
	 .latched_output10(latched_output1_10),
	 .latched_output20(latched_output1_20),
	 .latched_output11(latched_output1_11),
	 .latched_output21(latched_output1_21),
	 .latched_output12(latched_output1_12),
	 .latched_output22(latched_output1_22),
	 .latched_output13(latched_output1_13),
	 .latched_output23(latched_output1_23)

	 );
	 
wire [39:0]latched_output1_10;
wire [39:0]latched_output1_20;
wire [39:0]latched_output1_11;
wire [39:0]latched_output1_21;
wire [39:0]latched_output1_12;
wire [39:0]latched_output1_22;
wire [39:0]latched_output1_13;
wire [39:0]latched_output1_23;



wire [5:0]out1_10;
wire [5:0]out1_20;
wire [5:0]out1_30;
wire [5:0]out1_11;
wire [5:0]out1_21;
wire [5:0]out1_31;
wire [5:0]out1_12;
wire [5:0]out1_22;
wire [5:0]out1_32;
wire [5:0]out1_13;
wire [5:0]out1_23;
wire [5:0]out1_33;

//half_decoder period 5
decoder_0 decoder0
	(
	.data_in1(latched_output1_10),
	.data_in2(latched_output1_20),
	.out1(out1_10),
	.out2(out1_20),
	.clk(clk4x)
	);
decoder_1 decoder1
	(
	.data_in1(latched_output1_11),
	.data_in2(latched_output1_21),
	.out1(out1_11),
	.out2(out1_21),
	.clk(clk4x)
	);
decoder_2 decoder2
	(
	.data_in1(latched_output1_12),
	.data_in2(latched_output1_22),
	.out1(out1_12),
	.out2(out1_22),
	.clk(clk4x)
	);
decoder_3 decoder3
	(
	.data_in1(latched_output1_13),
	.data_in2(latched_output1_23),
	.out1(out1_13),
	.out2(out1_23),
	.clk(clk4x)
	);
//tt sample data 
always @(posedge clk4x) begin
	fifo_in1 <= {out1_11,out1_21,out1_10,out1_20,out1_12,out1_22,out1_23,out1_13,cnt_start1,24'b0,cnt_stop_1};
end

fifo_w32_1024_r256_128 pipe_fifo (
	.rst(pipe_fifo_rst),
	.wr_clk(okClk),
	.rd_clk(clk),
	.din(pi0_ep_dataout), // Bus [31 : 0]
	.wr_en(pi0_ep_write),
	.rd_en(pipe_in_read),
	.dout(pipe_in_data), // Bus [256 : 0]
	.full(pipe_in_full),
	.empty(pipe_fifo_empty),
	.valid(pipe_in_valid),
	.rd_data_count(pipe_in_rd_count), // Bus [9 : 0]
	.wr_data_count(pipe_in_wr_count)// Bus [12 : 0]
); // Bus [9 : 0]

fifo_w256_128_r32_1024 decoder_fifo (
	.rst(decoder_fifo_rst),
	.wr_clk(clk),
	.rd_clk(clk2x),
	.din(pipe_out_data), // Bus [256 : 0]
	.wr_en(pipe_out_write),
	.rd_en(decoder_fifo_rd_en),
	.dout(decoder_fifo_dout), // Bus [127 : 0]
	.full(decoder_fifo_full),
	.empty(pipe_out_empty),
	.valid(),
	.rd_data_count(pipe_out_rd_count), // Bus [10 : 0]
	.wr_data_count(pipe_out_wr_count),// Bus [9 : 0]
	.underflow(decoder_fifo_underflow)
); // Bus [6 : 0]

//tt fifo
wire [10:0]pipe_in_wr_count0;
wire [10:0]pipe_in_wr_count1;
fifo0_w128_1024_r512_512 stop_fifo0 (
	.rst(reset),
	.wr_clk(start_clk1),
	.rd_clk(clk),
	.din(fifo_in1), // Bus [63 : 0]
	.wr_en(fifo_write1),
	.rd_en(ib_tt_re0),
	.dout(ib_tt_data0), // Bus [256 : 0]
	.valid(ib_tt_valid0),
	.rd_data_count(ib_tt_count0), // Bus [9 : 0]
	.wr_data_count(pipe_in_wr_count0)); // Bus [10 : 0]

fifo0_w256_512_r32_4096 okPipeOut_fifo0 (
	.rst(reset),
	.wr_clk(clk),
	.rd_clk(okClk),
	.din(ob_tt_data0), // Bus [256 : 0]
	.wr_en(ob_tt_we0),
	.rd_en(po0_ep_read1),
	.dout(po0_ep_datain), // Bus [31 : 0]
	.rd_data_count(pipe_out1_rd_count), // Bus [12 : 0]
	.wr_data_count(ob_tt_count0)); // Bus [9 : 0]
//okhost 实例化
okHost okHI(
	.okUH(okUH),
	.okHU(okHU),
	.okUHU(okUHU),
	.okAA(okAA),
	.okClk(okClk),
	.okHE(okHE),
	.okEH(okEH)
);	
wire [65*28-1:0]  okEHx;
okWireOR # (.N(28)) wireOR (okEH, okEHx);
okBTPipeIn     pi0  (
	.okHE(okHE), 
	.okEH(okEHx[ 0*65 +: 65 ]), 
	.ep_addr(8'h80), 
	.ep_write(pi0_ep_write), 
	.ep_blockstrobe(), 
	.ep_dataout(pi0_ep_dataout), 
	.ep_ready(pipe_in_ready)
);

okTriggerIn pg_command (.okHE(okHE),
                      .ep_addr(8'h40), .ep_clk(clk), .ep_trigger(command));
okWireIn wire_in_control (
	.okHE(okHE),
	.ep_addr(8'h00),
	.ep_dataout( {use_trigger,reset_request} )
);
okWireIn  wire_in_rst_val_low (
	.okHE( okHE ),
	.ep_addr( 8'h01 ),
	.ep_dataout( decoder_reset_value )
);

reg  [2:0]load_file;
reg  [2:0]read_file;
wire [2:0]load_file_buf;
wire [2:0]read_file_buf;


always @(posedge clk ) begin
	read_file<=read_file_buf;
	load_file<=load_file_buf;
end

okWireIn  read (
	.okHE(okHE),
	.ep_addr(8'h03),
	.ep_dataout( {read_file_buf,load_file_buf} )
);

okWireIn       accu_max_min (.okHE(okHE), .ep_addr(8'h04), .ep_dataout(accuracy_max_min));
okWireIn       accu_num_the (.okHE(okHE), .ep_addr(8'h02), .ep_dataout(accuracy_num_thre));

okWireIn       tt_com       (.okHE(okHE), .ep_addr(8'h05), .ep_dataout(command_in));
okWireIn       ttstart1     (.okHE(okHE), .ep_addr(8'h06), .ep_dataout(cntstart1));
okWireIn       ttstop1      (.okHE(okHE), .ep_addr(8'h07), .ep_dataout(cntstop2));

okWireIn       cnt0_wht0     (.okHE(okHE), .ep_addr(8'h08), .ep_dataout(cnt0_weight0));
okWireIn       cnt0_wht1     (.okHE(okHE), .ep_addr(8'h09), .ep_dataout(cnt0_weight1));
okWireIn       cnt0_wht2     (.okHE(okHE), .ep_addr(8'h0a), .ep_dataout(cnt0_weight2));
okWireIn       cnt0_wht3     (.okHE(okHE), .ep_addr(8'h0b), .ep_dataout(cnt0_weight3));

okWireIn       cnt1_wht0     (.okHE(okHE), .ep_addr(8'h0c), .ep_dataout(cnt1_weight0));
okWireIn       cnt1_wht1     (.okHE(okHE), .ep_addr(8'h0d), .ep_dataout(cnt1_weight1));
okWireIn       cnt1_wht2     (.okHE(okHE), .ep_addr(8'h0e), .ep_dataout(cnt1_weight2));
okWireIn       cnt1_wht3     (.okHE(okHE), .ep_addr(8'h0f), .ep_dataout(cnt1_weight3));

okWireIn       cnt2_wht0     (.okHE(okHE), .ep_addr(8'h10), .ep_dataout(cnt2_weight0));
okWireIn       cnt2_wht1     (.okHE(okHE), .ep_addr(8'h11), .ep_dataout(cnt2_weight1));
okWireIn       cnt2_wht2     (.okHE(okHE), .ep_addr(8'h12), .ep_dataout(cnt2_weight2));
okWireIn       cnt2_wht3     (.okHE(okHE), .ep_addr(8'h13), .ep_dataout(cnt2_weight3));

okWireIn       cnt3_wht0     (.okHE(okHE), .ep_addr(8'h14), .ep_dataout(cnt3_weight0));
okWireIn       cnt3_wht1     (.okHE(okHE), .ep_addr(8'h15), .ep_dataout(cnt3_weight1));
okWireIn       cnt3_wht2     (.okHE(okHE), .ep_addr(8'h16), .ep_dataout(cnt3_weight2));
okWireIn       cnt3_wht3     (.okHE(okHE), .ep_addr(8'h17), .ep_dataout(cnt3_weight3));

okWireIn       cnt4_wht0     (.okHE(okHE), .ep_addr(8'h18), .ep_dataout(cnt4_weight0));
okWireIn       cnt4_wht1     (.okHE(okHE), .ep_addr(8'h19), .ep_dataout(cnt4_weight1));
okWireIn       cnt4_wht2     (.okHE(okHE), .ep_addr(8'h1a), .ep_dataout(cnt4_weight2));
okWireIn       cnt4_wht3     (.okHE(okHE), .ep_addr(8'h1b), .ep_dataout(cnt4_weight3));

okWireIn       cnt5_wht0     (.okHE(okHE), .ep_addr(8'h1c), .ep_dataout(cnt5_weight0));
okWireIn       cnt5_wht1     (.okHE(okHE), .ep_addr(8'h1d), .ep_dataout(cnt5_weight1));
okWireIn       cnt5_wht2     (.okHE(okHE), .ep_addr(8'h1e), .ep_dataout(cnt5_weight2));
okWireIn       cnt5_wht3     (.okHE(okHE), .ep_addr(8'h1f), .ep_dataout(cnt5_weight3));


okWireOut   wire_out_info    (.okHE( okHE ),.okEH(okEHx[ 1*65 +: 65 ]),.ep_addr( 8'h20 ),.ep_datain( {CHANNEL_WIDTH, N_CHANNELS} ));
okWireOut   wire_out_pg_state(.okHE( okHE ),.okEH(okEHx[ 2*65 +: 65 ]),.ep_addr( 8'h21 ),.ep_datain( state ));
okWireOut   wire_out_addr0 (.okHE( okHE ),.okEH(okEHx[ 3*65 +: 65 ]),.ep_addr( 8'h22 ),.ep_datain( cmd_byte_addr_wr0));
okWireOut   wire_out_addr1 (.okHE( okHE ),.okEH(okEHx[ 4*65 +: 65 ]),.ep_addr( 8'h23 ),.ep_datain( cmd_byte_addr_wr1));
okWireOut   wire_out_addr2 (.okHE( okHE ),.okEH(okEHx[ 5*65 +: 65 ]),.ep_addr( 8'h24 ),.ep_datain( cmd_byte_addr_wr2));
okWireOut   wire_out_addr3 (.okHE( okHE ),.okEH(okEHx[ 6*65 +: 65 ]),.ep_addr( 8'h25 ),.ep_datain( cmd_byte_addr_wr3));
okWireOut   wire_out_addr4 (.okHE( okHE ),.okEH(okEHx[ 7*65 +: 65 ]),.ep_addr( 8'h26 ),.ep_datain( cmd_byte_addr_wr4));
okWireOut   wire_out_addr5 (.okHE( okHE ),.okEH(okEHx[ 8*65 +: 65 ]),.ep_addr( 8'h27 ),.ep_datain( cmd_byte_addr_wr5));
okWireOut   wire_out_addr6 (.okHE( okHE ),.okEH(okEHx[ 9*65 +: 65 ]),.ep_addr( 8'h28 ),.ep_datain( cmd_byte_addr_wr6));
okWireOut   wire_out_addr7 (.okHE( okHE ),.okEH(okEHx[ 10*65+: 65 ]),.ep_addr( 8'h29 ),.ep_datain( cmd_byte_addr_wr7));
//tt
okWireOut   wire_out_tt_state (.okHE( okHE ),.okEH(okEHx[ 11*65 +: 65 ]),.ep_addr( 8'h2a ),.ep_datain( tt_state));
okWireOut   wire_out_sequence2 (.okHE( okHE ),.okEH(okEHx[ 12*65 +: 65 ]),.ep_addr( 8'h2b ),.ep_datain( sequence_rst1));

okWireOut   out1_10_calibration(.okHE( okHE ),.okEH(okEHx[ 13*65 +: 65 ]),.ep_addr( 8'h2c ),.ep_datain(out1_10));
okWireOut   out1_20_calibration(.okHE( okHE ),.okEH(okEHx[ 14*65 +: 65 ]),.ep_addr( 8'h2d ),.ep_datain(out1_20));
okWireOut   out1_11_calibration (.okHE( okHE ),.okEH(okEHx[ 16*65 +: 65 ]),.ep_addr( 8'h2f ),.ep_datain(out1_11));
okWireOut   out1_21_calibration (.okHE( okHE ),.okEH(okEHx[ 17*65 +: 65 ]),.ep_addr( 8'h30 ),.ep_datain(out1_21));
okWireOut   out1_12_calibration (.okHE( okHE ),.okEH(okEHx[ 19*65 +: 65 ]),.ep_addr( 8'h32 ),.ep_datain(out1_12));
okWireOut   out1_22_calibration (.okHE( okHE ),.okEH(okEHx[ 20*65 +: 65 ]),.ep_addr( 8'h33 ),.ep_datain(out1_22));
okWireOut   out1_13_calibration (.okHE( okHE ),.okEH(okEHx[ 22*65 +: 65 ]),.ep_addr( 8'h35 ),.ep_datain(out1_13));
okWireOut   out1_23_calibration (.okHE( okHE ),.okEH(okEHx[ 23*65 +: 65 ]),.ep_addr( 8'h36 ),.ep_datain(out1_23));





//trigger  to  pc
okTriggerOut  trigger_out (
	.okHE( okHE ),
	.okEH(okEHx[ 25*65 +: 65 ]),
	.ep_addr( 8'h60 ),
	.ep_clk( clk2x ),
	.ep_trigger( decoder_fifo_underflow )
);

okBTPipeOut    po0  (
	.okHE(okHE), 
	.okEH(okEHx[ 26*65 +: 65 ]), 
	.ep_addr(8'ha1),
	.ep_read(po0_ep_read1),   
	.ep_blockstrobe(), 
	.ep_datain(po0_ep_datain),   
	.ep_ready(pipe_out1_ready));

endmodule
