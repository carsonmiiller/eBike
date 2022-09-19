module inert_intf_test();
	reg clk;
	reg [7:0] LED;
	logic RST_n, rst_n, MISO, SCLK, MOSI, SS_n, vld;
	logic [12:0] incline;
	reg INT;
	
	reset_synch iRST_SYNCH(
		.RST_n(RST_n),
		.clk(clk),
		.rst_n(rst_n)
	);
	
	inert_intf iDUT(
		.clk(clk),
		.rst_n(rst_n),
		.INT(INT),
		.MISO(MISO),
		.SCLK(SCLK),
		.MOSI(MOSI),
		.SS_n(SS_n),
		.vld(vld),
		.incline(incline)
	);
	
	initial begin
		clk = 0;
		RST_n = 0;
		INT = 0;
		@(posedge clk);
		RST_n = 1;
		repeat (70000) @(posedge clk);
		INT = 1;
		@(posedge clk)
		INT = 0;
		repeat (10000) @(posedge clk);
		INT = 1;
		@(posedge clk)
		INT = 0;
		repeat (100000) @(posedge clk);
		$stop;
	end
	
	// infer an enable flop to grab bit [8:1] of incline
	always_ff @(posedge clk) begin
		if(vld)
			LED <= incline[8:1];
	end

	always
		#5 clk = ~clk;
endmodule