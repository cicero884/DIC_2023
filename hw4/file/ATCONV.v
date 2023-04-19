`timescale 1ns/10ps
module  ATCONV(
	input		clk,
	input		reset,
	output	reg	busy,	
	input		ready,	
			
	output reg	[11:0]	iaddr,
	input signed [12:0]	idata,
	
	output	reg 	cwr,
	output  reg	[11:0]	caddr_wr,
	output reg 	[12:0] 	cdata_wr,
	
	output	reg 	crd,
	output reg	[11:0] 	caddr_rd,
	input 	[12:0] 	cdata_rd,
	
	output reg 	csel
	);

/*
- input image size: 64 x 64 0~4095
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
assign bias = 13'h000C;

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
reg [4:0]x[0:2],y[0:2];
reg [2:0]group[0:2];
reg request_done,calc_done;
localparam RIGHT=0;
localparam LEFT=1;
localparam DOWN=2;
localparam RESET=3;
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

//direct_act: {next_xy,direction}
reg [2:0] direct_act[0:1];
always@(*) begin
	case(direct)
		RIGHT: begin//2,5,8
			if(req_pos[0]>5) direct_act[0]={1'b1,direct_next};//end(next state)
			else direct_act[0]={1'b0,direct[0]};
		end
		LEFT: begin//0,3,6
			if(req_pos[0]>5) direct_act[0]={1'b1,direct_next};//end(next state)
			else direct_act[0]={1'b0,direct[0]};
		end
		DOWN: begin//6,7,8
			if(req_pos[0]>7) direct_act[0]={1'b1,direct_next};//end(next state)
			else direct_act[0]={1'b0,direct[0]};
		end
		RESET: begin//all
			if(req_pos[0]>7) direct_act[0]={1'b1,direct_next};//end(next state)
			else direct_act[0]={1'b0,direct[0]};
		end
	endcase
end
//xy,req_pos[0] controller
//012
//345
//678
always@(posedge clk,posedge rst) begin
	if(rst) begin
		x[0]<=0;
		y[0]<=0;
		group[0]<=0;
		req_pos[0]<=0;
		direct<=RESET;
	end
	else if(ready) begin
		//cur direct(set req_pos[0])
		case(direct_act[0])//synthesis parallel_case full_case
			//jump
			{1'b1,RIGHT}:begin//(2),5,8
				req_pos[0]<=2;
				x[0]<=x[0]+1;
			end
			{1'b1,LEFT }:begin//(0),3,6
				req_pos[0]<=0;
				x[0]<=x[0]-1;
			end
			{1'b1,DOWN }:begin//(6),7,8
				req_pos[0]<=6;
				y[0]<=y[0]+1;
			end
			{1'b1,RESET}:begin//(0),1,2,3,4,5,6,7,8
				req_pos[0]<=0;
				y[0]<=y[0]+1;//overflow to 0
				group[0]<=group[0]+1;
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
//iaddr controller
//012
//345
//678
reg [5:0] tmp_x,tmp_y;
always@(*) begin
	case(req_pos[0])//synthesis full_case parallel_case
		0: {tmp_x,tmp_y}={x[0]-1,y[0]-1};
		1: {tmp_x,tmp_y}={x[0]  ,y[0]-1};
		2: {tmp_x,tmp_y}={x[0]+1,y[0]-1};
		3: {tmp_x,tmp_y}={x[0]-1,y[0]  };
		4: {tmp_x,tmp_y}={x[0]  ,y[0]  };
		5: {tmp_x,tmp_y}={x[0]+1,y[0]  };
		6: {tmp_x,tmp_y}={x[0]-1,y[0]+1};
		7: {tmp_x,tmp_y}={x[0]  ,y[0]+1};
		8: {tmp_x,tmp_y}={x[0]+1,y[0]+1};
	endcase
	if(tmp_x[5]) begin//x out board
		if(tmp_x[4]) tmp_x=6'd0;//-
		else tmp_x=~6'd0;//+
	end
	if(tmp_y[5]) begin//y out board
		if(tmp_y[4]) tmp_y=6'd0;//-
		else tmp_y=~6'd0;//+
	end
	iaddr={tmp_y[4:0],group[0][1],tmp_x[4:0],group[0][0]};
end
/********************************************************/
//write into 3*3
reg [12:0] cache[0:8];
reg valid_calc;
integer i;
always@(posedge clk) begin
	case(direct_act[1]) //synthesis parallel_case
		{1'b1,RIGHT}: begin
			for(i=0;i<9;i=i+3) begin
				cache[i]<=cache[i+1];
				cache[i+1]<=cache[i+2]
			end
		end
		{1'b1,LEFT}: begin
			for(i=2;i<9;i=i+3) begin
				cache[i]<=cache[i-1];
				cache[i-1]<=cache[i-2]
			end
		end
		{1'b1,DOWN}: begin
			for(i=0;i<6;++i) cache[i]<=cache[i+3];
		end
	endcase
	cache[req_pos[1]]<=idata;
	if(direct_act[1][1:0]==RESET && req_pos<6) valid_calc<=0;
	else valid_calc=1;

	x[1]<=x[0];
	y[1]<=y[0];
	req_pos[1]<=req_pos[0];
	direct_act[1]<=direct_act[0];
end
/*******************************************/
//conv
always@(posedge clk) begin

	x[2]<=x[1];
	y[2]<=y[1];
end
//caddr ctrl
//when last group start,start reading and write into mem1

endmodule
