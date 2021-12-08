module SPI_mnrch(clk, rst_n, SS_n, SCLK, MOSI, MISO, wrt, wt_data, done, rd_data);
	input clk, rst_n;
	output SCLK, MOSI;
	input MISO, wrt;
	input [15:0] wt_data;
	output reg done, SS_n;
	output [15:0] rd_data;

	logic [3:0] bit_cntr;
	logic shft, smpl, init, ld_SCLK, set_done;
	logic done15;
	logic [4:0] SCLK_div;
	wire SCLK_fall, SCLK_rise;

	logic [15:0] shft_reg;
	logic MISO_smpl;

	// state variables
	typedef enum logic [1:0]{IDLE, C15, MAIN, C0} state_t;
	state_t state, nxt_state;

	//////////////// define data path //////////////////
	
	// shift counter to count number of bits that have been shifted
	always_ff @(posedge clk)
		if (init)
			bit_cntr <= 4'b0000;
		else if (shft)
			bit_cntr <= bit_cntr + 1;

	assign done15 = &bit_cntr;	// done15 is set when all bits are

	// SCLK counter implementation. Used to generate clk to send to serf
	always_ff @(posedge clk)
		if (ld_SCLK)
			SCLK_div <= 5'b10111;		// pre-load with values so that SCLK fall comes in 16 system clks
		else
			SCLK_div <= SCLK_div + 1;	// coutner
	
	assign SCLK = SCLK_div[4];		// MSB of SCLK_div is SCLK sent to serf. Cycle time = 32 * clk
	assign SCLK_rise = !SCLK_div[4] && &(SCLK_div[3:0]);	// condition to check if SCLK will rise at next clk
	assign SCLK_fall = &SCLK_div;	// condition to check if SCLK will fall at next clk

	//// shift reg implementation ////
	
	// reg to hold MISO values. Sample at SCLK rise using smpl
	always_ff @(posedge clk)
		if (smpl)
			MISO_smpl <= MISO;
			
	// reg to hold shift_reg. Hold both MOSI and MISO
	always_ff @(posedge clk)
		if (init)
			shft_reg <= wt_data;	// initially update reg with values to be sent
		else if (shft)				// shift at SCLK fall
			shft_reg <= {shft_reg[14:0], MISO_smpl};	// update reg at every shft 

	assign MOSI = shft_reg[15];		// MOSI or value to be sent to serf extracted from MSB of shft_reg
	// after all shifts are done rd_data is same as shft_reg
	assign rd_data = shft_reg;
	/////////////// define state machine ////////////////

	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;

	always_comb begin
		smpl = 0;			// samples MOSI 
		shft = 0;			// shifts shift_reg
		ld_SCLK = 0;		// loads SCLK with initial value
		init = 0;			// initializes shift_reg with write data
		set_done = 0;		// controls SS_n and done outputs
		nxt_state = state;
		case (state)
		IDLE:	begin
				ld_SCLK = 1;		// set SCLK = 1 at IDLE always
				if (wrt) begin		// when wrt is set, enable init and go to C15
					init = 1;
					nxt_state = C15; end
				end
		C15:	if (SCLK_fall) 		// no shifting in C15.
					nxt_state = MAIN; 
		MAIN:	if (done15) begin		// go to last state when done 15 is high. 1 bit left to sample and shift
					nxt_state = C0; end
				else if (SCLK_rise)	
					smpl = 1;
				else if (SCLK_fall)
					shft = 1;
		C0:		if (SCLK_fall) begin	// check when SCLK fall is imminent	
					shft = 1;			// enable shift then
					ld_SCLK = 1;		// reset SCLK
					set_done = 1;		// say we are done working
					nxt_state = IDLE; end	// time for chillin
				else if (SCLK_rise)
					smpl = 1;			// one last sample in C0
		endcase
	end
	
	// define SS_n reg
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			SS_n <= 1'b1;		// preset SS_n
		else if (init)
			SS_n <= 1'b0;
		else if (set_done)
			SS_n <= 1'b1;
			
	// define done reg
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			done <= 1'b0;		// reset done
		else if (init)
			done <= 1'b0;
		else if (set_done)
			done <= 1'b1;
			

endmodule
