module PID_tb();
	reg [24:0] stim[0:1999];
	reg [21:0] resp[0:1999];
	
	logic clk, rst_n, moving, err_vld; 
	logic [11:0] error;
	logic [9:0] frwrd;
	wire [10:0] lft_spd, rght_spd;
	
	integer i;
	
	PID iNST1(.clk(clk), .rst_n(rst_n), .moving(moving), .err_vld(err_vld), .error(error), 
			  .frwrd(frwrd), .lft_spd(lft_spd), .rght_spd(rght_spd));
	
	initial begin
		clk = 0;
		$readmemh("PID_stim.hex", stim);
		$readmemh("PID_resp.hex", resp);
		
		for (i=0; i < 2000; i=i+1) begin
			@(negedge clk);
			rst_n = stim[i][24];
			moving = stim[i][23];
			err_vld = stim[i][22];
			error = stim[i][21:10];
			frwrd = stim[i][9:0];
			
			@(posedge clk);
			# 1
			if (lft_spd !== resp[i][21:11]) begin
				$display("Expected: %h",resp[i][21:11]);
				$display("Got: %h", lft_spd);
				$stop;
			end
			if (rght_spd !== resp[i][10:0]) begin
				$display("Expected: %h",resp[i][10:0]);
				$display("Got: %h", rght_spd);
				$stop;
			end
		end
		$display("Bharat Ramadas has achieved the possible!");
		
		repeat (5) @(posedge clk);
		
		$stop;
	end
	
	always
		#10 clk = ~clk;
		
endmodule
