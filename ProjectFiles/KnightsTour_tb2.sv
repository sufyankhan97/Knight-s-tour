module KnightsTour_tb2();

	import tb_package::*;
    
	/////////////////////////////
	// Stimulus of type reg //
	/////////////////////////
	reg clk, RST_n;
	reg [15:0] cmd;
	reg send_cmd;
  
	///////////////////////////////////
	// Declare internal signals //
	/////////////////////////////////
	wire SS_n,SCLK,MOSI,MISO,INT;
	wire lftPWM1,lftPWM2,rghtPWM1,rghtPWM2;
	wire TX_RX, RX_TX;
	logic cmd_sent, clr_rx_rdy;
	logic resp_rdy;
	logic [7:0] resp;
	wire IR_en;
	wire lftIR_n,rghtIR_n,cntrIR_n;
	
	logic [15:0] data2send;

	//////////////////////
	// Instantiate DUT //
	////////////////////
	KnightsTour iDUT(.clk(clk), .RST_n(RST_n), .SS_n(SS_n), .SCLK(SCLK),
				   .MOSI(MOSI), .MISO(MISO), .INT(INT), .lftPWM1(lftPWM1),
				   .lftPWM2(lftPWM2), .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2),
				   .RX(TX_RX), .TX(RX_TX), .piezo(piezo), .piezo_n(piezo_n),
				   .IR_en(IR_en), .lftIR_n(lftIR_n), .rghtIR_n(rghtIR_n),
				   .cntrIR_n(cntrIR_n));
				  
	/////////////////////////////////////////////////////
	// Instantiate RemoteComm to send commands to DUT //
	///////////////////////////////////////////////////
	RemoteComm iRMT(.clk(clk), .rst_n(RST_n), .RX(RX_TX), .TX(TX_RX), .cmd(cmd),
					.send_cmd(send_cmd), .cmd_sent(cmd_sent), .resp_rdy(resp_rdy), .resp(resp), .clr_rx_rdy(clr_rx_rdy));
				   
	//////////////////////////////////////////////////////
	// Instantiate model of Knight Physics (and board) //
	////////////////////////////////////////////////////
	KnightPhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),
					  .MOSI(MOSI),.INT(INT),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
					  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),.IR_en(IR_en),
					  .lftIR_n(lftIR_n),.rghtIR_n(rghtIR_n),.cntrIR_n(cntrIR_n)); 
				   
	initial begin
		// initial clk and rst_n signals
		Init (.clk(clk), .rst_n(RST_n));
		
		/////////////////////////// calibrate gyro ///////////////////////////
		
		// send command for gyro calibration
		SendCmdBLE (.clk(clk), .cmd(cmd), .send_cmd(send_cmd), .cmd_sent(cmd_sent), .data(CALIBRATE));
		// wait for cal_done
		Wait4Sig (.clk(clk), .sig(iDUT.cal_done), .clks2wait(1000000));
		// compare response obtained from KnightsTour against expected value
		Wait4Sig (.clk(clk), .sig(resp_rdy), .clks2wait(1000000));
		VerifyResponse (.clk(clk), .resp(resp), .clear_resp(clr_rx_rdy), .data(COMM_COMPLETE));
		
		/////////////////////////// send move west 1 command ///////////////////////////
		
		MoveCmdGen (.fanfare(1'b0), .direction(WEST), .count(4'h1), .cmd(data2send));
		// send command for gyro calibration
		SendCmdBLE (.clk(clk), .cmd(cmd), .send_cmd(send_cmd), .cmd_sent(cmd_sent), .data(data2send));
		// compare response obtained from KnightsTour against expected value
		Wait4Sig (.clk(clk), .sig(resp_rdy), .clks2wait(10000000));
		VerifyResponse (.clk(clk), .resp(resp), .clear_resp(clr_rx_rdy), .data(COMM_COMPLETE));
		$stop();
	end

	always begin
		#5 clk = ~clk;
		end
		
endmodule