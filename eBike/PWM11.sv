module PWM11(clk, rst_n, duty, PWM_sig, PWM_synch);
    input logic clk;
    input logic rst_n;
    input logic [10:0] duty;
    output logic PWM_sig;
    output logic PWM_synch;

    logic [10:0] cnt;

    // checking duty part
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n)
            PWM_sig <= 1'b0;
        else if(cnt>duty)
            PWM_sig <= 1'b0;
        else
            PWM_sig <= 1'b1;
    end
    // cnt part
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n)
            cnt <= 0;
        else
            cnt <= cnt+1;
    end
    assign PWM_synch = (cnt==11'h001) ? 1'b1 : 1'b0;
    
endmodule
