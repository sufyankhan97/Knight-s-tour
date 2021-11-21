module commTB();
	// declare module inputs as regs and outputs as wires
	reg clk, rst_n;
	wire RX_TX, TX_RX;	// TX and RX bytes of RemoteComm and UART_wrapper. TX of one is RX of other
	reg [15:0] cmd_in;	// two bytes to be sent over UART 
	reg send_cmd;		// set high to begin cmd_in transimission
	reg clr_rx_rdy1;	// to clear RX recieved in RemoteComm. Set as 0
	logic cmd_sent;		// high when cmd transimission is complete
	// wire resp_rdy;		// high when RX byte is ready
	// wire [7:0] resp_RC;	// RX byte
	
	logic cmd_rdy;			// high when cmd_out is ready
	wire [15:0] cmd_out;	// 16 bit output recieved over UART
	reg clr_cmd_rdy;		// set high to begin receiving next cmd
	reg trmt;				// set high to begin transimission. Set as 0
	reg [7:0] resp_UW;		// bit to be transimitted over UART
	
	

	// instantiate RemoteComm and UART_wrapper
	RemoteComm iNST1(.clk(clk), .rst_n(rst_n), .RX(RX_TX), .TX(TX_RX), .cmd(cmd_in), .send_cmd(send_cmd), 
					 .clr_rx_rdy(clr_rx_rdy1), .cmd_sent(cmd_sent), .resp_rdy(), .resp());
					 
	UART_wrapper iNST2(.cmd_rdy(cmd_rdy), .cmd(cmd_out), .tx_done(), .TX(RX_TX), .clk(clk), 
						.rst_n(rst_n), .clr_cmd_rdy(clr_cmd_rdy), .trmt(trmt), .resp(resp_UW), .RX(TX_RX));
	
	//////////////// test bench ///////////////////
	initial begin
		clk = 0;
		rst_n = 0;
		trmt = 0;				// not used
		clr_rx_rdy1 = 0;		// not used
		cmd_in = 16'h0000;
		send_cmd = 0;
		clr_cmd_rdy = 0;		
		resp_UW = 8'h00;		// not used	
		
		@(negedge clk); 		// delay
		rst_n = 1; 				// de-assert reset
		
		///////////////// first byte test //////////////////
		cmd_in = 16'h1234;
		send_cmd = 1;
		
		@(posedge clk);
		@(negedge clk); 			// delay
		send_cmd = 0; 				// de-assert transmitting
		
		wait4sig(cmd_rdy, 100000);	// sample rx_data when UART_rx says data is ready
		if (cmd_out !==16'h1234) begin
			$display("You messed up");
			$stop;	end
		
		repeat(5)@(posedge clk);
		clr_cmd_rdy = 1;			// clear ready after data has been read
		repeat(5)@(posedge clk); 	// delay
		clr_cmd_rdy = 0; 			// de-assert RX clear
		
		wait4sig(cmd_sent, 100000); // wait until transimission is complete
		repeat(5)@(posedge clk);	// delay
		
		///////////////// second byte test //////////////////
		cmd_in = 16'hAF82;
		send_cmd = 1;

		@(posedge clk);
		@(negedge clk); 			// delay
		send_cmd = 0; 				// de-assert transmitting

		wait4sig(cmd_rdy, 100000);	// sample rx_data when UART_rx says data is ready
		if (cmd_out !==16'hAF82) begin
			$display("You messed up");
			$stop;	end
		
		clr_cmd_rdy = 1;			// clear ready after data has been read
		@(posedge clk); 			// delay
		@(negedge clk); 			// delay
		clr_cmd_rdy = 0; 			// de-assert RX clear
		
		$display("All good!");
		$stop;
	end

	always
		#10 clk = ~clk;
	
	// task to check if signal rises within clks2wait clk cycles
	task automatic wait4sig(ref sig, input int clks2wait);
    fork
        begin: timeout
            repeat(clks2wait) @(posedge clk);
            $display("ERR: timed out waiting for sig in wait4sig");
		$stop();
        end
        begin
            @(posedge sig);	// signal of interest asserted
            disable timeout;
        end
    join
	endtask
	
endmodule
