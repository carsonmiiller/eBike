module eBike_tb();
import testTasks::*;
 
  // include or import tasks?

  localparam FAST_SIM = 1;		// accelerate simulation by default
  
  logic err;					// error signal

  ///////////////////////////
  // Stimulus of type reg //
  /////////////////////////
  reg clk,RST_n;
  reg [11:0] BATT;				// analog values
  reg [11:0] BRAKE,TORQUE;		// analog values
  reg tgglMd;					// push button for assist mode
  reg [15:0] YAW_RT;			// models angular rate of incline (+ => uphill)


  //////////////////////////////////////////////////
  // Declare any internal signal to interconnect //
  ////////////////////////////////////////////////
  wire A2D_SS_n,A2D_MOSI,A2D_SCLK,A2D_MISO;
  wire highGrn,lowGrn,highYlw,lowYlw,highBlu,lowBlu;
  wire hallGrn,hallBlu,hallYlw;
  wire inertSS_n,inertSCLK,inertMISO,inertMOSI,inertINT;
  logic cadence;
  wire [1:0] LED;			// hook to setting from PB_intf
  
  wire signed [11:0] coilGY,coilYB,coilBG;
  logic [11:0] curr;		// comes from hub_wheel_model
  wire [11:0] BATT_TX, TORQUE_TX, CURR_TX;
  logic vld_TX;

// testbench helper value
  logic change_cadence;
  
  //////////////////////////////////////////////////
  // Instantiate model of analog input circuitry //
  ////////////////////////////////////////////////
  AnalogModel iANLG(.clk(clk),.rst_n(RST_n),.SS_n(A2D_SS_n),.SCLK(A2D_SCLK),
                    .MISO(A2D_MISO),.MOSI(A2D_MOSI),.BATT(BATT),
		    .CURR(curr),.BRAKE(BRAKE),.TORQUE(TORQUE));

  ////////////////////////////////////////////////////////////////
  // Instantiate model inertial sensor used to measure incline //
  //////////////////////////////////////////////////////////////
  eBikePhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(inertSS_n),.SCLK(inertSCLK),
	             .MISO(inertMISO),.MOSI(inertMOSI),.INT(inertINT),
		     .yaw_rt(YAW_RT),.highGrn(highGrn),.lowGrn(lowGrn),
		     .highYlw(highYlw),.lowYlw(lowYlw),.highBlu(highBlu),
		     .lowBlu(lowBlu),.hallGrn(hallGrn),.hallYlw(hallYlw),
		     .hallBlu(hallBlu),.avg_curr(curr));

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  eBike #(FAST_SIM) iDUT(.clk(clk),.RST_n(RST_n),.A2D_SS_n(A2D_SS_n),.A2D_MOSI(A2D_MOSI),
                         .A2D_SCLK(A2D_SCLK),.A2D_MISO(A2D_MISO),.hallGrn(hallGrn),
			 .hallYlw(hallYlw),.hallBlu(hallBlu),.highGrn(highGrn),
			 .lowGrn(lowGrn),.highYlw(highYlw),.lowYlw(lowYlw),
			 .highBlu(highBlu),.lowBlu(lowBlu),.inertSS_n(inertSS_n),
			 .inertSCLK(inertSCLK),.inertMOSI(inertMOSI),
			 .inertMISO(inertMISO),.inertINT(inertINT),
			 .cadence(cadence),.tgglMd(tgglMd),.TX(TX_RX),
			 .LED(LED));
			 
			 
  ////////////////////////////////////////////////////////////
  // Instantiate UART_rcv or some other telemetry monitor? //
  //////////////////////////////////////////////////////////
  UART_rcv iRCV(.clk(clk), .rst_n(RST_n), .RX(TX_RX), .rdy(/* ??? */), .rx_data(/* ??? */), .clr_rdy(/* ??? */));
			 
  initial begin
    //<your magic here>
	// default all input
	change_cadence = 0;
	clk = 0;
	RST_n = 0;
	BATT = 12'hBFF;
	BRAKE = 12'hF00;
	TORQUE = '0;
	cadence = 1'b0;
	tgglMd = 0;
	YAW_RT = '0;
	@(posedge clk);
	@(negedge clk) RST_n = 1;
	
	// Torque Starts High //
	TORQUE = 12'h700;
	repeat(1000000) @(posedge clk);
	testOmega(.omega(iPHYS.omega), .highVal(25000), .lowVal(23500));
	testError(.error(iDUT.error), .highVal(640), .lowVal(580));
	repeat(1000000) @(posedge clk);
	testOmega(.omega(iPHYS.omega), .highVal(36000), .lowVal(32000));
	testError(.error(iDUT.error), .highVal(290), .lowVal(260));
	
	// Decrease Torque //
	TORQUE = 12'h500;
	repeat(1000000) @(posedge clk);
	testOmega(.omega(iPHYS.omega), .highVal(25020), .lowVal(22642));
	testError(.error(iDUT.error), .highVal(-137), .lowVal(-151));
	repeat(1000000) @(posedge clk);
	testOmega(.omega(iPHYS.omega), .highVal(23850), .lowVal(21580));
	testError(.error(iDUT.error), .highVal(-62), .lowVal(-70));

	// Battery below threshold and pedaling //
	change_cadence = 1;
	BATT = 12'h100;
	TORQUE = 12'h500;
	repeat(1000000) @(posedge clk);
	testOmega(.omega(iPHYS.omega), .highVal(25625), .lowVal(23185));
	testError(.error(iDUT.error), .highVal(0), .lowVal(0));
	repeat(1000000) @(posedge clk);
	testOmega(.omega(iPHYS.omega), .highVal(25625), .lowVal(23185));
	testError(.error(iDUT.error), .highVal(0), .lowVal(0));

	
	// Return to normal //
	BATT = 12'hBFF;
	TORQUE = 12'h700;
	

	// Going up-hill //
	YAW_RT = 16'h2000;
	repeat(1000000) @(posedge clk);
	testOmega(.omega(iPHYS.omega), .highVal(38275), .lowVal(34655));
	testError(.error(iDUT.error), .highVal(510), .lowVal(463));

	// Going down-hill //
	YAW_RT = 16'hF000;
	repeat(1000000) @(posedge clk);
	testOmega(.omega(iPHYS.omega), .highVal(43780), .lowVal(39620));
	testError(.error(iDUT.error), .highVal(83), .lowVal(75));

	// Flatten out //
	YAW_RT = '0;
	repeat(1000000) @(posedge clk);

	// Apply brake //
	BRAKE = 12'h0FF;
	TORQUE = 12'h000;
	repeat(1000000) @(posedge clk);
	if(curr != 0) begin
		$display("Error: avg_current should be 0");
		$display("Avg_curr: $d", curr);
		$stop();
	end
	// Tests Passed //
	$display("YAHOO!");
	$stop();	
  end
  
  ///////////////////
  // Generate clk //
  /////////////////
  always
    #10 clk = ~clk;

  ///////////////////////////////////////////
  // Block for cadence signal generation? //
  /////////////////////////////////////////
  always begin
	if(!change_cadence) begin
		repeat (2200) @(posedge clk);
	end
	else begin
		repeat (8192) @(posedge clk);
	end
	cadence = ~cadence;
  end

  
endmodule
