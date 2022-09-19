`default_nettype none
module cadence_meas #(parameter FAST_SIM = 1) (clk, rst_n, cadence_filt, not_pedaling, cadence_per);
	// Inputs and Outputs //
	input wire clk, rst_n;
	input wire cadence_filt; // Synchronized, DO NOT DOUBLE FLOP
	output logic not_pedaling;
	output logic [7:0] cadence_per;
	
	// Local Params //
	localparam THIRD_SEC_REAL = 24'hE4E1C0;
	localparam THIRD_SEC_FAST = 24'h007271;
	localparam THIRD_SEC_UPPER = 8'hE4;
	
	// Internal Logic //
	logic cadence_rise, capture_per, rise_detect_ff;
	logic [7:0] cadence_fast_sim, cadence_capture;
	logic [23:0] THIRD_SEC, fast_sim_in, fast_sim_increment;
	
	// Generate //
	generate if (FAST_SIM)
		assign THIRD_SEC = THIRD_SEC_FAST;
	else
		assign THIRD_SEC = THIRD_SEC_REAL;
	endgenerate
	
	// Rise Detect - cadence_filt is synchronized to clk (stable) //
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			rise_detect_ff <= 1'b0;
		else
			rise_detect_ff <= cadence_filt;
	end
	assign cadence_rise = cadence_filt & ~rise_detect_ff;
	
	// Increment the count between edges //
	// Feeds incrementor flop			 //
	assign fast_sim_increment = (fast_sim_in == THIRD_SEC)
							  ? fast_sim_in				// Hold count
							  : (fast_sim_in + 24'b1);  // Increment count
	// Incrementor - THIRD_SEC //
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			fast_sim_in <= 24'h0;
		else if(cadence_rise)
			fast_sim_in <= 24'h0;
		else
			fast_sim_in <= fast_sim_increment;
	end
	
	// Assign cadence based on FAST_SIM paramter 
	// and capture_per, feeds preset flop //
	assign cadence_fast_sim = FAST_SIM 
							? fast_sim_in[14:7]
							: fast_sim_in[23:16];
	assign cadence_capture = (cadence_rise | (fast_sim_in == THIRD_SEC)) // == capture_per
						   ? cadence_fast_sim
						   : cadence_per;
				   
	// Synchronized preset when rst_n is low //
	always_ff @(posedge clk) begin
		if(!rst_n)
			cadence_per <= THIRD_SEC_UPPER;
		else
			cadence_per <= cadence_capture;
	end
	
	// not_pedaling when cadence == THIRD_SEC_UPPER //
	assign not_pedaling = (cadence_per == THIRD_SEC_UPPER)
						? 1'b1
						: 1'b0;
	
endmodule
`default_nettype wire