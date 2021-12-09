module PID(clk, rst_n, moving, err_vld, error, frwrd, lft_spd, rght_spd);
	input clk, rst_n;
	input moving, err_vld;
	input signed [11:0] error;
	input [9:0] frwrd;
	output signed [10:0] lft_spd, rght_spd;
	
	localparam P_COEFF = 5'h8;
	localparam D_COEFF = 6'h0B;		// D constant of PID
	
	logic signed [13:0] P_term, I_term, D_term, PID;
	
	logic signed [9:0] error_sat;
	
	// variables for integrator
	wire [14:0] err_sat_se; 
	reg [14:0] I_term_whole; // 15 bit I term
	wire [14:0] summation;
	wire overflow;
	wire [14:0] move_in;
	wire [14:0] nxt_integrator;
	
	// variables for derivative 
	logic signed [9:0] err1, err2, D_diff;	
	logic signed [6:0] D_diff_sat;	// saturated value of D_diff
	logic signed [12:0] D_term1;
	
	// varibles for forward motion
	logic [10:0] lft_spd_add, rght_spd_add, frwrd_ex;
	logic [10:0] lft_spd_pre, rght_spd_pre;
	
	////////////////////////// Data path ////////////////////////////
	
	// saturation logic for both negative and positive error
	assign error_sat = (error[11] && ~&error[10:9]) ? 10'b1000000000 : (~error[11] && |error[10:9]) ? 10'b0111111111 : error[9:0] ;
	
	// P_COEFF typeset to signed for signed multiplication
	assign P_term = error_sat * $signed(P_COEFF);
	
	/////////////////////// I TERM ///////////////////////////////
	
	assign err_sat_se = {{5{error_sat[9]}}, error_sat}; // signed extend err_sat

	assign summation = err_sat_se + I_term_whole; // add current error with integrator accumulation

	// overflow logic
	// check if the signs of error and I_term match, if no, set overflow to 0. If they do match
	// check if signs of sum and I_term match, if not overflow has occured
	assign overflow = err_sat_se[14] ^ I_term_whole[14] ? 0 : summation[14] ^ I_term_whole[14] ? 1 : 0;
	
	assign move_in = ~overflow && err_vld ? summation : I_term_whole; // if add_en is not set, stop integrating
	assign nxt_integrator = moving ? move_in : 15'h0000;  // reset integrator if bot not moving
	
	always_ff @ (posedge clk, negedge rst_n)
		if (!rst_n)
			I_term_whole <= 15'h0000;
		else
			I_term_whole <=  nxt_integrator;
	
	// set I_coeff to 1/64 by doing a arithmetic right shift of 6
	assign I_term = {{5{I_term_whole[14]}}, I_term_whole[14:6]};
	
	/////////////////////// D TERM ///////////////////////////////
	
	// flip flops for err_sat value storing
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
		begin
			err1 <= 0;
			err2 <= 0;
		end

		else if (err_vld)
		begin
			err1 <= error_sat;	// 2 error values needed one time step apart
			err2 <= err1;		// for taking the difference
		end
		
	logic signed [9:0] error_sat_piped;
	always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		error_sat_piped	 <= 0;
	else
		error_sat_piped <= error_sat;
	
	assign D_diff = error_sat_piped - err2; // get the difference between current and prev error
	
	// saturation logic based on whether D_diff has a high positive or negative value
	assign D_diff_sat = (D_diff[9] && ~&D_diff[8:6]) ? 7'b1000000 : (~D_diff[9] && |D_diff[8:6]) ? 7'b0111111 : D_diff[6:0];
	reg [6:0]D_COEFF_piped;

	// scale D_diff_sat with D_COEFF to get final output of derivative controller
	assign D_term1 = D_diff_sat * $signed(D_COEFF);
	assign D_term = {D_term1[12], D_term1};
	
	
	///////////////////////// Combined ///////////////////////////////
	logic signed [13:0] P_term_piped,I_term_piped,D_term_piped ;
	logic [10:0] frwrd_ex_piped;
	always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		P_term_piped <= 0;
	else
		P_term_piped <= P_term;
				
	always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		I_term_piped <= 0;
	else
		I_term_piped <= I_term;
		
	always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		D_term_piped <= 0;
	else
		D_term_piped <= D_term;
	
	assign PID = P_term_piped + I_term_piped + D_term_piped;
	
	// get wheel speeds
	assign frwrd_ex = {1'b0, frwrd};
	assign lft_spd_add = frwrd_ex + PID[13:3];
	assign rght_spd_add = frwrd_ex - PID[13:3];
	
	assign lft_spd_pre = moving ? lft_spd_add : 11'h000;		// get left speed
	assign rght_spd_pre = moving ? rght_spd_add : 11'h000;		// get right speed
	
	// speed saturation
	// frwrd can only be positive so check for sign of PID
	logic PID_msb_piped;

		
	// if PID is positive but lft_spd_pre is negative, saturate lft_spd
	assign lft_spd = PID[13] ? lft_spd_pre : lft_spd_pre[10] ? 11'h3FF : lft_spd_pre;
	// if PID is negative but rght_spd_pre is negative, saturate rght_spd
	assign rght_spd = !PID[13] ? rght_spd_pre : rght_spd_pre[10] ? 11'h3FF : rght_spd_pre;
	
endmodule
