module brushless (
    input clk, rst_n, // 50 Mhz clock & asynch active low reset
    input unsigned [11:0] drv_mag, // From PID control. How much motor assists (unsigned)
    input hallGrn, hallYlw, hallBlu, // Raw hall effect sensors (asynch)
    input brake_n, // if low active regenerative braking at 75% duty cycle
    input PWM_synch, // used to synchronize hall reading with PWM cycle
    output [10:0] duty, //duty cycle to be used for PWM inside mtr_drv. should be 0x400 + drv_mag[11:2] in normal operation and 0x600 if braking
    output reg [1:0] selGrn, selYlw, selBlu // 2-bit vectors directing how mtr_drv should drive the FETs. 00=>HIGH_Z, 01=>rev_curr, 10=>frwd_curr, 11=>regen braking
);

    //////////////////////////////////////////////////////////
    //                   DOUBLE SYNCH BEGIN                 //
    //////////////////////////////////////////////////////////

    // green
    logic hallGrn_syn;
    logic hallGrn_dbl_syn;
    logic synchGrn;
    logic GrnMux;
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            synchGrn <= 1'b0;
        else
            synchGrn <= GrnMux;
    end
    always_ff @(posedge clk) begin
        hallGrn_syn <= hallGrn;
        hallGrn_dbl_syn <= hallGrn_syn;
    end
    assign GrnMux = PWM_synch ? hallGrn_dbl_syn : synchGrn;

    // yellow
    logic hallYlw_syn;
    logic hallYlw_dbl_syn;
    logic synchYlw;
    logic YlwMux;
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            synchYlw <= 1'b0;
        else
            synchYlw <= YlwMux;
    end
    always_ff @(posedge clk) begin
        hallYlw_syn <= hallYlw;
        hallYlw_dbl_syn <= hallYlw_syn;
    end
    assign YlwMux = PWM_synch ? hallYlw_dbl_syn : synchYlw;

    // blue
    logic hallBlu_syn;
    logic hallBlu_dbl_syn;
    logic synchBlu;
    logic BluMux;
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            synchBlu <= 1'b0;
        else
            synchBlu <= BluMux;
    end
    always_ff @(posedge clk) begin
        hallBlu_syn <= hallBlu;
        hallBlu_dbl_syn <= hallBlu_syn;
    end
    assign BluMux = PWM_synch ? hallBlu_dbl_syn : synchBlu;

    // rotation_state
    logic [2:0] rotation_state;
    assign rotation_state = {synchGrn, synchYlw, synchBlu};

    //////////////////////////////////////////////////////////
    //                   DOUBLE SYNCH END                   //
    //////////////////////////////////////////////////////////

    // COMBO LOGIC to drive coils
    always_comb begin
        if(!brake_n) begin
            selGrn = 2'b11;
            selYlw = 2'b11;
            selBlu = 2'b11;
        end
        else begin
            case (rotation_state)
                3'b101: begin
                    selGrn = 2'b10; // frwd_curr
                    selYlw = 2'b01; // rev_curr
                    selBlu = 2'b00; // HIGH_Z
                end
                3'b100: begin
                    selGrn = 2'b10; // frwd_curr
                    selYlw = 2'b00; // HIGH_Z
                    selBlu = 2'b01; // rev_curr
                end
                3'b110: begin
                    selGrn = 2'b00; // HIGH_Z
                    selYlw = 2'b10; // frwd_curr
                    selBlu = 2'b01; // rev_curr
                end
                3'b010: begin
                    selGrn = 2'b01; // rev_curr
                    selYlw = 2'b10; // frwd_curr
                    selBlu = 2'b00; // HIGH_Z
                end
                3'b011: begin
                    selGrn = 2'b01; // rev_curr
                    selYlw = 2'b00; // HIGH_Z
                    selBlu = 2'b10; // frwd_curr
                end
                default: begin // rotation_state == 3'b001
                    selGrn = 2'b00; // HIGH_Z
                    selYlw = 2'b01; // rev_curr
                    selBlu = 2'b10; // frwd_curr
                end
            endcase
        end
    end
    // END COMBO LOGIC

    // GENERATE DUTY CYCLE
    logic [10:0] normal_op;
    assign normal_op = drv_mag[11:2] + 11'h400;
    assign duty = brake_n ? normal_op : 11'h600;

endmodule