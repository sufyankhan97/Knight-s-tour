module charge_tb();
	logic clk, RST_N, GO;
	logic go, rst_n;
	logic piezo, piezo_n;

	charge charge_iDUT(.clk(clk),.rst_n(rst_n),.go(go),.piezo(piezo),.piezo_n(piezo_n));
	PB_release PB_iDUT(.clk(clk), .rst_n(rst_n),.PB(GO), .go(go));
	reset_synch RS_iDUT(.RST_n(RST_N), .clk(clk), .rst_n(rst_n));

	initial begin
		clk = 1'b0;
		RST_N = 1'b0;
		GO = 0;
		
		@(negedge clk)
			RST_N = 1'b1;
			GO = 1'b0;
		
		repeat(2000) @(negedge clk)
			GO = 1'b1;
		
		@(negedge clk)
			GO = 1'b0;
		
		repeat(2) @(negedge clk)
			GO = 1'b1;
	end
	
	always 
		#10 clk = ~clk; 
endmodule