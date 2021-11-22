module cmd_proc_tb();

reg clk,rst_n;					// 50MHz clock and asynch active low reset
reg [15:0] cmd_uart, cmd;					// command from BLE
reg cmd_rdy;						// command ready
wire clr_cmd_rdy;					// mark command as consumed
logic send_resp;					// command finished, send_response via UART_wrapper/BT
logic strt_cal;						// initiate calibration of gyro
reg cal_done;						// calibration of gyro done
reg signed [11:0] heading;			// heading from gyro
reg heading_rdy;					// pulses high 1 clk for valid heading reading
reg lftIR;							// nudge error +
reg cntrIR;							// center IR reading (have I passed a line)
reg rghtIR;							// nudge error -
reg signed [11:0] error;			// error to PID (heading - desired_heading)
reg [9:0] frwrd;					// forward speed register
logic moving;						// asserted when moving (allows yaw integration)
logic tour_go;						// pulse to initiate TourCmd block
logic fanfare_go;					// kick off the "Charge!" fanfare on piezo

wire rmc_to_uart, uart_to_rmc, tx_done, cmd_sent, resp_rdy, rdy, SS_n,SCLK,MOSI;
reg clr_rx_rdy;
wire [7:0] resp;
reg send_cmd, MISO, INT;

cmd_proc cmd_DUT(.clk(clk),.rst_n(rst_n),.cmd(cmd_uart),.cmd_rdy(cmd_rdy),
				.cal_done(cal_done),.heading(heading),.heading_rdy(heading_rdy),.lftIR(lftIR),.cntrIR(cntrIR),.rghtIR(rghtIR),
				.clr_cmd_rdy(clr_cmd_rdy),.send_resp(send_resp),.strt_cal(strt_cal),
                .error(error),.frwrd(frwrd),.moving(moving),.tour_go(tour_go),.fanfare_go(fanfare_go));
			
UART_wrapper wrapper_DUT(.clk(clk), .rst_n(rst_n), .clr_cmd_rdy(clr_cmd_rdy), .trmt(send_resp), .resp(8'hA5), 
						.RX(rmc_to_uart), 
						.cmd_rdy(cmd_rdy), .cmd(cmd_uart), .tx_done(tx_done), .TX(uart_to_rmc));
						
		
					
RemoteComm rc_DUT(.clk(clk), .rst_n(rst_n), .RX(uart_to_rmc), .TX(rmc_to_uart), .cmd(cmd), .send_cmd(send_cmd), .cmd_sent(cmd_sent), .clr_rx_rdy(clr_rx_rdy),
					.resp_rdy(resp_rdy), .resp(resp));


inert_intf inert_DUT(.clk(clk),.rst_n(rst_n),.strt_cal(strt_cal),.cal_done(cal_done),.heading(heading),.rdy(heading_rdy),.lftIR(lftIR),
                  .rghtIR(rghtIR),.SS_n(SS_n),.SCLK(SCLK),.MOSI(MOSI),.MISO(MISO),.INT(INT),.moving(moving));

					
SPI_iNEMO2 nemo_DUT(.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),.MOSI(MOSI),.INT(INT));
  
				
initial
begin
clk = 0 ;
rst_n = 0;
cntrIR = 0;
send_cmd = 0;
clr_rx_rdy = 0;
lftIR = 0;
rghtIR = 0;

@(posedge clk);
@(negedge clk);
rst_n = 1;


cmd = 16'h0000;
send_cmd = 1;
strt_cal = 1;

@(posedge clk);
send_cmd = 0;
strt_cal = 0;

fork 
begin : timeout_cal_done					//wait for done
		repeat(700000) @(posedge clk);
		$display("ERROR:timed out waiting for cal_done");
		$stop;
end
begin
	@(posedge cal_done);
	disable timeout_cal_done; 
end
join

fork 
begin : timeout_resp_rdy					//wait for done
		repeat(70000) @(posedge clk);
		$display("ERROR:timed out waiting for cal_done");
		$stop;
end
begin
	@(posedge resp_rdy);
	disable timeout_resp_rdy; 
end
join


cmd = 16'h2001;
send_cmd = 1;

@(posedge clk);
send_cmd = 0;


fork 
begin : timeout_cmd_snt					//wait for done
		repeat(70000) @(posedge clk);
		$display("ERROR:timed out waiting for cal_done");
		$stop;
end
begin
	@(posedge cmd_sent);
	disable timeout_cmd_snt; 
end
join

if(frwrd != 10'h000);
begin
	$display("forward not 0 after waiting for cmd sent");
	$stop();
end
repeat (10)	@(posedge heading_rdy);

if(frwrd != 10'h120 || frwrd != 10'h140)
begin
	$display("forward not 120/140 after waiting for cmd sent");
	$stop();
end

if(~moving)
begin
	$display("moving not asserted");
	$stop();
end

repeat (20)	@(posedge heading_rdy);

cntrIR = 1;

@(posedge clk);
cntrIR = 0;

repeat (50) @(posedge clk);

cntrIR = 1;

@(posedge clk);
cntrIR = 0;

fork 
begin : timeout_resp_rdy_2				//wait for done
		repeat(70000) @(posedge clk);
		$display("ERROR:timed out waiting for resp_rdy 2");
		$stop;
end
begin
	@(posedge resp_rdy);
	disable timeout_cmd_snt; 
end
join



repeat (5) @(posedge clk);
$stop();
end


always
	#5 clk = ~clk;
	
endmodule