package tb_package;

	// localparams
	localparam CALIBRATE = 16'h0000;
	
	localparam COMM_COMPLETE = 8'hA5;
	localparam COMM_INTERMEDIATE = 8'h5A;
	
	localparam NORTH = 8'h00;
	localparam WEST = 8'h3F;
	localparam SOUTH = 8'h7F;
	localparam EAST = 8'hBF;
	
	localparam START_X = 3'h2;
	localparam START_Y = 3'h2;
	
	// task to intiliaze clk and rst_n signals
	task automatic Init(ref clk, rst_n);
		clk = 0;
		rst_n = 0;
		
		@(posedge clk);
		@(negedge clk);
		rst_n = 1;		// de-assert reset
		
		// delay
		repeat(20) @(posedge clk);
	endtask
	
	// task to send commands over UART
	task automatic SendCmdBLE (ref clk, send_cmd, cmd_sent, ref[15:0] cmd, input [15:0] data);
		cmd = data;
		send_cmd = 1;
		// delay
		@(posedge clk);
		@(negedge clk);
		send_cmd = 0;
		Wait4Sig(clk, cmd_sent, 100000);
	endtask
	
	// task to Verify valid response is received from KnightsTour
	task automatic VerifyResponse (ref [7:0] resp, ref clear_resp, clk, input[7:0] data);
		if (resp != data) begin
			$display("Invalid response dumbass!");
			$stop();	end
		else
			$display("Hakuna Matata!");
		clear_resp = 1;
		// delay
		@(posedge clk);
		@(negedge clk);
		clear_resp = 0;
	endtask
	
	task automatic MoveCmdGen (input fanfare, input[7:0] direction, input[3:0] count, output[15:0] cmd);
		cmd = fanfare ? {4'b0011, direction, count} : {4'b0010, direction, count};
	endtask
	
	task automatic KnightsTourCmdGen (input [2:0] start_x, start_y, output[15:0] cmd);
		cmd = {4'b0100, 5'b00000, start_x, 1'b0, start_y};
	endtask
	
	// task to check if signal rises within clks2wait clk cycles
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
