module inert_intf(
	input clk, rst_n,
	input INT,
	input MISO,
	output SCLK,
	output MOSI,
	output SS_n,
	output reg vld,
	output signed [12:0] incline
);

	// necessary internal wires
	logic snd, done, C_R_H, C_R_L, C_Y_H, C_Y_L, C_AY_H, C_AY_L, C_AZ_H, C_AZ_L;
	logic [15:0] cmd, roll_rt, yaw_rt, AY, AZ;
	logic [15:0] resp;
	
	// SPI Instantiation
	SPI_mnrch iSPI(
		.clk(clk),
		.rst_n(rst_n),
		.SS_n(SS_n),
		.SCLK(SCLK),
		.MOSI(MOSI),
		.MISO(MISO),
		.snd(snd),
		.cmd(cmd),
		.done(done),
		.resp(resp)
	);
	
	// 8 8-bit holding registers
	reg [7:0] R_L, R_H, Y_L, Y_H, AYL, AYH, AZL, AZH;
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			R_L <= 8'h00;
		else if(C_R_L)
			R_L <= resp[7:0];
	end
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			R_H <= 8'h00;
		else if(C_R_H)
			R_H <= resp[7:0];
	end
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			Y_L <= 8'h00;
		else if(C_Y_L)
			Y_L <= resp[7:0];
	end
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			Y_H <= 8'h00;
		else if(C_Y_H)
			Y_H <= resp[7:0];
	end
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			AYL <= 8'h00;
		else if(C_AY_L)
			AYL <= resp[7:0];
	end
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			AYH <= 8'h00;
		else if(C_AY_H)
			AYH <= resp[7:0];
	end
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			AZL <= 8'h00;
		else if(C_AZ_L)
			AZL <= resp[7:0];
	end
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			AZH <= 8'h00;
		else if(C_AZ_H)
			AZH <= resp[7:0];
	end

	// 16-bit timer to wait for inertial sensor to wake up
	reg [15:0] timer;
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			timer <= 16'h0000;
		else
			timer <= timer + 1;
	end
	
	// double flop INT (interrupt from inertial sensor)
	reg INT_ff1, INT_ff2;
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) begin
			INT_ff1 <= 1'b0;
			INT_ff2 <= 1'b0;
		end else begin
			INT_ff1 <= INT;
			INT_ff2 <= INT_ff1;
		end
	end
	
	// state machine
	typedef enum reg[3:0]{INIT1, INIT2, INIT3, INIT4, roll_L, roll_H, yaw_L, yaw_H, AY_L, AY_H, AZ_L, AZ_H, valid} state_t;
	state_t nxt_state, state;
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			state <= INIT1;
		else
			state <= nxt_state;
	end
	always_comb begin
		// default all SM outputs
		cmd = 16'h0000;
		snd = 1'b0;
		vld = 1'b0;
		C_R_H = 1'b0;
		C_R_L = 1'b0;
		C_Y_H = 1'b0;
		C_Y_L = 1'b0;
		C_AY_H = 1'b0;
		C_AY_L = 1'b0;
		C_AZ_H = 1'b0;
		C_AZ_L = 1'b0;
		// default nxt_state to current state
		nxt_state = state;
		case(state)
			INIT1: begin
				cmd = 16'h0D02;
				if(&timer) begin
					snd = 1'b1;
					nxt_state = INIT2;
				end
			end
			INIT2: begin
				cmd = 16'h1053;
				if(done) begin
					snd = 1'b1;
					nxt_state = INIT3;
				end
			end
			INIT3: begin
				cmd = 16'h1150;
				if(done) begin
					snd = 1'b1;
					nxt_state = INIT4;
				end
			end
			INIT4: begin
				cmd = 16'h1460;
				if(done) begin
					snd = 1'b1;
					nxt_state = roll_L;
				end
			end
			roll_L: begin
				cmd = 16'hA4xx;
				if(done & INT_ff2) begin
					snd = 1'b1;
					nxt_state = roll_H;
				end
			end
			roll_H: begin
				cmd = 16'hA5xx;
				if(done) begin
					C_R_L = 1'b1;
					snd = 1'b1;
					nxt_state = yaw_L;
				end
			end
			yaw_L: begin
				cmd = 16'hA6xx;
				if(done) begin
					C_R_H = 1'b1;
					snd = 1'b1;
					nxt_state = yaw_H;
				end
			end
			yaw_H: begin
				cmd = 16'hA7xx;
				if(done) begin
					C_Y_L = 1'b1;
					snd = 1'b1;
					nxt_state = AY_L;
				end
			end
			AY_L: begin
				cmd = 16'hAAxx;
				if(done) begin
					C_Y_H = 1'b1;
					snd = 1'b1;
					nxt_state = AY_H;
				end
			end
			AY_H: begin
				cmd = 16'hABxx;
				if(done) begin
					C_AY_L = 1'b1;
					snd = 1'b1;
					nxt_state = AZ_L;
				end
			end
			AZ_L: begin
				cmd = 16'hACxx;
				if(done) begin
					C_AY_H = 1'b1;
					snd = 1'b1;
					nxt_state = AZ_H;
				end
			end
			AZ_H: begin
				cmd = 16'hADxx;
				if(done) begin
					C_AZ_L = 1'b1;
					snd = 1'b1;
					nxt_state = valid;
				end
			end
			valid: begin
				if(done) begin
					C_AZ_H = 1'b1;
					vld = 1'b1;
					nxt_state = roll_L;
				end
			end
		endcase
	end
	
	// Inertial Integrator Instantiation
	inertial_integrator iINERT(
		.clk(clk),
		.rst_n(rst_n),
		.vld(vld),
		.roll_rt({R_H, R_L}),
		.yaw_rt({Y_H, Y_L}),
		.AY({AYH, AYL}),
		.AZ({AZH, AZL}),
		.incline(incline),
		.LED() // not shown on block diagram
	);
endmodule