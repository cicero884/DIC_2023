//target
//cycle 800
//area 400
`define QUEUE_SIZE 16
module stack #(parameter WIDTH=8,SIZE=8)(clk,move,rw,data_in,data_out);
input clk;
input move;
input rw;
input [WIDTH-1:0] data_in;
output [WIDTH-1:0] data_out;
integer i;
reg [WIDTH-1:0] data[0:SIZE-1];
assign data_out=data[0];
always@(posedge clk) begin
	case({move,rw}) //synopsys parallel_case
		2'b01: data[0]<=data_in;
		2'b10: for(i=0;i<SIZE;i=i+1) data[i]<=data[i+1];
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
wire queue_pop;

reg [7:0]in_queue[0:`QUEUE_SIZE-1];
wire [7:0]queue_out;
reg [3:0]in_queue_length;
reg [4:0]temp_i

//input dynamic size queue buffer
assign queue_out=in_queue[0];
always@(posedge clk,posedge rst) begin
	if(rst) begin
		in_queue_length<=4'd0;
	end
	else begin
		if(queue_pop) begin
			for(temp_i=0;temp_i<`QUEUE_SIZE;temp_i=temp_i+1) begin
				if(temp_i<in_queue_length) in_queue[temp_i]<=in_queue[temp_i+1];
			end
		end
		in_queue_length<=(queue_out=="=")? 0:in_queue_length+1;
		in_queue[in_queue_length]=ascii_in;
	end
end

//prefix to pofix(main controller)
reg end_wait;
//match to ascii last two word
localparam PAR=2'b00;//left parenthesis
localparam SUB=2'b01;
localparam MUL=2'b10;
localparam ADD=2'b11;
wire op_move,num_move,op_w,num_w;
wire [1:0]op_in,op_out;
wire [6:0]num_in,num_out;

//num_stack | result <--num_in-- queue_out
//op_stack <---op_in-- queue_out

stack #(.WIDTH(2),.SIZE(7)) op_stack (
	.clk(clk),.move(op_move),.rw(op_w),.data_in(op_in),.data_out(op_out)
);
stack #(.WIDTH(7),.SIZE(5)) num_stack (
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

	if(!(ready||valid||in_wait)) begin
		case(queue_out[6:4]) //synopsys parallel_case full_case
			3'b010: begin //()*+-
				case(queue_out[2:0])
					3'b000: begin// (
						{op_move,op_w}=2'b11;
					end
					3'b001: begin// )
						{op_move,op_w}=2'b10;
						if(op_out!=PAR) queue_pop=1'b0;
						else {num_move,num_w}=2'b10;
					end
					3'b010: begin// *
						if(op_out==MUL) begin //calc
							{num_move,num_w}=2'b10;
							{op_move,op_w}=2'b0x;
						end
						else {op_move,op_w}=2'b11;
					end
					default: begin// +-
						if(op_out==PAR) {op_move,op_w}=2'b11;
						else begin //calc
							{num_move,num_w}=2'b10;
							{op_move,op_w}=2'b01;
						end
					end
				endcase
			end
			3'b011: begin //[0-9]=
				if(queue_out[3:0]>9) begin //=
					{op_move,op_w}=2'b10;
					{num_move,num_w}=2'b10;
				end
				else begin //[0-9]
					{num_move,num_w}=2'b11;
				end
				queue_pop=1'b0;
			end
			3'b110: begin //[a-f]
				{num_move,num_w}=2'b11;
			end
		endcase
	end
end

//calc
reg [2:0] num_cnt;
always@(posedge clk,posedge rst) begin
	if(rst) begin
		end_wait<=1'b1;
		valid<=0;
		num_cnt<=0;
	end
	else begin
		end_wait<=valid;
		if(num_move) begin
			if(num_w) begin
				result<=num_in;
				num_cnt<=num_cnt+3'd1;
			end
			else begin
				case(op_out) //synopsys parallel_case
					ADD: result<=num_in+result;
					SUB: result<=num_in-result;
					MUL: result<=num_in*result;
				endcase
				num_cnt<=num_cnt-3'd1;
			end
		end
	end
end
endmodule
