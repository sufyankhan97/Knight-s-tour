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
  logic [7:0] vertical, horizontal;
  logic [15:0] cmd_out;
  logic mv_indx_nudge;
  logic mv_indx_rst;
  logic vert_mov;
  logic [3:0] vert_num, horz_num;
  
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

always_comb
begin

next_state = state;
cmd_rdy = 0;
cmd = 8'hXX;  // possible cause for error
usurp = 0;
mv_indx_nudge = 0;
mv_indx_rst = 0;
vert_mov = 0;

case(state)

IDLE : 
	if (start_tour)
	begin
		next_state = VERT;
		mv_indx_rst = 1;
	end

VERT : 
begin
	cmd_rdy = 1;
	usurp = 1;
	vert_mov = 1;
	if (clr_cmd_rdy)
	begin
		next_state = VERT_MOVE;
	end
end

VERT_MOVE :
begin 
	usurp = 1;
	vert_mov = 1;
	if (send_resp)
	begin
		next_state = HORI;
	end
end

HORI :
begin
	usurp = 1;
	cmd_rdy = 1;
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
		if (mv_indx == 23)
			next_state = IDLE;
		else
		begin
		next_state = VERT;
		mv_indx_nudge = 1;
		end
	end
end

endcase
end


// move decompose
always_comb
begin

case(move)

8'h0 : 
begin
        vert_num = 4'h2;
	vertical = 8'h00;
        horz_num = 4'h1;
	horizontal = 8'h3F;
end

8'h1 : 
begin
	vert_num = 4'h2;
	vertical = 8'h00;
	horz_num = 4'h1;
	horizontal = 8'hBF;
	
end

8'h2 : 
begin
	vert_num = 4'h1;
	vertical = 8'h00;
	horz_num = 4'h2;
	horizontal = 8'h3F;
end

8'h3 : 
begin
	vert_num = 4'h1;
	vertical = 8'h7F;
	horz_num = 4'h2;
	horizontal = 8'h3F;
end

8'h4 : 
begin
	vert_num = 4'h2;
	vertical = 8'h7F;
	horz_num = 4'h1;
	horizontal = 8'h3F;
end

8'h5 : 
begin
	vert_num = 4'h2;
	vertical = 8'h7F;
	horz_num = 4'h1;
	horizontal = 8'hBF;
end

8'h6 : 
begin
	vert_num = 4'h1;
	vertical = 8'h7F;
	horz_num = 4'h2;
	horizontal = 8'hBF;
end

8'h7 : 
begin
	vert_num = 4'h1;
	vertical = 8'h00;
	horz_num = 4'h2;
	horizontal = 8'hBF;
end

endcase

end

// MUX to select b/w UART and TourCmd SM
assign cmd_out = (usurp&vert_mov)? {4'h2,vertical,vert_num} :
                 (usurp) ?  {4'h3,horizontal,horz_num} : cmd_UART;   
assign cmd_rdy_out = usurp ? cmd_rdy : cmd_rdy_UART;

// MUX to select response 
assign resp = (usurp & (mv_indx == 5'd23)) ? 8'hA5 : 8'h5A ;

 
endmodule
