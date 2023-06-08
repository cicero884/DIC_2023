module demosaic(clk, reset, in_en, data_in, wr_r, addr_r, wdata_r, rdata_r, wr_g, addr_g, wdata_g, rdata_g, wr_b, addr_b, wdata_b, rdata_b, done);
input clk;
input reset;
input in_en;
input [7:0] data_in;
output wr_g;
output [13:0] addr_g;
output [7:0] wdata_g;
input [7:0] rdata_g;
output wr_r;
output [13:0] addr_r;
output [7:0] wdata_r;
input [7:0] rdata_r;
output wr_b;
output [13:0] addr_b;
output [7:0] wdata_b;
input [7:0] rdata_b;
output reg done;

reg [6:0] x[0:2],y[0:2];
reg [2:0] state[0:2];

localparam FillMem=0;
localparam Bilinear=1;
localparam RefineGreen=2;
localparam RefineRBinBR=3;
localparam RefineRBinG=4;

reg refine;
reg [3:0]reqCNT[0:2];
localparam green=0;
localparam red=1;
localparam blue=2;

reg [2:0]mem_w_req;
reg [7:0]cache[0:8][0:2];

// main ctrl(xy,counter)
always@(posedge clk, posedge reset) begin
	if(reset) begin
		x[0]<=0;
		y[0]<=0;
		state[0]<=FillMem;
		refine<=0;
		reqCNT[0]<=0;
		done<=0;
	end
	else begin
		case(state[0])
			FillMem: begin // fill origin colors into mem
				{y[0],x[0]}<={y[0],x[0]}+1;
				if(&{y[0],x[0]}) state[0]<=Bilinear;
			end
			Bilinear: begin // fill missing with bilinear
				if(reqCNT[0][3]) begin
					{y[0],x[0]}<={y[0],x[0]}+1;
					if(&{y[0],x[0]}) state[0]<=RefineGreen;
					reqCNT[0][3]<=0;
				end
				else reqCNT[0]<=reqCNT[0]+1;
			end
			RefineGreen: begin // fill all missing green
				done<=1;
			////if(reqCNT[0][3]) begin
			////	{y[0],x[0]}<={y[0],x[0]}+1;
			////	if(&{y[0],x[0]}) state[0]<=RefineGreen;
			////	reqCNT[0][3]<=0;
			////end
			////else reqCNT[0]<=reqCNT[0]+1;
			end
			RefineRBinBR: begin // fill blue in red, red in blue
			end
			RefineRBinG: begin // fill blue and reg in green piexl
			end
		endcase
	end
end

// 405
// 381
// 726

//   4
//   0
// 73815
//   2
//   6

