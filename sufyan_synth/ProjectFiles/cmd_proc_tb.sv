module cmd_proc_tb();

	reg clk,rst_n;						// 50MHz clock and asynch active low reset
	reg [15:0] cmd_uart, cmd;			// command from BLE
	reg cmd_rdy;						// command ready
	wire clr_cmd_rdy;					// mark command as consumed
	logic send_resp;					// command finished, send_response via UART_wrapper/BT
	logic strt_cal;						// initiate calibration of gyro
	logic cal_done;						// calibration of gyro done
	reg signed [11:0] heading;			// heading from gyro
	reg heading_rdy;					// pulses high 1 clk for valid heading reading
	reg lftIR;							// nudge error +
	reg cntrIR;							// center IR reading (have I passed a line)
	reg rghtIR;							// nudge error -
	reg signed [11:0] error;			// error to PID (heading - desired_heading)
	reg [9:0] frwrd;					// forward speed register
	logic moving;						// asserted when moving (allows yaw integration)
	logic tour_go;						// pulse to initiate TourCmd block
	logic fanfare_go;					// kick off the "Charge!" fanfare on piezo

	logic TX_RX, RX_TX, cmd_sent, resp_rdy, rdy, SS_n,SCLK,MOSI;
	reg clr_rx_rdy;
	wire [7:0] resp;
	reg send_cmd, MISO, INT;

	cmd_proc cmd_DUT(.clk(clk), .rst_n(rst_n), .cmd(cmd_uart),.cmd_rdy(cmd_rdy), .cal_done(cal_done), .heading(heading),
					 .heading_rdy(heading_rdy), .lftIR(lftIR), .cntrIR(cntrIR), .rghtIR(rghtIR), .clr_cmd_rdy(clr_cmd_rdy),
					 .send_resp(send_resp), .strt_cal(strt_cal), .error(error), .frwrd(frwrd), .moving(moving),
					 .tour_go(tour_go), .fanfare_go(fanfare_go));
				
	UART_wrapper wrapper_DUT(.clk(clk), .rst_n(rst_n), .clr_cmd_rdy(clr_cmd_rdy), .trmt(send_resp), .resp(8'hA5), 
							 .RX(TX_RX), .cmd_rdy(cmd_rdy), .cmd(cmd_uart), .tx_done(), .TX(RX_TX));
			
						
	RemoteComm rc_DUT(.clk(clk), .rst_n(rst_n), .RX(RX_TX), .TX(TX_RX), .cmd(cmd), .send_cmd(send_cmd), .cmd_sent(cmd_sent), .clr_rx_rdy(clr_rx_rdy),
					  .resp_rdy(resp_rdy), .resp(resp));


	inert_intf inert_DUT(.clk(clk),.rst_n(rst_n),.strt_cal(strt_cal),.cal_done(cal_done),.heading(heading),.rdy(heading_rdy),.lftIR(lftIR),
					     .rghtIR(rghtIR),.SS_n(SS_n),.SCLK(SCLK),.MOSI(MOSI),.MISO(MISO),.INT(INT),.moving(moving));

						
	SPI_iNEMO3 nemo_DUT(.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),.MOSI(MOSI),.INT(INT));
	  
					
	initial
		begin
		clk = 0 ;
		rst_n = 0;
		cntrIR = 0;
		send_cmd = 0;
		clr_rx_rdy = 0;
		lftIR = 0;
		rghtIR = 0;
		cmd = 16'h0000;
		
		@(posedge clk);
		@(negedge clk);
		rst_n = 1;

		send_cmd = 1;

		@(negedge clk);
		send_cmd = 0;
		
		///////////////////////////////////////////////////////////////////////////////////
		////////////////////////////// check for sequence 2 ///////////////////////////////
		///////////////////////////////////////////////////////////////////////////////////
		
		wait4sig (cal_done, 1000000);		// wait for cal_done to be set
		wait4sig (resp_rdy, 1000000);		// wait for resp_rdy to be set
		
		repeat(5)@(posedge clk);	// delay
		
		///////////////////////////////////////////////////////////////////////////////////
		////////////////////////////// check for sequence 3 ///////////////////////////////		
		///////////////////////////////////////////////////////////////////////////////////
		
		cmd = 16'h2001;
		send_cmd = 1;

		@(posedge clk);
		@(negedge clk); 			// delay
		send_cmd = 0; 				// de-assert transmitting

		wait4sig(cmd_sent, 100000); // wait until transimission is complete
		
		repeat(10)@(posedge heading_rdy);	// delay
		if (frwrd !==10'h120) begin			// check if bot speed ramps up
			$display("You messed up");
			$stop;	end
		
		repeat(20)@(posedge heading_rdy);	// delay
		if (frwrd !==10'h300) begin			// check if bot speed saturates
			$display("You messed up");
			$stop;	end
		
		@(negedge clk);
		cntrIR = 1'b1;
		
		@(negedge clk);
		cntrIR = 1'b0;
		
		repeat(10)@(posedge heading_rdy);	// check if bot speed does not change with 1 IR pulse
		if (frwrd !==10'h300) begin
			$display("You messed up");
			$stop;	end
			
		@(negedge clk);
		cntrIR = 1'b1;
		
		@(negedge clk);
		cntrIR = 1'b0;
		
		wait4sig (resp_rdy, 1000000);		// check if bot speed ramps down and response is sent
		if (frwrd !==10'h000) begin
			$display("You messed up");
			$stop;	end
			
		///////////////////////////////////////////////////////////////////////////////////
		////////////////////////////// check for sequence 4 ///////////////////////////////		
		///////////////////////////////////////////////////////////////////////////////////
		
		cmd = 16'h2001;						// move bot north 1 step again
		send_cmd = 1;

		@(posedge clk);
		@(negedge clk); 					// delay
		send_cmd = 0; 						// de-assert transmitting

		wait4sig(cmd_sent, 100000); 		// wait until transimission is complete
		
		repeat(30)@(posedge heading_rdy);	// check if bot speed is maximum
		if (frwrd !==10'h300) begin
			$display("You messed up");
			$stop;	end
		
		rghtIR = 1'b1;
		repeat(100)@(posedge clk)			// look at error at when right IR is high
		
		
	    repeat (5) @(posedge clk);
		$display("Hakuna Matata");
		$stop();
	end


	always
		#5 clk = ~clk;

// task to check if signal rises within clks2wait clk cycles
	task automatic wait4sig(ref sig, input int clks2wait);
    fork
        begin: timeout
            repeat(clks2wait) @(posedge clk);
            $display("ERR: timed out waiting for sig in wait4sig");
		$stop();
        end
        begin
            @(posedge sig);	// signal of interest asserted
            disable timeout;
        end
    join
	endtask
endmodule