`timescale 10ns/1ns

module TB_matrix_mult_top;

    reg        clk, reset, start;
    reg [23:0] IR_in;
    wire       done;

    matrix_mult_top dut (.clk(clk), .reset(reset), .start(start), .IR_in(IR_in), .done(done));

    always #1 clk = ~clk;

    initial begin
        // TC1: A=[1..16]@0, B=identity@16, C@32 — expect C=A
        #0  clk = 0; reset = 1; start = 0; IR_in = 24'b0001_000000_010000_100000_00;
        #4  reset = 0;
        #2  start = 1;
        #2  start = 0;
        #500;
        $display("%0dns TC1 done: C[0..3]=%0d %0d %0d %0d | C[4..7]=%0d %0d %0d %0d | C[8..11]=%0d %0d %0d %0d | C[12..15]=%0d %0d %0d %0d",
            $time*10,
            dut.mu.mem[32], dut.mu.mem[33], dut.mu.mem[34], dut.mu.mem[35],
            dut.mu.mem[36], dut.mu.mem[37], dut.mu.mem[38], dut.mu.mem[39],
            dut.mu.mem[40], dut.mu.mem[41], dut.mu.mem[42], dut.mu.mem[43],
            dut.mu.mem[44], dut.mu.mem[45], dut.mu.mem[46], dut.mu.mem[47]);

        // TC2: swap — A=identity@16, B=[1..16]@0, C@32 — expect C=B
        reset = 1; IR_in = 24'b0001_010000_000000_100000_00;
        #4  reset = 0;
        #2  start = 1;
        #2  start = 0;
        #500;
        $display("%0dns TC2 done: C[0..3]=%0d %0d %0d %0d | C[4..7]=%0d %0d %0d %0d | C[8..11]=%0d %0d %0d %0d | C[12..15]=%0d %0d %0d %0d",
            $time*10,
            dut.mu.mem[32], dut.mu.mem[33], dut.mu.mem[34], dut.mu.mem[35],
            dut.mu.mem[36], dut.mu.mem[37], dut.mu.mem[38], dut.mu.mem[39],
            dut.mu.mem[40], dut.mu.mem[41], dut.mu.mem[42], dut.mu.mem[43],
            dut.mu.mem[44], dut.mu.mem[45], dut.mu.mem[46], dut.mu.mem[47]);

        $stop;
    end

    initial $monitor("%0dns  reset=%b  start=%b  done=%b", $time*10, reset, start, done);

endmodule