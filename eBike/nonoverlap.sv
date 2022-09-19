module nonoverlap(clk, rst_n, highIn, lowIn, highOut, lowOut);
	input clk, rst_n; // 50MHz clock and reset
	input highIn; // control for high side FET
	input lowIn; // control for low side FET
	output logic highOut; // control for high side FET with ensured non-overlap
	output logic lowOut; // control for low side FET with ensured non-overlap
	
	
	// edge detect block
	logic high_change_d;
	logic low_change_d;
	logic high_edge_detect;
	logic low_edge_detect;
	assign high_edge_detect = high_change_d ^ highIn;
	assign low_edge_detect = low_change_d ^ lowIn;
	always_ff @(posedge clk) begin
		high_change_d <= highIn;
		low_change_d <= lowIn;
	end
	// edge detect block
	
	// timer block
	logic [4:0] cnt;
	logic cnt_rst;
	logic cnt_en;
	always_ff @(posedge clk, posedge cnt_rst) begin
		if(cnt_rst)
			cnt <= 4'b0000;
		else if(cnt_en)
			cnt <= cnt + 1;
	end
	// timer block
	
	// combo logic
	logic high_out_preFlop;
	logic low_out_preFlop;
	logic timerFull;
	assign timerFull = &cnt;
	always_comb begin
		high_out_preFlop = 0;
		low_out_preFlop = 0;
		cnt_rst = 0;
		if(high_edge_detect | low_edge_detect) begin
			cnt_rst = 1;
			cnt_en = 1;
		end
		if(timerFull) begin
			cnt_en = 0;
			high_out_preFlop = highIn;
			low_out_preFlop = lowIn;
		end else 
			cnt_en = 1;
	end
	// combo logic
			
	// flopping block to stop glitches
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) begin
			highOut <= 1'b0;
			lowOut <= 1'b0;
		end	else begin
			highOut <= high_out_preFlop;
			lowOut <= low_out_preFlop;
		end
	end
	// flopping block to stop glitches
endmodule