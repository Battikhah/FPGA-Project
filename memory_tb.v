// Claude Generated TB

`timescale 1ns/1ps

module memory_tb;
    reg         clk;
    reg         we;
    reg  [5:0]  addr;
    reg  [15:0] din;
    wire [15:0] dout;

    memory uut (
        .clk  (clk),
        .we   (we),
        .addr (addr),
        .din  (din),
        .dout (dout)
    );

    // 50 MHz clock (20ns period)
    initial clk = 0;
    always #10 clk = ~clk;

    // Expected values for Matrix A (hex 0001..0010)
    reg [15:0] expected_A [0:15];
    // Expected values for Matrix B (identity)
    reg [15:0] expected_B [0:15];

    integer i;
    integer errors;

    initial begin
        // --- Fill expected arrays ---
        // Matrix A: 1 to 16
        begin : fill_A
            integer n;
            for (n = 0; n < 16; n = n + 1)
                expected_A[n] = n + 1;
        end

        // Matrix B: identity (row-major)
        // [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]
        begin : fill_B
            integer r, c;
            for (r = 0; r < 4; r = r + 1)
                for (c = 0; c < 4; c = c + 1)
                    expected_B[r*4 + c] = (r == c) ? 16'h0001 : 16'h0000;
        end

        we     = 0;
        addr   = 0;
        din    = 0;
        errors = 0;

        // Let memory settle after init
        repeat(2) @(posedge clk);

        // -----------------------------------------------
        // TEST 1: Verify Matrix A loads correctly
        // -----------------------------------------------
        $display("============================================");
        $display("  TEST 1: Matrix A (addresses 0-15)");
        $display("============================================");
        $display("  Row-major layout: A[row][col]");
        for (i = 0; i < 16; i = i + 1) begin
            addr = i;
            @(posedge clk); #1;
            if (dout === expected_A[i])
                $display("  PASS  mem[%2d] = A[%0d][%0d] = 0x%04h (%0d)",
                         i, i/4, i%4, dout, dout);
            else begin
                $display("  FAIL  mem[%2d] = A[%0d][%0d] = 0x%04h, expected 0x%04h",
                         i, i/4, i%4, dout, expected_A[i]);
                errors = errors + 1;
            end
        end

        // -----------------------------------------------
        // TEST 2: Verify Matrix B loads correctly (identity)
        // -----------------------------------------------
        $display("============================================");
        $display("  TEST 2: Matrix B (addresses 16-31)");
        $display("============================================");
        for (i = 0; i < 16; i = i + 1) begin
            addr = i + 16;
            @(posedge clk); #1;
            if (dout === expected_B[i])
                $display("  PASS  mem[%2d] = B[%0d][%0d] = 0x%04h",
                         i+16, i/4, i%4, dout);
            else begin
                $display("  FAIL  mem[%2d] = B[%0d][%0d] = 0x%04h, expected 0x%04h",
                         i+16, i/4, i%4, dout, expected_B[i]);
                errors = errors + 1;
            end
        end

        // -----------------------------------------------
        // TEST 3: Verify Matrix C region starts as zeros
        // -----------------------------------------------
        $display("============================================");
        $display("  TEST 3: Matrix C region (addresses 32-47)");
        $display("============================================");
        for (i = 32; i < 48; i = i + 1) begin
            addr = i;
            @(posedge clk); #1;
            if (dout === 16'h0000)
                $display("  PASS  mem[%2d] = 0x%04h (zero as expected)", i, dout);
            else begin
                $display("  FAIL  mem[%2d] = 0x%04h, expected 0x0000", i, dout);
                errors = errors + 1;
            end
        end

        // -----------------------------------------------
        // TEST 4: Write/read-back check on C region
        // -----------------------------------------------
        $display("============================================");
        $display("  TEST 4: Write then read-back to C region");
        $display("============================================");
        begin : write_test
            reg [15:0] test_val;
            test_val = 16'hABCD;
            addr = 32; din = test_val; we = 1;
            @(posedge clk); #1;
            we = 0;
            // read back (addr already 32, dout updates next clock)
            @(posedge clk); #1;
            if (dout === test_val)
                $display("  PASS  mem[32] write/read-back = 0x%04h", dout);
            else begin
                $display("  FAIL  mem[32] = 0x%04h, expected 0x%04h", dout, test_val);
                errors = errors + 1;
            end
        end

        // -----------------------------------------------
        // Summary
        // -----------------------------------------------
        $display("============================================");
        if (errors == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  %0d TEST(S) FAILED", errors);
        $display("============================================");

        $finish;
    end

    initial begin
        $dumpfile("memory_tb.vcd");
        $dumpvars(0, memory_tb);
    end

endmodule