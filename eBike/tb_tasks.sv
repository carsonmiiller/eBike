package testTasks;
    task automatic testOmega(input logic [19:0] omega, input int highVal, input int lowVal);
      begin
        if ((omega < lowVal) || (omega > highVal)) begin
          $display("Error: omega went out of bounds");
	  $display("omega: %d", omega);
          $stop;
	end
      end
    endtask
	
    task automatic testError(input logic signed [12:0] error, input int highVal, input int lowVal);
      begin
	if ((error < lowVal) || (error > highVal)) begin
	  $display("Error: error went out of bounds");
	  $display("error: %d", error);
	  $stop;
	end
      end
    endtask
endpackage

