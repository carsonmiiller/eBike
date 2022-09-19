module A2D_intf(
	input clk, rst_n,		// clock and asynch active low reset
	input logic MISO,			// Master In Slave Out (serial data from the A2D)
	output logic [11:0] batt,		// battery voltage result (channel 0)
	output logic [11:0] curr,		// current motor is consuming (channel 1)
	output logic [11:0] brake,	// brake lever position (channel 3)
	output logic [11:0] torque,	// crank spindle torque sensor (channel 4)
	output logic SS_n,			// active low slave select (to A2D)
	output logic SCLK,			// serial clock to the A2D
	output logic MOSI			// Master Out Slave In (serial data to the A2D
);

// Intermediate signals
logic cnv_cmplt;
logic batt_en, curr_en, brake_en, torque_en;

///////////////////
// Counter //
///////////////////
logic [1:0] cnt;
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		cnt <= 2'b00;
	else if(cnv_cmplt)
		cnt <= cnt + 1;
end

///////////////////////////////////////////////////
// CHANNEL COMBO BLOCK //
///////////////////////////////////////////////////
logic [15:0] cmd;
// COUNTER OUTPUT COMBO BLOCK
always_comb begin
	batt_en = 0;
	curr_en = 0;
	brake_en = 0;
	torque_en = 0;
	cmd = 16'h0000;
	case(cnt)
		2'b00: begin
			cmd = 16'h0000; 
			if(cnv_cmplt) 
				batt_en = 1;
			else
				batt_en = 0;
		end
		2'b01: begin
			cmd = 16'h0800;
			if(cnv_cmplt)
				curr_en = 1;
			else
				curr_en = 0;
		end
		2'b10: begin
			cmd = 16'h1800;
			if(cnv_cmplt)
				brake_en = 1;
			else
				brake_en = 0;
		end
		2'b11: begin
			cmd = 16'h2000;
			if(cnv_cmplt)
				torque_en = 1;
			else
				torque_en = 0;
		end
	endcase
end

/////////////////////////////
// State Machine //
////////////////////////////
// 14 bit counter
logic [13:0] sm_cntr;
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		sm_cntr <= 14'b0;
	else if(cnv_cmplt)
		sm_cntr <= 14'b0;
	else
		sm_cntr <= sm_cntr + 1;
end

// SM signals
typedef enum reg[1:0]  {IDLE, SEND, WAIT, READ} state_t;
// inputs
logic done;
// outputs
logic snd;
state_t state, nxt_state;
always_ff@(posedge clk, negedge rst_n)
	if(!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;

always_comb begin
// default outputs
	snd = 0;
	cnv_cmplt = 0;
	nxt_state = state;
	case(state)
		default: begin 			// this is the IDLE state
			if(&sm_cntr) begin
				snd = 1;
				nxt_state = SEND;
			end
		end
		SEND: begin
			if(done)
				nxt_state = WAIT;
		end
		WAIT: begin
			snd = 1;
			nxt_state = READ;
		end
		READ: begin
			if(done) begin
				cnv_cmplt = 1;
				nxt_state = IDLE;
			end
		end
	endcase
end

// SPI?
logic [15:0] resp;
SPI_mnrch spi (.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .snd(snd), .cmd(cmd), .done(done), .resp(resp));

//////////////////////////////////
// OUTPUT FLOPS //
//////////////////////////////////
// batt output flop
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		batt <= 12'h000;
	else if (batt_en)
		batt <= resp [11:0];
end
// curr output flop
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		curr <= 12'h000;
	else if (curr_en)
		curr <= resp [11:0];
end
// brake output flop
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		brake <= 12'h000;
	else if (brake_en)
		brake <= resp [11:0];
end
// torque output flop
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		torque <= 12'h000;
	else if (torque_en)
		torque <= resp [11:0];
end

endmodule

