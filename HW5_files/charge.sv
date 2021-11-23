module charge (clk,rst_n,go,piezo,piezo_n);
	input clk, rst_n;
	input go;
	output piezo;
	output piezo_n;

	logic PB,go,RST_n;
	logic [23:0]clock;
	logic [15:0] freq_counter, freq;
	//logic SCLK;
	//logic [13:0] duty;
	logic strt_clk, strt_freq;
	logic [4:0] increment;


	parameter FAST_SIM = 0;

	//always @(posedge clk, negedge rst_n)
	generate if (FAST_SIM)
		assign increment = 5'h10;
	else 
		assign increment = 5'h01;
	endgenerate

	// timer to capture number of clks
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			clock <= 24'h000000;
		else if(strt_clk)
			clock <= 24'h000000;
		else
			clock <= clock+increment;
	end 

	// timer to set frequency of piezo
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			freq_counter <= 16'h0000;						//(50MHZ/frequency)
		else if(strt_freq)
			freq_counter <= freq;		// scale by 2
		else
			freq_counter <= freq_counter - 1'b1;
	end

	// Generate piezo at set frequency
	assign piezo = (freq_counter > {1'b0, freq[15:1]}) ? 1'b1 : 1'b0;		
	assign piezo_n = ~piezo;

	typedef enum reg [2:0] {IDLE,G6,C7,E7_1,G7_1,E7_2,G7_2} state_t;
	state_t state, next_state;

	always_ff @(posedge clk, negedge rst_n) 
	begin
		if (!rst_n)
			state <= IDLE;
		else
			state <= next_state;
	end

	always_comb begin
	//default//
	next_state = state;
	strt_freq = 0;
	strt_clk = 0;
	freq = 16'h0;

	case(state)
	IDLE:	if(go)	begin
				strt_clk = 1'b1;
				strt_freq = 1'b1;
				freq = 16'h7C90;	//decimal - 31888 (50MHZ/1568)
				next_state = G6;
			end
			
	G6: 	begin  	
			freq = 16'h7C90;			//decimal - 31888 (50MHZ/1568)
			if (!(|freq_counter))		// reinitiate counter when is drops to 0
				strt_freq = 1'b1;
				
			if (clock[23])	begin
				freq = 16'h5D51;		//decimal - 23889 (50MHZ/2093)
				strt_clk = 1'b1;
				strt_freq = 1'b1;
				next_state = C7; end
			end
			
	C7:     begin  	
			freq = 16'h5D51;			//decimal - 31888 (50MHZ/1568)
			if (!(|freq_counter))		// reinitiate counter when is drops to 0
				strt_freq = 1'b1;
				
			if (clock[23])	begin
				freq = 16'h4A11;		//decimal - 18961 (50MHZ/2637)
				strt_clk = 1'b1;
				strt_freq = 1'b1;
				next_state = E7_1; end
			end

	E7_1:   begin  	
			freq = 16'h4A11;			//decimal - 31888 (50MHZ/1568)
			if (!(|freq_counter))		// reinitiate counter when is drops to 0
				strt_freq = 1'b1;
				
			if (clock[23])	begin
				freq = 16'h3E47;		//decimal - 15943 (50MHZ/3136)
				strt_clk = 1'b1;
				strt_freq = 1'b1;
				next_state = G7_1; end
			end
				
	G7_1:	begin  	
			freq = 16'h3E47;			//decimal - 31888 (50MHZ/1568)
			if (!(|freq_counter))		// reinitiate counter when is drops to 0
				strt_freq = 1'b1;
				
			if (clock[23] && clock[22])	begin
				freq = 16'h4A11;		//decimal - 18961 (50MHZ/2637)
				strt_clk = 1'b1;
				strt_freq = 1'b1;
				next_state = E7_2; end
			end
			
	E7_2:   begin  	
			freq = 16'h4A11;			//decimal - 31888 (50MHZ/1568)
			if (!(|freq_counter))		// reinitiate counter when is drops to 0
				strt_freq = 1'b1;
				
			if (clock[23] && clock[22])	begin
				freq = 16'h3E47;		//decimal - 15943 (50MHZ/3136)
				strt_clk = 1'b1;
				strt_freq = 1'b1;
				next_state = G7_2; end
			end
				
	G7_2:   begin  	
			freq = 16'h3E47;			//decimal - 31888 (50MHZ/1568)
			if (!(|freq_counter))		// reinitiate counter when is drops to 0
				strt_freq = 1'b1;
				
			if (&clock)
				next_state = IDLE; 	
			end
			
	endcase
	
	end

endmodule

