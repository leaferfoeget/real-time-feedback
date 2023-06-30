`default_nettype none
`timescale 1ns / 1ps

/*
Provides detection of a rising edge in an input signal.

If 'reset' is high, 'state' is set to low (waiting).
If 'reset' is low and a rising edge is detected in 'signal',
'state' is set to high (triggered) and kept high
until 'reset' is set high again
*/

module EdgeDetector(clk, reset, signal, state);

input wire	clk;
input wire	reset;
input wire	signal;
output reg	state;

reg			prev;

parameter   WAITING = 1'd0;
parameter TRIGGERED = 1'd1;

always @(posedge clk) begin

	prev <= signal;

	if ( reset ) begin
		state <= WAITING;
	end else begin
		case ( state )
			WAITING: begin
				if ( prev == 0 && signal == 1 ) begin // rising edge
					state <= TRIGGERED;
				end else begin
					state <= WAITING;
				end
			end
			TRIGGERED: begin
				state <= TRIGGERED;
			end
		endcase
	end
end

endmodule

