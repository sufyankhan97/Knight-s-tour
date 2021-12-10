module TourCmd(clk,rst_n,start_tour,move,mv_indx,
               cmd_UART,cmd,cmd_rdy_UART,cmd_rdy,
			   clr_cmd_rdy,send_resp,resp);

  input clk,rst_n;			// 50MHz clock and asynch active low reset
  input start_tour;			// from done signal from TourLogic
  input [7:0] move;			// encoded 1-hot move to perform
  output reg [4:0] mv_indx;	// "address" to access next move
  input [15:0] cmd_UART;	// cmd from UART_wrapper
  input cmd_rdy_UART;		// cmd_rdy from UART_wrapper
  output logic [15:0] cmd;		// multiplexed cmd to cmd_proc
  output logic cmd_rdy;			// cmd_rdy signal to cmd_proc
  input clr_cmd_rdy;		// from cmd_proc (goes to UART_wrapper too)
  input send_resp;			// lets us know cmd_proc is done with command
  output [7:0] resp;		// either 0xA5 (done) or 0x5A (in progress)

  logic usurp; // select signal to choose b/w UART wrapper & TourCmd SM
  logic [7:0] vertical, horizontal;  //horizontal and vertical heading
  logic cmd_rdy_out;  //to assert final cmd_rdy
  logic mv_indx_nudge; //to start move index count
  logic mv_indx_rst; //to reset move index value
  logic vert_mov; //indicates whether the move was vertical or hortizontal
  logic [3:0] vert_num, horz_num; //number of squares to move
  
// move index counter
always_ff @(posedge clk, negedge rst_n)
begin
	if(!rst_n)
		mv_indx = 5'h00;
	else if (mv_indx_rst)
		mv_indx = 5'h00;
	else if (mv_indx_nudge)
		mv_indx = mv_indx + 1;
end


// Declaring states for State Machine
typedef enum reg [2:0]{IDLE, VERT, VERT_MOVE, HORI, HORI_MOVE} state_t;
state_t state, next_state;

always_ff @(posedge clk, negedge rst_n)
begin
	if (!rst_n)
		state <= IDLE;
	else
		state <= next_state;
end

always_comb
begin

next_state = state;
cmd_rdy_out = 0;
usurp = 0;
mv_indx_nudge = 0;
mv_indx_rst = 0;
vert_mov = 0;

case(state)

IDLE : 				
	if (start_tour) 		//asserted by TourLogic
	begin
		next_state = VERT; 	//first vertical move
		mv_indx_rst = 1; 	//reset index to start counting
	end

VERT : 
begin
	cmd_rdy_out = 1; 		//indicates cmd is ready for cmd proc
	usurp = 1; 				//control usurped by SM
	vert_mov = 1; 			//indicates the move made is vertical
	if (clr_cmd_rdy)
	begin
		next_state = VERT_MOVE;
	end
end

VERT_MOVE :
begin 
	usurp = 1;
	vert_mov = 1;
	if (send_resp) 			//if cmd_proc is done processing latest command, goes to next state
	begin
		next_state = HORI;
	end
end

HORI :
begin
	usurp = 1;
	cmd_rdy_out = 1;
	if (clr_cmd_rdy)
	begin
		next_state = HORI_MOVE;
	end
end


HORI_MOVE :
begin
	usurp = 1;
	if (send_resp)
	begin
		if (mv_indx == 23) //final move
			next_state = IDLE;
		else
		begin
		next_state = VERT;
		mv_indx_nudge = 1; //increase the move index and read cmds until the 23rd move
		end
	end
end

endcase
end


// move decompose
//calculating horizontal and vertical heading and the
//number of horizontal and vertical squares to move
	//refer page no 3 and 12 from Ex23_KnightsTour pdf for the values
always_comb
begin
	
case(move) //encoded move to perform

8'h1 : 
begin
        vert_num = 4'h2; //move two squares vertically
	vertical = 8'h00;	 //move north (+Y)
        horz_num = 4'h1; //move one square horizontally
	horizontal = 8'h3F;  //move west (-X)
end

8'h2 : 
begin
	vert_num = 4'h2;
	vertical = 8'h00;
	horz_num = 4'h1;
	horizontal = 8'hBF; //move east (+X)
	
end

8'h4 : 
begin
	vert_num = 4'h1;
	vertical = 8'h00;
	horz_num = 4'h2;
	horizontal = 8'h3F;
end

8'h8 : 
begin
	vert_num = 4'h1;
	vertical = 8'h7F; //move south (-Y)
	horz_num = 4'h2;
	horizontal = 8'h3F;
end

8'h10 : 
begin
	vert_num = 4'h2;
	vertical = 8'h7F;
	horz_num = 4'h1;
	horizontal = 8'h3F;
end

8'h20 : 
begin
	vert_num = 4'h2;
	vertical = 8'h7F;
	horz_num = 4'h1;
	horizontal = 8'hBF;
end

8'h40 : 
begin
	vert_num = 4'h1;
	vertical = 8'h7F;
	horz_num = 4'h2;
	horizontal = 8'hBF;
end

8'h80 : 
begin
	vert_num = 4'h1;
	vertical = 8'h00;
	horz_num = 4'h2;
	horizontal = 8'hBF;
end
	
default : // default state to prevent latch in synthesis
begin
	vert_num = 4'hX;
	vertical = 8'hXX;
	horz_num = 4'hX;
	horizontal = 8'hXX;
end

endcase

end

// MUX to select b/w UART and TourCmd SM depending on whether control is usurped by TourCmd SM
	//command = Vertical(2)/horizontal(3) (without/with charge) selection + heading + no of squares to move
assign cmd = (usurp & vert_mov)? {4'h2,vertical,vert_num} :
                 (usurp) ?  {4'h3,horizontal,horz_num} : cmd_UART;   
assign cmd_rdy = usurp ? cmd_rdy_out : cmd_rdy_UART;

// MUX to set response
	//If cmd was from UART_wrapper, or was last command of the tour then response is 8’hA5,
	//otherwise 8’h5A, if intermediate move of the tour
assign resp = !usurp ? 8'hA5 : (mv_indx == 5'd23) ? 8'hA5 : 8'h5A;
 
endmodule
