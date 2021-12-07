module TourLogic(clk,rst_n,x_start,y_start,go,done,indx,move);

	input clk,rst_n;				// 50MHz clock and active low asynch reset
	input [2:0] x_start, y_start;	// starting position on 5x5 board
	input go;						// initiate calculation of solution
	input [4:0] indx;				// used to specify index of move to read out
	output logic done;				// pulses high for 1 clock when solution complete
	output [7:0] move;				// the move addressed by indx (1 of 24 moves)

	logic go_ff1, go_ff2;			// double flop go for meta-stability
	logic move_init, move_incr, move_decr;		// control signals for move counter
	logic done_SM;					// done output from state machine
	
	// state variables
	typedef enum logic [2:0]{IDLE, INIT, MOVES_CHECK, MOVE, BACKUP} state_t;
	state_t state, nxt_state;
	
	////////////////////////////////////////
	// Declare needed internal registers //
	//////////////////////////////////////

	// 2-D array of 5-bit vectors that keep track of where on the board the knight
	//  has visited.  Will be reduced to 1-bit boolean after debug phase 
	logic [4:0] board [0:4][0:4];		
	logic [4:0] board_movenum;					// used within SM to store is move num associated with board location before updating board
	logic [2:0] board_x, board_y;				// indices at with board_movenum value is to be stored
	
	// 1-D array (of size 24) to keep track of last move taken from each move index
	logic [7:0] moves_taken [0:23];				
	logic [7:0] move_taken;						// used within SM to store move taken at a particular board location
	logic update_moves_taken;					// control signal to udpate moves_taken
	
	// 1-D array (of size 24) to keep track of possible moves from each move index
	logic [7:0] poss_moves [0:23];
	logic [7:0] poss_move;						// used within SM to store list of all possible moves at a particular board location
	logic update_poss_moves;					// control signal to update poss_moves
	
	// move_try ... not sure you need this.  I had this to hold move I would try next
	logic [7:0] move_try, move_try_next;		
	logic update_move_try;						// control signal to update move_try
	
	// move number...when you have moved 24 times you are done.  Decrement when backing up
	logic [4:0] move_count, prev_move_count;
	
	// xx, yy couple of 3-bit vectors that represent the current x/y coordinates of the knight
	logic [2:0] xx, yy, next_xx, next_yy;
	logic update_loc;							// control signal to update location and board data
	
	////////////////////////////////////////////////////////////////////////////////////
	///////////////////////////////// functions /////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////

	function [7:0] calc_poss(input [2:0] xpos,ypos);
		// a function that returns a packed byte of all the possible moves (at least in bound) 
		// moves given coordinates of Knight.
		if (xpos > 0 && ypos < 3)
			calc_poss[0] = 1;
		else
			calc_poss[0] = 0;
       
		if (xpos < 4 && ypos < 3)
			calc_poss[1] = 1;
		else 
			calc_poss[1] = 0;
			
		if (xpos > 1 && ypos < 4)
			calc_poss[2] = 1;
		else
			calc_poss[2] = 0;
			
		if (xpos > 1 && ypos > 0)
			calc_poss[3] = 1;
		else
			calc_poss[3] = 0;
			
		if (xpos > 0 && ypos > 1)
			calc_poss[4] = 1;
		else 
			calc_poss[4] = 0;
			
		if (xpos < 4 && ypos > 1)
			calc_poss[5] = 1;
		else 
			calc_poss[5] = 0;
			
		if (xpos < 3 && ypos > 0)
			calc_poss[6] = 1;
		else 
			calc_poss[6] = 0;
			
		if (xpos < 3 && ypos < 4)
			calc_poss[7] = 1;
		else
			calc_poss[7] = 0;
			
	endfunction

	function signed [2:0] off_x(input [7:0] try);
		//function that returns a the x-offset the Knight will move given the encoding of 
		// the move you are going to try. 
		  off_x = try[0] || try[4] ? -1 : try[2] || try[3] ? -2 : try[1] || try[5] ? 1 : try[6] || try[7] ? 2 : 0;
	endfunction

	function signed [2:0] off_y(input [7:0] try);
		//function that returns a the y-offset the Knight will move given the encoding of 
		// the move you are going to try.
		  off_y = try[0] || try[1] ? 2 : try[2] || try[7] ? 1 : try[3] || try[6] ? -1 : try[4] || try[5] ? -2 : 0;
	endfunction

	////////////////////////////////////////////////////////////////////////////////////
	///////////////////////////////// datapath /////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////
	
	// double flop go for metastability
	always_ff @(posedge clk)	begin
		go_ff1 <= go;
		go_ff2 <= go_ff1; 	end
	
	// up-down counter for number of moves
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			move_count <= 5'h0;
		else if (move_init)
			move_count <= 5'h0;
		else if (move_incr)
			move_count <= move_count + 1;
		else if (move_decr)
			move_count <= move_count - 1;
		
	// flop to update Knight's location at posedge
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n) begin
			xx <= 3'h7; 
			yy <= 3'h7; end
		else if (update_loc) begin
			xx <= next_xx;
			yy <= next_yy; end
			
	// flop to update board at posedge clock
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			board <= '{default:0};
		else if (move_init)
			board <= '{default:0};
		else if (update_loc)
			board[board_x][board_y] <= board_movenum;
	
	// flop to update possible moves (all) avialable to Knight
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			poss_moves <= '{default:0};
		else if (update_poss_moves)
			poss_moves[move_count] <= poss_move;
	
	// flop to update moves_taken
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			moves_taken <= '{default:0};
		else if (update_moves_taken)
			moves_taken[move_count] <= move_taken;
	
	// provide move taken as part of solving Knights tour to TourCmd
	assign move = moves_taken[indx];
	
	// flop to update move_try 
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			move_try <= 8'h0;
		else if (update_move_try)
			move_try <= move_try_next;
			
	// flop done obtained from state machine as output of combinational logic can glitch
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			done <= 1'b0;
		else if (done_SM)
			done <= 1'b1;
		
	////////////////////////////////////////////////////////////////////////////////////
	///////////////////////////////// statemachine /////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////
	
	// state reg
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;
			
	// state transitions
	always_comb begin
		move_init = 0;
		move_incr = 0;
		move_decr = 0;
		update_loc = 0;
		next_xx = 0;
		next_yy = 0;
		board_movenum = 0;
		poss_move = 0;
		update_poss_moves = 0;
		move_try_next = 0;
		update_move_try = 0;
		move_taken = 0;
		update_moves_taken = 0;
		board_x = 0;
		board_y = 0;
		done_SM = 0;
		prev_move_count = 0;
		nxt_state = state;
		
		case (state)
		IDLE:	if (go_ff2) begin
					// set all board values to 0 to indicate that board hasn't been traversed yet
					// set move counter to 0. Both done by setting move_init to 1
					move_init = 1'b1;
					nxt_state = INIT;
				end
				
		INIT: 	begin
				// set initial position to start location
				next_xx = x_start;						
				next_yy = y_start;
				// save initial position as 1st on board
				board_x = x_start;
				board_y = y_start;
				board_movenum = 5'h1;	
				update_loc = 1'b1;			// update location and board data
				
				nxt_state = MOVES_CHECK; end
		
		MOVES_CHECK: 	begin
						poss_move = calc_poss(xx, yy);		// calculate moves available to Knight
						update_poss_moves = 1'b1;			// update poss_moves memory array
						move_try_next = 8'h01;				// try first move (if available)
						update_move_try = 1'b1; 			// update move_try register
						nxt_state = MOVE; end
		
		MOVE: 	begin
				// calculate next position based on move
				next_xx = xx + off_x(move_try);
				next_yy = yy + off_y(move_try);
				if (|(poss_moves[move_count] & move_try) && board[next_xx][next_yy] == 0)
					begin
					board_movenum = board[xx][yy] + 1;		// increment move num by 1 from previous movenum. Will need to change later
					board_x = next_xx;
					board_y = next_yy;
					update_loc = 1'b1;						// update location and board data
					move_taken = move_try;					// store successfully executed move
					update_moves_taken = 1'b1;
					
					if (move_count == 23) begin				// if move_count has reached 23, with this move its done
						done_SM = 1'b1;
						nxt_state = IDLE; end
					  
					else 
						nxt_state = MOVES_CHECK;			// go to previous state if moves are remaining
					// increment move counter by 1
					move_incr = 1'b1; 	end
				
				else if (move_try != 8'h80) begin			// try next move if current move in invalid
					move_try_next = {move_try[6:0], 1'b0};	// left shift by 1 position
					update_move_try = 1'b1; end
				else										// go to BACKUP if no valid moves remain
					nxt_state = BACKUP;
				end
				
		BACKUP:	begin
				// delete previous entry on board
				prev_move_count = move_count-1;							// previous move no longer occured
				board_movenum = 0;										// set board traversed info to 0
				board_x = xx;
				board_y = yy;
				next_xx = xx - off_x(moves_taken[prev_move_count]);		// go back to previous position
				next_yy = yy - off_y(moves_taken[prev_move_count]);
				update_loc = 1'b1; 										// update location and board data
				move_try_next = {moves_taken[prev_move_count][6:0], 1'b0};	// left shift move available
				update_move_try = 1'b1;									
				if (move_try_next != 8'h0)								// move if any moves are left at position
					nxt_state = MOVE;
				move_decr = 1'b1;
				end
		
		default: nxt_state = IDLE;
		endcase
	end
endmodule

  
  
