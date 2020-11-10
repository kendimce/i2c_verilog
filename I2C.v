`timescale 1ns/1ps
module acceloremeter_i2c(SCLK,CS,clk,SDA,alt_address,LED_out_first,LED_out_second,LED_out_third, LED_out_fourth);

input wire clk;

output reg CS;
inout reg alt_address;

inout reg SDA;
output wire SCLK;

output reg[6:0] LED_out_first; //7 segmentS
output reg[6:0] LED_out_second; //7 segmentS
output reg[6:0] LED_out_third; //7 segmentS
output reg[6:0] LED_out_fourth; //7 segmentS
reg [3:0] LED_BCD [3:0]; //bcd

localparam OP_STAND_BY=0;
localparam OP_START=1;
localparam OP_STOP=9;
localparam OP_ADDRESS=2;
localparam OP_CODE=0;			//READ-WRITE
localparam OP_ACK=3;
localparam OP_BEFORE_STOP=8;

reg [6:0] slave_address;
reg [5:0] state; //3 bit state/.

reg [6:0] ADDR;
reg [7:0] INTERNAL_REG;
reg [7:0] INTERNAL_DATA;
reg [7:0] data_from_slave;		//INCOMING DATA
reg operation;


reg [7:0] power_ctl;			// WAKE UP THE SENSOR
reg [7:0] measuring_enable;

reg [7:0] axis_data_format_register;	//DATA FORMAT REGISTER
reg [7:0] axis_data_format;				// DATA FORMAT

reg [7:0] axis_data_read_register;		//AXIS REGISTERS


integer count;

integer clock_counter;		//CLOCK DIVIDER
reg clk_enable;

reg sclk_enable;

reg [3:0] op_counter;
reg SENT_BY_READ;


initial
begin
CS<=1; 		//Set to I2C Mode in Accelerometer Should be connected to VDDIO
alt_address<=1;
slave_address<=7'h1D;//7'h53

clock_counter<=0;
sclk_enable<=0;
clk_enable<=0;

op_counter<=0;
operation<=OP_CODE;
SENT_BY_READ<=0;
count<=6;
state<=OP_STAND_BY;

power_ctl<=8'h2D;			// WAKE UP THE SENSOR AND ENABLE MEASURING
measuring_enable<=8'h08; //MEASURING DATA FORMAT

axis_data_format_register<=8'h31;
axis_data_format<=8'h02;

axis_data_read_register<=8'h36;

end

always@(posedge clk)
begin
		if(clock_counter==150)
		begin

			clk_enable<=~clk_enable;
			clock_counter<=0;
		end

		else
		begin
			clock_counter<=clock_counter+1;

		end
end

always @ (negedge clk_enable)
begin
		if((state==OP_START) || (state==OP_STAND_BY) || (state==OP_STOP))
		begin
		sclk_enable<=0;
		end
		
		else
		begin
		
		sclk_enable<=1;
		
		end
end

assign SCLK = (sclk_enable==0) ? 1: ~clk_enable;



always @(*)
begin

			case(op_counter)

				0:
				begin
				
				// Wake up + measuring enable
				
				ADDR<=slave_address;
				INTERNAL_REG <= power_ctl;
				INTERNAL_DATA <= measuring_enable;
				end
				
				
				1:
				begin
				
				// READING AXIS DATA
				ADDR<=slave_address;
				INTERNAL_REG <= axis_data_read_register;
				
				end


			endcase
end



always@(posedge clk_enable)
begin		
		
		case(state)
		
				OP_STAND_BY:		//STAND BY MODE
				begin

						SDA<=1;
						state<=OP_START;
				end
					
				OP_START:		//START CONDITION
				begin
				
						SDA<=0;
						state<= OP_ADDRESS;
			
				end
		
		
				OP_ADDRESS:
				begin
						#1
						if(count>=0 )
						begin
					
							SDA <= ADDR[count];  //SLAVE_ADDRESS
							count<=count-1;
					
						end
		
						else
						begin
							if(SENT_BY_READ==1)
							begin	

								operation<=~OP_CODE;	//READ
								SDA<=~OP_CODE;  		//WRITE
							end

							else
							begin

								operation<=OP_CODE; //WRITE
								SDA<= OP_CODE;  		//WRITE
					
							end

								
								state<= OP_ACK;
						end
				end
		

				OP_ACK:
				begin	
					
					if(operation==1)
					begin
						
						SDA<=1'bz;
						state<=13;
						count<=7;

					end
					else
					begin	
						//ACK
						SDA<=1'bz;
						count<=7;
						state<=10;
							end
						
				end
		
	
		10:
		begin
				if(count>=0)
				begin
						
						SDA <= INTERNAL_REG[count];  // INTERNAL REGISTER_ADDRESS
						count<=count-1;
			
				end
		
				else
				begin
						SDA<=1'bz;   //ACK
					
						// CHOOSE READ OPERATION OR WRITE OPERATION 
						if(op_counter == 0)
						begin
								//WRITE
								count<=7;
								state<=11;  
								
						end
			
						else if(op_counter == 1)
						begin
						
						//READ
						count<=6;
						state<=OP_STAND_BY;
						SENT_BY_READ <=1;
			
						end

				end
		end
	
		
		11:
		begin
			if(count>=0)
			begin
			SDA <= INTERNAL_DATA[count];  // MEASURE ENABLE
			count<=count-1;
			end
		
			else
			begin
			//ACK
			SDA<=1'bz;
			state<=OP_BEFORE_STOP;  
			count<=6;
			end
		end
	
		
		13:
		begin
					if(count>=0)
					begin
								
							data_from_slave[count]<=SDA;
							count<=count-1;
		
					end
					
					else
					begin
							LED_BCD[0]<= data_from_slave[3:0];
							LED_BCD[1]<= data_from_slave[7:4];
							//NACK
							SDA<=1;
							state<=OP_BEFORE_STOP;  
							count<=6;
					
					end
			
			end

		
			OP_BEFORE_STOP:
		begin

			if(op_counter==0)
			begin
					SDA<=0;
					state<=OP_STAND_BY;
					op_counter<=1;

			end

			else if(op_counter==1)
			begin
					
					state<=OP_STOP;
					SDA<=0;
			end
			
		end

		
			OP_STOP:
			begin		
					
					SDA<=1; //STOP
					state<=OP_STAND_BY;
				
			end
endcase
end


always @(*)
begin
 case(LED_BCD[0])
 4'b0000: LED_out_first = 7'b1000000; // "0"  
 4'b0001: LED_out_first = 7'b1111001; // "1" 
 4'b0010: LED_out_first = 7'b0100100; // "2" 
 4'b0011: LED_out_first = 7'b0110000; // "3" 
 4'b0100: LED_out_first = 7'b0011001; // "4" 
 4'b0101: LED_out_first = 7'b0010010; // "5" 
 4'b0110: LED_out_first = 7'b0000010; // "6" 
 4'b0111: LED_out_first = 7'b1111000; // "7" 
 4'b1000: LED_out_first = 7'b0000000; // "8"  
 4'b1001: LED_out_first = 7'b0010000; // "9" 
 4'b1010: LED_out_first = 7'b0001000; // "A" 
 4'b1011: LED_out_first = 7'b0000011; // "B" 
 4'b1100: LED_out_first = 7'b1000110; // "C" 
 4'b1101: LED_out_first = 7'b0100001; // "D" 
 4'b1110: LED_out_first = 7'b0000110; // "E"
 4'b1111: LED_out_first = 7'b0001110; // "F" 
 default: LED_out_first = 7'b1000000; // "0"
 endcase
end


always @(*)
begin
 case(LED_BCD[1])
 4'b0000: LED_out_second = 7'b1000000; // "0"  
 4'b0001: LED_out_second = 7'b1111001; // "1" 
 4'b0010: LED_out_second = 7'b0100100; // "2" 
 4'b0011: LED_out_second = 7'b0110000; // "3" 
 4'b0100: LED_out_second = 7'b0011001; // "4" 
 4'b0101: LED_out_second = 7'b0010010; // "5" 
 4'b0110: LED_out_second = 7'b0000010; // "6" 
 4'b0111: LED_out_second = 7'b1111000; // "7" 
 4'b1000: LED_out_second = 7'b0000000; // "8"  
 4'b1001: LED_out_second = 7'b0010000; // "9" 
 4'b1010: LED_out_second = 7'b0001000; // "A" 
 4'b1011: LED_out_second = 7'b0000011; // "B" 
 4'b1100: LED_out_second = 7'b1000110; // "C" 
 4'b1101: LED_out_second = 7'b0100001; // "D" 
 4'b1110: LED_out_second = 7'b0000110; // "E"
 4'b1111: LED_out_second = 7'b0001110; // "F" 
 default: LED_out_second = 7'b1000000; // "0"
 endcase
end

always @(*)
begin
 case(LED_BCD[2])
 4'b0000: LED_out_third = 7'b1000000; // "0"  
 4'b0001: LED_out_third = 7'b1111001; // "1" 
 4'b0010: LED_out_third = 7'b0100100; // "2" 
 4'b0011: LED_out_third = 7'b0110000; // "3" 
 4'b0100: LED_out_third = 7'b0011001; // "4" 
 4'b0101: LED_out_third = 7'b0010010; // "5" 
 4'b0110: LED_out_third = 7'b0000010; // "6" 
 4'b0111: LED_out_third = 7'b1111000; // "7" 
 4'b1000: LED_out_third = 7'b0000000; // "8"  
 4'b1001: LED_out_third = 7'b0010000; // "9" 
 4'b1010: LED_out_third = 7'b0001000; // "A" 
 4'b1011: LED_out_third = 7'b0000011; // "B" 
 4'b1100: LED_out_third = 7'b1000110; // "C" 
 4'b1101: LED_out_third = 7'b0100001; // "D" 
 4'b1110: LED_out_third = 7'b0000110; // "E"
 4'b1111: LED_out_third = 7'b0001110; // "F" 
 default: LED_out_third = 7'b1000000; // "0"
 endcase
end

always @(*)
begin
 case(LED_BCD[3])
 4'b0000: LED_out_fourth = 7'b1000000; // "0"  
 4'b0001: LED_out_fourth = 7'b1111001; // "1" 
 4'b0010: LED_out_fourth = 7'b0100100; // "2" 
 4'b0011: LED_out_fourth = 7'b0110000; // "3" 
 4'b0100: LED_out_fourth = 7'b0011001; // "4" 
 4'b0101: LED_out_fourth = 7'b0010010; // "5" 
 4'b0110: LED_out_fourth = 7'b0000010; // "6" 
 4'b0111: LED_out_fourth = 7'b1111000; // "7" 
 4'b1000: LED_out_fourth = 7'b0000000; // "8"  
 4'b1001: LED_out_fourth = 7'b0010000; // "9" 
 4'b1010: LED_out_fourth = 7'b0001000; // "A" 
 4'b1011: LED_out_fourth = 7'b0000011; // "B" 
 4'b1100: LED_out_fourth = 7'b1000110; // "C" 
 4'b1101: LED_out_fourth = 7'b0100001; // "D" 
 4'b1110: LED_out_fourth = 7'b0000110; // "E"
 4'b1111: LED_out_fourth = 7'b0001110; // "F" 
 default: LED_out_fourth = 7'b1000000; // "0"
 
 endcase
end


endmodule


