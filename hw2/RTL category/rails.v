module stack(clk,valid,rw,data_in,data_out);
input clk;
input valid;
input rw;
input [3:0] data_in;
output [3:0] data_out;
integer i;
reg [3:0] data[0:9];
assign data_out=data[0];
always@(posedge clk) begin
	if(valid) begin
		if(rw) begin//read
			data[0]<=data_in;
			for(i=0;i<9;i=i+1) data[i+1]<=data[i];
		end
		else begin
			for(i=0;i<9;i=i+1) data[i]<=data[i+1];
		end
	end
end
endmodule
module rails(clk, reset, data, valid, result);
input        clk;
input        reset;
input  [3:0] data;
output reg      valid;
output reg      result; 

localparam IN_NUM=0,IN_SEQ=1,BUSY=2,WAIT=3;

reg [1:0] status;
//enum status{IN_NUM,IN_SEQ,BUSY,WAIT};

reg [3:0] in_cnt,out_cnt,station_cnt;//in[0:9],station[0:9];

reg dir_b_valid,dir_b_rw;
wire[3:0] dir_b_out;
stack dir_b(.clk(clk),.valid(dir_b_valid),.rw(dir_b_rw),.data_in(data),.data_out(dir_b_out));

reg station_valid,station_rw;
wire[3:0] station_out;
stack station(.clk(clk),.valid(station_valid),.rw(station_rw),.data_in(dir_b_out),.data_out(station_out));
always@(*) begin
	case(status)
		IN_SEQ: begin
			{dir_b_valid,dir_b_rw}<={|out_cnt,1'b1};
			{station_valid,station_rw}<=2'b0x;
		end
		BUSY: begin
			case({out_cnt,1'b1})
				{dir_b_out,(|in_cnt)}: begin
					{dir_b_valid,dir_b_rw}<=2'b10;
					{station_valid,station_rw}<=2'b0x;
				end
				{station_out,(|station_cnt)}: begin
					{dir_b_valid,dir_b_rw}<=2'b0x;
					{station_valid,station_rw}<=2'b10;
				end
				default: begin
					if(in_cnt) begin
						{dir_b_valid,dir_b_rw}<=2'b10;
						{station_valid,station_rw}<=2'b11;
					end
					else begin
						{dir_b_valid,dir_b_rw}<=2'b0x;
						{station_valid,station_rw}<=2'b0x;
					end
				end
			endcase
		end
		default: begin
			{dir_b_valid,dir_b_rw}<=2'b0x;
			{station_valid,station_rw}<=2'b0x;
		end
	endcase
end

always@(posedge clk,posedge reset) begin
	if(reset) begin
		status<=IN_NUM;
		valid<=1'b0;
		result<=1'b0;
		station_cnt<=4'd0;
	end
	else begin
		case(status)
			IN_NUM: begin
				out_cnt<=data;
				in_cnt<=data;
				status<=IN_SEQ;
			end
			IN_SEQ: begin
				if(!out_cnt) begin
					station_cnt<=4'd0;
					status<=BUSY;
					out_cnt<=in_cnt;
				end
				else begin
					out_cnt<=out_cnt-1;
				end
			end
			BUSY: begin
				case({out_cnt,1'b1})
					{dir_b_out,(|in_cnt)}: begin
						in_cnt<=in_cnt-1;
						out_cnt<=out_cnt-1;
					end
					{station_out,(|station_cnt)}: begin
						station_cnt<=station_cnt-1;
						out_cnt<=out_cnt-1;
					end
					default: begin
						if(in_cnt) begin
							in_cnt<=in_cnt-1;
							station_cnt<=station_cnt+1;
						end
						else begin
							{valid,result}<={1'b1,&(~station_cnt)};
							status<=WAIT;
						end
					end
				endcase
			end
			WAIT: begin
				{valid,result}<=2'b00;
				status<=IN_NUM;
			end
		endcase
	end
end
/*
	Write Your Design Here ~
*/

endmodule
