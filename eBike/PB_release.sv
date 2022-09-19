module PB_release(
	input PB,
	input rst_n,
	input clk,
	output released
);
	logic flop1_out, flop2_out, flop3_out;
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) begin
			flop1_out <= 1'b1;
			flop2_out <= 1'b1;
			flop3_out <= 1'b1;
		end else begin
			flop1_out <= PB;
			flop2_out <= flop1_out;
			flop3_out <= flop2_out;
		end
	end
	
	assign released = flop2_out & ~flop3_out;
endmodule