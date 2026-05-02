// Claude Generated TB

`timescale 1ns/1ps

module control_unit_tb;

reg  clk, reset, start;
reg  k_done, j_done, i_done;

wire init_ijk, init_k, init_j, init_i;
wire inc_k, inc_j, inc_i;
wire load_A_reg, load_B_reg;
wire sel_addr, sel_AB;
wire clear_sum, do_multiply, write_C;
wire done;

control_unit uut (
    .clk(clk), .reset(reset), .start(start),
    .k_done(k_done), .j_done(j_done), .i_done(i_done),
    .init_ijk(init_ijk), .init_k(init_k), .init_j(init_j), .init_i(init_i),
    .inc_k(inc_k), .inc_j(inc_j), .inc_i(inc_i),
    .load_A_reg(load_A_reg), .load_B_reg(load_B_reg),
    .sel_addr(sel_addr), .sel_AB(sel_AB),
    .clear_sum(clear_sum), .do_multiply(do_multiply), .write_C(write_C),
    .done(done)
);

always #10 clk = ~clk;

// advance to the point where state=8 (INC_K) with given status inputs
// assumes we are currently in S_CLEAR (state 2)
task reach_inc_k;
    input k_in, j_in, i_in;
    begin
        // CLEAR(2) -> FETCH_A(3) -> LOAD_A(4) -> FETCH_B(5) -> LOAD_B(6) -> MULTIPLY(7) -> INC_K(8)
        repeat(5) @(negedge clk);
        k_done = k_in; j_done = j_in; i_done = i_in;
        @(negedge clk); // now in INC_K
    end
endtask

integer errors;

initial begin
    clk = 0; reset = 1; start = 0;
    k_done = 0; j_done = 0; i_done = 0;
    errors = 0;
    repeat(2) @(negedge clk);
    reset = 0;

    // ----------------------------------------------------------------
    // T1: stays IDLE without start
    // ----------------------------------------------------------------
    repeat(4) @(negedge clk);
    if (done || init_ijk) begin
        $display("FAIL T1: spurious output while idle");
        errors = errors + 1;
    end

    // ----------------------------------------------------------------
    // T2: INIT fires init_ijk
    // ----------------------------------------------------------------
    start = 1;
    @(negedge clk); // IDLE -> INIT
    start = 0;
    if (!init_ijk) begin $display("FAIL T2: init_ijk not asserted in INIT"); errors = errors + 1; end

    // ----------------------------------------------------------------
    // T3: CLEAR asserts clear_sum
    // ----------------------------------------------------------------
    @(negedge clk); // INIT -> CLEAR
    if (!clear_sum) begin $display("FAIL T3: clear_sum not asserted in CLEAR"); errors = errors + 1; end
    if (sel_addr)   begin $display("FAIL T3: sel_addr high in CLEAR");          errors = errors + 1; end

    // ----------------------------------------------------------------
    // T4: FETCH_A — no latch, A address selected
    // ----------------------------------------------------------------
    @(negedge clk); // CLEAR -> FETCH_A
    if (load_A_reg) begin $display("FAIL T4: load_A_reg early in FETCH_A"); errors = errors + 1; end
    if (sel_AB)     begin $display("FAIL T4: sel_AB high in FETCH_A");      errors = errors + 1; end

    // ----------------------------------------------------------------
    // T5: LOAD_A latches A and switches to B address
    // ----------------------------------------------------------------
    @(negedge clk); // FETCH_A -> LOAD_A
    if (!load_A_reg) begin $display("FAIL T5: load_A_reg not asserted in LOAD_A"); errors = errors + 1; end
    if (!sel_AB)     begin $display("FAIL T5: sel_AB not switched in LOAD_A");     errors = errors + 1; end

    // ----------------------------------------------------------------
    // T6: FETCH_B — no latch, B address held
    // ----------------------------------------------------------------
    @(negedge clk); // LOAD_A -> FETCH_B
    if (load_B_reg) begin $display("FAIL T6: load_B_reg early in FETCH_B"); errors = errors + 1; end
    if (!sel_AB)    begin $display("FAIL T6: sel_AB dropped in FETCH_B");   errors = errors + 1; end

    // ----------------------------------------------------------------
    // T7: LOAD_B latches B
    // ----------------------------------------------------------------
    @(negedge clk); // FETCH_B -> LOAD_B
    if (!load_B_reg) begin $display("FAIL T7: load_B_reg not asserted in LOAD_B"); errors = errors + 1; end

    // ----------------------------------------------------------------
    // T8: MULTIPLY asserts do_multiply
    // ----------------------------------------------------------------
    @(negedge clk); // LOAD_B -> MULTIPLY
    if (!do_multiply) begin $display("FAIL T8: do_multiply not asserted in MULTIPLY"); errors = errors + 1; end

    // ----------------------------------------------------------------
    // T9: INC_K with k not done -> inc_k high, loops back to CLEAR
    // ----------------------------------------------------------------
    k_done = 0;
    @(negedge clk); // MULTIPLY -> INC_K
    if (!inc_k)  begin $display("FAIL T9: inc_k not asserted when k not done"); errors = errors + 1; end
    if (write_C) begin $display("FAIL T9: write_C asserted before k done");     errors = errors + 1; end
    @(negedge clk); // INC_K -> CLEAR
    if (!clear_sum) begin $display("FAIL T9: did not return to CLEAR after k loop"); errors = errors + 1; end

    // ----------------------------------------------------------------
    // T10: INC_K with k done -> WRITE_C: write_C, sel_addr, init_k, inc_j asserted
    //      j not done so inc_j should be high
    // ----------------------------------------------------------------
    k_done = 1; j_done = 0; i_done = 0;
    reach_inc_k(1, 0, 0); // already in INC_K now
    if (inc_k)  begin $display("FAIL T10: inc_k asserted when k_done");  errors = errors + 1; end
    @(negedge clk); // INC_K -> WRITE_C
    if (!write_C)  begin $display("FAIL T10: write_C not asserted in WRITE_C"); errors = errors + 1; end
    if (!sel_addr) begin $display("FAIL T10: sel_addr not high in WRITE_C");    errors = errors + 1; end
    if (!init_k)   begin $display("FAIL T10: init_k not asserted in WRITE_C");  errors = errors + 1; end
    if (!inc_j)    begin $display("FAIL T10: inc_j not asserted when j not done in WRITE_C"); errors = errors + 1; end

    // ----------------------------------------------------------------
    // T11: WRITE_C with j not done -> loops back to CLEAR
    // ----------------------------------------------------------------
    @(negedge clk); // WRITE_C -> CLEAR (j not done)
    if (!clear_sum) begin $display("FAIL T11: did not return to CLEAR when j not done"); errors = errors + 1; end

    // ----------------------------------------------------------------
    // T12: WRITE_C with j done, i not done -> INC_I: init_j and inc_i asserted
    // ----------------------------------------------------------------
    k_done = 1; j_done = 1; i_done = 0;
    reach_inc_k(1, 1, 0);   // in INC_K
    @(negedge clk);          // INC_K -> WRITE_C
    @(negedge clk);          // WRITE_C -> INC_I
    if (!init_j) begin $display("FAIL T12: init_j not asserted in INC_I"); errors = errors + 1; end
    if (!inc_i)  begin $display("FAIL T12: inc_i not asserted when i not done"); errors = errors + 1; end
    if (done)    begin $display("FAIL T12: done asserted before i_done");  errors = errors + 1; end
    @(negedge clk); // INC_I -> CLEAR
    if (!clear_sum) begin $display("FAIL T12: did not return to CLEAR after INC_I"); errors = errors + 1; end

    // ----------------------------------------------------------------
    // T13: all done -> state 11, done asserts and stays
    // ----------------------------------------------------------------
    k_done = 1; j_done = 1; i_done = 1;
    reach_inc_k(1, 1, 1);   // in INC_K
    @(negedge clk);          // INC_K -> WRITE_C
    @(negedge clk);          // WRITE_C -> INC_I
    @(negedge clk);          // INC_I -> DONE
    if (!done) begin $display("FAIL T13: done not asserted in DONE state"); errors = errors + 1; end
    repeat(3) @(negedge clk);
    if (!done) begin $display("FAIL T13: done dropped, should stay asserted"); errors = errors + 1; end

    // ----------------------------------------------------------------
    // T14: reset clears done and returns to IDLE
    // ----------------------------------------------------------------
    reset = 1;
    @(negedge clk);
    if (done) begin $display("FAIL T14: done not cleared by reset"); errors = errors + 1; end
    reset = 0;
    repeat(4) @(negedge clk);
    if (done) begin $display("FAIL T14: done asserted after reset with no start"); errors = errors + 1; end

    // ----------------------------------------------------------------
    if (errors == 0)
        $display("ALL TESTS PASSED");
    else
        $display("%0d TEST(S) FAILED", errors);

    $finish;
end

endmodule