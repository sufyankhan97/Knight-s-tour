module MtrDrv_tb;
	logic clk, rst_n, lftPWM1, lftPWM2, rghtPWM1, rghtPWM2;
	logic signed [10:0] lft_spd, rght_spd;

	MtrDrv iRBT(.clk(clk), .rst_n(rst_n), .lft_spd(lft_spd), .rght_spd(rght_spd), .lftPWM1(lftPWM1), .lftPWM2(lftPWM2), .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2));
	
	initial begin
		clk = 0;
		rst_n = 0; // assert reset
		lft_spd = 11'h000; // set initial speed to 0
		rght_spd = 11'h000; // set initial speed to 0
		
		@(posedge clk);
		@(negedge clk);
		rst_n = 1; // deassert reset
		
		// check if PWM duty is 50%
		repeat(2048)@(posedge clk);
		@(negedge clk); // delay
		
		// set speed to highest positive value for left and most negative for right. 
		// Check if PWM duty is almost 100% for lftPWM1 and 0% for rghtPWM1
		lft_spd = 11'h3ff;
		rght_spd = 11'h400;
		repeat(2048)@(posedge clk);
		@(negedge clk); // delay
		
		// set speed to most negative value. Check if PWM duty is almost 100% for PWM2
		// Check if PWM duty is 0% for lftPWM1 and almost 100% for rghtPWM1
		lft_spd = 11'h400;
		rght_spd = 11'h3ff;
		repeat(2048)@(posedge clk);
		@(negedge clk); // delay
		
		$stop;
	end

	always
		#5 clk = ~clk;

endmodule
