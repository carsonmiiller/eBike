module reset_synch(
	input RST_n, // raw input from push button
	input clk, // clock using negedge
	output logic rst_n
);
	logic between_flops;
	always_ff @(negedge clk, negedge RST_n) begin
		if(!RST_n) begin
			between_flops <= 1'b0;
			rst_n <= 1'b0;
		end else begin
			between_flops <= 1'b1;
			rst_n <= between_flops;
		end
	end
endmodule