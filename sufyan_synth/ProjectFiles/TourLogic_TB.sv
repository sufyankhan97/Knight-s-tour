module TourLogic_TB();
	reg clk, rst_n, go;
	reg [2:0] x_start, y_start;
	logic done;
	logic [4:0] indx;
	logic [7:0] move;
	
	TourLogic iDUT(.clk(clk), .rst_n(rst_n), .x_start(x_start), .y_start(y_start), .go(go), .done(done), .indx(indx) , .move(move));
	
	initial begin
		clk = 0;
		rst_n = 0;				// assert reset
		go = 0;
		x_start = 3'h0;			// set starting point for Knight
		y_start = 3'h0;
		
		@(posedge clk);			// delay
		@(negedge clk);
		rst_n = 1'b1;				// de-assert reset
		
		@(negedge clk);
		go = 1;
		
		@(posedge clk);			// delay
		@(negedge clk);
		go = 0;
		
		wait4sig (done, 10000000);		// wait for done to be set
		
		// get first move
		indx = 5'h00;	
		@(posedge clk);			// delay
		@(negedge clk);		
		$display ("First move is %b", move);
		// get 10th move
		indx = 5'h09;		
		@(posedge clk);			// delay
		@(negedge clk);
		$display ("10th move is %b", move);
		
		$stop();
	end
	
	always
		#5 clk = ~clk;
	
	// code for debug
	always @(negedge iDUT.update_loc) begin
		integer y;
		for (y=4; y>=0; y--) 
			$display("%2d  %2d  %2d  %2d  %2d\n", iDUT.board[0][y], iDUT.board[1][y], 
					 iDUT.board[2][y], iDUT.board[3][y], iDUT.board[4][y]);
		$display("------------------------------\n");
		end
	
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
