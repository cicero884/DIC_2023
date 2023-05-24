module demosaic(clk, reset, in_en, data_in, wr_r, addr_r, wdata_r, rdata_r, wr_g, addr_g, wdata_g, rdata_g, wr_b, addr_b, wdata_b, rdata_b, done);
input clk;
input reset;
input in_en;
input [7:0] data_in;
output wr_r;
output [13:0] addr_r;
output [7:0] wdata_r;
input [7:0] rdata_r;
output wr_g;
output [13:0] addr_g;
output [7:0] wdata_g;
input [7:0] rdata_g;
output wr_b;
output [13:0] addr_b;
output [7:0] wdata_b;
input [7:0] rdata_b;
output done;

endmodule
