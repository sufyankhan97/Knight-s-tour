module RemoteComm(clk, rst_n, RX, TX, cmd, send_cmd, clr_rx_rdy, cmd_sent, resp_rdy, resp);

input clk, rst_n;		// clock and active low reset
input RX;				// serial data input
input send_cmd;			// indicates to tranmit 16-bit command (cmd)
input [15:0] cmd;		// 16-bit command
input clr_rx_rdy;		// input to indicate rx_data has been received

output TX;				// serial data output
output reg cmd_sent;		// indicates transmission of command complete
output resp_rdy;		// indicates 8-bit response has been received
output [7:0] resp;		// 8-bit response from DUT

wire [7:0] tx_data;		// 8-bit data to send to UART
wire tx_done;			// indicates 8-bit was sent over UART

///////////////////////////////////////////////
// Registers needed...state machine control //
/////////////////////////////////////////////
logic sel_high, trmt, set_cmd_snt;
reg [7:0] low_byte;

///////////////////////////////
// state definitions for SM //
/////////////////////////////
typedef enum reg [1:0] {IDLE, FIRST, SECOND} state_t;
state_t state, nxt_state;


///////////////////////////////////////////////
// Instantiate basic 8-bit UART transceiver //
/////////////////////////////////////////////
UART iUART(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .tx_data(tx_data), .trmt(trmt),
           .tx_done(tx_done), .rx_data(resp), .rx_rdy(resp_rdy), .clr_rx_rdy(clr_rx_rdy));
		   
////////////// byte transfer select ///////////
always_ff @(posedge clk)
	if (send_cmd)
		low_byte <= cmd [7:0];

assign tx_data = sel_high ? cmd[15:8] : low_byte;

//////////// state machine ////////////////////
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;

always_comb begin
	nxt_state = state;
	sel_high = 1;
	trmt = 0;
	set_cmd_snt = 0;
	case (state)
		IDLE:	if (send_cmd) begin			// go to next state when send_cmd is set
					trmt = 1;
					nxt_state = FIRST; end
		FIRST:	if (tx_done) begin			// check if transmission is done
					sel_high = 0;
					trmt = 1;
					nxt_state = SECOND; end	
		SECOND: if (tx_done) begin			// check if 2nd byte transmission is done
					set_cmd_snt = 1;
					nxt_state = IDLE; end
		default: nxt_state = IDLE;
	endcase
end

// register for cmd_sent
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		cmd_sent <= 0;
	else if (set_cmd_snt)
		cmd_sent <= 1;
	else if (send_cmd)
		cmd_sent <= 0;
	
endmodule	

