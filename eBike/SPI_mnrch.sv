module SPI_mnrch(clk,rst_n,SS_n,SCLK,MOSI,MISO,snd,cmd,done,resp);

input clk,rst_n; //50 MHz clock and reset
input snd; //High for one clock period initiates SPI transaction
input [15:0]cmd; //Command being sent to intertial scanner
input MISO; //SPI protocol signal
output reg SS_n,SCLK,MOSI; //SPI protocol signals
output reg done; //Asserted when SPI transaction complete
output [15:0]resp; //Data from SPI serf

typedef enum reg[1:0] {idle,shift,finish}state_t; //states of state machine
state_t state, nxt_state;
logic [4:0]count,sclk_div; //counter and counter to determine SCLK
logic [15:0]shift_reg; //shift register
logic ld_sclk,init,set_done,shft,full; //signals generated by state machine

assign SCLK = sclk_div[4];
assign shft = (sclk_div == 5'b10001) ? 1'b1 : 1'b0; //shift two clock cycles after SCLK rise
assign full = (sclk_div == 5'b11111) ? 1'b1 : 1'b0; //full when sclk_div is all 1's
assign MOSI = shift_reg[15];
assign resp = shift_reg;

always_ff @(posedge clk, negedge rst_n) begin //FF to determine next state
  if (!rst_n)
    state <= idle;
  else
    state <= nxt_state;
end

always_ff @(posedge clk, negedge rst_n) begin 
  if (!rst_n) begin
    done <= 1'b0;
    SS_n <= 1'b1;
  end
  else if (init) begin //initial ouputs of state machine
    done <= 1'b0;
    SS_n <= 1'b0;
  end
  else if (set_done) begin //end outputs of state machine
    done <= 1'b1;
    SS_n <= 1'b1;
  end
end

always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    count <= 5'b00000;
  else if (init) //reset counter at beginning of state machine
    count <= 5'b00000;
  else if (shft) //increment count with each shift
    count <= count + 1;
end

always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    sclk_div <= 5'b10111;
  else if(ld_sclk) //SCLK waits high until new state machine begins
    sclk_div <= 5'b10111;
  else //increment sclk_div if state machine is running
    sclk_div <= sclk_div + 1;
end

always_ff @(posedge clk) begin
  if (init) //parallel load cmd into shift_reg at beginning of state machine
    shift_reg <= cmd;
  else if (shft) //if in shift state, shift shift_reg left making MISO new LSB
    shift_reg <= {shift_reg[14:0],MISO};
end
    
always_comb begin //state machine implementation
  ld_sclk = 1'b0; //initial conditions
  init = 1'b0;
  set_done = 1'b0;
  nxt_state = state;
  case(state)
    shift : begin
              if(count == 5'b10000)
                nxt_state = finish;        
             end
    finish : begin
               if(full == 1) begin
                 set_done = 1'b1;
	         ld_sclk = 1'b1;
                 nxt_state = idle; 
               end
				end
	default : begin
             if (snd) begin
               init = 1'b1;
               nxt_state = shift;
             end
             else
               ld_sclk = 1'b1;
           end

  endcase
end
endmodule 