module PWM11(clk, rst_n, duty, PWM_sig, PWM_sig_n);
	
	input clk, rst_n;
	input [10:0] duty;
	output logic PWM_sig, PWM_sig_n;
	
	logic [10:0] cnt;
	logic top_PWM_on;
	
	// counter to compare duty against
	always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		cnt <= 11'h000;
	else
		cnt <= cnt+1;
	
	// set duty on only if its greater than count. Can't achieve 100% ON
	assign top_PWM_on = duty > cnt ? 1 : 0;
	
	// flip flop to prevent glitches on PWM output
	always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		PWM_sig <= 0;
	else
		PWM_sig <= top_PWM_on;
	
	assign PWM_sig_n = ~PWM_sig;

endmodule
