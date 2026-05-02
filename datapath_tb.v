// Claude Geneerated TB

// =============================================================================
// datapath_tb.v
// Testbench for datapath.v
//
// Strategy:
//   - Instantiate datapath + memory side-by-side (no top-level module needed).
//   - Pre-load memory manually inside the testbench so no .hex file is needed.
//   - Drive control signals by hand to walk through one full 4x4 matrix
//     multiplication (A x I = A), then verify every C[i][j].
//
// Test matrices
//   Matrix A (addresses 0-15, row-major):
//     [ 1  2  3  4 ]
//     [ 5  6  7  8 ]
//     [ 9 10 11 12 ]
//     [13 14 15 16 ]
//
//   Matrix B = Identity (addresses 16-31):
//     [ 1  0  0  0 ]
//     [ 0  1  0  0 ]
//     [ 0  0  1  0 ]
//     [ 0  0  0  1 ]
//
//   Expected C = A (addresses 32-47).
// =============================================================================

`timescale 1ns/1ps

module datapath_tb;

// ---------------------------------------------------------------------------
// Clock & reset
// ---------------------------------------------------------------------------
reg clk, reset;
parameter CLK_PERIOD = 20; // 50 MHz → 20 ns period

initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

// ---------------------------------------------------------------------------
// DUT control inputs
// ---------------------------------------------------------------------------
reg init_ijk, init_k, init_j, init_i;
reg inc_k, inc_j, inc_i;
reg load_A_reg, load_B_reg;
reg sel_addr, sel_AB;
reg clear_sum, do_multiply, write_C;

// Base addresses (from instruction register)
reg [5:0] base_A, base_B, base_C;

// ---------------------------------------------------------------------------
// Memory wires
// ---------------------------------------------------------------------------
wire [15:0] mem_dout;
wire [5:0]  mem_addr;
wire [15:0] mem_din;
wire        mem_we;

// ---------------------------------------------------------------------------
// Status outputs from DU
// ---------------------------------------------------------------------------
wire k_done, j_done, i_done;

// ---------------------------------------------------------------------------
// Instantiate datapath (DUT)
// ---------------------------------------------------------------------------
datapath DUT (
    .clk        (clk),
    .reset      (reset),
    .init_ijk   (init_ijk),
    .init_k     (init_k),
    .init_j     (init_j),
    .init_i     (init_i),
    .inc_k      (inc_k),
    .inc_j      (inc_j),
    .inc_i      (inc_i),
    .load_A_reg (load_A_reg),
    .load_B_reg (load_B_reg),
    .sel_addr   (sel_addr),
    .sel_AB     (sel_AB),
    .clear_sum  (clear_sum),
    .do_multiply(do_multiply),
    .write_C    (write_C),
    .base_A     (base_A),
    .base_B     (base_B),
    .base_C     (base_C),
    .mem_dout   (mem_dout),
    .mem_addr   (mem_addr),
    .mem_din    (mem_din),
    .mem_we     (mem_we),
    .k_done     (k_done),
    .j_done     (j_done),
    .i_done     (i_done)
);

// ---------------------------------------------------------------------------
// Instantiate memory (direct — no .hex file needed; we fill it below)
// ---------------------------------------------------------------------------
reg        mem_we_tb;      // testbench write enable for pre-loading
reg [5:0]  mem_addr_tb;
reg [15:0] mem_din_tb;

// Mux between testbench pre-load and DUT-driven accesses
wire        mem_we_mux   = reset ? mem_we_tb   : mem_we;
wire [5:0]  mem_addr_mux = reset ? mem_addr_tb : mem_addr;
wire [15:0] mem_din_mux  = reset ? mem_din_tb  : mem_din;

// Simple inline memory (mirrors memory.v but without $readmemh)
reg [15:0] mem_array [0:63];

// Synchronous read/write – matches memory.v behaviour
reg [15:0] mem_dout_reg;
always @(posedge clk) begin
    if (mem_we_mux)
        mem_array[mem_addr_mux] <= mem_din_mux;
    mem_dout_reg <= mem_array[mem_addr_mux];
end
assign mem_dout = mem_dout_reg;

// ---------------------------------------------------------------------------
// Helper task: default all control signals to 0
// ---------------------------------------------------------------------------
task all_idle;
begin
    init_ijk   = 0; init_k = 0; init_j = 0; init_i = 0;
    inc_k      = 0; inc_j  = 0; inc_i  = 0;
    load_A_reg = 0; load_B_reg = 0;
    sel_addr   = 0; sel_AB = 0;
    clear_sum  = 0; do_multiply = 0; write_C = 0;
    mem_we_tb  = 0;
end
endtask

// ---------------------------------------------------------------------------
// Helper task: tick one clock
// ---------------------------------------------------------------------------
task tick;
begin
    @(posedge clk); #1;
end
endtask

// ---------------------------------------------------------------------------
// Helper task: read a memory location (poll one cycle after addr is stable)
// ---------------------------------------------------------------------------
reg [15:0] rd_val;
task mem_read;
    input [5:0] addr;
begin
    @(posedge clk); #1;
    rd_val = mem_array[addr]; // direct array read – just for checking
end
endtask

// ---------------------------------------------------------------------------
// Helper task: manually perform one multiply-accumulate cycle
//   Sequence per (i,j,k):
//     1. Point to A[i][k]  → load_A_reg on next clock
//     2. Point to B[k][j]  → load_B_reg on next clock
//     3. do_multiply
// ---------------------------------------------------------------------------
task mac_step;
    input [1:0] i_val, j_val, k_val; // only used for comments, counters set externally
begin
    // --- Read A[i][k] ---
    sel_addr = 0; sel_AB = 0;   // address = BASE_A + i*4 + k
    tick;
    load_A_reg = 1;
    tick;
    load_A_reg = 0;

    // --- Read B[k][j] ---
    sel_addr = 0; sel_AB = 1;   // address = BASE_B + k*4 + j
    tick;
    load_B_reg = 1;
    tick;
    load_B_reg = 0;

    // --- Accumulate ---
    do_multiply = 1;
    tick;
    do_multiply = 0;
end
endtask

// ---------------------------------------------------------------------------
// Main test
// ---------------------------------------------------------------------------
integer i_v, j_v, k_v;
integer errors;
reg [15:0] expected [0:15]; // expected C values (flat, row-major)

initial begin
    $dumpfile("datapath_tb.vcd");
    $dumpvars(0, datapath_tb);

    errors = 0;
    all_idle;

    // -----------------------------------------------------------------------
    // 1. Reset
    // -----------------------------------------------------------------------
    reset = 1;
    repeat(4) @(posedge clk);

    // -----------------------------------------------------------------------
    // 2. Pre-load memory while reset is high
    //    Matrix A: A[i][j] = i*4 + j + 1  (values 1..16) at addresses 0-15
    //    Matrix B: Identity                               at addresses 16-31
    //    Matrix C: all zeros                              at addresses 32-47
    // -----------------------------------------------------------------------
    mem_we_tb = 1;
    begin : preload
        integer idx;
        // Matrix A
        for (idx = 0; idx < 16; idx = idx + 1) begin
            mem_addr_tb = idx;
            mem_din_tb  = idx + 1; // 1,2,...,16
            @(posedge clk);
        end
        // Matrix B – identity
        for (idx = 0; idx < 16; idx = idx + 1) begin
            mem_addr_tb = 16 + idx;
            // Identity: element [r][c] = 1 if r==c else 0; r = idx/4, c = idx%4
            mem_din_tb  = ((idx / 4) == (idx % 4)) ? 16'd1 : 16'd0;
            @(posedge clk);
        end
        // Matrix C – zeros
        for (idx = 0; idx < 16; idx = idx + 1) begin
            mem_addr_tb = 32 + idx;
            mem_din_tb  = 16'd0;
            @(posedge clk);
        end
    end
    mem_we_tb = 0;

    // -----------------------------------------------------------------------
    // 3. Release reset; set base addresses
    // -----------------------------------------------------------------------
    reset  = 0;
    base_A = 6'd0;
    base_B = 6'd16;
    base_C = 6'd32;
    all_idle;

    // -----------------------------------------------------------------------
    // 4. Assert init_ijk to zero all counters
    // -----------------------------------------------------------------------
    init_ijk = 1; tick; init_ijk = 0;

    // -----------------------------------------------------------------------
    // 5. Verify reset state of status signals
    // -----------------------------------------------------------------------
    $display("\n--- STATUS SIGNALS AFTER RESET/INIT ---");
    $display("k_done=%0b  j_done=%0b  i_done=%0b  (expect 0 0 0)",
              k_done, j_done, i_done);
    if (k_done || j_done || i_done) begin
        $display("FAIL: status signals should be 0 after init"); errors=errors+1;
    end

    // -----------------------------------------------------------------------
    // 6. Full 4x4 multiply:  C[i][j] = sum_k A[i][k]*B[k][j]
    //    Counters are driven manually here (mimicking what the CU would do).
    // -----------------------------------------------------------------------
    $display("\n--- STARTING MATRIX MULTIPLICATION ---");

    for (i_v = 0; i_v < 4; i_v = i_v + 1) begin
        for (j_v = 0; j_v < 4; j_v = j_v + 1) begin

            // Clear sum accumulator for new (i,j)
            clear_sum = 1; tick; clear_sum = 0;

            for (k_v = 0; k_v < 4; k_v = k_v + 1) begin
                // Execute one MAC step
                mac_step(i_v, j_v, k_v);

                // Increment k (unless last iteration)
                if (k_v < 3) begin
                    inc_k = 1; tick; inc_k = 0;
                end
            end

            // Write C[i][j]
            sel_addr = 1;                   // point to C region
            tick;
            write_C = 1; tick; write_C = 0;
            sel_addr = 0;

            // Increment j; if j reached 3, reset k and increment i
            if (j_v < 3) begin
                // reset k for next j, increment j
                init_k = 1; tick; init_k = 0;
                inc_j  = 1; tick; inc_j  = 0;
            end else begin
                // End of inner j loop: reset k and j, increment i
                init_k = 1; tick; init_k = 0;
                init_j = 1; tick; init_j = 0;
                if (i_v < 3) begin
                    inc_i = 1; tick; inc_i = 0;
                end
            end
        end
    end

    // -----------------------------------------------------------------------
    // 7. Wait a few cycles for final write to settle
    // -----------------------------------------------------------------------
    repeat(5) tick;

    // -----------------------------------------------------------------------
    // 8. Verify results
    //    Expected: C = A  (since B is identity)
    //    A[i][j] = i*4 + j + 1
    // -----------------------------------------------------------------------
    $display("\n--- VERIFYING C = A (expected since B = I) ---");
    begin : verify
        integer idx2;
        integer row, col;
        reg [15:0] got;
        reg [15:0] exp;
        for (idx2 = 0; idx2 < 16; idx2 = idx2 + 1) begin
            row = idx2 / 4;
            col = idx2 % 4;
            got = mem_array[32 + idx2];
            exp = idx2 + 1; // A[row][col] = idx2+1
            if (got !== exp) begin
                $display("FAIL C[%0d][%0d] @ addr %0d: got=%0d, expected=%0d",
                          row, col, 32+idx2, got, exp);
                errors = errors + 1;
            end else begin
                $display("PASS C[%0d][%0d] @ addr %0d = %0d",
                          row, col, 32+idx2, got);
            end
        end
    end

    // -----------------------------------------------------------------------
    // 9. Check i_done / j_done / k_done behaviour
    //    After the full loop we expect i_done, j_done, k_done = 0 because
    //    we reinitialised them. This section re-runs increments to 3 and
    //    checks the done signals.
    // -----------------------------------------------------------------------
    $display("\n--- TESTING DONE SIGNALS ---");
    init_ijk = 1; tick; init_ijk = 0;

    // Increment k three times → k_count = 3 (but done is asserted at count==3)
    inc_k = 1; tick; inc_k = 0;
    inc_k = 1; tick; inc_k = 0;
    inc_k = 1; tick; inc_k = 0;
    // One more tick so combinational k_done can propagate
    tick;
    $display("After 3 k increments: k_done=%0b (expect 1)", k_done);
    if (!k_done) begin $display("FAIL: k_done should be 1"); errors=errors+1; end

    // Increment j three times
    inc_j = 1; tick; inc_j = 0;
    inc_j = 1; tick; inc_j = 0;
    inc_j = 1; tick; inc_j = 0;
    tick;
    $display("After 3 j increments: j_done=%0b (expect 1)", j_done);
    if (!j_done) begin $display("FAIL: j_done should be 1"); errors=errors+1; end

    // Increment i three times
    inc_i = 1; tick; inc_i = 0;
    inc_i = 1; tick; inc_i = 0;
    inc_i = 1; tick; inc_i = 0;
    tick;
    $display("After 3 i increments: i_done=%0b (expect 1)", i_done);
    if (!i_done) begin $display("FAIL: i_done should be 1"); errors=errors+1; end

    // -----------------------------------------------------------------------
    // 10. Test address generation spot-checks
    // -----------------------------------------------------------------------
    $display("\n--- SPOT-CHECKING ADDRESS GENERATION ---");
    // Reset counters and set to i=2, j=1, k=3 manually
    init_ijk = 1; tick; init_ijk = 0;
    inc_i=1; tick; inc_i=0;   // i=1
    inc_i=1; tick; inc_i=0;   // i=2
    inc_j=1; tick; inc_j=0;   // j=1
    inc_k=1; tick; inc_k=0;   // k=1
    inc_k=1; tick; inc_k=0;   // k=2
    inc_k=1; tick; inc_k=0;   // k=3

    // Check A address: BASE_A + i*4 + k = 0 + 2*4 + 3 = 11
    sel_addr = 0; sel_AB = 0; tick;
    $display("A addr (i=2,k=3): mem_addr=%0d (expect 11)", mem_addr);
    if (mem_addr !== 6'd11) begin $display("FAIL"); errors=errors+1; end

    // Check B address: BASE_B + k*4 + j = 16 + 3*4 + 1 = 29
    sel_addr = 0; sel_AB = 1; tick;
    $display("B addr (k=3,j=1): mem_addr=%0d (expect 29)", mem_addr);
    if (mem_addr !== 6'd29) begin $display("FAIL"); errors=errors+1; end

    // Check C address: BASE_C + i*4 + j = 32 + 2*4 + 1 = 41
    sel_addr = 1; tick;
    $display("C addr (i=2,j=1): mem_addr=%0d (expect 41)", mem_addr);
    if (mem_addr !== 6'd41) begin $display("FAIL"); errors=errors+1; end

    // -----------------------------------------------------------------------
    // 11. Summary
    // -----------------------------------------------------------------------
    $display("\n======================================");
    if (errors == 0)
        $display("ALL TESTS PASSED");
    else
        $display("%0d TEST(S) FAILED", errors);
    $display("======================================\n");

    $finish;
end

// ---------------------------------------------------------------------------
// Timeout watchdog (prevents infinite simulation if something hangs)
// ---------------------------------------------------------------------------
initial begin
    #500000;
    $display("TIMEOUT: simulation did not finish in time");
    $finish;
end

endmodule