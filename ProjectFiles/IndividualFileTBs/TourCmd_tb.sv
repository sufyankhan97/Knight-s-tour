module TourCmd_tb();

  reg clk,rst_n;			// 50MHz clock and asynch active low reset
  reg start_tour;			// from done signal from TourLogic
  reg [7:0] move;			// encoded 1-hot move to perform
  reg [15:0] cmd_UART;		// cmd from UART_wrapper
  reg cmd_rdy_UART;			// cmd_rdy from UART_wrapper
  reg clr_cmd_rdy;			// from cmd_proc (goes to UART_wrapper too)
  reg send_resp;			// lets us know cmd_proc is done with command
  
  wire [7:0] resp;		// either 0xA5 (done) or 0x5A (in progress)
  wire  [4:0] mv_indx;	// "address" to access next move
  wire [15:0] cmd;		// multiplexed cmd to cmd_proc
  wire cmd_rdy;			// cmd_rdy signal to cmd_proc
  
TourCmd dut(.clk(clk),.rst_n(rst_n),.start_tour(start_tour),.move(move),.mv_indx(mv_indx),
               .cmd_UART(cmd_UART),.cmd(cmd),.cmd_rdy_UART(cmd_rdy_UART),.cmd_rdy(cmd_rdy),
			   .clr_cmd_rdy(clr_cmd_rdy),.send_resp(send_resp),.resp(resp));

initial
begin
clk 			=	1'b0 	;
rst_n 			=	1'b0	;
start_tour		=	1'b0	;
//move 			=	8'h0	;
cmd_UART		=	16'habcd;
cmd_rdy_UART	=	0		;
clr_cmd_rdy		=	0		;	
send_resp		=	1'b0	;

@(posedge	clk);
@(negedge	clk);
rst_n	=	1'b1;

repeat (5) @(posedge	clk);

//initial state
$display("	Initial state, cmd = %h, expected abcd, resp = %h expected 0, mv_indx = %h, expected 0, cmd_rdy = %h, expected 0", cmd,resp,mv_indx,cmd_rdy);

//move = 8'b00000001;

//starting tour
start_tour	=	1'b1;

@(posedge clk);
start_tour = 1'b0;

/* @(posedge clk);
clr_cmd_rdy = 1;
@(posedge clk);
@(negedge clk);
clr_cmd_rdy = 1'b0;
repeat (5) @(posedge	clk);
send_resp = 1'b1; */

repeat (50) @(posedge	clk);

//$stop();
end

always @(posedge clk)
	if(resp == 8'hA5)
		$stop();

always
#5	clk	=	~clk;		

task change_move;
    input [4:0]mv_indx; 
    begin
		if(mv_indx == 5'd0)
			move = 8'b00000001;
		else if(mv_indx == 5'd3)
			move = 8'b00000010;
		else if(mv_indx == 5'd6)
			move = 8'b00000100;
		else if(mv_indx == 5'd9)
			move = 8'b00001000;
		else if(mv_indx == 5'd12)
			move = 8'b00010000;
		else if(mv_indx == 5'd15)
			move = 8'b00100000;
		else if(mv_indx == 5'd18)
			move = 8'b01000000;
		else if(mv_indx == 5'd20)
			move = 8'b10000000;
    end
  endtask
    
always @(posedge clk)
 change_move(mv_indx);
 
always @(posedge cmd_rdy)
begin
//@(posedge clk);

clr_cmd_rdy = 1;
@(posedge clk);

//@(negedge clk);
clr_cmd_rdy = 1'b0;

repeat (5) @(posedge	clk);
send_resp = 1'b1;

@(posedge clk)
send_resp = 1'b0;
end
endmodule
