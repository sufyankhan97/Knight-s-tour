module inert_intf_tb();
	reg clk, rst_n, strt_cal;
	logic signed [11:0] heading;
	
	logic SS_n, SCLK, MOSI, MISO, cal_done, rdy;
	logic INT;
	
	inert_intf INTF1 (.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal), .cal_done(cal_done), .heading(heading), .rdy(rdy), 
					  .lftIR(1'b0), .rghtIR(1'b0), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .INT(INT), .moving(1'b1));
					  
	SPI_iNEMO2 SPI2(.SS_n(SS_n), .SCLK(SCLK), .MISO(MISO), .MOSI(MOSI), .INT(INT));
	
	initial begin
		clk = 0;
		rst_n = 0; 		// assert reset
		strt_cal = 0;
		
		@(negedge clk);	// delay
		rst_n = 1;		// de-assert reset
		
		wait4sig (SPI2.NEMO_setup, 100000);		// wait for NEMO to be set
		
		strt_cal = 1;	// start calibration
		
		@(posedge clk);	// delay
		@(negedge clk);
		
		strt_cal = 0;
		
		wait4sig (cal_done, 1000000);			// wait for calibration to get completed
		
		repeat (8000000) @(posedge clk);
		$stop;
		
	end
	
	always
		#10 clk = ~clk;
		
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
