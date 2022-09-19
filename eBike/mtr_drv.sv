module mtr_drv(clk, rst_n, duty, selGrn, selYlw, selBlu, highGrn, lowGrn, highYlw, lowYlw, highBlu, lowBlu, PWM_synch);
input logic clk, rst_n;
input logic [10:0] duty;
input logic [1:0] selGrn;
input logic [1:0] selYlw;
input logic [1:0] selBlu;
output logic highGrn, lowGrn, highYlw, lowYlw, highBlu, lowBlu;
output logic PWM_synch;
// PWM outputs
logic PWM_sig;

// Intermediate mux signals for nonoverlap input
logic grnMux1, grnMux2, ylwMux1, ylwMux2, bluMux1, bluMux2;

PWM11 iPWM(.clk(clk), .rst_n(rst_n), .duty(duty), .PWM_sig(PWM_sig), .PWM_synch(PWM_synch));

assign grnMux1 = (selGrn==2'b10) ? PWM_sig : (selGrn==2'b01) ? ~PWM_sig : 1'b0;
assign grnMux2 = (selGrn==2'b01) ? PWM_sig : (selGrn==2'b11) ? PWM_sig : (selGrn==2'b10) ? ~PWM_sig : 1'b0;
assign ylwMux1 = (selYlw==2'b10) ? PWM_sig : (selYlw==2'b01) ? ~PWM_sig : 1'b0;
assign ylwMux2 = (selYlw==2'b01) ? PWM_sig : (selYlw==2'b11) ? PWM_sig : (selYlw==2'b10) ? ~PWM_sig : 1'b0;
assign bluMux1 = (selBlu==2'b10) ? PWM_sig : (selBlu==2'b01) ? ~PWM_sig : 1'b0;
assign bluMux2 = (selBlu==2'b01) ? PWM_sig : (selBlu==2'b11) ? PWM_sig : (selBlu==2'b10) ? ~PWM_sig : 1'b0;

nonoverlap iGrnNO(.clk(clk), .rst_n(rst_n), .highIn(grnMux1), .lowIn(grnMux2), .highOut(highGrn), .lowOut(lowGrn));
nonoverlap iYlwNO(.clk(clk), .rst_n(rst_n), .highIn(ylwMux1), .lowIn(ylwMux2), .highOut(highYlw), .lowOut(lowYlw));
nonoverlap iBluNO(.clk(clk), .rst_n(rst_n), .highIn(bluMux1), .lowIn(bluMux2), .highOut(highBlu), .lowOut(lowBlu));


endmodule