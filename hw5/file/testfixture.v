`timescale 1ns/10ps
`define End_CYCLE 1000000
`define cycle 40.0

`define PAT "./mosaic/test1.dat"  
`define OUT_F "./test1.raw"

module testfixture();

parameter WIDTH = 128;
parameter HEIGHT = 128;
parameter IMG_SIZE = WIDTH * HEIGHT;

integer out_f, i, in_count, cycle_count;

reg clk;
reg reset;
reg in_en;
reg flag;
wire wr_r, wr_g, wr_b;
wire done;
wire [13:0] addr_r, addr_g, addr_b;
wire [7:0] wdata_r, wdata_g, wdata_b;
reg [7:0] pixel, rdata_r, rdata_g, rdata_b;

reg	[7:0] PAT [0:IMG_SIZE-1];
reg [7:0] MEM_R [0:IMG_SIZE-1];
reg [7:0] MEM_G [0:IMG_SIZE-1];
reg [7:0] MEM_B [0:IMG_SIZE-1];

demosaic u_demosaic(.clk(clk), .reset(reset), .in_en(in_en), .data_in(pixel), .wr_r(wr_r), .addr_r(addr_r), .wdata_r(wdata_r), .rdata_r(rdata_r), 
	 .wr_g(wr_g), .addr_g(addr_g), .wdata_g(wdata_g), .rdata_g(rdata_g), .wr_b(wr_b), .addr_b(addr_b), .wdata_b(wdata_b), .rdata_b(rdata_b), .done(done));

initial begin
	out_f = $fopen(`OUT_F, "wb");
end

initial begin  
	$readmemh(`PAT, PAT);
end

initial begin
	clk = 0;
	reset = 0;
	in_en = 0;
	in_count = 0;
	cycle_count = 0;
	pixel = 'hx;
	rdata_r = 'hx;
	rdata_g = 'hx;
	rdata_b = 'hx;
	flag = 0;
	for(i = 0; i < IMG_SIZE; i = i + 1) begin
		MEM_R[i] = 0;
		MEM_G[i] = 0;
		MEM_B[i] = 0;
	end

end

always #(`cycle/2) clk = ~clk;

initial begin
    $display("********************************************************************");
    $display("**                        Simulation Start                        **");
    $display("********************************************************************");
    @(posedge clk); #2 reset = 1'b1; 
    #(`cycle*2);  
    @(posedge clk); #2 reset = 1'b0;
end

initial begin    
	@(posedge clk);
	# (`cycle*3) flag = 1;
end

always @ (negedge clk or posedge reset) begin // send mosaic image
  	if(reset) begin
		pixel <= 0;
		in_en <= 0;
  	end
  	else begin
		if(flag) begin
			if(in_count <= IMG_SIZE-1) begin
				in_en <= 1;
				in_count <= in_count + 1;
				pixel <= PAT[in_count];
			end
			else begin 
				in_en <= 0;
				pixel <= 'hx;
			end
		end
	end
end

always @ (negedge clk) begin // write memory
	if(wr_r) begin
		MEM_R[addr_r] <= wdata_r;
	end
	if(wr_g) begin
		MEM_G[addr_g] <= wdata_g;
	end
	if(wr_b) begin
		MEM_B[addr_b] <= wdata_b;
	end
end

always @ (negedge clk) begin // read memory
	if(!wr_r)
		rdata_r <= MEM_R[addr_r];
	else 
		rdata_r <= 'hx;
	if(!wr_g)
		rdata_g <= MEM_G[addr_g];
	else 
		rdata_g <= 'hx;
	if(!wr_b)
		rdata_b <= MEM_B[addr_b];
	else 
		rdata_b <= 'hx; 
end

always @ (posedge clk) begin // count cycle
	cycle_count <= cycle_count + 1;
	if(cycle_count >= `End_CYCLE) begin
		$display("********************************************************************");
		$display("**                    Fail waiting done signal                    **");
		$display("**             You can increase END_CYCLE by yourself             **");
		$display("********************************************************************");
		$finish;
	end
end

always @ (posedge clk) begin // check result
	if(done) begin
		for(i = 0; i < IMG_SIZE; i = i + 1) begin
            $fwrite(out_f, "%c", MEM_R[i]);
            $fwrite(out_f, "%c", MEM_G[i]);
            $fwrite(out_f, "%c", MEM_B[i]);
		end
		$fclose(out_f);
		$display("********************************************************************");
		$display("**               Simulation completed successfully!               **");
		$display("********************************************************************");	
		$finish;
	end
end

endmodule
