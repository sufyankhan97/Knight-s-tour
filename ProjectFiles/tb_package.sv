package tb_package;
	
	localparam CALIBRATE = 16'h0000;
	
	localparam COMM_COMPLETE = 8'hA5;
	localparam COMM_INTERMEDIATE = 8'h5A;
	
	// localparam 	
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
	
	task automatic VerifyResponse (ref [7:0] resp, input [7:0] data);
		if (resp != data) begin
			$display("Invalid response dumbass!");
			$stop();	end
		else
			$display("Hakuna Matata!");
	endtask
	
	task automatic MoveCmdGen (input Fanfare, )
	
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
