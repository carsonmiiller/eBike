module sensorCondition #(parameter FAST_SIM = 1) (clk, rst_n, torque, cadence_raw, curr, incline, scale, batt, error, not_pedaling, TX);
input clk, rst_n, cadence_raw;
input logic [11:0] torque;
input logic [11:0] curr;
input logic [11:0] batt;
input logic [12:0] incline;
input logic [2:0] scale;
output logic [12:0] error;
output not_pedaling, TX;

localparam LOW_BATT_THRES = 12'hA98;

// Cadence blocks
// intermediate signals
logic cadence_rise;
logic cadence_filt;
logic [7:0] cadence_per;
logic [4:0] cadence;
logic tmr_full;
logic [21:0] tmr;

cadence_filt #(.FAST_SIM(FAST_SIM)) icad_filt(.clk(clk), .rst_n(rst_n), .cadence(cadence_raw), .cadence_filt(cadence_filt), .cadence_rise(cadence_rise));
cadence_meas #(.FAST_SIM(FAST_SIM)) icad_meas(.clk(clk), .rst_n(rst_n), .cadence_filt(cadence_filt), .not_pedaling(not_pedaling), .cadence_per(cadence_per));
cadence_LU cad_LU(.cadence_per(cadence_per), .cadence(cadence));


// Average Current
logic [11:0] avg_curr, avg_torque;
logic [13:0] accum_curr;

always_ff @(posedge clk, negedge rst_n) begin
  if(!rst_n)
    accum_curr <= 14'b0;
  else if(tmr_full)
    accum_curr <= ((accum_curr * 3) >> 2) + curr;
end

assign avg_curr = accum_curr >> 2;

//Average Torque
logic [16:0] accum_torque;
assign avg_torque = accum_torque >> 5;

logic pedaling_resumes, not_pedaling_ff1;

always_ff @(posedge clk) begin
	not_pedaling_ff1 <= not_pedaling;
end
assign pedaling_resumes = not_pedaling_ff1 & ~not_pedaling;

//Accum_torque initialization
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    accum_torque <=  17'b0;
  else if (pedaling_resumes)
    accum_torque <= {1'b0,torque,4'h0};
 else if(cadence_rise)
    accum_torque <= ((accum_torque * 31) >> 5) + torque;
end

// flip flop/timer logic

always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    tmr <= 22'b0;
  else
    tmr <= tmr + 1;
end

//FAST_SIM generate
generate if(FAST_SIM) 
	assign tmr_full = &tmr[15:0];
else
	assign tmr_full = &tmr;
endgenerate



// Desired drive block
logic [11:0] target_curr;
desiredDrive des_drive(.avg_torque(avg_torque), .cadence(cadence), .not_pedaling(not_pedaling), .incline(incline), .scale(scale), .target_curr(target_curr), .clk(clk));
// calculate error for PID
// if not pedaling or battery below threshold, 0 error, else, error = target-curr
assign error = (not_pedaling || (batt < LOW_BATT_THRES)) ? 13'b0 : target_curr-avg_curr;

// Telemetry block
telemetry telem(.clk(clk), .rst_n(rst_n), .batt_v(batt), .avg_curr(avg_curr), .avg_torque(avg_torque), .TX(TX));

endmodule