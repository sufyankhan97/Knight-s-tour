module MtrDrv(clk, rst_n, lft_spd, rght_spd, lftPWM1, lftPWM2, rghtPWM1, rghtPWM2);
	input signed [10:0] lft_spd, rght_spd;
	output lftPWM1, lftPWM2, rghtPWM1, rghtPWM2;
	input clk, rst_n;

	wire [10:0] duty1, duty2;
	
	// set offset to maximum negative number. negative number used to implement logic specified in problem 
	localparam signed OFFSET = 11'h400;
	
	// subtract offset to wheel speeds to get duty required from FETs
	assign duty1 = lft_spd - OFFSET;
	assign duty2 = rght_spd - OFFSET;

	// use PWM11 module to convert duty to PWM signals
	PWM11 iLFT(.clk(clk), .rst_n(rst_n), .duty(duty1), .PWM_sig(lftPWM1), .PWM_sig_n(lftPWM2));
	PWM11 iRHT(.clk(clk), .rst_n(rst_n), .duty(duty2), .PWM_sig(rghtPWM1), .PWM_sig_n(rghtPWM2));
	
endmodule
