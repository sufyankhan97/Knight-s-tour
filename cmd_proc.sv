module cmd_proc(clk,rst_n,cmd,cmd_rdy,clr_cmd_rdy,send_resp,strt_cal,
                cal_done,heading,heading_rdy,lftIR,cntrIR,rghtIR,error,
				frwrd,moving,tour_go,fanfare_go);
				
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
  
  //////////////////////////////////////////////////////////////
	


	
  
	
  
  
  
endmodule
  