// 0   1
//  4 5
//   8
//  7 6
// 3   2
reg [7:0]calc_data[0:2];
// calc
always@(posedge clk) begin
	reqCNT[1]<=reqCNT[0];
	{y[1],x[1]}<={y[0],x[0]};
	if(reqCNT[1][3]) begin
		{y[2],x[2]}<={y[1],x[1]};
		reqCNT[2]<=reqCNT[1];
		case(state[0])
			Bilinear: begin
				case({y[1][0],x[1][0]})
					2'b00: begin
						calc_data[green]=cache[8][green];
						calc_data[red]  =({1'd0,cache[3][red]}+cache[1][red]+1)>>1;
						calc_data[blue] =({1'd0,cache[0][blue]}+cache[2][blue]+1)>>1;
					end
					2'b01: begin
						calc_data[green]=(({2'd0,cache[0][green]}+cache[1][green])+({2'd0,cache[2][green]}+cache[3][green])+2)>>2;
						calc_data[red]  =cache[8][red];
						calc_data[blue] =(({2'd0,cache[4][blue]}+cache[5][blue])+({2'd0,cache[6][blue]}+cache[7][blue])+2)>>2;
					end
					2'b10: begin
						calc_data[green]=(({2'd0,cache[0][green]}+cache[1][green])+({2'd0,cache[2][green]}+cache[3][green])+2)>>2;
						calc_data[red]  =(({2'd0,cache[4][red]}+cache[5][red])+({2'd0,cache[6][red]}+cache[7][red])+2)>>2;
						calc_data[blue] =cache[8][blue];
					end
					2'b11: begin
						calc_data[green]=cache[8][green];
						calc_data[red]  =({1'd0,cache[0][red]}+cache[2][red]+1)>>1;
						calc_data[blue] =({1'd0,cache[1][blue]}+cache[3][blue]+1)>>1;
					end
				endcase
			end
		endcase
	end
end

reg [13:0]r_addr[0:2];
reg r_req[0:1][0:2];
reg [13:0]w_addr[0:2];
reg [7:0]w_data[0:2];
reg w_req[0:2];

// cache ctrl
always@(posedge clk) begin
////reqCNT[1]<=reqCNT[0];
////{y[1],x[1]}<={y[0],x[0]};
////{r_req[1][0],r_req[1][1],r_req[1][2]}<={r_req[0][0],r_req[0][1],r_req[0][2]};

	cache[reqCNT[0]][green]<=(r_req[0][green])? rdata_g:8'dx;
	cache[reqCNT[0]][red]  <=(r_req[0][red])  ? rdata_r:8'dx;
	cache[reqCNT[0]][blue] <=(r_req[0][blue]) ? rdata_b:8'dx;
end
// req addr
// 405
// 381
// 726

//   4
//   0
// 73815
//   2
//   6

// 0   1
//  4 5
//   8
//  7 6
// 3   2

// read addr ctrl
reg [7:0]req_x,req_y;
always@(*) begin
	req_x=x[0];
	req_y=y[0];
	case(state[0])
		Bilinear: begin
			case(reqCNT[0])
				4'd0: {req_y,req_x}={req_y-8'd1,req_x     };
				4'd1: {req_y,req_x}={req_y     ,req_x+8'd1};
				4'd2: {req_y,req_x}={req_y+8'd1,req_x     };
				4'd3: {req_y,req_x}={req_y     ,req_x-8'd1};
				4'd4: {req_y,req_x}={req_y-8'd1,req_x-8'd1};
				4'd5: {req_y,req_x}={req_y-8'd1,req_x+8'd1};
				4'd6: {req_y,req_x}={req_y+8'd1,req_x+8'd1};
				4'd7: {req_y,req_x}={req_y+8'd1,req_x-8'd1};
				4'd8: {req_y,req_x}={req_y     ,req_x     };
			endcase
		end
		RefineGreen: begin
		end
	endcase
	if(req_x[7]) begin
		if(req_x[6]) req_x=req_x+2;
		else req_x=req_x-2;
	end
	if(req_y[7]) begin
		if(req_y[6]) req_y=req_y+2;
		else req_y=req_y-2;
	end
end

// read write ctrl
always@(*) begin
	case(state[0]) //synopsys parallel_case full_case
		FillMem: begin
			{r_req[0][0],r_req[0][1],r_req[0][2]}=3'b000;
			{w_addr[0],w_addr[1],w_addr[2]}={3{y[0],x[0]}};
			{w_data[0],w_data[1],w_data[2]}={3{data_in}};
			{w_req[0],w_req[1],w_req[2]}=3'b111;
		end
		Bilinear: begin
			r_req[0][green]=!(req_y[0]^req_x[0]);
			r_req[0][red]=({req_y[0],req_x[0]}==2'b01);
			r_req[0][blue]=({req_y[0],req_x[0]}==2'b10);
			{r_addr[0],r_addr[1],r_addr[2]}={3{req_y[6:0],req_x[6:0]}};
			{w_addr[0],w_addr[1],w_addr[2]}={3{y[2],x[2]}};
			{w_data[0],w_data[1],w_data[2]}={calc_data[0],calc_data[1],calc_data[2]};
			{w_req[0],w_req[1],w_req[2]}={3{reqCNT[2][3]}};
		end
		RefineGreen: begin
		end
		RefineRBinBR: begin
		end
	endcase
end

// mem ctrl
reg w_wait[0:2];
reg [13:0]w_addr_cache[0:2];
reg [7:0]w_data_cache[0:2];
reg wr[0:2];
wire [13:0] addr[0:2];
assign {wr_g,wr_r,wr_b}={wr[0],wr[1],wr[2]};
assign {addr_g,addr_r,addr_b}={addr[0],addr[1],addr[2]};
assign {wdata_g,wdata_r,wdata_b}={w_data_cache[0],w_data_cache[1],w_data_cache[2]};
genvar gen_i;
generate
for(gen_i=0;gen_i<3;gen_i=gen_i+1) begin
	always @(posedge clk,posedge reset) begin
		if(reset) begin
			w_wait[gen_i]<=1'b0;
		end
		else begin
			if(w_req[gen_i]) begin
				w_wait[gen_i]<=1'b1;
				w_addr_cache[gen_i]<=w_addr[gen_i];
				w_data_cache[gen_i]<=w_data[gen_i];
			end
			else if(wr[gen_i]) w_wait[gen_i]<=1'b0;
		end
	end
	always@(*) begin
		if((!r_req[0][gen_i]) && w_req[gen_i]) wr[gen_i]=1'b1;
		else wr[gen_i]=1'b0;
	end
	assign addr[gen_i]=wr[gen_i]? w_addr_cache[gen_i]:r_addr[gen_i];
end
endgenerate
endmodule
