module MMS_4num(result, select, number0, number1, number2, number3);

input        select;
input  [7:0] number0;
input  [7:0] number1;
input  [7:0] number2;
input  [7:0] number3;
output [7:0] result; 


multi_cmp #(.WIDTH(8),.SIZE(4))
mms_4num(.data({number0,number1,number2,number3}),.sel(select),.min_max(result));

endmodule

module multi_cmp #(parameter WIDTH=32,SIZE=2)(
	input [WIDTH*SIZE-1:0] data,input sel,
	output [WIDTH-1:0] min_max
);
generate
	case(SIZE)
		1:assign min_max=data[WIDTH-1:0];
		2:assign min_max=(sel ^ (data[WIDTH+:WIDTH]>data[0+:WIDTH]))? data[WIDTH+:WIDTH]:data[0+:WIDTH];
		default: begin
			wire [WIDTH-1:0]r1;
			multi_cmp #(.WIDTH (WIDTH),.SIZE(SIZE/2))
			right(.data(data[WIDTH*(SIZE/2)-1:0]),.min_max(r1),.sel(sel));

			wire [WIDTH-1:0]r2;
			multi_cmp #(.WIDTH (WIDTH),.SIZE(SIZE-SIZE/2))
			left(.data(data[WIDTH*SIZE-1:WIDTH*(SIZE/2)]),.min_max(r2),.sel(sel));

			assign min_max=(sel ^ (r1>r2))? r1:r2;
		end
	endcase
endgenerate
endmodule
