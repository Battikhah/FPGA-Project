// Claude was used in this file to only add more things to the waveform

`timescale 10ns/1ns

module matrix_mult_top_tb;

reg  clk, reset, start;
reg  [23:0] IR_in;
wire done;

matrix_mult_top DUT (clk, reset, start, IR_in, done);

// Hierarchical probes — control unit state
wire [3:0] cu_state   = DUT.cu.state;

// Hierarchical probes — datapath counters and registers
wire [1:0] i_cnt      = DUT.du.i_count;
wire [1:0] j_cnt      = DUT.du.j_count;
wire [1:0] k_cnt      = DUT.du.k_count;
wire [15:0] A_reg     = DUT.du.A_reg;
wire [15:0] B_reg     = DUT.du.B_reg;
wire [34:0] sum_reg   = DUT.du.sum_reg;

// Hierarchical probes — memory interface
wire [5:0]  mem_addr  = DUT.mem_addr;
wire [15:0] mem_dout  = DUT.mem_dout;
wire [15:0] mem_din   = DUT.mem_din;
wire        mem_we    = DUT.mem_we;

// Hierarchical probes — key control signals
wire load_A  = DUT.load_A_reg;
wire load_B  = DUT.load_B_reg;
wire mul_en  = DUT.do_multiply;
wire wr_C    = DUT.write_C;
wire clr_sum = DUT.clear_sum;

// 50 MHz clock
always #1 clk = ~clk;

// State name decoder for readable $display output
function [8*10-1:0] state_name;
    input [3:0] s;
    case (s)
        4'd0:  state_name = "IDLE      ";
        4'd1:  state_name = "INIT      ";
        4'd2:  state_name = "CLEAR     ";
        4'd3:  state_name = "FETCH_A   ";
        4'd4:  state_name = "LOAD_A    ";
        4'd5:  state_name = "FETCH_B   ";
        4'd6:  state_name = "LOAD_B    ";
        4'd7:  state_name = "MULTIPLY  ";
        4'd8:  state_name = "INC_K     ";
        4'd9:  state_name = "WRITE_C   ";
        4'd10: state_name = "INC_I     ";
        4'd11: state_name = "DONE      ";
        default: state_name = "UNKNOWN   ";
    endcase
endfunction

initial begin
    clk   = 0;
    reset = 1;
    start = 0;

    // opcode=0001, BASE_A=0, BASE_B=16, BASE_C=32, reserved=00
    IR_in = 24'b0001_000000_010000_100000_00;

    #2 reset = 0;
    #2 start = 1;
    #2 start = 0;

    wait (done == 1);
    #4; // allow final write to settle

    // ----------------------------------------------------------------
    // Dump result matrix C from memory (addresses 32–47)
    // ----------------------------------------------------------------
    $display("\n======== Result Matrix C (from memory) ========");
    $display("  C[0][0]=%0d  C[0][1]=%0d  C[0][2]=%0d  C[0][3]=%0d",
        $signed(DUT.mu.mem[32]), $signed(DUT.mu.mem[33]),
        $signed(DUT.mu.mem[34]), $signed(DUT.mu.mem[35]));
    $display("  C[1][0]=%0d  C[1][1]=%0d  C[1][2]=%0d  C[1][3]=%0d",
        $signed(DUT.mu.mem[36]), $signed(DUT.mu.mem[37]),
        $signed(DUT.mu.mem[38]), $signed(DUT.mu.mem[39]));
    $display("  C[2][0]=%0d  C[2][1]=%0d  C[2][2]=%0d  C[2][3]=%0d",
        $signed(DUT.mu.mem[40]), $signed(DUT.mu.mem[41]),
        $signed(DUT.mu.mem[42]), $signed(DUT.mu.mem[43]));
    $display("  C[3][0]=%0d  C[3][1]=%0d  C[3][2]=%0d  C[3][3]=%0d",
        $signed(DUT.mu.mem[44]), $signed(DUT.mu.mem[45]),
        $signed(DUT.mu.mem[46]), $signed(DUT.mu.mem[47]));
    $display("================================================\n");

    #10 $stop;
end

// ----------------------------------------------------------------
// Structured per-cycle log — prints on every rising clock edge
// ----------------------------------------------------------------
always @(posedge clk) begin
    $display("%0t ns | %-10s | i=%0d j=%0d k=%0d | addr=%02h dout=%04h din=%04h we=%b | A=%04h B=%04h sum=%0d | ldA=%b ldB=%b mul=%b wrC=%b clr=%b | done=%b",
        $time * 10,
        state_name(cu_state),
        i_cnt, j_cnt, k_cnt,
        mem_addr, mem_dout, mem_din, mem_we,
        A_reg, B_reg, sum_reg,
        load_A, load_B, mul_en, wr_C, clr_sum,
        done);
end

// ----------------------------------------------------------------
// Waveform dump — captures every signal for GTKWave / ModelSim
// ----------------------------------------------------------------
initial begin
    $dumpfile("matrix_mult_tb.vcd");
    $dumpvars(0, matrix_mult_top_tb); // dumps all nets in TB scope
    // also force-dump internal hierarchy so waveform viewer shows them
    $dumpvars(1, DUT.cu);
    $dumpvars(1, DUT.du);
    $dumpvars(1, DUT.mu);
end

endmodule