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

/*
- input image size: 64 L0_x 64 0~4095
- idata: 9 bits integer, 4 bits float  Q9.4 FIXED POINT
- csel : 0 --> layer0 (conv output)  1 --> layer2 (max pool output)

replication padding mode description:
>>> m = nn.ReplicationPad2d(2)
>>> input = torch.arange(9, dtype=torch.float).reshape(1, 1, 3, 3)
>>> input
tensor([[[[0., 1., 2.],
		  [3., 4., 5.],
		  [6., 7., 8.]]]])
>>> m(input)
tensor([[[[0., 0., 0., 1., 2., 2., 2.],
		  [0., 0., 0., 1., 2., 2., 2.],
		  [0., 0., 0., 1., 2., 2., 2.],
		  [3., 3., 3., 4., 5., 5., 5.],
		  [6., 6., 6., 7., 8., 8., 8.],
		  [6., 6., 6., 7., 8., 8., 8.],
		  [6., 6., 6., 7., 8., 8., 8.]]]])
*/

wire signed [12:0] kernel [0:8];
assign kernel[0] = 13'h1FFF; assign kernel[1] = 13'h1FFE; assign kernel[2] = 13'h1FFF;
assign kernel[3] = 13'h1FFC; assign kernel[4] = 13'h0010; assign kernel[5] = 13'h1FFC;
assign kernel[6] = 13'h1FFF; assign kernel[7] = 13'h1FFE; assign kernel[8] = 13'h1FFF;
wire [12:0] bias;
assign bias = 13'h1FF4;

/*
separate main pattern into four group for data-reuse
ababab
cdcdcd
ababab
cdcdcd
ababab
cdcdcd
*/
//data-request
reg [4:0]L0_x,L0_y;
reg [11:0]L0_caddr_wr[0:2];
reg [2:0]group;
localparam RIGHT=2'b00;
localparam LEFT=2'b01;
localparam DOWN=2'b10;
localparam RESET=2'b11;
reg [4:0] req_pos[0:1];
reg [1:0] direct,direct_next;

//cur direction
/*
R=RIGHT
L=LEFT
D=DOWN
S=RESET

S-R-R-R-R
		|
L-L-L-L-D
|
D-R-R-R-R
		|
...
*/
//direction next
/*
...
R-R-R-R-D
		|
D-L-L-L-L
|
R-R-R-R-D
		|
S-L-L-L-L
*/
//next direction control
always@(*) begin
	//next direct
	if(L0_y[0]) begin//left
		if(L0_x) direct_next=LEFT;
		else begin
			if(&L0_y[4:1]) direct_next=RESET;
			else direct_next=DOWN;
		end
	end
	else begin//right
		if(&L0_x) direct_next=DOWN;
		else direct_next=RIGHT;
	end
end

