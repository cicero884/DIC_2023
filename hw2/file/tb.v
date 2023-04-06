`timescale 1ns/10ps
`define CYCLE      50.0  
`define End_CYCLE  1000000000
`define PATTERN    "test_data_rails.dat"
`define EXPECT     "golden_data_rails.dat"

module testfixture();
parameter TEST_N_PAT = 100;

integer fd;
integer fg;
integer golden_result;
integer charcount;
integer pass=0;
integer fail=0;
integer pattern_count=0;

reg [3:0] data;
reg clk = 0;
wire valid;
reg reset =0;
wire result;

rails u_rails(.clk(clk),
        .reset(reset),
        .data(data),
        .valid(valid),
        .result(result));

always begin #(`CYCLE/2) clk = ~clk; end

initial begin
    $display("----------------------");
    $display("-- Simulation Start --");
    $display("----------------------");
    @(posedge clk);  #2 reset = 1'b1; 
    #(`CYCLE*2);  
    @(posedge clk);  #2  reset = 1'b0;
end

reg [31:0] cycle=0;

always @(posedge clk) begin
    cycle=cycle+1;
    if (cycle > `End_CYCLE) begin
        $display("--------------------------------------------------");
        $display("-- Failed waiting valid signal, Simulation STOP --");
        $display("--------------------------------------------------");
        $fclose(fd);
        $finish;
    end
end

initial begin
    fd = $fopen(`PATTERN,"r");
    if (fd == 0) begin
        $display ("pattern handle null");
        $finish;
    end
end

initial begin
    fg = $fopen(`EXPECT,"r");
    if (fg == 0) begin
        $display ("golden handle null");
        $finish;
    end
end

// reg  valid_reg;
// always @(posedge clk) begin
//     valid_reg = valid;
// end
reg wait_valid;
reg get_result;
reg first;
reg [3:0] num;
integer in_count;

always @(posedge clk ) begin
    if (reset) begin
        wait_valid=0;
    end
    else begin
        if(wait_valid == 0) begin
            if(in_count == num) wait_valid =1;
        end
        else begin
            if (valid ==1) begin
                wait_valid=0;
                get_result=result;
                charcount = $fscanf(fg, "%d", golden_result);
                if(get_result == golden_result) begin
                    pass = pass +1;
                    $display("Pattern%0d: Expect= %1d Get= %d, PASS\n",pattern_count,golden_result,get_result);
                end
                else begin
                    fail = fail +1;
                    $display("Pattern%0d: Expect= %1d Get= %d, FAIL\n",pattern_count,golden_result,get_result);
                end
                pattern_count = pattern_count + 1;
            end
        end
    end
end

always @(negedge clk ) begin
    if (reset) begin
        in_count = 0;
        first = 1;
    end 
    else begin
        if (pattern_count < TEST_N_PAT) begin
            if(wait_valid ==0) begin
                if(first) begin
                    first = 0;
                    charcount = $fscanf(fd, "%d", num);
                    data = num;
                end
                else begin
                    charcount = $fscanf(fd, "%d", data);
                    in_count = in_count + 1;    
                end
            end
            else begin
                data = 4'dx;
                first = 1;
                in_count = 0;
            end
        end //if (!$feof(fd)) begin
        else begin
             $fclose(fd);
             $display ("-----------------------------------------------------------");
             if(fail == 0)
                 $display("----    Simulation finish,  ALL PASS,  Score = %2d     ----", pass);
             else
                 $display("-- Simulation finish,  Pass = %2d , Fail = %2d, Score = %2d --",pass,fail,pass);
             $display ("-----------------------------------------------------------");
             $finish;
        end
    end
end
endmodule
