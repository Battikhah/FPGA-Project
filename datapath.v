module datapath (
	input clk,
	input reset,
	
	// Based on datapaths shown in the matrix_mult_top RTL viewer shown in the file
	// Control Vectors (CU to DU)
		// init
		input init_ijk,
		input init_k,
		input init_j,
		input init_i,

		// increment flags
		input inc_k, input inc_j, input inc_i,

		// latch mem_dout
		input load_A_reg,
		input load_B_reg,

		// Selectors
		input sel_addr,    // 0=read addr, 1=write addr (C region)
		input sel_AB,      // 0=A address, 1=B address
		input clear_sum,
		input do_multiply,
		input write_C,     // write sum to C[i][j] in memory

	// Base Addresses (From IU)
	input [5:0] base_A,
	input [5:0] base_B,
	input [5:0] base_C,
	
	// Mem Interface (DU to and from MU)
    input  [15:0] mem_dout,
    output reg [5:0]  mem_addr,
    output [15:0] mem_din,
    output mem_we,
	
	// Status Vector (DU to CU)
	output k_done,
	output j_done,
	output i_done
);

// important variables and regs
	// Counters for IJK
	reg [1:0] i_count, j_count, k_count;

	// A, B and sum regs
	reg [15:0] A_reg, B_reg;
	reg [34:0] sum_reg; // only internal will be 34 bits (output matrix will be limited to 16 bits)

	// CU to MU through DU
	assign mem_we = write_C;
	assign mem_din = sum_reg;
	
	// Status vectors
	assign k_done = (k_count ==2'd3);
	assign j_done = (j_count ==2'd3);
	assign i_done = (i_count ==2'd3);


// loop counters
always @(posedge clk or posedge reset) begin
	// for some reason reset || init_ijk did notr work, has to split them
	if (reset) begin
		i_count <= 2'b00;
		j_count <= 2'b00;
		k_count <= 2'b00;
	end 
	
	else begin
		if (init_ijk) begin
			i_count <= 2'b00;
			j_count <= 2'b00;
			k_count <= 2'b00;
		end 
		
		else begin
			if (init_i) i_count <= 2'b00;
			if (init_j) j_count <= 2'b00;
			if (init_k) k_count <= 2'b00;
			if (inc_k && !init_k) k_count <= k_count + 1'b1;
			if (inc_j && !init_j) j_count <= j_count + 1'b1;
			if (inc_i && !init_i) i_count <= i_count + 1'b1;
		end
	end
end

// set up regs, reset/init, loading
always @(posedge clk or posedge reset) begin
	    if (reset) begin
        A_reg <= 16'd0;
        B_reg <= 16'd0;
        sum_reg <= 16'd0;
    end else begin
        if (load_A_reg) A_reg <= mem_dout;
        if (load_B_reg) B_reg <= mem_dout;
        if (clear_sum)  sum_reg <= 34'd0;
        if (do_multiply) sum_reg <= sum_reg + (A_reg[15:0] * B_reg[15:0]);
    end
end

// which mem do we need this cycle
always @(*) begin
    if (sel_addr)
        // Address of C[i][j]: BASE_C + i*4 + j
        mem_addr = base_C + {4'b0, i_count, 2'b0} + {4'b0, j_count};

    else if (!sel_AB)
        // Address of A[i][k]: BASE_A + i*4 + k
        mem_addr = base_A + {4'b0, i_count, 2'b0} + {4'b0, k_count};
    
	else
        // Address of B[k][j]: BASE_B + k*4 + j
        mem_addr = base_B + {4'b0, k_count, 2'b0} + {4'b0, j_count};
end

endmodule