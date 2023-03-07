
module MMS_8num(result, select, number0, number1, number2, number3, number4, number5, number6, number7);

input        select;
input  [7:0] number0;
input  [7:0] number1;
input  [7:0] number2;
input  [7:0] number3;
input  [7:0] number4;
input  [7:0] number5;
input  [7:0] number6;
input  [7:0] number7;
output [7:0] result; 

multi_cmp #(.width(8),.size(8))
	mms_8num(.data({number0,number1,number2,number3,number4,number5,number6,number7}),.sel(select),.min_max(result));
/*
	Write Your Design Here ~
*/

endmodule
