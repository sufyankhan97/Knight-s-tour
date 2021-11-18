module cmd_proc(clk,rst_n,cmd,cmd_rdy,clr_cmd_rdy,send_resp,strt_cal,
                cal_done,heading,heading_rdy,lftIR,cntrIR,rghtIR,error,
				frwrd,moving,tour_go,fanfare_go);
				
	//sufyan
	parameter FAST_SIM = 1;		// speeds up incrementing of frwrd register for faster simulation
				
	input clk,rst_n;					// 50MHz clock and asynch active low reset
	input [15:0] cmd;					// command from BLE
	input cmd_rdy;					// command ready
	output logic clr_cmd_rdy;			// mark command as consumed
	output logic send_resp;			// command finished, send_response via UART_wrapper/BT
	output logic strt_cal;			// initiate calibration of gyro
	input cal_done;					// calibration of gyro done
	input signed [11:0] heading;		// heading from gyro
	input heading_rdy;				// pulses high 1 clk for valid heading reading
	input lftIR;						// nudge error +
	input cntrIR;						// center IR reading (have I passed a line)
	input rghtIR;						// nudge error -
	output reg signed [11:0] error;	// error to PID (heading - desired_heading)
	output reg [9:0] frwrd;			// forward speed register
	output logic moving;				// asserted when moving (allows yaw integration)
	output logic tour_go;				// pulse to initiate TourCmd block
	output logic fanfare_go;			// kick off the "Charge!" fanfare on piezo

	reg move_cmd;
	wire move_done;
	reg [2:0]op_ff_move_counter;
	reg [2:0]op_ff_move_count;
	wire posedge_cntrIR;
	reg posedge_cntrIR_temp;
	
	// frwrd variables
	logic signed [9:0]frwrd_inc;		// magnitude of how fast the bot should move
	logic frwrd_zero, max_spd;			// needed to limit bounds of frwrd

	logic en, clr, inc_frwrd, dec_frwrd;
	// cmd_proc variables
	logic [3:0] opcode;

	// state variables
	typedef enum logic [2:0]{IDLE, CAL, STR_MOVE, MOVE, STP_MOVE, TOUR} state_t;
	state_t state, nxt_state;
	
	logic move_cmd;

	//////////////////////////////////////////////////////////////////
	//////////////////////// data path ///////////////////////////////
	//////////////////////////////////////////////////////////////////
	
	///////////////posedge detector////////////////
	always @(posedge clk)								//rising edge detector
	posedge_cntrIR_temp <= cntrIR;


	assign posedge_cntrIR = cntrIR & ~posedge_cntrIR_temp;
	///////////////////////////////////////////////

	///////////counter/////////////////////////////\
	reg op_ff_move_cmd;

	always @(posedge clk)
	op_ff_move_cmd = move_cmd;				//flop move_cmd since it is a fsm output and can glitch

	always @(posedge clk, cntrIR)
	begin
	if(op_ff_move_cmd)
		op_ff_move_counter <= 1'b0;			
	else if(posedge_cntrIR)
		op_ff_move_counter <= op_ff_move_counter + 1'b1;
	end
	////////////////////////////////////////////

	///////////flop for cmd////////////////////
	always @(posedge clk)
	begin
	if(op_ff_move_cmd)
	op_ff_move_count <= cmd[2:0] << 1 ;			//shift by one place since we cross center line 2 times for every square
	end
	//////////////////////////////////////////

	assign move_done = (op_ff_move_count === op_ff_move_counter);	



	///////////////////////////////////////////////////////PID//////////////////////////////////////////////////////

	/////////////desired heading/////////////////////////////////////
	wire [11:0]adjusted_cmd;
	reg [11:0]op_ff_desired_heading;

	adjusted_cmd = (|cmd[11:4] == 0) ? 12'h0	:	{cmd[11:4] , 4'hF};

	always @(posedge clk)
	if(move_cmd)
	op_ff_desired_heading <= adjusted_cmd;
	////////////////////////////////////////////////////////////////

	/////////////////////leftIR and rghtIR ///////////////////////
	wire [11:0]err_nudge; 

	err_nudge	=	(leftIR)	?	12'h05F	:	(rghtIR)	?	12'hFA1	:	12'h0;

	///////////////////final summation////////////////////////////
	wire [11:0]error;

	error = heading - desired_heading	+ err_nudge;
	
	////////////////// frwrd reg implementation //////////////////

	// set magnitude of increment based on FAST_SIM
	generate if (FAST_SIM)
		assign frwrd_inc = inc_frwrd ? 10'h020 : 10'h3C0;	// +ve when inc_frwrd is set, -ve otherwise
	else
		assign frwrd_inc = inc_frwrd ? 10'h004 : 10'h3F8;
	endgenerate	
	  
	// assign frwrd_inc = FAST_SIM ? 8'h20 : 8'h04;
	// assign bkwrd_inc = {frwrd_inc, 1'b0};			// make bkwrd_inc twice of frwrd_inc

	// frwrd counter 
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			frwrd <= 10'h000;				// reset reg
		else if (clr)
			frwrd <= 10'h000;				// counter reset
		else if (en)
			frwrd <= frwrd + frwrd_inc;		// increment counter

	// logic for enable 
	assign frwrd_zero = !(|frwrd);
	assign max_spd = &frwrd[9:8];

	assign en = heading_rdy ? (frwrd_zero && inc_frwrd) || (max_spd && dec_frwrd) : 1'b0;

	//// command processing ////
	assign opcode = cmd[15:12];
	
	/////////////////////////////////////////////////////////////////////
	//////////////////////// state machine //////////////////////////////
	/////////////////////////////////////////////////////////////////////

	// state reg
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;
				

	// state transitions
	always_comb begin
		strt_cal = 0;			// start calibration of gyro signal
		clr_cmd_rdy = 0;		// clear cmd rdy signal
		send_resp = 0;
		move_cmd = 0;
		inc_frwrd = 0;
		dec_frwrd = 0;
		
		nxt_state = state;
		case (state)
		IDLE:	begin 
				if (cmd_rdy)
					clr_cmd_rdy = 1'b1;
				if (opcode == 4'h0)
					nxt_state = CAL;
				else if (opcode == 4'h2)
					nxt_state = MOVE;
				else if (opcode == 4'h3)
					nxt_state = MOVE;
				else if (opcode == 4'h4)
					nxt_state = TOUR;
				end
				
		CAL:	begin 
				strt_cal = 1'b1;
				if (cal_done)	begin
					send_resp = 1'b1;
					nxt_state = IDLE;
				end
		
		STR_MOVE:	begin	
					move_cmd = 1'b1;
					if ((error < 12'h030) && (error > 12'FD0))
					nxt_state = MOVE;	end
					
		MOVE:	begin
				move_cmd = 1'b1;
				inc_frwrd = 1'b1;
				if (move_done)
					nxt_state = STP_MOVE;
				end
				
		STP_MOVE: 	begin
					move_cmd = 1'b1;
					dec_frwrd = 1'b1;
					if (!(|frwrd)) begin
						send_resp = 1'b1;
						nxt_state = IDLE;	end
					end
		endcase
	end
	

endmodule
  