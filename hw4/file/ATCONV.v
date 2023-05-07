`timescale 1ns/10ps
(* multstyle = "dsp" *) module ATCONV(
	input		clk,
	input		reset,
	output	reg	busy,	
	input		ready,	

	output reg	[11:0]	iaddr,
	input signed [12:0]	idata,

	output	cwr,
	output  reg	[11:0]	caddr_wr,
	output reg 	[12:0] 	cdata_wr,

	output	crd,
	output [11:0] 	caddr_rd,
	input 	[12:0] 	cdata_rd,

	output csel
);

wire signed [5:0] kernel [0:2][0:2];
assign {kernel[0][0],kernel[0][1],kernel[0][2]}={6'h3F,6'h3E,6'h3F};
assign {kernel[1][0],kernel[1][1],kernel[1][2]}={6'h3C,6'h10,6'h3C};
assign {kernel[2][0],kernel[2][1],kernel[2][2]}={6'h3F,6'h3E,6'h3F};
wire signed [4:0] bias;
assign bias = 5'h14;

/* data-request */
// separate main pattern into four group[0] for data-reuse
// 010101
// 232323
// 010101
// 232323
reg [4:0]x[0:1],y[0:1];
reg [11:0]L0_caddr_wr;
reg [9:0] L1_caddr_wr;
reg [2:0]group[0:1];
localparam RIGHT=2'b00;
localparam LEFT =2'b01;
localparam DOWN =2'b10;
localparam RESET=2'b11;
reg [1:0] req_pos[0:1];//0:x,1:y
reg [1:0] direct,direct_next;

/* cur direction */
// R=RIGHT
// L=LEFT
// D=DOWN
// S=RESET
// 
// S-R-R-R-R
//         |
// L-L-L-L-D
// |
// D-R-R-R-R
//         |
// ...

/* direction next */
// ...
// R-R-R-R-D
//         |
// D-L-L-L-L
// |
// R-R-R-R-D
//         |
// S-L-L-L-L

/* next direction control */
always@(*) begin
	//next direct
	if(y[0][0]) begin//left
		if(x[0]) direct_next=LEFT;
		else begin
			if(&y[0][4:1]) direct_next=RESET;
			else direct_next=DOWN;
		end
	end
	else begin//right
		if(&x[0]) direct_next=DOWN;
		else direct_next=RIGHT;
	end
end

/* direct_act: {next_xy,direction} */
reg [2:0] direct_act[0:1];
always@(*) begin
	case(direct)//synthesis parallel_case full_case
		RIGHT,LEFT: begin//(2,5,8),(0,3,6)
			if(req_pos[1][1]) direct_act[0]={1'b1,direct_next};//end(next state)
			else direct_act[0]={1'b0,direct};
		end
		DOWN,RESET: begin//(6,7,8),(all)
			if(req_pos[0][1]&&req_pos[1][1]) direct_act[0]={1'b1,direct_next};//end(next state)
			else direct_act[0]={1'b0,direct};
		end
	endcase
end
/* xy,req_pos controller */
// req_pos[0]:x
// req_pos[1]:y
// (0,0)(0,1)(0,2)
// (1,0)(1,1)(1,2)
// (2,0)(2,1)(2,2)
always@(posedge clk,posedge reset) begin
	if(reset) begin
		x[0]<=0;
		y[0]<=0;
		group[0]<=0;
		req_pos[0]<=0;
		req_pos[1]<=0;
		direct<=RESET;
	end
	else if(busy) begin
		//cur direct(set req_pos)
		case(direct_act[0])//synthesis parallel_case full_case
			//jump
			{1'b1,RIGHT}:begin
				req_pos[1][1]<=0;
				x[0]<=x[0]+1;
			end
			{1'b1,LEFT }:begin
				req_pos[0][1]<=0;
				req_pos[1][1]<=0;
				x[0]<=x[0]-1;
			end
			{1'b1,DOWN }:begin
				req_pos[0][1]<=0;
				y[0]<=y[0]+1;
			end
			{1'b1,RESET}:begin
				req_pos[0][1]<=0;
				req_pos[1][1]<=0;
				y[0]<=y[0]+1;//overflow to 0
				group[0]<=group[0]+1;
			end
			//stay
			{1'b0,RIGHT}:begin
				req_pos[1]<=req_pos[1]+1;
			end
			{1'b0,LEFT }:begin
				req_pos[1]<=req_pos[1]+1;
			end
			{1'b0,DOWN }:begin
				req_pos[0]<=req_pos[0]+1;
			end
			{1'b0,RESET}:begin
				if(req_pos[0][1]) begin
					req_pos[1]<=req_pos[1]+1;
					req_pos[0][1]<=0;
				end
				else req_pos[0]<=req_pos[0]+1;
			end
		endcase
		if(direct_act[0][2]) direct<=direct_next;
	end
end
/* iaddr controller */
// 012
// 345
// 678
reg [6:0] tmp_x,tmp_y;
always@(*) begin
	tmp_x={x[0],group[0][0]};
	tmp_y={y[0],group[0][1]};
	tmp_x=tmp_x+$signed({req_pos[0]-1,1'b0});
	tmp_y=tmp_y+$signed({req_pos[1]-1,1'b0});
	if(tmp_x[6]) begin//x[0] out board
		if(tmp_x[5]) tmp_x=6'd0;//-
		else tmp_x=~6'd0;//+
	end
	if(tmp_y[6]) begin//y[0] out board
		if(tmp_y[5]) tmp_y=6'd0;//-
		else tmp_y=~6'd0;//+
	end
	iaddr={tmp_y[5:0],tmp_x[5:0]};
end
/********************************************************/
//write into 3*3
reg [7:0] cache[0:2][0:2];//cache[y][x]
reg calc_valid;
integer i;
always@(posedge clk) begin
	case(direct_act[1]) //synthesis parallel_case
		{1'b1,RIGHT}: begin
			for(i=0;i<3;i=i+1) begin
				cache[i][0]<=cache[i][1];
				cache[i][1]<=cache[i][2];
			end
		end
		{1'b1,LEFT}: begin
			for(i=0;i<3;i=i+1) begin
				cache[i][2]<=cache[i][1];
				cache[i][1]<=cache[i][0];
			end
		end
		{1'b1,DOWN}: begin
			for(i=0;i<3;i=i+1) begin
				cache[0][i]<=cache[1][i];
				cache[1][i]<=cache[2][i];
			end
		end
	endcase
	cache[req_pos[1]][req_pos[0]]<=idata[11:4];//remove idata sign bit and decimel point 4 bit(all zero)
	if(direct_act[1][1:0]==RESET && !req_pos[1][1]) calc_valid<=0;
	else calc_valid<=1;

	direct_act[1]<=direct_act[0];
end
/*******************************************/
/* conv mul */
// cnt counter
// 0: 0,1,2
// 1: 3,4,5
// 2: 6,7,8
// 
// mul data
// -1,-2,-1
// -4,16,-4
// -1,-2,-1
// =>shift
// 0,1,0
// 2,4,2
// 0,1,0

/* cnt used both counter and rw control */
// in same addr
// cnt:		2,0,1,
// csel:	1,0,1,
// rw:		r,w,w,
reg [1:0] cnt;
always@(posedge clk,posedge reset) begin
	if(reset) cnt<=0;
	else if(calc_valid) begin
		if(cnt[1]) cnt<=0;
		else cnt<=cnt+1;
	end
end
reg signed [8:0]conv_sign[0:2];
reg signed [12:0]conv_mul[0:2];
always@(*) begin
	for(i=0;i<3;i=i+1) begin
		conv_mul[i]=$signed({1'b0,cache[cnt][i]})*kernel[cnt][i];
	end
end
/* conv add */
reg signed [12:0]conv_add,conv_data;
wire [11:0] relu;
reg L0_w;
always@(posedge clk) begin
	if(cnt[0]==0) begin
		conv_add <=(bias    +conv_mul[0])+(conv_mul[1]+conv_mul[2]);
	end
	else begin
		conv_add <=(conv_add+conv_mul[0])+(conv_mul[1]+conv_mul[2]);
	end

	if(cnt[1]) begin
		conv_data<=(conv_add+conv_mul[0])+(conv_mul[1]+conv_mul[2]);
	end
end
// should try store in latch
//always@(posedge clk) begin
//	if(cnt[1]) conv_data=(conv_add+conv_mul[0])+(conv_mul[1]+conv_mul[2]);
//end

/* save addr when cnt==1 */
/*
//I dont know why do I need to reset group to pass gate-level(in dcnxt)
always@(posedge clk,posedge reset) begin
	if(reset) group[1]=0;
	else if(cnt[0]) group[1]=group[0];
end
*/
always@(posedge clk) begin
	if(cnt[0]) begin
		x[1]=x[0];
		y[1]=y[0];
		group[1]=group[0];
	end
end
assign relu=(conv_data<0)? 0:conv_data;

/* L1 */
wire [7:0] round_up,max;
assign round_up=relu[11:4]+(|relu[3:0]);
assign max=(round_up>cdata_rd[11:4])? round_up:cdata_rd[11:4];

/* mem ctrl */
// cnt:		2,0,1,
// csel:	1,0,1,
// rw:		r,w,w,

assign csel=(|cnt);
assign cwr=!cnt[1];
assign crd=cnt[1];

always@(posedge clk,posedge reset) begin
	if(reset) busy<=0;
	else begin
		if(busy) begin
			if(group[1][2]) busy<=0;
		end
		else if(ready) busy<=1;
	end
end
assign caddr_rd={y[1],x[1]};
always@(*) begin
	if(csel) begin
		caddr_wr={y[1],x[1]};
		cdata_wr=(group[1])? {1'd0,max,4'd0}:{1'd0,round_up,4'd0};
	end
	else begin
		caddr_wr={y[1],group[1][1],x[1],group[1][0]};
		cdata_wr=relu;
	end
end
endmodule
