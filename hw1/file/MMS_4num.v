module MMS_4num(result, select, number0, number1, number2, number3);

input        select;
input  [7:0] number0;
input  [7:0] number1;
input  [7:0] number2;
input  [7:0] number3;
output [7:0] result; 

module multi_cmp #(parameter WIDTH=32,SIZE=2)(
	input [WIDTH*SIZE-1:0] data,input sel
	output [WIDTH-1:0] min_max
);
generate
case(SIZE)
	1:assign min_max=data[WIDTH-1:0];
    2:assign min_max=(sel ^ (data[WIDTH+:WIDTH]>data[0+:WIDTH]))? data[0+:WIDTH]:data[WIDTH+:WIDTH];
	default: begin
		wire [WIDTH+$clog2(SIZE/2)-1:0]r1;
		multi_cmp #(.WIDTH (WIDTH),.SIZE(SIZE/2))
		right(.data(data[WIDTH*(SIZE/2)-1:0]),.min_max(r1));

		wire [WIDTH+$clog2(SIZE-SIZE/2)-1:0]r2;
		multi_cmp #(.WIDTH (WIDTH),.SIZE(SIZE-SIZE/2))
		left(.data(data[WIDTH*SIZE-1:WIDTH*(SIZE/2)]),.min_max(r2));

		assign min_max=(sel ^ (r1>r2))? r2:r1;
	end
endcase
endgenerate
endmodule

multi_cmp #(.width(8),.size(4))
	mms_4num(.data({number0,number1,number2,number3}),.sel(select),.min_max(result));

endmodule
