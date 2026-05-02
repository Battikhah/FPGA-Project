module matrix_mult_top (
 input clk, // 50 MHz
 input reset, // active high reset
 input start, // active high input
 input [23:0] IR_in, // fixsed matrix-multiply instruction
 output done // assert when operation is complete
);

endmodule