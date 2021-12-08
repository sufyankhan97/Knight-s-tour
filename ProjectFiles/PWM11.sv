module PWM11(clk, rst_n, duty, PWM_sig,PWM_sig_n);
input clk, rst_n;
input [10:0] duty;
output reg PWM_sig, PWM_sig_n;
logic [10:0] cnt;
logic inter;
always_ff @(posedge clk, negedge rst_n) begin //up counter
	if (!rst_n) cnt <= 11'h000;
	else cnt <= cnt + 1; 
end
assign inter = (cnt<duty) ? 1:0;
always_ff @(posedge clk, negedge rst_n) begin //flopping PWM directly to avoid glitch
	if (!rst_n) PWM_sig <= 1'b0;
	else PWM_sig <= inter;
end
assign PWM_sig_n = ~PWM_sig; 
endmodule 