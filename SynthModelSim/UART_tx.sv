`timescale 1 ns / 1 ps
module UART_tx(clk, rst_n, trmt, tx_data, TX, tx_done);
	input clk, rst_n, trmt;
	input [7:0] tx_data;
	output TX;
	output reg tx_done;
	
	logic shift, set_done, init, transmitting;
	logic [11:0] baud_cnt;	// 12 bits needed for 19200baud with 50 MHz clock
	logic [3:0] bit_cnt;	// 4 bits needed to count 10 shifts
	logic [8:0] tx_shift_reg;	// shift register
	// state variables
	typedef enum logic {IDLE, SHIFT} state_t;
	state_t state, nxt_state;
	
	// baud counter. Decides when to shift
	always_ff @(posedge clk)
		if (init|shift)		// reset counter on initialization or after shift
			baud_cnt <= 12'h000;
		else if (transmitting)
			baud_cnt <= baud_cnt+1;
	
	// shift when counter == 2604
	assign shift = baud_cnt==12'hA2C ? 1 : 0;
	
	// shift counter. Decides when to stop transmission based on number of shifts
	always_ff @(posedge clk)
		if (init)		// reset counter after byte is transfered
			bit_cnt <= 4'h0;
		else if (shift)
			bit_cnt <= bit_cnt+1;
	
	// Update bit send register
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			tx_shift_reg <= 9'h1ff;		// reset bit to all highs as high is idle in UART
		else if (init)
			tx_shift_reg <= {tx_data, 1'b0};	// add 0 to lowermost bit as start bit
		else if (shift)
			tx_shift_reg <= {1'b1, tx_shift_reg[8:1]};	// right shift bit by one at each shift. Append 1 at the end for stop bit
	
	assign TX = tx_shift_reg[0];

	////////////// state flow //////////////////////////
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
		init = 0;
		set_done = 0;
		transmitting = 0;
		case(state)
		IDLE:	if (trmt) begin		// change state to SHIFT when trmt is enabled
					init = 1;
					nxt_state = SHIFT; end
		SHIFT:	begin				// go back to IDLE when 10 shifts are done
				transmitting = 1;
				if (bit_cnt == 4'hA) begin
					set_done = 1;
					nxt_state = IDLE; end
				end
		default: nxt_state = IDLE;
		endcase
	end

	// flip flop for tx_done 
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			tx_done <= 0;
		else if (init)
			tx_done <= 0;
		else if (set_done)
			tx_done <= 1;
	
endmodule