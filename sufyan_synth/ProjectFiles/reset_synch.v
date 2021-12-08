module reset_synch(RST_n, clk, rst_n);
	input clk, RST_n;
	output reg rst_n;
	reg rst_n1;
	
	always @(negedge clk, negedge RST_n) begin
		if (!RST_n) begin
			rst_n1 <= 1'b0;
			rst_n <= 1'b0;	end
		else begin
			rst_n1 <= 1'b1;
			rst_n <= rst_n1; end
	end
			
endmodule
		