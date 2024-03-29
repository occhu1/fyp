//This verilog file is used to program the FPGA with the purpose of sending a PRBS-generated signal to a DAC.
//4 bit lengths are implemented in this module; 7, 11, 15 and 31. Though only the 7-bit pattern could be sent to the DAC interface.
//The initial PRBS bit length is 7 bits.
//The push buttons KEY[1] and KEY[3] are used to initiate the PRBS and change the pattern generation respectively.
//The 2 left-most 7 segment displays are used to display the PRBS bit length while the rest are used to display the first few values of the pattern in hexadecimal.
//The PRBS sequence is sent to the DAC interface through the GPIO_1 port.
//A second pattern generator is implemented for error checking.
module sender(GPIO_1, GPIO_0, CLOCK_50, KEY, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7, LEDG, LEDR);
	input  [35:0]	GPIO_0;
	input  [3:0]	KEY;
	input 			CLOCK_50;
	
	output [35:0]	GPIO_1;
	output [6:0]  	HEX0;
	output [6:0]   HEX1;
	output [6:0] 	HEX2;
	output [6:0] 	HEX3;
	output [6:0]	HEX4;
	output [6:0] 	HEX5;
	output [6:0] 	HEX6;
	output [6:0] 	HEX7;
	output [3:0] 	LEDG;
	output [3:0] 	LEDR;
	
	//Registers for the 4 PRBS, length selector, error checkers, flags, saving the generated patterns and clocks.
	reg [6:0]	prbs07;
	reg [10:0]	prbs11;
	reg [14:0]	prbs15;
	reg [30:0]	prbs31;
	reg [6:0]	error07;
	reg [7:0]	result;
	reg [3:0]  	sel_1;
	reg [3:0]  	sel_2;
	reg		  	error;
	reg		  	flag;
	reg		  	seq_send;
	reg [126:0] seq_receive;
	reg [20:0] 	alt_clk;
	reg		  	checkout;
	reg		  	shft_bgn;
	reg		  	old_shft;
	reg [7:0]  	buffer;
	reg [126:0]	pattern;
	reg			sendover;
	reg [7:0]	display;
	reg [126:0]	err_seq;
	
	//Initial values of registers that shouldn't start with 0.
	initial prbs07		 =    1'b1;
	initial prbs11		 =    1'b1;
	initial prbs15		 =    1'b1;
	initial prbs31		 =    1'b1;
	initial sel_1		 = 4'b0000;
	initial sel_2		 = 4'b0111;
	initial result 	 =    1'b1;
	
	integer select		 =			0;
	integer old_select =			0;
	integer error_cntr =			0;
	integer flag_cntr  =			0;
	integer error_chkr = 		0;
	integer shft_cntr	 = 		0;
	integer batch_cntr =			0;
	integer old_batch	 =			0;
	integer ele_num	 =			0;
	
	always @ (posedge KEY[3])
	begin
	//Event that occurs when KEY3 is pressed. The current length selector state is saved to old_select and a FSM is implemented to find the next bit length.
	//sel_1 and sel_2 are used to output the bit length value to the 7 segment displays.
	//The selector values 00 represent 7 bits, 01 represent 11 bits, 10 represent 15 bits and 11 represent 31 bits.
	//Resets the error checker.
	old_select 	= select;
		case(old_select)
		2'b00 : begin
				select =   		1;
				sel_1  = 4'b0001;
				sel_2  = 4'b0001;
			 end
		2'b01 : begin
				select =   		2;
				sel_1  = 4'b0001;
				sel_2  = 4'b0101;
			  end
		2'b10 : begin
				select =   		3;
				sel_1  = 4'b0011;
				sel_2  = 4'b0001;
			  end
		2'b11 : begin
				select =   		0;
				sel_1  = 4'b0000;
				sel_2  = 4'b0111;
			  end
		default : begin
				select =   		0;
				sel_1  = 4'b0001;
				sel_2  = 4'b0111;
			  end
			  endcase
	end
	
	always @ (posedge KEY[1])
	begin
	//Event when KEY1 is pressed. Triggers the PRBS shift sequence to begin.
		shft_bgn = shft_bgn + 1'b1;
	end
	
	always @ (*)
	begin
	//Constantly checks the bit length selector and displays the appropriate PRBS
		case (select)
		2'b00 : begin
					display = 1'b0;
					display = prbs07;
				end
		2'b01 : begin
					display = 1'b0;
					display = prbs11;
				end
		2'b10 : begin
					display = 1'b0;
					display = prbs15;
					end
		2'b11 : begin
					display = 1'b0;
					display = prbs31;
				end
		endcase
	end
	
	always @ (posedge CLOCK_50)
	begin
	//Increments the alt_clk register so other functions can operate at slower clock speeds
		alt_clk 	= alt_clk + 1;
	end
	
	always @	(posedge alt_clk[7])
	begin
	//If KEY[1] was pressed previously, the 7 bit PRBS will start sequencing until it's been run (2^7)-1 times, each time saving the MSB to a separate register for later use
	//Once the PRBS shifting process is complete, the FPGA will loop the data back to itself at a rate of 12.5MHz and will also send the data to the other FPGA at a rate of 6.25MHz for error checking
		
		if(shft_bgn ^ old_shft)						//Initiates the bit shift sequence for the PRBS
		begin
			buffer[shft_cntr] 	= prbs07[6];
			pattern[ele_num] 		= prbs07[6];
			err_seq[ele_num] 		= error07[6];
			prbs07 					= {prbs07[5:0], prbs07[6] ^ prbs07[5]};
			error07 					= {error07[5:0], error07[6] ^ error07[5]};
			shft_cntr 				= shft_cntr + 1;
			ele_num 					= ele_num + 1;
		end
		
		if(shft_cntr >= 8)							//Every 8 bit shifts, the PRBS will push the result to the data bus (called "buffer")
		begin
			result 		= buffer;
			shft_cntr 	= 0;
			batch_cntr 	= batch_cntr + 1;
		end
		
		if(batch_cntr >= 15 && shft_cntr >= 7)	//When the shifting sequence is complete, everything is reset and the second error checker is activated.
		begin
			result 		= buffer;
			shft_cntr 	= 0;
			batch_cntr 	= 0;
			old_shft 	= shft_bgn;
			ele_num 		= 0;
			sendover 	= 1'b1;
		end
						
		seq_send = pattern[error_cntr];			//Loops the data back to itself for error checking
		
		if(sendover)									//The second error checker, the one that sends data over to the other FPGA directly. A simple header of sending over a 1 followed by a 0 is used to tell the other FPGA to start reading the data on the bus
		begin
			case (error_chkr)
			0  		: checkout = 1'b1;
			1  		: checkout = 1'b0;
			default	: checkout = pattern[error_chkr - 2];
			endcase
			
			error_chkr = error_chkr + 1;
			
			if(error_chkr >= 129)
			begin
				error_chkr 	= 		0;
				checkout 	= 	1'b0;
				sendover 	= 	1'b0;
			end
		end
	end
	
	always @(negedge alt_clk[7])
	begin
	//Reads the data sent by the first error checker until 127 bits are collected. It's then compared to a pattern generated previously to see if there are any errors.
		seq_receive[error_cntr] = GPIO_0[1];
		error_cntr 					= error_cntr + 1;
		
		if(error_cntr >= 127)
		begin
			error 		= !(seq_receive == err_seq);
			error_cntr 	= 0;
		end
	end
	
	always @(posedge alt_clk[8])
	begin
	//A flag will be triggered every 8 bit shifts to turn the DAC on and read the data bus.
		flag = 1'b0;
		
		if(batch_cntr != old_batch)
		begin
			flag = 1'b1;
			old_batch = batch_cntr;
		end
		
		if(old_shft == shft_bgn)
			old_batch = 0;
	end
	
	//A submodule is implemented to find the correct values for the 7 segment displays and outputs the result to the appropriate display.			
	hexconverter h1(pattern[3:0]  , HEX0);
	hexconverter h2(pattern[7:4]  , HEX1);
	hexconverter h3(pattern[11:8]	, HEX2);
	hexconverter h4(pattern[15:12], HEX3);
	hexconverter h5(pattern[19:16], HEX4);
	hexconverter h6(pattern[23:20], HEX5);
	hexconverter h7(sel_2			, HEX6);
	hexconverter h8(sel_1			, HEX7);
	
	
	//The data within the result register will sent to the DAC interface through the GPIO_1 port.
	//GPIO_1[0] will be used to loop back the result sequence for error checking within the FPGA.
	//Assigns key press of the push buttons to the green LEDs for key stroke detection.
	//The red LEDs LEDR[3:0] are used for error checking. LEDR[1:0] will light up if there are no errors and LEDR[3:2] will light up if there are any errors.
	assign GPIO_1[0]  = seq_send;
	assign GPIO_1[2]	= checkout;
	assign GPIO_1[4]	= checkout;
	assign GPIO_1[1]  = result[0];
	assign GPIO_1[3]  = result[1];
	assign GPIO_1[5]  = result[2];
	assign GPIO_1[7]  = result[3];
	assign GPIO_1[9]  = result[4];
	assign GPIO_1[11] = result[5];
	assign GPIO_1[13] = result[6];
	assign GPIO_1[15] = result[7];
	assign GPIO_1[19] = flag;
	assign LEDG[3:0]  = ~KEY[3:0];
	assign LEDR[0] 	= ~error;
	assign LEDR[1]		= ~error;
	assign LEDR[2] 	= error;
	assign LEDR[3] 	= error;
	
		
	nios_system nios_system_inst
	(
	.clk_clk(CLOCK_50),
	.reset_reset_n(KEY[0])
		);
		
endmodule

//Submodule to find the 7-bit values to output to the 7 segment displays.
module hexconverter(digit, hexout);
	input [3:0] digit;
	output [6:0] hexout;
	reg [6:0] hexout;

	always @(*)
	begin
		case (digit)
		4'b0000 : hexout = 7'b1000000;
		4'b0001 : hexout = 7'b1111001;
		4'b0010 : hexout = 7'b0100100;
		4'b0011 : hexout = 7'b0110000;
		4'b0100 : hexout = 7'b0011001;
		4'b0101 : hexout = 7'b0010010;
		4'b0110 : hexout = 7'b0000010;
		4'b0111 : hexout = 7'b1111000;
		4'b1000 : hexout = 7'b0000000;
		4'b1001 : hexout = 7'b0010000;
		4'b1010 : hexout = 7'b0001000;
		4'b1011 : hexout = 7'b0000011;
		4'b1100 : hexout = 7'b1000110;
		4'b1101 : hexout = 7'b0100001;
		4'b1110 : hexout = 7'b0000110;
		4'b1111 : hexout = 7'b0001110;
		default : hexout = 7'b1111111;
		endcase
	end

endmodule
