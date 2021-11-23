module UART_wrapper(cmd_rdy, cmd, tx_done, TX, clk, rst_n, clr_cmd_rdy, trmt,
					resp, RX);
	
	output TX, tx_done;
	output reg cmd_rdy;
	output [15:0] cmd;
	input  [7:0] resp;
	input clk, rst_n, clr_cmd_rdy, RX, trmt;
	
	logic rx_rdy, clr_rx_rdy, rd_upper;
	logic [7:0] rx_data, cmd_upper;
	
	// state variables
	typedef enum logic {IDLE, READY} state_t;
	state_t state, nxt_state;
	
	///////////// instantiate UART module //////////////////
	UART iNST1(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .rx_rdy(rx_rdy), 
				.clr_rx_rdy(clr_rx_rdy), .rx_data(rx_data), .trmt(trmt), .tx_data(resp),
				.tx_done(tx_done));
	
	//////////// define datapath //////////////////////
	always_ff @(posedge clk) 
		if (rd_upper)
			cmd_upper <= rx_data;
	
	assign cmd = {cmd_upper, rx_data}; // concatenate upper and lower bytes
	
	////////////// define controlpath ////////////////
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;
	
	always_comb begin
		// default values for SM outputs
		cmd_rdy = 0;
		clr_rx_rdy = 0;
		rd_upper = 0;
		nxt_state = state;
		case (state) 
		IDLE:	if (rx_rdy) begin	
					rd_upper = 1;	// when byte is ready first time, store it as upper byte of cmd
					clr_rx_rdy = 1;	// clear ready to get next byte
					nxt_state = READY; 	
				end
		READY:	if (clr_cmd_rdy) begin
					clr_rx_rdy = 1;	// when clr_cmd_rdy ready is received, higher order SM is done
									// using cmd. So now it can be discarded and next value is requested
					nxt_state = IDLE;
				end
				else if (rx_rdy)	// when 2nd rx_rdy is received, cmd is ready for consumption
					cmd_rdy = 1;
		endcase	
	end 
	
endmodule
