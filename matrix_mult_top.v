module matrix_mult_top (
 input clk, // 50 MHz
 input reset, // active high reset
 input start, // active high input
 input [23:0] IR_in, // fixsed matrix-multiply instruction
 output done // assert when operation is complete
);

// Opcode breakdown
wire [5:0] base_A = IR_in[19:14];
wire [5:0] base_B = IR_in[13:8];
wire [5:0] base_C = IR_in[7:2];

// Control Vectors
wire init_ijk, init_k, init_j, init_i;
wire inc_k, inc_j, inc_i;
wire load_A_reg, load_B_reg;
wire sel_addr, sel_AB;
wire clear_sum, do_multiply, write_C;

// Status Vectors
wire k_done, j_done, i_done;

// Memory Interface
wire [5:0] mem_addr;
wire [15:0] mem_din, mem_dout;
wire mem_we;

// Instantiate Control Unit 
control_unit cu (
    .clk        (clk),
    .reset      (reset),
    .start      (start),
    .k_done     (k_done),
    .j_done     (j_done),
    .i_done     (i_done),
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
    .done       (done)
);

// Instantiate Datapath
datapath du (
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
// Instantiate Memory
memory mu (
    .clk  (clk),
    .we   (mem_we),
    .addr (mem_addr),
    .din  (mem_din),
    .dout (mem_dout)
);


endmodule