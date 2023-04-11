`timescale 1ns/10ps
`define cycle 5.0              // Modify your cycle time here
`define terminate_cycle 5000   // Modify your terminate cycle here



// Don't modify below
module testfixture;

// Input pattern
`define num_pattern "./dat/pattern.data"
 

// Input
reg clk = 0;
reg rst = 0;
reg [7:0] ascii_in;
reg ready;
reg readyEn;

// Output
wire valid;
wire [6:0] result;

reg [7:0] score;

// Connect custom design
AEC u_AEC(.clk(clk), 
		  .rst(rst),
		  .ready(ready),
		  .ascii_in(ascii_in),
		  .valid(valid),
		  .result(result)
		  );


// Clock signal
always begin #(`cycle/2) clk <= ~clk; end 


integer linedata;
initial begin
	linedata = $fopen(`num_pattern,"r");
	if(linedata == 0) begin
		$display("Please check your data path!");
	end
end


initial begin
	@(posedge clk); #1; rst = 1'b1;
	# (`cycle*2);
	@(posedge clk); #1; rst = 1'b0;
	@(posedge clk); ready = 1;
end


reg [11:0] cycleCount = 0;
always@(posedge clk)begin
	cycleCount <= cycleCount + 1;
	if(cycleCount > `terminate_cycle) begin
		$display("-------------------------------------------------------------");
		$display("-----------------Fail waiting valid signal!------------------");
		$display("-----Please check your design or increase terminateCycle-----");
		$display("-------------------------------------------------------------");
		$fclose(linedata);
		$finish;
	end
end

reg wait_valid;
string data;
string strNum;
reg[15:0] strNum_s;
string strData;
string strData_s;
string strData_s2;
reg [150:0] strData_reg;
reg [7:0] strAns;
integer strIndex;
integer char_count;

integer err = 0;


initial begin
	$display("----------------------------------------------");
	$display("---------------Start Simulation---------------");
	$display("----------------------------------------------");
	char_count = $fgets(data, linedata);
	$display("%s", data.substr(0,data.len()-2));
	if(!$feof(linedata))begin
		char_count = $fgets(data, linedata);
		if(char_count !== 0) begin
			if(data.substr(0,3) == "num:")begin
				strIndex = 0;
				strNum = data.substr(4,5);
				strData_s = data.substr(9,10);
				strAns = strData_s.atoi();
				strData = data.substr(12,data.len()-1);
			end
		end
	end
end



// Send data
always@(negedge clk)begin
	if(rst) begin
		ascii_in = 0;
	end
	else begin
		if(readyEn==1)begin
			ready = 1;
			readyEn = 0;
			ascii_in = strData.getc(strIndex);
			strIndex = strIndex + 1;
		end
		else if(wait_valid == 1'b0)begin   
			ready = 0;
			if(strIndex<strData.len()-1)begin     // send test signal
				ascii_in = strData.getc(strIndex);
				strIndex = strIndex + 1;
			end
		end
	end
end

string strAns_str;
// Check data and read new line 
always@(negedge clk)begin
	if(rst) begin
		wait_valid = 0;
		ready = 0;
		readyEn = 1;
		score = 0;
	end
	else begin
		if (wait_valid==1 && valid==1) begin      // from designer valid signal
            wait_valid = 0;                       // Tb start to send signal
            strNum_s = strNum.atoi();
            strData_s2 = strData.substr(0,strData.len()-2);
            if(strAns==result)begin
            	$display(" Pattern %2d : %s ", strNum_s, strData_s2);
            	$display(" Expected answer:%d | get:%d --> Pass", strAns, result);
            	if(strNum_s<=40) score = score + 2;
            	else score = score + 1;
            end
            else begin
            	$display(" Pattern %2d : %s ", strNum_s, strData_s2);
            	$display(" Expected answer:%d | get:%d --> Fail", strAns, result);
            	err = err + 1;
            end

            strIndex = 0;  
            readyEn = 1; 
            if(!$feof(linedata))begin            // Read new line
				char_count = $fgets(data, linedata);
				if(data.substr(0,2) == "END")begin
					if(err==0)begin
						$display("\n");
						$display("         _        "           );
						$display("     _.-(_)._     "           ); 
						$display("   .'________'.   "           );
						$display("  [____________]      Congraultaions!!! You past all patterns! Your score is %d.",score);
						$display("  /  / .\\/. \\  \\      Total use %1d cycles to complete simulation.", cycleCount);       
						$display("  |  \\__/\\__/  | "          );
						$display("  \\            /  "          );
						$display("  /'._  \\_/ _.'\\ "          );
						$display(" /_   `''''`   _\\ "          );
						$display("(__/    '|    \\ _|"          );
						$display("  |_____'|_____|  "           );
						$display("   '----------' "             );
					end
					else begin
						$display("\n");
						$display("         _            "            );
						$display("     _.-(_)._         "            ); 
						$display("   .'________'.       "            );
						$display("  [____________]     There are %1d error in test patterns. Your score is %d.", err, score);
						$display("  /  \\/   \\/   \\     Please check your design!!!        "     );
						$display("  |  /\\   /\\   |    "            );
						$display("  \\    ___     /     "            );
						$display("  /'._      _.'\\     "            );
						$display(" /_   `''''`   _\\    "            );
						$display("(__/    '|    \\ _|   "            );
						$display("  |_____'|_____|      "            );
						$display("   '----------'       "            );
					end
					$finish;
				end

				if(data.substr(0,3) == "Case")begin
					$display("\n%s", data.substr(0,data.len()-2));
					char_count = $fgets(data, linedata);
				end
				if(char_count !== 0) begin
					if(data.substr(0,3) == "num:")begin
						strIndex = 0;
						strNum = data.substr(4,5);
						strData_s = data.substr(9,10);
						strAns = int'(strData_s.atoi());
						strData = data.substr(12,data.len()-1);
					end
				end
			end
        end
		else if(strIndex==strData.len()-1)begin   // Finsih sending this line
			wait_valid = 1;
		end
	end
end



endmodule
