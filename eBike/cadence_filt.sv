module cadence_filt #(parameter FAST_SIM = 1) (clk, rst_n, cadence, cadence_filt, cadence_rise);
	input clk; // 50MHz clock
	input rst_n; // asynch active low reset signal
	input cadence; // raw cadence signal (bouncy and asynch)
	output reg cadence_filt; // filtered meta-stability free version of cadence signal
	output cadence_rise; // rise edge detect of cadence

	logic [15:0] stbl_cnt; // counter

	logic can_update;
	// fast sim stuff
	generate if (FAST_SIM)
		assign can_update = &stbl_cnt[7:0];
	else
		assign can_update = &stbl_cnt[15:0];
	endgenerate
	
	// meta-stability block
	reg meta_stability1;
	reg meta_stability2;
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) begin
			meta_stability1 <= 1'b0;
			meta_stability2 <= 1'b0;
		end
		else begin
			meta_stability1 <= cadence;
			meta_stability2 <= meta_stability1;
		end
	end
	
	
	
	// edge detect block
	reg post_flop_edge_detect;
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			post_flop_edge_detect <= 1'b0;
		else
			post_flop_edge_detect <= meta_stability2;
	end
	
	
	
	// combinational logic block that produces chngd_n and cadence_rise
	wire chngd_n;
	assign chngd_n = meta_stability2 ~^ post_flop_edge_detect;
	assign cadence_rise = meta_stability2 & ~post_flop_edge_detect;
	// end combo logic block
	
	
	
	// counter block

	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) // if reset is low(active) or chngd_n is low
			stbl_cnt <= 16'h0000;
		else if(!chngd_n)
			stbl_cnt <= '0;
		else // if neither are low, keep incrementing counter
			stbl_cnt <= stbl_cnt + 1;
	end
	// end counter block
	
	
	
	// counter full block
	//wire counter_full;
	//assign counter_full = &stbl_cnt;
	// counter full block end
	
	
	// cadence_filt enable ff
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			cadence_filt <= 1'b0;
		else if(can_update)
			cadence_filt <= post_flop_edge_detect;
		else
			cadence_filt <= cadence_filt;
	end
	// end cadence_filt block
	
endmodule