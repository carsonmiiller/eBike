`default_nettype none
module PID #(parameter FAST_SIM = 1) (clk, rst_n, error, not_pedaling, drv_mag);
	input wire clk, rst_n, not_pedaling; // 50 MHz clock - active low asynch reset
	input wire signed [12:0] error;
	output logic [11:0] drv_mag;
	
	// Internal Logic //
	logic [19:0] decimator; 
	logic decimator_full; // Enable flops 48 times per second
	logic signed [13:0] P_term;
	logic unsigned [13:0] I_term;
	logic signed [13:0] D_term;
	logic signed [12:0] err_ff1, err_ff2, prev_err, D_diff;
	logic signed [9:0] D_diff_sat;
	logic unsigned [17:0] accumulator, accumulator_sat; 
	logic [17:0] integrator, integrator_buffer;
	logic signed [17:0]extend_error;
	//logic signed [17:0] m1,m2,m3,m4;
	
	logic signed [13:0] PID_temp; // Buffer for saturating before assigning
	
	// Params //
	localparam signed max_positive_d_term = 10'h1ff;
	localparam signed max_negative_d_term = 10'h200;
	localparam max_drv_mag = 12'hfff;
	localparam min_drv_mag = 12'h0;
	localparam max_accumulator = 18'h1ffff; // acumulator CANNOT be negative
	localparam min_accumulator = 18'h0;
	
	////////////////// Generator and Counter for flop enables ///////////////////////
	generate if (FAST_SIM)
		assign decimator_full = &decimator[14:0];
	else
		assign decimator_full = &decimator;
	endgenerate

	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			decimator <= 20'h00000;
		else
			decimator <= decimator + 20'h00001;
	end
	
	//////////////////////// Internal logic for D_term ////////////////////////////
	// Enabled flops - need to cmp curr val with val from 3 cycles prior //
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			err_ff1 <= 13'h0000;
		else if(decimator_full)
			err_ff1 <= error;
	end
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			err_ff2 <= 13'h0000;
		else if(decimator_full)
			err_ff2 <= err_ff1;
	end
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			prev_err <= 13'h0000;
		else if (decimator_full)
			prev_err <= err_ff2;
	end
	
	always_comb begin
		// Current error - previous error (3 readings ago) // 
		D_diff = error - prev_err;
		
		// Saturate D_diff down to 9 bits //
		D_diff_sat = ( D_diff[12] && !(&D_diff[11:8]) ) ? max_negative_d_term // D_diff is too negative
				   : ( !D_diff[12] && (|D_diff[11:8]) ) ? max_positive_d_term // D_diff is too positive
				   : {D_diff[8:0], 1'b0}; // D_diff is in range
						  
		// Multiply saturated term by 2 //
		D_term = {{4{D_diff_sat[9]}}, D_diff_sat};
	end
	
	//////////////////////// Internal logic for PI_terms //////////////////////////
	
	always_comb begin
		// Sign extended value for integration //
		extend_error = {{5{error[12]}},error};
	
		// Sum error //
		accumulator = extend_error + integrator;
		
		// Saturate accumulated value //
		accumulator_sat = (accumulator[17] & integrator[16]) ? max_accumulator
						: accumulator[17] ?  min_accumulator
						: accumulator;
		
		// Assign every 1/48th second //
		integrator_buffer = decimator_full ? accumulator_sat : integrator;
		
		// Resulting I_term clipped from integrator //
		I_term = {2'b00,integrator[16:5]};

		// Error x Constant(1) -> P_term == error //
		P_term = {error[12],error};
	end

	// Flop integrated value - safe to use //
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			integrator <= 18'h0;
		else if(not_pedaling)
			integrator <= 18'h0;
		else
			integrator <= integrator_buffer;
	end
	
	//////////////////////// Internal logic for Summing Terms /////////////////////
	// Sum terms //
	logic [13:0] P_plus_I;
	//Pipelined addition
	always_ff @(posedge clk) begin
		P_plus_I <= P_term + I_term;
		PID_temp <= P_plus_I + D_term;
	end
	
	// Saturate PID term //
	assign drv_mag = PID_temp[13] ? min_drv_mag
				   : PID_temp[12] ? max_drv_mag 
				   : PID_temp[11:0];

endmodule
`default_nettype wire
