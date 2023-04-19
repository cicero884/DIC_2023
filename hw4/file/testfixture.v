`timescale 1ns/10ps
`define CYCLE      10          	  // Modify your clock period here
`define SDFFILE    "./CONV_syn.sdf"	  // Modify your sdf file name
`define End_CYCLE  100000000              // Modify cycle times once your design need more cycle times!
`define IMG_DATA "./data/img.dat"
`define RELU_GOLDEN "./data/afterRelu.dat"
`define RESULT_GOLDEN "./data/result.dat"

module testfixture;

reg [12:0] imgData [0:4095];

reg [12:0] afterReluGolden [0:4095];
reg [12:0] resultGolden [0:1023];

reg [12:0] afterReluMem [0:4095];
reg [12:0] resultMem [0:1023];

wire		cwr;
wire		crd;
wire	[12:0]	cdata_wr;
reg	[12:0]	cdata_rd;
wire	csel;
wire	[11:0]	caddr_rd;
wire	[11:0]	caddr_wr;

reg		reset = 0;
reg		clk = 0;
reg		ready = 0;

wire	[11:0]	iaddr;
reg	[12:0]	idata;


integer		p0, p1, p3, p4, p2;
integer		err0,  err1;
reg		check0=0, check1=0;

ATCONV u_ATCONV(
			.clk(clk),
			.reset(reset),
			.busy(busy),	
			.ready(ready),	
			.iaddr(iaddr),
			.idata(idata),
			.cwr(cwr),
			.caddr_wr(caddr_wr),
			.cdata_wr(cdata_wr),
			.crd(crd),
			.cdata_rd(cdata_rd),
			.caddr_rd(caddr_rd),
			.csel(csel)
			);

always begin #(`CYCLE/2) clk = ~clk; end

initial begin  // global control
	$display("-----------------------------------------------------\n");
 	$display("START!!! Simulation Start .....\n");
 	$display("-----------------------------------------------------\n");
	@(negedge clk); #1; reset = 1'b1;  ready = 1'b1;
   	#(`CYCLE*3);  #1;   reset = 1'b0;  
   	wait(busy == 1); #(`CYCLE/4); ready = 1'b0;
end

initial begin // initial pattern and expected result
	wait(reset==1);
	wait ((ready==1) && (busy ==0) ) begin
		$readmemb(`IMG_DATA, imgData);
        $readmemb(`RELU_GOLDEN, afterReluGolden);
        $readmemb(`RESULT_GOLDEN, resultGolden);
	end	
end
always@(negedge clk) begin // generate the stimulus input data
	#1;
	if ((ready == 0) & (busy == 1)) idata <= imgData[iaddr];
	else idata <= 'hx;
end



always@(negedge clk) begin
	if (crd == 1) begin
		case(csel)
			1'b0:cdata_rd <= afterReluMem[caddr_rd] ;
			1'b1:cdata_rd <= resultMem[caddr_rd] ;
		endcase
	end
end

always@(posedge clk) begin 
	if (cwr == 1) begin
		case(csel)
            1'b0: begin check0 <= 1; afterReluMem[caddr_wr] <= cdata_wr; end
            1'b1: begin check1 <= 1; resultMem[caddr_wr] <= cdata_wr; end 
		endcase
	end
end


//-------------------------------------------------------------------------------------------------------------------
initial begin  	// layer 0,  conv output
check0<= 0;
wait(busy==1); wait(busy==0);
if (check0 == 1) begin 
	err0 = 0;
	for (p0=0; p0<=4095; p0=p0+1) begin
		if (afterReluMem[p0] ==afterReluGolden[p0]) ;
		/*else if ( (L0_MEM0[p0]+20'h1) == L0_EXP0[p0]) ;
		else if ( (L0_MEM0[p0]-20'h1) == L0_EXP0[p0]) ;
		else if ( (L0_MEM0[p0]+20'h2) == L0_EXP0[p0]) ;
		else if ( (L0_MEM0[p0]-20'h2) == L0_EXP0[p0]) ;
		else if ( (L0_MEM0[p0]+20'h3) == L0_EXP0[p0]) ;
		else if ( (L0_MEM0[p0]-20'h3) == L0_EXP0[p0]) ;*/
		else begin
			err0 = err0 + 1;
			begin 
				if(p0 < 128)
				begin
					$display("WRONG! Layer 0 (Convolutional Output) with Kernel , Pixel %d is wrong!", p0);
					$display("               The output data is %h, but the expected data is %h ", afterReluMem[p0], afterReluGolden[p0]);
				end
			end
		end
	end
	if (err0 == 0) $display("Layer 0 (Convolutional Output) with Kernel is correct !");
	else		 $display("Layer 0 (Convolutional Output) with Kernel be found %d error !", err0);
end
end

//-------------------------------------------------------------------------------------------------------------------
initial begin  	// layer 1,  max-pooling output
check1<= 0;
wait(busy==1); wait(busy==0);
if(check1 == 1) begin
	err1 = 0;
	for (p1=0; p1<=1023; p1=p1+1) begin
		if (resultMem[p1] == resultGolden[p1]) ;
		else begin
			err1 = err1 + 1;
			begin 
				$display("WRONG! Layer 1 (Max-pooling Output) with Kernel , Pixel %d is wrong!", p1);
				$display("               The output data is %h, but the expected data is %h ", resultMem[p1], resultGolden[p1]);
			end
		end
	end
	if (err1 == 0) $display("Layer 1 (Max-pooling Output) with Kernel is correct!");
	else		 $display("Layer 1 (Max-pooling Output) with Kernel be found %d error !", err1);
end
end


//-------------------------------------------------------------------------------------------------------------------
initial  begin
 #`End_CYCLE ;
 	$display("-----------------------------------------------------\n");
 	$display("Error!!! The simulation can't be terminated under normal operation!\n");
 	$display("-------------------------FAIL------------------------\n");
 	$display("-----------------------------------------------------\n");
 	$finish;
end

initial begin
      wait(busy == 1);
      wait(busy == 0);      
    $display(" ");
	$display("-----------------------------------------------------\n");
	$display("--------------------- S U M M A R Y -----------------\n");
	if( (check0==1)&(err0==0)) $display("Congratulations! Layer 0 data have been generated successfully! The result is PASS!!\n");
		else if (check0 == 0) $display("Layer 0 output was fail! \n");
		else $display("FAIL!!!  There are %d errors! in Layer 0 \n", err0);
	if( (check1==1)&(err1==0) ) $display("Congratulations! Layer 1 data have been generated successfully! The result is PASS!!\n");
		else if (check1 == 0) $display("Layer 1 output was fail! \n");
		else $display("FAIL!!!  There are %d errors! in Layer 1 \n", err1);

	if ((check0|check1) == 0) $display("FAIL!!! No output data was found!! \n");
	$display("-----------------------------------------------------\n");
      #(`CYCLE/2); $finish;
end
endmodule