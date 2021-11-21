//////////////////////////////////////////////////////
// Interfaces with ST 6-axis inertial sensor.  In  //
// this application we only use Z-axis gyro for   //
// heading of robot.  Fusion correction comes    //
// from "gaurdrail" signals lftIR/rghtIR.       //
/////////////////////////////////////////////////
module inert_intf(clk,rst_n,strt_cal,cal_done,heading,rdy,lftIR,
                  rghtIR,SS_n,SCLK,MOSI,MISO,INT,moving);

	parameter FAST_SIM = 8;	// used to speed up simulation

	input clk, rst_n;
	input MISO;					// SPI input from inertial sensor
	input INT;					// goes high when measurement ready
	input strt_cal;				// initiate claibration of yaw readings
	input moving;					// Only integrate yaw when going
	input lftIR,rghtIR;			// gaurdrail sensors

	output cal_done;				// pulses high for 1 clock when calibration done
	output signed [11:0] heading;	// heading of robot.  000 = Orig dir 3FF = 90 CCW 7FF = 180 CCW
	output rdy;					// goes high for 1 clock when new outputs ready (from inertial_integrator)
	output SS_n,SCLK,MOSI;		// SPI outputs


	////////////////////////////////////////////
	// Declare any needed internal registers //
	//////////////////////////////////////////
	logic [15:0] cmd, yaw_rt, inert_data;
	reg [7:0] yawH, yawL;
	reg [15:0] init_timer;
	reg INT_ff1, INT_ff2;
	
	//////////////////////////////////////////////
	// Declare outputs of SM are of type logic //
	////////////////////////////////////////////
	logic wrt, done;
	logic vld, yawH_vld, yawL_vld, yaw_rt_vld;
  
	///////////////////////////////////////
	// Create enumerated type for state //
	/////////////////////////////////////
	typedef enum logic [2:0]{INIT1, INIT2, INIT3, INT_EN, YAWL, YAWH, READY} state_t;
	state_t state, nxt_state;

	////////////////////////////////////////////////////////////
	// Instantiate SPI monarch for Inertial Sensor interface //
	//////////////////////////////////////////////////////////
	SPI_mnrch iSPI(.clk(clk),.rst_n(rst_n),.SS_n(SS_n),.SCLK(SCLK),
				 .MISO(MISO),.MOSI(MOSI),.wrt(wrt),.done(done),
				 .rd_data(inert_data),.wt_data(cmd));
				  
	////////////////////////////////////////////////////////////////////
	// Instantiate Angle Engine that takes in angular rate readings  //
	// and acceleration info and produces a heading reading         //
	/////////////////////////////////////////////////////////////////
	inertial_integrator #(FAST_SIM) iINT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal),.vld(vld),
						   .rdy(rdy),.cal_done(cal_done), .yaw_rt(yaw_rt),.moving(moving),.lftIR(lftIR),
						   .rghtIR(rghtIR),.heading(heading));
	
	//////////////////////// Datapath /////////////////////////////////
	
	// reg to hold yawH values
	always_ff @(posedge clk)
		if (yawH_vld)
			yawH <= inert_data[7:0];	// set yawH reg when data is valid
			
	// reg to hold yawL values
	always_ff @(posedge clk)
		if (yawL_vld)
			yawL <= inert_data[7:0];	// set yawL reg when data is valid
	
	assign yaw_rt = {yawH, yawL};
	
	// 16 bit counter to wait initially before writing to sensor
	always_ff @(posedge clk) 
		if (!rst_n)
			init_timer <= 16'h0000;
		else
			init_timer <= init_timer + 1;
			
	// double flop INT
	always_ff @(posedge clk) begin
		INT_ff1 <= INT;
		INT_ff2 <= INT_ff1;	end
	
	// flop yaw_vld
	always_ff @(posedge clk, negedge rst_n) 
		if (!rst_n)
			vld <= 1'b0;
		else	
			vld <= yaw_rt_vld;
	
			
	/////////////////// State Machine ///////////////////////////////
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			state <= INIT1;
		else
			state <= nxt_state;
			
			
	always_comb begin
		wrt = 0;			// enables writing / reading to sensor 
		yaw_rt_vld = 0;			// indicates to integrator that data is valid
		cmd = 16'hxxxx;			// cmd given to sensor
		yawH_vld = 0;
		yawL_vld = 0;
		nxt_state = state;
		case (state)
		INIT1:	if (&init_timer) begin		// when timer is done, enable write and go to INIT2
					wrt = 1;
					cmd = 16'h0D02;
					nxt_state = INIT2; end
		INIT2:	if (done) begin		
					wrt = 1;
					cmd = 16'h1160;			// setup gyro for 416 Hz data rate and +- 250 degree.sec range
					nxt_state = INIT3; end 
					
		INIT3:	if (done) begin		
					wrt = 1;
					cmd = 16'h1440;			// enable rounding of data
					nxt_state = INT_EN; end 
		
	    INT_EN: if (INT_ff2) 				// check if data from sensor is ready
					nxt_state = YAWH;	
					
		YAWH:	if (done) begin	
					wrt = 1;				
					cmd = 16'hA7xx;			//  cmd to rady YAWH
					nxt_state = YAWL; end 
					
		YAWL: 	if (done) begin	
					yawH_vld = 1;			// save yawH to reg
					wrt = 1;				
					cmd = 16'hA6xx;			// cmd to rady YAWL
					nxt_state = READY; end 
					
		READY:  if (done && !INT_ff2) begin	
					yawL_vld = 1;			// save yawL to reg
					yaw_rt_vld = 1;
					wrt = 1;				
					nxt_state = INT_EN; end
		
		default: 	nxt_state = INIT1;
		endcase
	end
	

 
endmodule
	  