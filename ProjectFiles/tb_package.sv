package tb_package;

	///////////////// localparams /////////////////
	
	localparam CALIBRATE = 16'h0000;		// data sent for gyro calibration
	
	localparam COMM_COMPLETE = 8'hA5;		// data returned from KnightsTour when comd execution is over
	localparam COMM_INTERMEDIATE = 8'h5A;	// data returned from KnightsTour at intermediate stages of KnightsLogic
	
	// heading to data mapping as part of Knight MOVE command
	localparam NORTH = 8'h00;				
	localparam WEST = 8'h3F;
	localparam SOUTH = 8'h7F;
	localparam EAST = 8'hBF;
	
	// start coordinates of Knight
	localparam START_X = 3'h2;
	localparam START_Y = 3'h2;
	
	///////////////// TASKS /////////////////
	
	// Intiliaze clk and rst_n signals 
	task automatic Init(ref clk, rst_n);
		clk = 0;
		rst_n = 0;
		
		@(posedge clk);
		@(negedge clk);
		rst_n = 1;		// de-assert reset
		
		// delay
		repeat(20) @(posedge clk);
	endtask
	
	// Send commands over UART
	task automatic SendCmdBLE (ref clk, send_cmd, cmd_sent, ref[15:0] cmd, input [15:0] data);
		cmd = data;
		send_cmd = 1;						// send recieved data
		// delay
		@(posedge clk);
		@(negedge clk);
		send_cmd = 0;
		Wait4Sig(clk, cmd_sent, 100000);	// wait until cmd_sent confirmation is received
	endtask
	
	// Verify valid response is received from KnightsTour
	task automatic VerifyResponse (ref [7:0] resp, ref clear_resp, clk, input[7:0] data);
		if (resp !== data) begin						// compare received resp against expected data
			$display("Invalid response dumbass!");
			$stop();	end
		else
			$display("Hakuna Matata!");
		clear_resp = 1;								// clear resp after verification
		// delay
		@(posedge clk);
		@(negedge clk);
		clear_resp = 0;
	endtask
	
	// Generate MOVE command based on direction, count of sqaures to traverse, and fanfare
	task automatic MoveCmdGen (input fanfare, input[7:0] direction, input[3:0] count, output[15:0] cmd);
		cmd = fanfare ? {4'b0011, direction, count} : {4'b0010, direction, count};
	endtask
	
	// Generate TOUR command based on starting co-ordinates
	task automatic KnightsTourCmdGen (input[2:0] start_x, start_y, output[15:0] cmd);
		cmd = {4'b0100, 5'b00000, start_x, 1'b0, start_y};
	endtask
	
	// Get expected position after move
	task automatic GetNextPos (input[2:0] curr_x, curr_y, input[7:0] move, output[2:0] next_x, next_y);
		if (move[0]) begin
			next_x = curr_x-1;
			next_y = curr_y+2; end
		else if (move[1]) begin
			next_x = curr_x+1;
			next_y = curr_y+2; end
		else if (move[2]) begin
			next_x = curr_x-2;
			next_y = curr_y+1; end
		else if (move[3]) begin
			next_x = curr_x-2;
			next_y = curr_y-1; end
		else if (move[4]) begin
			next_x = curr_x-1;
			next_y = curr_y-2; end
		else if (move[5]) begin
			next_x = curr_x+1;
			next_y = curr_y-2; end
		else if (move[6]) begin
			next_x = curr_x+2;
			next_y = curr_y-1; end
		else begin
			next_x = curr_x+2;
			next_y = curr_y+1; end
	endtask
	
	// Compare expected position against actual position
	task automatic ComparePos (input[2:0] actual_x, actual_y, exp_x, exp_y);
		if (actual_x!==exp_x && actual_y!==exp_y) begin
			$display("ERR: Where the hell is the bot at?");
			$stop(); end
		else	begin
			$display("Onwards, Oh Gallant Knight!");
			$display("Position x %d, y %d", actual_x, actual_y); end
	endtask
	
	// Check if signal posedge encountered within clks2wait clk cycles
	task automatic Wait4Sig(ref clk, sig, input int clks2wait);
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
	
	
endpackage
