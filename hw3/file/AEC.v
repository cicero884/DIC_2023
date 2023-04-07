//target
//cycle 815
//area 478
//area(dc) 4929
`define QUEUE_SIZE 5
`define NUM_WIDTH 7
`define OP_STACK_SIZE 4
`define NUM_STACK_SIZE 3
module stack #(parameter WIDTH=8,SIZE=8)(clk,move,rw,data_in,data_out,data2_out);
input clk;
input move;
input rw;
input [WIDTH-1:0] data_in;
output [WIDTH-1:0] data_out,data2_out;
integer i;
reg [WIDTH-1:0] data[0:SIZE-1];
assign data_out=data[0];
assign data2_out=data[1];
//stack
//use reset to initialize to 0 [op='(']
always@(posedge clk) begin
	case({move,rw}) //synopsys parallel_case
		2'b01: data[0]<=data_in;
		2'b10: begin
			for(i=1;i<SIZE;i=i+1) data[i-1]<=data[i];
			data[SIZE-1]<={WIDTH{1'b0}};
		end
		2'b11: begin
			data[0]<=data_in;
			for(i=0;i<SIZE;i=i+1) data[i+1]<=data[i];
		end
	endcase
end
endmodule

module AEC(clk, rst, ascii_in, ready, valid, result);

// Input signal
input clk;
input rst;
input ready;
input [7:0] ascii_in;

// Output signal
output reg valid;
output reg [6:0] result;
reg queue_pop;

reg [6:0]in_queue[0:`QUEUE_SIZE-1];
wire [6:0]queue_out;
reg [3:0]in_queue_length;
integer i;

//input dynamic size queue buffer
assign queue_out=in_queue[0];
always@(posedge clk,posedge rst) begin
	if(rst) begin
		in_queue_length<=4'd0;
		in_queue[0]<="=";
	end
	else begin
		if(queue_pop) begin
			for(i=0;i<`QUEUE_SIZE;i=i+1) begin
				if(i<in_queue_length-1) in_queue[i]<=in_queue[i+1];
			end
		end
		else in_queue_length<=(valid)? 0:in_queue_length+1;
		in_queue[in_queue_length-queue_pop]<=ascii_in[6:0];
	end
end

//prefix to pofix(main controller)
reg end_wait;
//match to ascii last two word
localparam PAR=2'b00;//left parenthesis
localparam SUB=2'b01;
localparam MUL=2'b10;
localparam ADD=2'b11;
reg op_move,num_move,op_w,num_w;
reg [$clog2(`NUM_STACK_SIZE)-1:0] num_cnt;
reg [$clog2(`OP_STACK_SIZE)-1:0] op_cnt;
wire [1:0]op_in,op1_out,op2_out;
wire [`NUM_WIDTH-1:0]num_in,num_out;

//num_stack | result   <--num_in-- queue_out
//op_stack   <---op_in-- queue_out

stack #(.WIDTH(2),.SIZE(`OP_STACK_SIZE)) op_stack (
	.clk(clk),.move(op_move),.rw(op_w),.data_in(op_in),.data_out(op1_out),.data2_out(op2_out)
);
stack #(.WIDTH(`NUM_WIDTH),.SIZE(`NUM_STACK_SIZE)) num_stack (
	.clk(clk),.move(num_move),.rw(num_w),.data_in(result),.data_out(num_out)
);
assign op_in=queue_out[1:0];
assign num_in=(queue_out[4])? queue_out[3:0]:(queue_out[3:0]+4'd9);
/*controlls:
		queue_pop
		op_move,op_w
		num_move,num_w
*/
always@(*) begin
	queue_pop=1'b1;
	{op_move ,op_w }=2'b00;
	{num_move,num_w}=2'b00;

	case(queue_out[6:4]) //synopsys parallel_case full_case
		3'b010: begin //()*+-
			case(queue_out[2:0])
				3'b000: begin// (
					{op_move,op_w}=2'b11;
				end
				3'b001: begin// )
					{op_move,op_w}=2'b10;
					if(op1_out!=PAR) begin
						queue_pop=1'b0;
						{num_move,num_w}=2'b10;
					end
					else {num_move,num_w}=2'b00;
				end
				3'b010: begin// *
					if(op2_out==MUL) begin //calc
						{num_move,num_w}=2'b10;
						{op_move,op_w}=2'b0x;
					end
					else {op_move,op_w}=2'b11;
				end
				default: begin// +-
					if(op1_out==PAR) {op_move,op_w}=2'b11;
					else begin
						{num_move,num_w}=2'b10;
						if(op2_out==PAR) begin
							{op_move,op_w}=2'b01;
						end
						else begin
							{op_move,op_w}=2'b10;
							queue_pop=1'b0;
						end
					end
				end
			endcase
		end
		3'b011: begin //[0-9]=
			if(queue_out[3:0]>9) begin //=
				{op_move,op_w}=2'b10;
				{num_move,num_w}=2'b10;
				queue_pop=1'b0;
			end
			else begin //[0-9]
				{num_move,num_w}=2'b11;
			end
		end
		3'b110: begin //[a-f]
			{num_move,num_w}=2'b11;
		end
	endcase
end

//calc
always@(posedge clk,posedge rst) begin
	if(rst) begin
		end_wait<=1'b1;
		valid<=1'b0;
		num_cnt<=0;
		op_cnt<=0;
	end
	else begin
		end_wait<=valid;
		valid<=(!(end_wait||ready) && num_cnt==2 && queue_out=="=");
		if(num_move) begin
			if(num_w) begin
				result<=num_in;
				num_cnt<=num_cnt+3'd1;
			end
			else begin
				case(op1_out) //synopsys parallel_case
					ADD: result<=num_out+result;
					SUB: result<=num_out-result;
					MUL: result<=num_out*result;
				endcase
				if(ready) num_cnt<=3'd0;
				else num_cnt<=num_cnt-3'd1;
			end
		end
		if(op_move) begin
			if(ready) op_cnt<=3'd0;
			else op_cnt<=(op_w)? op_cnt+1:op_cnt-1;
		end
	end
end
endmodule
