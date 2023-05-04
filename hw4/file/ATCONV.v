`timescale 1ns/10ps
module  ATCONV(
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

wire signed [12:0] kernel [0:8];
assign kernel[0] = 13'h1FFF; assign kernel[1] = 13'h1FFE; assign kernel[2] = 13'h1FFF;
assign kernel[3] = 13'h1FFC; assign kernel[4] = 13'h0010; assign kernel[5] = 13'h1FFC;
assign kernel[6] = 13'h1FFF; assign kernel[7] = 13'h1FFE; assign kernel[8] = 13'h1FFF;
wire [2:0]kernel_shift[0:8];
assign {kernel_shift[0],kernel_shift[1],kernel_shift[2]}={3'd0,3'd1,3'd0};
assign {kernel_shift[3],kernel_shift[4],kernel_shift[5]}={3'd2,3'd4,3'd2};
assign {kernel_shift[6],kernel_shift[7],kernel_shift[8]}={3'd0,3'd1,3'd0};
wire signed [12:0] bias;
assign bias = 13'h1FF4;

/* data-request */
// separate main pattern into four group[0] for data-reuse
// ababab
// cdcdcd
// ababab
// cdcdcd
// ababab
// cdcdcd
reg [4:0]x[0:1],y[0:1];
reg [11:0]L0_caddr_wr;
reg [9:0] L1_caddr_wr;
reg [2:0]group[0:1];
localparam RIGHT=2'b00;
localparam LEFT=2'b01;
localparam DOWN=2'b10;
localparam RESET=2'b11;
reg [4:0] req_pos;
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
			if(req_pos>5) direct_act[0]={1'b1,direct_next};//end(next state)
			else direct_act[0]={1'b0,direct};
		end
		DOWN,RESET: begin//(6,7,8),(all)
			if(req_pos>7) direct_act[0]={1'b1,direct_next};//end(next state)
			else direct_act[0]={1'b0,direct};
		end
	endcase
end
/* xy,req_pos[0] controller */
// 012
// 345
// 678
always@(posedge clk,posedge reset) begin
	if(reset) begin
		x[0]<=0;
		y[0]<=0;
		group[0]<=0;
		req_pos<=0;
		direct<=RESET;
	end
	else if(busy) begin
		//cur direct(set req_pos)
		case(direct_act[0])//synthesis parallel_case full_case
			//jump
			{1'b1,RIGHT}:begin//(2),5,8
				req_pos<=2;
				x[0]<=x[0]+1;
			end
			{1'b1,LEFT }:begin//(0),3,6
				req_pos<=0;
				x[0]<=x[0]-1;
			end
			{1'b1,DOWN }:begin//(6),7,8
				req_pos<=6;
				y[0]<=y[0]+1;
			end
			{1'b1,RESET}:begin//(0),1,2,3,4,5,6,7,8
				req_pos<=0;
				y[0]<=y[0]+1;//overflow to 0
				group[0]<=group[0]+1;
			end
			//stay
			{1'b0,RIGHT}:begin//2,(5,8)
				req_pos<=req_pos+3;
			end
			{1'b0,LEFT }:begin//0,(3,6)
				req_pos<=req_pos+3;
			end
			{1'b0,DOWN }:begin//6,(7,8)
				req_pos<=req_pos+1;
			end
			{1'b0,RESET}:begin//0,(1,2,3,4,5,6,7,8)
				req_pos<=req_pos+1;
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
	case(req_pos)//synthesis full_case parallel_case
		4'd0: {tmp_x,tmp_y}={tmp_x-7'd2,tmp_y-7'd2};
		4'd1: {tmp_x,tmp_y}={tmp_x     ,tmp_y-7'd2};
		4'd2: {tmp_x,tmp_y}={tmp_x+7'd2,tmp_y-7'd2};
		4'd3: {tmp_x,tmp_y}={tmp_x-7'd2,tmp_y     };
		4'd4: {tmp_x,tmp_y}={tmp_x     ,tmp_y     };
		4'd5: {tmp_x,tmp_y}={tmp_x+7'd2,tmp_y     };
		4'd6: {tmp_x,tmp_y}={tmp_x-7'd2,tmp_y+7'd2};
		4'd7: {tmp_x,tmp_y}={tmp_x     ,tmp_y+7'd2};
		4'd8: {tmp_x,tmp_y}={tmp_x+7'd2,tmp_y+7'd2};
	endcase
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
reg [7:0] cache[0:8];
reg calc_valid;
integer i;
always@(posedge clk) begin
	case(direct_act[1]) //synthesis parallel_case
		{1'b1,RIGHT}: begin
			for(i=0;i<9;i=i+3) begin
				cache[i]<=cache[i+1];
				cache[i+1]<=cache[i+2];
			end
		end
		{1'b1,LEFT}: begin
			for(i=2;i<9;i=i+3) begin
				cache[i]<=cache[i-1];
				cache[i-1]<=cache[i-2];
			end
		end
		{1'b1,DOWN}: begin
			for(i=0;i<6;i=i+1) cache[i]<=cache[i+3];
		end
	endcase
	cache[req_pos]<=idata[11:4];//remove idata sign bit and decimel point 4 bit(all zero)
	if(direct_act[1][1:0]==RESET && req_pos<6) calc_valid<=0;
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
		if(i==1 && cnt==1) conv_sign[i]<=cache[cnt*3+i];
		else conv_sign[i]<=-cache[cnt*3+i];
	end
	for(i=0;i<3;i=i+1) begin
		conv_mul[i]<=conv_sign[i]<<kernel_shift[cnt*3+i];
	end
end
/* conv add */
reg signed [12:0]conv_add,conv_data;
wire signed [12:0]conv_tmp;
wire [11:0] relu;
reg L0_w;
assign conv_tmp=(conv_add+conv_mul[0])+(conv_mul[1]+conv_mul[2]);
always@(posedge clk) begin
	if(cnt[0]==0) conv_add<=(bias+conv_mul[0])+(conv_mul[1]+conv_mul[2]);
	else conv_add<=(conv_add+conv_mul[0])+(conv_mul[1]+conv_mul[2]);

	if(cnt[1]) conv_data=(conv_add+conv_mul[0])+(conv_mul[1]+conv_mul[2]);
end
// should try store in latch
//always@(posedge clk) begin
//	if(cnt[1]) conv_data=(conv_add+conv_mul[0])+(conv_mul[1]+conv_mul[2]);
//end
/* save addr when cnt==1 */
//I dont know why do I need to reset this to pass gate-level(in dcnxt)
/*
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
