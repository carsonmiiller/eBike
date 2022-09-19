module telemetry(
    input [11:0] batt_v, // battery voltage
    input [11:0] avg_curr, // motor's average current
    input [11:0] avg_torque, // rider's average input torque
    input clk, rst_n, // 50MHz clock and reset
    output TX // serial output
);

	// SM inputs
	logic done, send;

	// SM outputs
	logic trmt;
	logic [7:0] trmt_byte;

	// UART_tx instantiation
	UART_tx iUART(
		.clk(clk),
		.rst_n(rst_n),
		.TX(TX),
		.trmt(trmt),
		.tx_data(trmt_byte),
		.tx_done(done)
	);
	
	// generation of send signal
	// needs to rise 47.68x per second
	// instructions hint at it being built off of 50MHz clk
	// here's my temp solution
	logic [19:0] cntr;
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			cntr <= 20'h00000;
		else if(send)
			cntr <= 20'h00000;
		else
			cntr <= cntr + 1;
	end
	assign send = &cntr;
	
	// SM
	typedef enum reg[3:0]{IDLE, D1, D2, P1, P2, P3, P4, P5, P6} state_t;
	
	state_t state, nxt_state;

	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;
	end
	
	always_comb begin
		nxt_state = IDLE;
		trmt = 0;
		trmt_byte = 8'h00;

		case(state)
			D1: begin
				if (done) begin
					trmt_byte = 8'h55;
					trmt = 1;
					nxt_state = D2;
				end
				else
					nxt_state = D1;
			end
			D2: begin
				if (done) begin
					trmt_byte = {4'h0, batt_v[11:8]};
					trmt = 1;
					nxt_state = P1;
				end
				else
					nxt_state = D2;
			end
			P1: begin
				if (done) begin
					trmt_byte = batt_v[7:0];
					trmt = 1;
					nxt_state = P2;
				end
				else
					nxt_state = P1;
			end
			P2: begin
				if (done) begin
					trmt_byte = {4'h0, avg_curr[11:8]};
					trmt = 1;
					nxt_state = P3;
				end
				else
					nxt_state = P2;
			end
			P3: begin
				if (done) begin
					trmt_byte = avg_curr[7:0];
					trmt = 1;
					nxt_state = P4;
				end
				else
					nxt_state = P3;
			end
			P4: begin
				if (done) begin
					trmt_byte = {4'h0, avg_torque[11:8]};
					trmt = 1;
					nxt_state = P5;
				end
				else
					nxt_state = P4;
			end
			P5: begin
				if (done) begin
					trmt_byte = avg_torque[7:0];
					trmt = 1;
					nxt_state = P6;
				end
				else
					nxt_state = P5;
			end
			P6: begin
				if (done)
					nxt_state = IDLE;
				else
					nxt_state = P6;
			end
			default: begin
				if (send) begin
					trmt_byte = 8'hAA;
					trmt = 1;
					nxt_state = D1;
				end
			end
		endcase
	end
endmodule