//direct_act: {next_xy,direction}
reg [2:0] direct_act[0:1];
always@(*) begin
	case(direct)//synthesis parallel_case full_case
		RIGHT: begin//2,5,8
			if(req_pos[0]>5) direct_act[0]={1'b1,direct_next};//end(next state)
			else direct_act[0]={1'b0,direct};
		end
		LEFT: begin//0,3,6
			if(req_pos[0]>5) direct_act[0]={1'b1,direct_next};//end(next state)
			else direct_act[0]={1'b0,direct};
		end
		DOWN: begin//6,7,8
			if(req_pos[0]>7) direct_act[0]={1'b1,direct_next};//end(next state)
			else direct_act[0]={1'b0,direct};
		end
		RESET: begin//all
			if(req_pos[0]>7) direct_act[0]={1'b1,direct_next};//end(next state)
			else direct_act[0]={1'b0,direct};
		end
	endcase
end
//xy,req_pos[0] controller
//012
//345
//678
always@(posedge clk,posedge reset) begin
	if(reset) begin
		L0_x<=0;
		L0_y<=0;
		group<=0;
		req_pos[0]<=0;
		direct<=RESET;
	end
	else if(busy) begin
		//cur direct(set req_pos[0])
		case(direct_act[0])//synthesis parallel_case full_case
			//jump
			{1'b1,RIGHT}:begin//(2),5,8
				req_pos[0]<=2;
				L0_x<=L0_x+1;
			end
			{1'b1,LEFT }:begin//(0),3,6
				req_pos[0]<=0;
				L0_x<=L0_x-1;
			end
			{1'b1,DOWN }:begin//(6),7,8
				req_pos[0]<=6;
				L0_y<=L0_y+1;
			end
			{1'b1,RESET}:begin//(0),1,2,3,4,5,6,7,8
				req_pos[0]<=0;
				L0_y<=L0_y+1;//overflow to 0
				group<=group+1;
			end
			//stay
			{1'b0,RIGHT}:begin//2,(5,8)
				req_pos[0]<=req_pos[0]+3;
			end
			{1'b0,LEFT }:begin//0,(3,6)
				req_pos[0]<=req_pos[0]+3;
			end
			{1'b0,DOWN }:begin//6,(7,8)
				req_pos[0]<=req_pos[0]+1;
			end
			{1'b0,RESET}:begin//0,(1,2,3,4,5,6,7,8)
				req_pos[0]<=req_pos[0]+1;
			end
		endcase
		if(direct_act[0][2]) direct<=direct_next;
	end
end
always@(posedge clk) L0_caddr_wr[0]<={L0_y,group[1],L0_x,group[0]};
//iaddr controller
//012
//345
//678
reg [6:0] tmp_x,tmp_y;
//reg [6:0] debugx,debugy;
always@(*) begin
	tmp_x={L0_x,group[0]};
	tmp_y={L0_y,group[1]};
	case(req_pos[0])//synthesis full_case parallel_case
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
	if(tmp_x[6]) begin//L0_x out board
		if(tmp_x[5]) tmp_x=6'd0;//-
		else tmp_x=~6'd0;//+
	end
	if(tmp_y[6]) begin//L0_y out board
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
	cache[req_pos[0]]<=idata[11:4];//remove idata sign bit and decimel point 4 bit(all zero)
	if(direct_act[1][1:0]==RESET && req_pos[0]<6) calc_valid<=0;
	else calc_valid<=1;

	req_pos[1]<=req_pos[0];
	L0_caddr_wr[1]<=L0_caddr_wr[0];
	direct_act[1]<=direct_act[0];
end
/*******************************************/
//conv mul
/*
cnt counter
0: 0,1,2
1: 3,4,5
2: 6,7,8

mul data
-1,-2,-1
-4,16,-4
-1,-2,-1
=>shift
0,1,0
2,4,2
0,1,0
*/
wire [2:0]kernel_shift[0:8];
assign {kernel_shift[0],kernel_shift[1],kernel_shift[2]}={3'd0,3'd1,3'd0};
assign {kernel_shift[3],kernel_shift[4],kernel_shift[5]}={3'd2,3'd4,3'd2};
assign {kernel_shift[6],kernel_shift[7],kernel_shift[8]}={3'd0,3'd1,3'd0};

reg [1:0] L0_cnt;
always@(posedge clk,posedge reset) begin
	if(reset) L0_cnt<=0;
	else if(calc_valid) begin
		if(L0_cnt==2) L0_cnt<=0;
		else L0_cnt<=L0_cnt+1;
	end
end
reg [8:0]conv_sign[0:2];
reg [12:0]conv_mul[0:2];
always@(*) begin
	for(i=0;i<3;i=i+1) begin
		if(i==1 && L0_cnt==1) conv_sign[i]<= {1'b0,cache[L0_cnt*3+i]};
		else conv_sign[i]<= ~{1'b0,cache[L0_cnt*3+i]}+1'b1;
	end
	for(i=0;i<3;i=i+1) begin
		conv_mul[i]<=$signed(conv_sign[i])<<<kernel_shift[L0_cnt*3+i];
	end
end
//conv add
//TODO:try latch to reduce area?
reg [12:0]conv_add,conv_data;
reg conv_done;
always@(posedge clk) begin
	case(L0_cnt) //synthesis parallel_case full_case
		2'd0:conv_add <=(bias    +conv_mul[0])+(conv_mul[1]+conv_mul[2]);
		2'd1:conv_add <=(conv_add+conv_mul[0])+(conv_mul[1]+conv_mul[2]);
		2'd2:begin
			conv_data<=(conv_add+conv_mul[0])+(conv_mul[1]+conv_mul[2]);
			conv_add<=13'dx;
			L0_caddr_wr[2]<=L0_caddr_wr[1];
		end
	endcase
end

always@(posedge clk,posedge reset) begin
	if(reset) begin
		conv_done<=0;
	end
	else begin
		if(conv_done) begin
			if(csel==0) conv_done<=0;
		end
		else conv_done<=L0_cnt[1];//L0_cnt==2;
	end
end
/*-----------------------------------------*/
//max_pooling & round up & caddr ctrl & (ReLU)
reg [4:0] L1_x,L1_y;
reg [2:0] L1_cnt;
wire L1_w;
reg L1_ready;
assign csel=L1_w;
assign crd=(!L1_w)&&L1_ready;
assign caddr_rd={L1_y,L1_cnt[1],L1_x,L1_cnt[0]};
//layer 1 request data
//when last group start,start reading and write into mem1
//L1_cnt: 0,1,2,3,4
//rw	: r,r,r,r,w
//recv	: x,0,1,2,3
assign L1_w=L1_cnt[2];
always@(posedge clk,posedge reset) begin
	if(reset) L1_ready<=0;
	else if(group==2'd3 && req_pos[1]>6) L1_ready<=1;
end
always@(posedge clk,posedge reset) begin
	if(reset) begin
		L1_x<=0;
		L1_y<=0;
		L1_cnt<=0;
	end
	else if(L1_ready) begin
		if(L1_w) begin
			L1_cnt<=0;
			if(L1_y[0]) begin
				if(!L1_x) L1_y<=L1_y+1;
				else L1_x<=L1_x-1;
			end
			else begin
				if(&L1_x) L1_y<=L1_y+1;
				else L1_x<=L1_x+1;
			end
		end
		else L1_cnt<=L1_cnt+1;
	end
end
//write data
wire [7:0] round_up,larger;
reg [7:0] max;
reg [9:0] L1_caddr_wr;
assign cwr=conv_done || L1_w;
assign round_up=(cdata_rd[3:0])? cdata_rd[11:4]+1:cdata_rd[11:4];
assign larger=(round_up>max)? round_up:max;
always@(*) begin
	if(csel) begin
		caddr_wr={2'd0,L1_caddr_wr};
		cdata_wr={1'd0,max,4'd0};
	end
	else begin
		caddr_wr=L0_caddr_wr[2];
		cdata_wr=(conv_data[12])? 0:conv_data;
	end
	L1_caddr_wr<={L1_y,L1_x};
end
always@(posedge clk) begin
	if(L1_w||!L1_ready) max<=0;
	else max<=larger;
end
//busy ctl
always@(posedge clk,posedge reset) begin
	if(reset) busy<=0;
	else begin
		if(busy) begin
			if(L1_caddr_wr==10'b1111100000 && csel) busy<=0;
		end
		else if(ready) busy<=1;
	end
end
endmodule




