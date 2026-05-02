module control_unit (
    // Inputs
    input clk,
    input reset,
    input start,
    input k_done,
    input j_done,
    input i_done,

    // Outputs
        // init
        output reg init_ijk,
        output reg init_k,
        output reg init_j,
        output reg init_i,

        // inc
        output reg inc_k,
        output reg inc_j,
        output reg inc_i,

        // load
        output reg load_A_reg,
        output reg load_B_reg,

        // sel
        output reg sel_addr,
        output reg sel_AB,

        //other
        output reg clear_sum,
        output reg do_multiply,
        output reg write_C,
        output reg done
);

reg [3:0] state, next_state; // There are a total of 12 states
// Idle - init - clear - fetch a - load a - fetch b - load b - multiply - inc k - write c & inc j - inc i - done

// State register
always @(posedge clk or posedge reset) 
    state <= reset ? 0 : next_state;

// Next state logic
always @(*) begin
    case (state)
        0:  next_state = start   ? 1  : 0; // Idle  - wait for start signal
        1:  next_state = 2; // init - set i, j, k to 0
        2:  next_state = 3; // clear - clear sum register
        3:  next_state = 4; // fetch a - set address to A[i][k]
        4:  next_state = 5; // load a - load A[i][k] into register
        5:  next_state = 6; // fetch b - set address to B[k][j]
        6:  next_state = 7; // load b - load B[k][j] into register
        7:  next_state = 8; // multiply - multiply A[i][k] and B[k][j], add to sum
        8:  next_state = k_done  ? 9  : 2; // inc k - if k done, move to write c, else inc k and repeat
        9:  next_state = j_done  ? 10 : 2; // write c - if j done, move to inc i, else back to clear
        10: next_state = i_done  ? 11 : 2; // inc i - if i done, move to done, else back to clear
        11: next_state = 11; // done
        default: next_state = 0;
    endcase
end
 
// Output logic
always @(*) begin
    init_ijk   = 0;
    init_k     = 0;
    init_j     = 0;
    init_i     = 0;
    inc_k      = 0;
    inc_j      = 0;
    inc_i      = 0;
    load_A_reg = 0;
    load_B_reg = 0;
    sel_addr   = 0;
    sel_AB     = 0;
    clear_sum  = 0;
    do_multiply = 0;
    write_C    = 0;
    done       = 0;
    case (state)
        1: begin // init
            init_ijk = 1;
        end
        2: begin // clear
            clear_sum = 1;
        end
        3: begin // fetch a
            sel_addr = 0;
            sel_AB   = 0;
        end
        4: begin // load a
            load_A_reg = 1;
            sel_AB     = 1;  // switch address to B for next fetch
        end
        5: begin // fetch b
            sel_addr = 0;
            sel_AB   = 1;
        end
        6: begin // load b
            load_B_reg = 1;
        end
        7: begin // multiply
            do_multiply = 1;
        end
        8: begin // inc k
            inc_k = ~k_done;
        end
        9: begin // write c
            write_C  = 1;
            sel_addr = 1;   // address C[i][j]
            init_k   = 1;   // reset k for next (i,j)
            inc_j    = ~j_done;
        end
        10: begin // inc i
            init_j = 1;        // reset j for new row
            inc_i  = ~i_done;
        end
        11: begin // done
            done = 1;
        end
    endcase
end

endmodule