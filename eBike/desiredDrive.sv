module desiredDrive(
	input unsigned [11:0] avg_torque, // unsigned number representing the torque the rider is putting on the cranks (force of their pedaling)
	input unsigned [4:0] cadence, // unsigned number proportional to the sqrt the speed of the rider's pedaling
	input not_pedaling, // asserts if cadence is so slow it has been determined rider is not pedaling
	input signed [12:0] incline, // signed number dealth with in incline module
	input unsigned [2:0] scale, // unsigned number representing level of assist motor provides; 111 => a lot of assist, 101 => medium, 011 => little, 000 => no assist
    input clk,
	output unsigned [11:0] target_curr // unsigned output setting the target current the motor should be running at. this will go to the PID controller to eventually form the duty cycle the motor driver is run at
);

	logic signed [9:0] incline_sat;
						// if number is negative and has a 0 in bits [11:9], saturate to most negative number
	assign incline_sat = (incline[12] && ~&(incline[11:9])) ? 10'b1000000000
						// else if number is positive and has a 1 in bits [11:9], saturate to most positive number
						: (~incline[12] && |(incline[11:9])) ? 10'b0111111111
						// else, just copy over lower bits of incline
						: incline[9:0];
						
	logic signed [10:0] incline_factor;
	assign incline_factor = {incline_sat[9], incline_sat} + 10'b0100000000;
	
	logic [5:0] cadence_factor;
	assign cadence_factor = (cadence > 5'b00001) ? (cadence + 6'b100000) : 6'b000000;
	
	logic [8:0] incline_lim;
						// if incline_factor is negative, clip it to zero
	assign incline_lim = (incline_factor[10]) ? 9'b000000000
						// if it's not negative, but IS greater than 511, clip it to 511
						: ((incline_factor[9]) ? 9'b111111111
						// if neither negative nor greater than 511, pass along bits 8 through 0
						: incline_factor[8:0]);
	
	localparam TORQUE_MIN = 13'h0380;
	logic [12:0] sign_extend_avg_torque;
	assign sign_extend_avg_torque = {avg_torque[11], avg_torque[11:0]};
	logic signed [12:0] torque_off;
	assign torque_off = avg_torque - TORQUE_MIN;
	logic [11:0] torque_pos;
						// if torque_off is negative, clip to zero, otherwise copy lowest 12 bits to torque_pos
	assign torque_pos = (torque_off[12]) ? 12'h000 : torque_off[11:0];
	
	logic [29:0] assist_prod;
    logic [14:0] product1;
    logic [14:0] product2;
    logic [29:0] product3;
    
    //Pipeline multiplication
    always_ff @(posedge clk) begin
        product1 <= incline_lim * cadence_factor;
        product2 <= torque_pos * scale;
        product3 <= product2 * product1;
    end

	assign assist_prod = not_pedaling ? '0 : product3;
	assign target_curr = (|assist_prod[29:27]) ? 12'hFFF : assist_prod[26:15];
endmodule