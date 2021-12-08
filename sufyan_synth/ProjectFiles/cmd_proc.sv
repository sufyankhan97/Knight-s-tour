module cmd_proc(clk,rst_n,cmd,cmd_rdy,clr_cmd_rdy,send_resp,strt_cal,
                cal_done,heading,heading_rdy,lftIR,cntrIR,rghtIR,error,
				frwrd,moving,tour_go,fanfare_go);
				
	parameter FAST_SIM = 1;				// speeds up incrementing of frwrd register for faster simulation
				
	input clk,rst_n;					// 50MHz clock and asynch active low reset
	input [15:0] cmd;					// command from BLE
	input cmd_rdy;						// command ready
	output logic clr_cmd_rdy;			// mark command as consumed
	output logic send_resp;				// command finished, send_response via UART_wrapper/BT
	output logic strt_cal;				// initiate calibration of gyro
	input cal_done;						// calibration of gyro done
	input signed [11:0] heading;		// heading from gyro
	input heading_rdy;					// pulses high 1 clk for valid heading reading
	input lftIR;						// nudge error +
	input cntrIR;						// center IR reading (have I passed a line)
	input rghtIR;						// nudge error -
	output reg signed [11:0] error;		// error to PID (heading - desired_heading)
	output reg [9:0] frwrd;				// forward speed register
	output logic moving;				// asserted when moving (allows yaw integration)
	output logic tour_go;				// pulse to initiate TourCmd block
	output logic fanfare_go;			// kick off the "Charge!" fanfare on piezo

	logic move_cmd;
	logic move_cmd_ff;
	wire move_done;
	reg [3:0] move_counter;
	reg [3:0] move_count_cmd;
	wire posedge_cntrIR;
	reg posedge_cntrIR_temp;
	
	// frwrd variables
	logic signed [9:0]frwrd_inc;		// magnitude of how fast the bot should move
	logic frwrd_zero, max_spd;			// needed to limit bounds of frwrd

	logic en, clr_frwd, inc_frwrd, dec_frwrd;
	// cmd_proc variables
	logic [3:0] opcode;

	// state variables
	typedef enum logic [2:0]{IDLE, CAL, STR_MOVE, MOVE, STP_MOVE, TOUR} state_t;
	state_t state, nxt_state;
	

	logic tour_go_comb;	// tour_go in state machine. need to flop to prevent glitch
	
	//////////////////////////////////////////////////////////////////
	//////////////////////// data path ///////////////////////////////
	//////////////////////////////////////////////////////////////////
	
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
		else if (clr_frwd)
			frwrd <= 10'h000;				// counter reset
		else if (en)
			frwrd <= frwrd + frwrd_inc;		// increment counter

	// logic for enable 
	assign frwrd_zero = !(|frwrd);			// dec_frwrd used to set enable when frwd is not 0
	assign max_spd = &frwrd[9:8]; 	

	assign moving = frwrd_zero ? 1'b0 : 1'b1;	// set moving to 1 when bot is in motion
	
	assign en = heading_rdy ? !((frwrd_zero && dec_frwrd) || (max_spd && inc_frwrd)) : 1'b0;
	
	////////////////////posedge detector for IR//////////////////////
	always @(posedge clk)		
		posedge_cntrIR_temp <= cntrIR;

	assign posedge_cntrIR = cntrIR & ~posedge_cntrIR_temp;	// 1 if rising edge for cntrIR

	////////////////////counter for sqaures/////////////////////////////
	always @(posedge clk)
		move_cmd_ff = move_cmd;				//flop move_cmd since it is a fsm output and can glitch

	always @(posedge clk) begin
		if(move_cmd_ff)
			move_counter <= 1'b0;			
		else if(posedge_cntrIR)
			move_counter <= move_counter + 1'b1;	// increment counter at posedge of IR
	end

	//flop for cmd
	always @(posedge clk) 	begin
		if(move_cmd_ff)
			move_count_cmd <= {cmd[2:0], 1'b0} ;	//multiply by 2 since we cross center line 2 times for every square
	end
	//////////////////////////////////////////

	assign move_done = (move_counter == move_count_cmd) && (move_count_cmd != 4'h0);	

	/////////////////////////////////////PID Interface/////////////////////////////////////////

	//desired heading
	reg [11:0] desired_heading;

	always @(posedge clk)
		if(move_cmd_ff)
			desired_heading <= !(|cmd[11:4]) ? 12'h0	:	{cmd[11:4] , 4'hF};	// set heading from cmd 

	//leftIR and rghtI
	logic [11:0]err_nudge; 		// nudge factor to align bot when it hits the end rails

	generate if (FAST_SIM)
		assign err_nudge =	lftIR ? 12'h1FF : rghtIR ?	12'hE00 : 12'h000;
	else 
		assign err_nudge =	lftIR ? 12'h05F : rghtIR ?	12'hFA1	: 12'h000;
	endgenerate
	
	//final summation
	assign error = heading - desired_heading + err_nudge;

	//// command processing ////
	assign opcode = cmd[15:12];		// determines what the bot is supposed to do
	
	// setting fanfare
	reg fanfare_set;
	always @(posedge clk) 	// flip flop needed to set fanfare as cmd gets cleared 
		if(cmd_rdy)
			fanfare_set <= opcode==4'h3 ? 1'b1 : 1'b0 ;	//set fanfare based on command
	
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
		send_resp = 0;			// send response to UART. Not needed for TOUR
		move_cmd = 0;			// signal to start bot orienting itself. Reset square count, and desired_heading
		inc_frwrd = 0;			// begins ramping up speed of bot to max speed
		dec_frwrd = 0;			// begins decelerating bot.
		clr_frwd = 1'b1;			// sets bot speed to 0
		tour_go_comb = 0;		// sets tour_go
		fanfare_go = 0;			// sets fanfare_go
		nxt_state = state;
		
		case (state)
		IDLE:	begin 
				if (cmd_rdy) begin
					if (opcode == 4'h0)
						nxt_state = CAL;
					else if (opcode == 4'h2)
						nxt_state = STR_MOVE;
					else if (opcode == 4'h3)
						nxt_state = STR_MOVE;
					else if (opcode == 4'h4)
						nxt_state = TOUR;
					end
				end
				
		CAL:	begin 					
				strt_cal = 1'b1;		// begin calibration
				clr_cmd_rdy = 1'b1;
				if (cal_done)	begin	// after cal is over, got back to IDLE
					send_resp = 1'b1;
					nxt_state = IDLE;	
					
					end
				end
		
		STR_MOVE:	begin 
					clr_cmd_rdy = 1'b1;
					if ((error < $signed(12'h030)) && (error > $signed(12'hFD0))) 	// make sure heading is more or less correct
						nxt_state = MOVE;								// start moving forward
						move_cmd = 1'b1;								// bot begins orienting itself
					end
					
		MOVE:	begin
				clr_frwd = 1'b0;
				inc_frwrd = 1'b1;
				if (move_done) begin			
					nxt_state = STP_MOVE;			// begin bot deceleration after squares are covered
					fanfare_go = fanfare_set; end	// set fanfare_go based on type of cmd after move_done
				end
				
		STP_MOVE: 	begin
					clr_frwd = 1'b0;
					dec_frwrd = 1'b1;
					if (!(|frwrd)) begin	// check if bot is stationary
						send_resp = 1'b1;	// send response
						nxt_state = IDLE;	end
					end
		
		TOUR:	begin 						// commands received from TourCmd
				clr_cmd_rdy = 1'b1;
				tour_go_comb = 1'b1;
				nxt_state = IDLE; 
				end
		
		default: 	nxt_state = IDLE;
		endcase
	end
	
	// tour_go flop to prevent glitch
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			tour_go <= 1'b0;
		else 
			tour_go <= tour_go_comb;
			
endmodule
  