`timescale 1 ns / 1 ps
module UART_rx(clk, rst_n, RX, clr_rdy, rx_data, rdy);
	input clk, rst_n, RX, clr_rdy;
	output [7:0] rx_data;
	output reg rdy;

	logic [11:0] baud_cnt_begin, baud_cnt;	// 12 bits needed for 19200baud with 50 MHz clock
	logic start, shift, receiving, RX1, RX2, set_rdy;
	logic [8:0] rx_shift_reg;		// shift register
	logic [3:0] bit_cnt;			// 4 bits needed to count 10 shifts
	// state variables
	typedef enum logic {IDLE, RECEIVE} state_t;
	state_t state, nxt_state;

	// double flop RX for meta-stability 
	always_ff @(posedge clk) begin
		RX1 <= RX;
		RX2 <= RX1;	end

	// set baud counter to 1302 when bit read begins, 2604 after	
	// ensures bit is sampled in the middle of transmission	
	assign baud_cnt_begin = start ? 12'h516 : 12'hA2C; 
	
	// baud down counter. Decides when to shift
	always_ff @(posedge clk)
		if (start|shift)		// reset counter on initialization or after shift
			baud_cnt <= baud_cnt_begin;
		else if (receiving)
			baud_cnt <= baud_cnt-1;
	
	// shift when counter == 0
	assign shift = baud_cnt==0 ? 1 : 0;
	
	// shift counter. Determines when byte transfer is complete
	always_ff @(posedge clk)
		if (start)		// reset counter at the beginning of each receive
			bit_cnt <= 4'h0;
		else if (shift)
			bit_cnt <= bit_cnt+1;
			
	// Update bit receive 9 bit shift register
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n)
			rx_shift_reg <= 9'h0;
		else if (shift)
			rx_shift_reg <= {RX2, rx_shift_reg[8:1]};	// append data to MSB of reg
	
	assign rx_data = rx_shift_reg[7:0];
	
	////////////// state machine //////////////////////////
	// state flip flop
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;
	// state transition logic
	always_comb
	begin
		nxt_state = state;
		start = 0;
		set_rdy = 0;
		receiving = 0;
		case(state)
		IDLE:	if (!RX2) begin		// when RX goes low, change state to RECEIVE (UART)
					start = 1;
					nxt_state = RECEIVE; end
		RECEIVE:begin				// stay in RECEIVE until 10 shifts are done
				start = 0;
				receiving = 1;
				if (bit_cnt == 4'hA) begin
					set_rdy = 1;
					nxt_state = IDLE; end
				end

		default: nxt_state = IDLE;
		endcase
	end
	
	// flip flop for rx_done 
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			rdy <= 0;
		else if (start)
			rdy <= 0;
		else if (clr_rdy)
			rdy <= 0;
		else if (set_rdy)
			rdy <= 1;
endmodule
