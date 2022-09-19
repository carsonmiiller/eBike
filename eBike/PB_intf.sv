`default_nettype none
module PB_intf(clk, rst_n, tgglMd, setting, scale);
	input wire clk;
	input wire rst_n;
	input wire tgglMd;
	output logic [1:0] setting;
	output logic [2:0] scale;
	
	// Internal logic //
	logic tggleMd_ff1, tggleMd_ff2, tggleMd_stable;
	logic rise_detected;
	
	// Meta-stability //
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) 
			tggleMd_ff1 <= 1'b0;
		else
			tggleMd_ff1 <= tgglMd;
	end
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) 
			tggleMd_ff2 <= 1'b0;
		else
			tggleMd_ff2 <= tggleMd_ff1;
	end
	
	// Rise Edge Detect //
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			tggleMd_stable <= 1'b0;
		else
			tggleMd_stable <= tggleMd_ff2;
	end
	assign rise_detected = (!tggleMd_stable & tggleMd_ff2);
	
	// Counter 								 //
	// 00 => off, 01 => low assist 		 	 //
	// 10 => medium assist, 11 => max assist //
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			setting <= 2'b10;
		else if (rise_detected)
			setting <= setting + 1'b1;
	end
	// Scale the setting //
	assign scale = (setting == 2'b00) ? {setting, 1'b0} : {setting, 1'b1};
	
endmodule
`default_nettype wire