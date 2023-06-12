`define abs(a,b) ((a>b)? (a-b):(b-a))
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
integer i,j;

reg [6:0] x[0:4],y[0:4];
reg [2:0] state[0:4];

localparam FillMem=0;
localparam Bilinear=1;
localparam RefineGreen=2;
localparam RefineRBinBR=3;
localparam RefineRinG=4;
localparam RefineBinG=5;
localparam EndRound=6;

reg refine;
reg [3:0]reqCNT;
localparam green=0;
localparam red=1;
localparam blue=2;

reg calc_en;
reg [2:0]mem_w_req;
reg [7:0]cache[0:12][0:2];

// main ctrl(xy,counter)
always@(posedge clk, posedge reset) begin
	if(reset) begin
		x[0]<=0;
		y[0]<=0;
		state[0]<=FillMem;
		refine<=0;
		reqCNT<=0;
		done<=0;
		calc_en<=1'b1;
	end
	else begin
		case(state[0])
			FillMem: begin // fill origin colors into mem
				{y[0],x[0]}<={y[0],x[0]}+1;
				if(&{y[0],x[0]}) state[0]<=state[0]+1;
				calc_en<=1'b1;
			end
			Bilinear: begin // fill missing with bilinear
				calc_en<=(reqCNT==12);
				if(reqCNT==12) begin
					if(&{y[0],x[0]}) begin
						{y[0],x[0]}<=14'd1;
						state[0]<=state[0]+1;
					end
					else {y[0],x[0]}<={y[0],x[0]}+1;
					reqCNT<=0;
				end
				else reqCNT<=reqCNT+1;
			end
			RefineGreen,RefineRBinBR: begin // fill all missing green
				calc_en<=(reqCNT==9);
				if(reqCNT==9) begin
					if(&x[0][6:1]) begin
						if(&y[0]) begin
							y[0]<=0;
							if(state[0]==RefineRinG) x[0]<=0;
							else x[0]<={6'd0,y[0][0]};
							state[0]<=state[0]+1;
						end
						else y[0]<=y[0]+1;
					end
					else x[0]<=x[0]+2;
					reqCNT<=0;
				end
				else reqCNT<=reqCNT+1;
			end
			RefineRinG,RefineBinG: begin // fill blue and reg in green piexl
				calc_en<=(reqCNT==9);
				if(reqCNT==9) begin
					x[0]<={6'd0,!y[0][0]};
					if(&x[0][6:1]) begin
						if(&y[0]) begin
							y[0]<=0;
							state[0]<=state[0]+1;
						end
						else y[0]<=y[0]+1;
					end
					else x[0]<=x[0]+2;
					reqCNT<=0;
				end
				else reqCNT<=reqCNT+1;
			end
			EndRound: begin
				calc_en<=1'b1;
				if(reqCNT>10) begin
					if(refine) begin
						state[0]<=RefineGreen;
						{y[0],x[0]}<=14'd1;
						reqCNT<=0;
					end
					else done<=1;
				end
				else reqCNT<=reqCNT+1;
			end
		endcase
	end
end

// read addr ctrl
reg [7:0]req_x,req_y;
always@(*) begin
	req_x=x[0];
	req_y=y[0];
	case(state[0]) //synthesis parallel_case full_case
		Bilinear: begin
			case(reqCNT)
				4'd0: {req_y,req_x}={req_y-8'd1,req_x     };
				4'd1: {req_y,req_x}={req_y     ,req_x+8'd1};
				4'd2: {req_y,req_x}={req_y+8'd1,req_x     };
				4'd3: {req_y,req_x}={req_y     ,req_x-8'd1};
				4'd4: {req_y,req_x}={req_y-8'd1,req_x-8'd1};
				4'd5: {req_y,req_x}={req_y-8'd1,req_x+8'd1};
				4'd6: {req_y,req_x}={req_y+8'd1,req_x+8'd1};
				4'd7: {req_y,req_x}={req_y+8'd1,req_x-8'd1};
				4'd8: {req_y,req_x}={req_y-8'd2,req_x     };
				4'd9: {req_y,req_x}={req_y     ,req_x+8'd2};
				4'd10: {req_y,req_x}={req_y+8'd2,req_x     };
				4'd11: {req_y,req_x}={req_y     ,req_x-8'd2};
				4'd12: {req_y,req_x}={req_y     ,req_x     };
			endcase
		end
		RefineGreen,RefineRinG,RefineBinG: begin
			case(reqCNT)
				4'd0: {req_y,req_x}={req_y-8'd1,req_x     };
				4'd1: {req_y,req_x}={req_y     ,req_x+8'd1};
				4'd2: {req_y,req_x}={req_y+8'd1,req_x     };
				4'd3: {req_y,req_x}={req_y     ,req_x-8'd1};
				4'd4: {req_y,req_x}={req_y-8'd2,req_x     };
				4'd5: {req_y,req_x}={req_y     ,req_x+8'd2};
				4'd6: {req_y,req_x}={req_y+8'd2,req_x     };
				4'd7: {req_y,req_x}={req_y     ,req_x-8'd2};
				4'd8: {req_y,req_x}={req_y     ,req_x     };
				4'd9: {req_y,req_x}={8'dx      ,8'dx      };
			endcase
		end
		RefineRBinBR: begin
			case(reqCNT)
				4'd0: {req_y,req_x}={req_y-8'd1,req_x-8'd1};
				4'd1: {req_y,req_x}={req_y+8'd1,req_x-8'd1};
				4'd2: {req_y,req_x}={req_y+8'd1,req_x+8'd1};
				4'd3: {req_y,req_x}={req_y-8'd1,req_x+8'd1};
				4'd4: {req_y,req_x}={req_y-8'd2,req_x-8'd2};
				4'd5: {req_y,req_x}={req_y+8'd2,req_x-8'd2};
				4'd6: {req_y,req_x}={req_y+8'd2,req_x+8'd2};
				4'd7: {req_y,req_x}={req_y-8'd2,req_x+8'd2};
				4'd8: {req_y,req_x}={req_y     ,req_x     };
				4'd9: {req_y,req_x}={8'dx      ,8'dx      };
			endcase
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

// read ctrl
reg [13:0]r_addr[0:2];
reg r_req[0:2];
always@(*) begin
	case(state[0]) //synthesis parallel_case full_case
		FillMem: begin
			{r_req[0],r_req[1],r_req[2]}=3'b000;
		end
		Bilinear: begin
			r_req[green]=!(req_y[0]^req_x[0]);
			r_req[red]=({req_y[0],req_x[0]}==2'b01);
			r_req[blue]=({req_y[0],req_x[0]}==2'b10);
		end
		RefineGreen: begin
			r_req[green]=(reqCNT<9);
			r_req[red]=(reqCNT<4 || reqCNT==8) && (!y[0][0]);
			r_req[blue]=(reqCNT<4 || reqCNT==8) && (y[0][0]);
		end
		RefineRBinBR: begin
			r_req[green]=0;
			if(reqCNT<9) begin
				if(y[0][0]) begin
					r_req[red]=1;
					r_req[blue]=(reqCNT<4 || reqCNT==8);
				end
				else begin
					r_req[red]=(reqCNT<4 || reqCNT==8);
					r_req[blue]=1;
				end
			end
			else begin
				r_req[red]=0;
				r_req[blue]=0;
			end
		end
		RefineRinG: begin
			r_req[green]=(reqCNT<9);
			r_req[red]=(reqCNT<4 || reqCNT==8);
			r_req[blue]=0;
		end
		RefineBinG: begin
			r_req[green]=(reqCNT<9);
			r_req[red]=0;
			r_req[blue]=(reqCNT<4 || reqCNT==8);
		end
		EndRound: begin
			{r_req[0],r_req[1],r_req[2]}=3'b000;
		end
	endcase
	{r_addr[0],r_addr[1],r_addr[2]}={3{req_y[6:0],req_x[6:0]}};
end
// cache ctrl
always@(posedge clk) begin
	state[1]<=state[0];
	{y[1],x[1]}<={y[0],x[0]};
	cache[reqCNT][green]<=(r_req[green])? rdata_g:8'dx;
	cache[reqCNT][red]  <=(r_req[red])  ? rdata_r:8'dx;
	cache[reqCNT][blue] <=(r_req[blue]) ? rdata_b:8'dx;
end
//  8
// 405
//b3c19
// 726
//  a
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
reg signed[13:0]bi_data[0:2];
reg [7:0]calc_bi_data[0:2];
// weight=1/(a+1)
reg [12:0]a[0:3];
reg [9:0]weight[0:3];
reg signed[8:0]k[0:3];
reg [7:0]center[0:2];
wire [11:0]weight_sum;

assign weight_sum=weight[0]+weight[1]+weight[2]+weight[3];
// calc
always@(posedge clk) begin
	if(calc_en) begin
		state[2]<=state[1];
		{y[2],x[2]}<={y[1],x[1]};
		case(state[1])
			Bilinear: begin
				case({y[1][0],x[1][0]})
					2'b00: begin
						bi_data[green]=cache[4'hc][green]*8;
						bi_data[red]  =(cache[3][red]+cache[1][red])*4+cache[4'hc][green]*5-cache[4][green]-cache[5][green]-cache[6][green]-cache[7][green]+((cache[8][green]+cache[4'ha][green])>>1)-cache[9][green]-cache[4'hb][green];
						bi_data[blue] =(cache[0][blue]+cache[2][blue])*4+cache[4'hc][green]*5-cache[4][green]-cache[5][green]-cache[6][green]-cache[7][green]+((cache[9][green]+cache[4'hb][green])>>1)-cache[8][green]-cache[4'ha][green];
					end
					2'b01: begin
						bi_data[green]=cache[4'hc][red]*4+(cache[0][green]+cache[1][green]+cache[2][green]+cache[3][green])*2-cache[8][red]-cache[9][red]-cache[10][red]-cache[11][red];
						bi_data[red]  =cache[4'hc][red]*8;
						bi_data[blue] =cache[4'hc][red]*6+(cache[4][blue]+cache[5][blue]+cache[6][blue]+cache[7][blue])*2-(cache[8][red]+cache[9][red]+cache[10][red]+cache[11][red])*3/2;
					end
					2'b10: begin
						bi_data[green]=cache[4'hc][blue]*4+(cache[0][green]+cache[1][green]+cache[2][green]+cache[3][green])*2-cache[8][blue]-cache[9][blue]-cache[10][blue]-cache[11][blue];
						bi_data[red]  =cache[4'hc][blue]*6+(cache[4][red]+cache[5][red]+cache[6][red]+cache[7][red])*2-(cache[8][blue]+cache[9][blue]+cache[10][blue]+cache[11][blue])*3/2;
						bi_data[blue] =cache[4'hc][blue]*8;
					end
					2'b11: begin
						bi_data[green]=cache[4'hc][green]*8;
						bi_data[red]  =(cache[2][red]+cache[0][red])*4+cache[4'hc][green]*5-cache[4][green]-cache[5][green]-cache[6][green]-cache[7][green]+((cache[9][green]+cache[4'hb][green])>>1)-cache[8][green]-cache[4'ha][green];
						bi_data[blue] =(cache[3][blue]+cache[1][blue])*4+cache[4'hc][green]*5-(cache[4][green]+cache[5][green]+cache[6][green]+cache[7][green])+((cache[8][green]+cache[4'ha][green])>>1)-(cache[9][green]+cache[4'hb][green]);
					end
				endcase
				for(i=0;i<3;i=i+1) begin
					if(bi_data[i][13]) bi_data[i]={{3{bi_data[i][13]}},bi_data[i][13:3]};
					else bi_data[i]=bi_data[i][13:3]+bi_data[i][2];
					calc_bi_data[i]<=(bi_data[i][13])? 8'h00: (|bi_data[i][12:8])? 8'hff:bi_data[i];
				end
			end
			RefineGreen: begin
				if(y[1][0]) begin
					a[0]=`abs(cache[4][green],cache[8][green])+`abs(cache[0][blue],cache[2][blue]);
					a[1]=`abs(cache[5][green],cache[8][green])+`abs(cache[1][blue],cache[3][blue]);
					a[2]=`abs(cache[6][green],cache[8][green])+`abs(cache[2][blue],cache[0][blue]);
					a[3]=`abs(cache[7][green],cache[8][green])+`abs(cache[3][blue],cache[1][blue]);
					for(i=0;i<4; i=i+1) k[i]<=cache[i][green]-cache[i][blue];
					center[0]<=cache[8][blue];
				end
				else begin
					a[0]=`abs(cache[4][green],cache[8][green])+`abs(cache[0][red],cache[2][red]);
					a[1]=`abs(cache[5][green],cache[8][green])+`abs(cache[1][red],cache[3][red]);
					a[2]=`abs(cache[6][green],cache[8][green])+`abs(cache[2][red],cache[0][red]);
					a[3]=`abs(cache[7][green],cache[8][green])+`abs(cache[3][red],cache[1][red]);
					for(i=0;i<4; i=i+1) k[i]<=cache[i][green]-cache[i][red];
					center[0]<=cache[8][red];
				end
				for(i=0;i<4;i=i+1) begin
					//round and shift right(for find significent bit)
					a[i]=(a[i]+(a[i]<<1))>>2;
					//find significent bit
					a[i]=(a[i]|(a[i]>>1));
					a[i]=(a[i]|(a[i]>>2));
					a[i]=(a[i]|(a[i]>>4));
					a[i]=(a[i]|(a[i]>>8));
					a[i]=a[i]+1;
					//bit reverse(divide 2^9)
					for(j=0;j<10;j=j+1) begin
						weight[i][j]<=a[i][9-j];
					end
				end
			end
			RefineRBinBR: begin
				if(y[1][0]) begin
					a[0]=`abs(cache[4][red],cache[8][red])+`abs(cache[0][blue],cache[2][blue]);
					a[1]=`abs(cache[5][red],cache[8][red])+`abs(cache[1][blue],cache[3][blue]);
					a[2]=`abs(cache[6][red],cache[8][red])+`abs(cache[2][blue],cache[0][blue]);
					a[3]=`abs(cache[7][red],cache[8][red])+`abs(cache[3][blue],cache[1][blue]);
					for(i=0;i<4; i=i+1) k[i]<=cache[i][red]-cache[i][blue];
					center[0]<=cache[8][blue];
				end
				else begin
					a[0]=`abs(cache[4][blue],cache[8][blue])+`abs(cache[0][red],cache[2][red]);
					a[1]=`abs(cache[5][blue],cache[8][blue])+`abs(cache[1][red],cache[3][red]);
					a[2]=`abs(cache[6][blue],cache[8][blue])+`abs(cache[2][red],cache[0][red]);
					a[3]=`abs(cache[7][blue],cache[8][blue])+`abs(cache[3][red],cache[1][red]);
					for(i=0;i<4; i=i+1) k[i]<=cache[i][blue]-cache[i][red];
					center[0]<=cache[8][red];
				end
				for(i=0;i<4;i=i+1) begin
					//round and shift right(for find significent bit)
					a[i]=(a[i]+(a[i]<<1))>>2;
					//find significent bit
					a[i]=(a[i]|(a[i]>>1));
					a[i]=(a[i]|(a[i]>>2));
					a[i]=(a[i]|(a[i]>>4));
					a[i]=(a[i]|(a[i]>>8));
					a[i]=a[i]+1;
					//bit reverse(divide 2^9)
					for(j=0;j<10;j=j+1) begin
						weight[i][j]<=a[i][9-j];
					end
				end
			end
			RefineRinG: begin
				a[0]=`abs(cache[4][green],cache[8][green])+`abs(cache[0][red],cache[2][red]);
				a[1]=`abs(cache[5][green],cache[8][green])+`abs(cache[1][red],cache[3][red]);
				a[2]=`abs(cache[6][green],cache[8][green])+`abs(cache[2][red],cache[0][red]);
				a[3]=`abs(cache[7][green],cache[8][green])+`abs(cache[3][red],cache[1][red]);
				for(i=0;i<4; i=i+1) k[i]<=cache[i][red]-cache[i][green];
				center[0]<=cache[8][green];
				for(i=0;i<4;i=i+1) begin
					//round and shift right(for find significent bit)
					a[i]=(a[i]+(a[i]<<1))>>2;
					//find significent bit
					a[i]=(a[i]|(a[i]>>1));
					a[i]=(a[i]|(a[i]>>2));
					a[i]=(a[i]|(a[i]>>4));
					a[i]=(a[i]|(a[i]>>8));
					a[i]=a[i]+1;
					//bit reverse(divide 2^9)
					for(j=0;j<10;j=j+1) begin
						weight[i][j]<=a[i][9-j];
					end
				end
			end
			RefineBinG: begin
				a[0]=`abs(cache[4][green],cache[8][green])+`abs(cache[0][blue],cache[2][blue]);
				a[1]=`abs(cache[5][green],cache[8][green])+`abs(cache[1][blue],cache[3][blue]);
				a[2]=`abs(cache[6][green],cache[8][green])+`abs(cache[2][blue],cache[0][blue]);
				a[3]=`abs(cache[7][green],cache[8][green])+`abs(cache[3][blue],cache[1][blue]);
				for(i=0;i<4; i=i+1) k[i]<=cache[i][blue]-cache[i][green];
				center[0]<=cache[8][green];
				for(i=0;i<4;i=i+1) begin
					//round and shift right(for find significent bit)
					a[i]=(a[i]+(a[i]<<1))>>2;
					//find significent bit
					a[i]=(a[i]|(a[i]>>1));
					a[i]=(a[i]|(a[i]>>2));
					a[i]=(a[i]|(a[i]>>4));
					a[i]=(a[i]|(a[i]>>8));
					a[i]=a[i]+1;
					//bit reverse(divide 2^9)
					for(j=0;j<10;j=j+1) begin
						weight[i][j]<=a[i][9-j];
					end
				end
			end
		endcase
	end
end

//--------------
// calc_pipe prepare numerator & denominator
reg signed[17:0]tmp_result[0:3];
reg signed[19:0] numerator;
reg signed[17:0] div2mul;
reg signed[17:0] denominator;
always@(posedge clk) begin
	if(calc_en) begin
		state[3]=state[2];
		{y[3],x[3]}<={y[2],x[2]};
		case(state[2])
			RefineGreen,RefineRBinBR,RefineRinG,RefineBinG: begin
				for(i=0;i<4;i=i+1) begin
					case(1'b1) //synthesis parallel_case full_case
						weight[i][9]: tmp_result[i]=k[i]<<<9;
						weight[i][8]: tmp_result[i]=k[i]<<<8;
						weight[i][7]: tmp_result[i]=k[i]<<<7;
						weight[i][6]: tmp_result[i]=k[i]<<<6;
						weight[i][5]: tmp_result[i]=k[i]<<<5;
						weight[i][4]: tmp_result[i]=k[i]<<<4;
						weight[i][3]: tmp_result[i]=k[i]<<<3;
						weight[i][2]: tmp_result[i]=k[i]<<<2;
						weight[i][1]: tmp_result[i]=k[i]<<<1;
						weight[i][0]: tmp_result[i]=k[i]<<<0;
					endcase
				end
				numerator=((tmp_result[0]+tmp_result[1])+(tmp_result[2]+tmp_result[3]));
				denominator=div2mul;
				center[1]<=center[0];
			end
		endcase
	end
end

//---------------
//calc_pipe mul(convert from div)
reg signed[37:0] mul_result;
reg signed[38:0] eeci_result,DEBUG;
reg [7:0] calc_eeci_data;

always@(posedge clk) begin
	if(calc_en) begin
		center[2]<=center[1];
		state[4]=state[3];
		{y[4],x[4]}<={y[3],x[3]};
		case(state[3])
			RefineGreen,RefineRBinBR,RefineRinG,RefineBinG: begin
				mul_result=numerator*denominator;
				DEBUG={1'b0,center[1],18'd0};
				eeci_result=mul_result+DEBUG;
				eeci_result=eeci_result+(eeci_result[17]<<17);
				calc_eeci_data=(eeci_result[38])? 8'h00:((|eeci_result[37:26])? 8'hff:(eeci_result[25:18]));
			end
		endcase
	end
end




// write ctrl

reg [13:0]w_addr[0:2];
reg [7:0]w_data[0:2];

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

reg write_stall;
reg w_req[0:2];
reg [2:0] write_state,next_write_state;
always@(posedge clk,posedge reset) begin
	if(reset) write_state<=FillMem;
	else begin
		if(next_write_state>write_state) write_state=next_write_state;
	end
end

always@(*) begin
	case(write_state) //synthesis parallel_case full_case
		FillMem: begin
			next_write_state=state[0];
			{w_addr[0],w_addr[1],w_addr[2]}={3{y[0],x[0]}};
			{w_data[0],w_data[1],w_data[2]}={3{data_in}};
			{w_req[0],w_req[1],w_req[2]}=3'b111;
		end
		Bilinear: begin
			next_write_state=state[2];
			{w_addr[0],w_addr[1],w_addr[2]}={3{y[2],x[2]}};
			{w_data[0],w_data[1],w_data[2]}={calc_bi_data[0],calc_bi_data[1],calc_bi_data[2]};
			{w_req[0],w_req[1],w_req[2]}=3'b111;
		end
		RefineGreen: begin
			next_write_state=state[4];
			{w_addr[0],w_addr[1],w_addr[2]}={3{y[4],x[4]}};
			{w_data[0],w_data[1],w_data[2]}={calc_eeci_data,8'dx,8'dx};
			{w_req[0],w_req[1],w_req[2]}=3'b100;
		end
		RefineRBinBR: begin
			next_write_state=state[4];
			{w_addr[0],w_addr[1],w_addr[2]}={3{y[4],x[4]}};
			{w_data[0],w_data[1],w_data[2]}={8'dx,calc_eeci_data,calc_eeci_data};
			if(y[4][0]) {w_req[0],w_req[1],w_req[2]}=3'b010;
			else {w_req[0],w_req[1],w_req[2]}=3'b001;
		end
		RefineRinG: begin
			next_write_state=state[4];
			{w_addr[0],w_addr[1],w_addr[2]}={3{y[4],x[4]}};
			{w_data[0],w_data[1],w_data[2]}={8'dx,calc_eeci_data,8'dx};
			{w_req[0],w_req[1],w_req[2]}=3'b010;
		end
		RefineBinG: begin
			next_write_state=state[4];
			{w_addr[0],w_addr[1],w_addr[2]}={3{y[4],x[4]}};
			{w_data[0],w_data[1],w_data[2]}={8'dx,8'dx,calc_eeci_data};
			{w_req[0],w_req[1],w_req[2]}=3'b001;
		end
		RefineBinG: begin
			next_write_state=state[4];
			{w_addr[0],w_addr[1],w_addr[2]}={3{y[4],x[4]}};
			{w_data[0],w_data[1],w_data[2]}={8'dx,8'dx,8'dx};
			{w_req[0],w_req[1],w_req[2]}=3'b000;
		end
	endcase
	if(!calc_en || (write_state!=next_write_state)) {w_req[0],w_req[1],w_req[2]}=3'b000;
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
		if((!r_req[gen_i]) && (w_wait[gen_i])) wr[gen_i]=1'b1;
		else wr[gen_i]=1'b0;
	end
	assign addr[gen_i]=wr[gen_i]? w_addr_cache[gen_i]:r_addr[gen_i];
end
endgenerate

//lut fot divide
always@(*) begin
	case(weight_sum) //synthesis parallel_case full_case
		4    : div2mul=18'b010000000000000000;
		5    : div2mul=18'b001100110011001100;
		6    : div2mul=18'b001010101010101010;
		7    : div2mul=18'b001001001001001001;
		8    : div2mul=18'b001000000000000000;
		9    : div2mul=18'b000111000111000111;
		10   : div2mul=18'b000110011001100110;
		11   : div2mul=18'b000101110100010111;
		12   : div2mul=18'b000101010101010101;
		13   : div2mul=18'b000100111011000100;
		14   : div2mul=18'b000100100100100100;
		15   : div2mul=18'b000100010001000100;
		16   : div2mul=18'b000100000000000000;
		17   : div2mul=18'b000011110000111100;
		18   : div2mul=18'b000011100011100011;
		19   : div2mul=18'b000011010111100101;
		20   : div2mul=18'b000011001100110011;
		21   : div2mul=18'b000011000011000011;
		22   : div2mul=18'b000010111010001011;
		23   : div2mul=18'b000010110010000101;
		24   : div2mul=18'b000010101010101010;
		25   : div2mul=18'b000010100011110101;
		26   : div2mul=18'b000010011101100010;
		27   : div2mul=18'b000010010111101101;
		28   : div2mul=18'b000010010010010010;
		29   : div2mul=18'b000010001101001111;
		30   : div2mul=18'b000010001000100010;
		32   : div2mul=18'b000010000000000000;
		33   : div2mul=18'b000001111100000111;
		34   : div2mul=18'b000001111000011110;
		35   : div2mul=18'b000001110101000001;
		36   : div2mul=18'b000001110001110001;
		37   : div2mul=18'b000001101110101100;
		38   : div2mul=18'b000001101011110010;
		39   : div2mul=18'b000001101001000001;
		40   : div2mul=18'b000001100110011001;
		41   : div2mul=18'b000001100011111001;
		42   : div2mul=18'b000001100001100001;
		43   : div2mul=18'b000001011111010000;
		44   : div2mul=18'b000001011101000101;
		45   : div2mul=18'b000001011011000001;
		46   : div2mul=18'b000001011001000010;
		48   : div2mul=18'b000001010101010101;
		49   : div2mul=18'b000001010011100101;
		50   : div2mul=18'b000001010001111010;
		51   : div2mul=18'b000001010000010100;
		52   : div2mul=18'b000001001110110001;
		53   : div2mul=18'b000001001101010010;
		54   : div2mul=18'b000001001011110110;
		56   : div2mul=18'b000001001001001001;
		57   : div2mul=18'b000001000111110111;
		58   : div2mul=18'b000001000110100111;
		60   : div2mul=18'b000001000100010001;
		64   : div2mul=18'b000001000000000000;
		65   : div2mul=18'b000000111111000000;
		66   : div2mul=18'b000000111110000011;
		67   : div2mul=18'b000000111101001000;
		68   : div2mul=18'b000000111100001111;
		69   : div2mul=18'b000000111011010111;
		70   : div2mul=18'b000000111010100000;
		71   : div2mul=18'b000000111001101100;
		72   : div2mul=18'b000000111000111000;
		73   : div2mul=18'b000000111000000111;
		74   : div2mul=18'b000000110111010110;
		75   : div2mul=18'b000000110110100111;
		76   : div2mul=18'b000000110101111001;
		77   : div2mul=18'b000000110101001100;
		78   : div2mul=18'b000000110100100000;
		80   : div2mul=18'b000000110011001100;
		81   : div2mul=18'b000000110010100100;
		82   : div2mul=18'b000000110001111100;
		83   : div2mul=18'b000000110001010110;
		84   : div2mul=18'b000000110000110000;
		85   : div2mul=18'b000000110000001100;
		86   : div2mul=18'b000000101111101000;
		88   : div2mul=18'b000000101110100010;
		89   : div2mul=18'b000000101110000001;
		90   : div2mul=18'b000000101101100000;
		92   : div2mul=18'b000000101100100001;
		96   : div2mul=18'b000000101010101010;
		97   : div2mul=18'b000000101010001110;
		98   : div2mul=18'b000000101001110010;
		99   : div2mul=18'b000000101001010111;
		100  : div2mul=18'b000000101000111101;
		101  : div2mul=18'b000000101000100011;
		102  : div2mul=18'b000000101000001010;
		104  : div2mul=18'b000000100111011000;
		105  : div2mul=18'b000000100111000000;
		106  : div2mul=18'b000000100110101001;
		108  : div2mul=18'b000000100101111011;
		112  : div2mul=18'b000000100100100100;
		113  : div2mul=18'b000000100100001111;
		114  : div2mul=18'b000000100011111011;
		116  : div2mul=18'b000000100011010011;
		120  : div2mul=18'b000000100010001000;
		128  : div2mul=18'b000000100000000000;
		129  : div2mul=18'b000000011111110000;
		130  : div2mul=18'b000000011111100000;
		131  : div2mul=18'b000000011111010001;
		132  : div2mul=18'b000000011111000001;
		133  : div2mul=18'b000000011110110011;
		134  : div2mul=18'b000000011110100100;
		135  : div2mul=18'b000000011110010101;
		136  : div2mul=18'b000000011110000111;
		137  : div2mul=18'b000000011101111001;
		138  : div2mul=18'b000000011101101011;
		139  : div2mul=18'b000000011101011101;
		140  : div2mul=18'b000000011101010000;
		141  : div2mul=18'b000000011101000011;
		142  : div2mul=18'b000000011100110110;
		144  : div2mul=18'b000000011100011100;
		145  : div2mul=18'b000000011100001111;
		146  : div2mul=18'b000000011100000011;
		147  : div2mul=18'b000000011011110111;
		148  : div2mul=18'b000000011011101011;
		149  : div2mul=18'b000000011011011111;
		150  : div2mul=18'b000000011011010011;
		152  : div2mul=18'b000000011010111100;
		153  : div2mul=18'b000000011010110001;
		154  : div2mul=18'b000000011010100110;
		156  : div2mul=18'b000000011010010000;
		160  : div2mul=18'b000000011001100110;
		161  : div2mul=18'b000000011001011100;
		162  : div2mul=18'b000000011001010010;
		163  : div2mul=18'b000000011001001000;
		164  : div2mul=18'b000000011000111110;
		165  : div2mul=18'b000000011000110100;
		166  : div2mul=18'b000000011000101011;
		168  : div2mul=18'b000000011000011000;
		169  : div2mul=18'b000000011000001111;
		170  : div2mul=18'b000000011000000110;
		172  : div2mul=18'b000000010111110100;
		176  : div2mul=18'b000000010111010001;
		177  : div2mul=18'b000000010111001001;
		178  : div2mul=18'b000000010111000000;
		180  : div2mul=18'b000000010110110000;
		184  : div2mul=18'b000000010110010000;
		192  : div2mul=18'b000000010101010101;
		193  : div2mul=18'b000000010101001110;
		194  : div2mul=18'b000000010101000111;
		195  : div2mul=18'b000000010101000000;
		196  : div2mul=18'b000000010100111001;
		197  : div2mul=18'b000000010100110010;
		198  : div2mul=18'b000000010100101011;
		200  : div2mul=18'b000000010100011110;
		201  : div2mul=18'b000000010100011000;
		202  : div2mul=18'b000000010100010001;
		204  : div2mul=18'b000000010100000101;
		208  : div2mul=18'b000000010011101100;
		209  : div2mul=18'b000000010011100110;
		210  : div2mul=18'b000000010011100000;
		212  : div2mul=18'b000000010011010100;
		216  : div2mul=18'b000000010010111101;
		224  : div2mul=18'b000000010010010010;
		225  : div2mul=18'b000000010010001101;
		226  : div2mul=18'b000000010010000111;
		228  : div2mul=18'b000000010001111101;
		232  : div2mul=18'b000000010001101001;
		240  : div2mul=18'b000000010001000100;
		256  : div2mul=18'b000000010000000000;
		257  : div2mul=18'b000000001111111100;
		258  : div2mul=18'b000000001111111000;
		259  : div2mul=18'b000000001111110100;
		260  : div2mul=18'b000000001111110000;
		261  : div2mul=18'b000000001111101100;
		262  : div2mul=18'b000000001111101000;
		263  : div2mul=18'b000000001111100100;
		264  : div2mul=18'b000000001111100000;
		265  : div2mul=18'b000000001111011101;
		266  : div2mul=18'b000000001111011001;
		267  : div2mul=18'b000000001111010101;
		268  : div2mul=18'b000000001111010010;
		269  : div2mul=18'b000000001111001110;
		270  : div2mul=18'b000000001111001010;
		272  : div2mul=18'b000000001111000011;
		273  : div2mul=18'b000000001111000000;
		274  : div2mul=18'b000000001110111100;
		275  : div2mul=18'b000000001110111001;
		276  : div2mul=18'b000000001110110101;
		277  : div2mul=18'b000000001110110010;
		278  : div2mul=18'b000000001110101110;
		280  : div2mul=18'b000000001110101000;
		281  : div2mul=18'b000000001110100100;
		282  : div2mul=18'b000000001110100001;
		284  : div2mul=18'b000000001110011011;
		288  : div2mul=18'b000000001110001110;
		289  : div2mul=18'b000000001110001011;
		290  : div2mul=18'b000000001110000111;
		291  : div2mul=18'b000000001110000100;
		292  : div2mul=18'b000000001110000001;
		293  : div2mul=18'b000000001101111110;
		294  : div2mul=18'b000000001101111011;
		296  : div2mul=18'b000000001101110101;
		297  : div2mul=18'b000000001101110010;
		298  : div2mul=18'b000000001101101111;
		300  : div2mul=18'b000000001101101001;
		304  : div2mul=18'b000000001101011110;
		305  : div2mul=18'b000000001101011011;
		306  : div2mul=18'b000000001101011000;
		308  : div2mul=18'b000000001101010011;
		312  : div2mul=18'b000000001101001000;
		320  : div2mul=18'b000000001100110011;
		321  : div2mul=18'b000000001100110000;
		322  : div2mul=18'b000000001100101110;
		323  : div2mul=18'b000000001100101011;
		324  : div2mul=18'b000000001100101001;
		325  : div2mul=18'b000000001100100110;
		326  : div2mul=18'b000000001100100100;
		328  : div2mul=18'b000000001100011111;
		329  : div2mul=18'b000000001100011100;
		330  : div2mul=18'b000000001100011010;
		332  : div2mul=18'b000000001100010101;
		336  : div2mul=18'b000000001100001100;
		337  : div2mul=18'b000000001100001001;
		338  : div2mul=18'b000000001100000111;
		340  : div2mul=18'b000000001100000011;
		344  : div2mul=18'b000000001011111010;
		352  : div2mul=18'b000000001011101000;
		353  : div2mul=18'b000000001011100110;
		354  : div2mul=18'b000000001011100100;
		356  : div2mul=18'b000000001011100000;
		360  : div2mul=18'b000000001011011000;
		368  : div2mul=18'b000000001011001000;
		384  : div2mul=18'b000000001010101010;
		385  : div2mul=18'b000000001010101000;
		386  : div2mul=18'b000000001010100111;
		387  : div2mul=18'b000000001010100101;
		388  : div2mul=18'b000000001010100011;
		389  : div2mul=18'b000000001010100001;
		390  : div2mul=18'b000000001010100000;
		392  : div2mul=18'b000000001010011100;
		393  : div2mul=18'b000000001010011011;
		394  : div2mul=18'b000000001010011001;
		396  : div2mul=18'b000000001010010101;
		400  : div2mul=18'b000000001010001111;
		401  : div2mul=18'b000000001010001101;
		402  : div2mul=18'b000000001010001100;
		404  : div2mul=18'b000000001010001000;
		408  : div2mul=18'b000000001010000010;
		416  : div2mul=18'b000000001001110110;
		417  : div2mul=18'b000000001001110100;
		418  : div2mul=18'b000000001001110011;
		420  : div2mul=18'b000000001001110000;
		424  : div2mul=18'b000000001001101010;
		432  : div2mul=18'b000000001001011110;
		448  : div2mul=18'b000000001001001001;
		449  : div2mul=18'b000000001001000111;
		450  : div2mul=18'b000000001001000110;
		452  : div2mul=18'b000000001001000011;
		456  : div2mul=18'b000000001000111110;
		464  : div2mul=18'b000000001000110100;
		480  : div2mul=18'b000000001000100010;
		512  : div2mul=18'b000000001000000000;
		513  : div2mul=18'b000000000111111111;
		514  : div2mul=18'b000000000111111110;
		515  : div2mul=18'b000000000111111101;
		516  : div2mul=18'b000000000111111100;
		517  : div2mul=18'b000000000111111011;
		518  : div2mul=18'b000000000111111010;
		519  : div2mul=18'b000000000111111001;
		520  : div2mul=18'b000000000111111000;
		521  : div2mul=18'b000000000111110111;
		522  : div2mul=18'b000000000111110110;
		523  : div2mul=18'b000000000111110101;
		524  : div2mul=18'b000000000111110100;
		525  : div2mul=18'b000000000111110011;
		526  : div2mul=18'b000000000111110010;
		528  : div2mul=18'b000000000111110000;
		529  : div2mul=18'b000000000111101111;
		530  : div2mul=18'b000000000111101110;
		531  : div2mul=18'b000000000111101101;
		532  : div2mul=18'b000000000111101100;
		533  : div2mul=18'b000000000111101011;
		534  : div2mul=18'b000000000111101010;
		536  : div2mul=18'b000000000111101001;
		537  : div2mul=18'b000000000111101000;
		538  : div2mul=18'b000000000111100111;
		540  : div2mul=18'b000000000111100101;
		544  : div2mul=18'b000000000111100001;
		545  : div2mul=18'b000000000111100000;
		546  : div2mul=18'b000000000111100000;
		547  : div2mul=18'b000000000111011111;
		548  : div2mul=18'b000000000111011110;
		549  : div2mul=18'b000000000111011101;
		550  : div2mul=18'b000000000111011100;
		552  : div2mul=18'b000000000111011010;
		553  : div2mul=18'b000000000111011010;
		554  : div2mul=18'b000000000111011001;
		556  : div2mul=18'b000000000111010111;
		560  : div2mul=18'b000000000111010100;
		561  : div2mul=18'b000000000111010011;
		562  : div2mul=18'b000000000111010010;
		564  : div2mul=18'b000000000111010000;
		568  : div2mul=18'b000000000111001101;
		576  : div2mul=18'b000000000111000111;
		577  : div2mul=18'b000000000111000110;
		578  : div2mul=18'b000000000111000101;
		579  : div2mul=18'b000000000111000100;
		580  : div2mul=18'b000000000111000011;
		581  : div2mul=18'b000000000111000011;
		582  : div2mul=18'b000000000111000010;
		584  : div2mul=18'b000000000111000000;
		585  : div2mul=18'b000000000111000000;
		586  : div2mul=18'b000000000110111111;
		588  : div2mul=18'b000000000110111101;
		592  : div2mul=18'b000000000110111010;
		593  : div2mul=18'b000000000110111010;
		594  : div2mul=18'b000000000110111001;
		596  : div2mul=18'b000000000110110111;
		600  : div2mul=18'b000000000110110100;
		608  : div2mul=18'b000000000110101111;
		609  : div2mul=18'b000000000110101110;
		610  : div2mul=18'b000000000110101101;
		612  : div2mul=18'b000000000110101100;
		616  : div2mul=18'b000000000110101001;
		624  : div2mul=18'b000000000110100100;
		640  : div2mul=18'b000000000110011001;
		641  : div2mul=18'b000000000110011000;
		642  : div2mul=18'b000000000110011000;
		643  : div2mul=18'b000000000110010111;
		644  : div2mul=18'b000000000110010111;
		645  : div2mul=18'b000000000110010110;
		646  : div2mul=18'b000000000110010101;
		648  : div2mul=18'b000000000110010100;
		649  : div2mul=18'b000000000110010011;
		650  : div2mul=18'b000000000110010011;
		652  : div2mul=18'b000000000110010010;
		656  : div2mul=18'b000000000110001111;
		657  : div2mul=18'b000000000110001111;
		658  : div2mul=18'b000000000110001110;
		660  : div2mul=18'b000000000110001101;
		664  : div2mul=18'b000000000110001010;
		672  : div2mul=18'b000000000110000110;
		673  : div2mul=18'b000000000110000101;
		674  : div2mul=18'b000000000110000100;
		676  : div2mul=18'b000000000110000011;
		680  : div2mul=18'b000000000110000001;
		688  : div2mul=18'b000000000101111101;
		704  : div2mul=18'b000000000101110100;
		705  : div2mul=18'b000000000101110011;
		706  : div2mul=18'b000000000101110011;
		708  : div2mul=18'b000000000101110010;
		712  : div2mul=18'b000000000101110000;
		720  : div2mul=18'b000000000101101100;
		736  : div2mul=18'b000000000101100100;
		768  : div2mul=18'b000000000101010101;
		769  : div2mul=18'b000000000101010100;
		770  : div2mul=18'b000000000101010100;
		771  : div2mul=18'b000000000101010100;
		772  : div2mul=18'b000000000101010011;
		773  : div2mul=18'b000000000101010011;
		774  : div2mul=18'b000000000101010010;
		776  : div2mul=18'b000000000101010001;
		777  : div2mul=18'b000000000101010001;
		778  : div2mul=18'b000000000101010000;
		780  : div2mul=18'b000000000101010000;
		784  : div2mul=18'b000000000101001110;
		785  : div2mul=18'b000000000101001101;
		786  : div2mul=18'b000000000101001101;
		788  : div2mul=18'b000000000101001100;
		792  : div2mul=18'b000000000101001010;
		800  : div2mul=18'b000000000101000111;
		801  : div2mul=18'b000000000101000111;
		802  : div2mul=18'b000000000101000110;
		804  : div2mul=18'b000000000101000110;
		808  : div2mul=18'b000000000101000100;
		816  : div2mul=18'b000000000101000001;
		832  : div2mul=18'b000000000100111011;
		833  : div2mul=18'b000000000100111010;
		834  : div2mul=18'b000000000100111010;
		836  : div2mul=18'b000000000100111001;
		840  : div2mul=18'b000000000100111000;
		848  : div2mul=18'b000000000100110101;
		864  : div2mul=18'b000000000100101111;
		896  : div2mul=18'b000000000100100100;
		897  : div2mul=18'b000000000100100100;
		898  : div2mul=18'b000000000100100011;
		900  : div2mul=18'b000000000100100011;
		904  : div2mul=18'b000000000100100001;
		912  : div2mul=18'b000000000100011111;
		928  : div2mul=18'b000000000100011010;
		960  : div2mul=18'b000000000100010001;
		1024 : div2mul=18'b000000000100000000;
		1025 : div2mul=18'b000000000011111111;
		1026 : div2mul=18'b000000000011111111;
		1027 : div2mul=18'b000000000011111111;
		1028 : div2mul=18'b000000000011111111;
		1029 : div2mul=18'b000000000011111110;
		1030 : div2mul=18'b000000000011111110;
		1032 : div2mul=18'b000000000011111110;
		1033 : div2mul=18'b000000000011111101;
		1034 : div2mul=18'b000000000011111101;
		1036 : div2mul=18'b000000000011111101;
		1040 : div2mul=18'b000000000011111100;
		1041 : div2mul=18'b000000000011111011;
		1042 : div2mul=18'b000000000011111011;
		1044 : div2mul=18'b000000000011111011;
		1048 : div2mul=18'b000000000011111010;
		1056 : div2mul=18'b000000000011111000;
		1057 : div2mul=18'b000000000011111000;
		1058 : div2mul=18'b000000000011110111;
		1060 : div2mul=18'b000000000011110111;
		1064 : div2mul=18'b000000000011110110;
		1072 : div2mul=18'b000000000011110100;
		1088 : div2mul=18'b000000000011110000;
		1089 : div2mul=18'b000000000011110000;
		1090 : div2mul=18'b000000000011110000;
		1092 : div2mul=18'b000000000011110000;
		1096 : div2mul=18'b000000000011101111;
		1104 : div2mul=18'b000000000011101101;
		1120 : div2mul=18'b000000000011101010;
		1152 : div2mul=18'b000000000011100011;
		1153 : div2mul=18'b000000000011100011;
		1154 : div2mul=18'b000000000011100011;
		1156 : div2mul=18'b000000000011100010;
		1160 : div2mul=18'b000000000011100001;
		1168 : div2mul=18'b000000000011100000;
		1184 : div2mul=18'b000000000011011101;
		1216 : div2mul=18'b000000000011010111;
		1280 : div2mul=18'b000000000011001100;
		1281 : div2mul=18'b000000000011001100;
		1282 : div2mul=18'b000000000011001100;
		1284 : div2mul=18'b000000000011001100;
		1288 : div2mul=18'b000000000011001011;
		1296 : div2mul=18'b000000000011001010;
		1312 : div2mul=18'b000000000011000111;
		1344 : div2mul=18'b000000000011000011;
		1408 : div2mul=18'b000000000010111010;
		1536 : div2mul=18'b000000000010101010;
		1537 : div2mul=18'b000000000010101010;
		1538 : div2mul=18'b000000000010101010;
		1540 : div2mul=18'b000000000010101010;
		1544 : div2mul=18'b000000000010101001;
		1552 : div2mul=18'b000000000010101000;
		1568 : div2mul=18'b000000000010100111;
		1600 : div2mul=18'b000000000010100011;
		1664 : div2mul=18'b000000000010011101;
		1792 : div2mul=18'b000000000010010010;
		2048 : div2mul=18'b000000000010000000;
		// total size of lut is 439
	endcase
end

endmodule
