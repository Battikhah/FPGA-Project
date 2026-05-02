module memory (
    input	clk,
    input	we,	// write enable
    input	[5:0]  addr,	// 2^6 = 64, enough for all data addresses
    input	[15:0] din,	// data coming in (only matters when we=1)
    output reg [15:0] dout	// data going out
);

// load vals from .mif
// https://community.altera.com/discussions/quartus-prime/load-mif-file-on-de0-cv-board/241316 
// (* ram_init_file = "memory_init.mif" *)
// Doesn't work with simulation. cannot be tested :/


reg [15:0] mem [0:63];
//works with simulation
initial begin
    $readmemh("memory_init.hex", mem);
end


always @(posedge clk) begin
	if (we)
		mem[addr] <= din;
	// We always need to read
	dout <= mem[addr];
end

endmodule
		
	
