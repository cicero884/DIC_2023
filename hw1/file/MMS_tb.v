`timescale 10ns / 1ps
`define CYCLE 10
`define PATTERN_4num    "./test_data_4num.dat"         
`define EXPECT_4num   "./golden_data_4num.dat" 
`define PATTERN_8num    "./test_data_8num.dat"         
`define EXPECT_8num   "./golden_data_8num.dat"    

module MMS_tb;

parameter              TEST_N_PAT_4_max = 500;
parameter              TEST_N_PAT_4_min = 500;
parameter              TEST_N_PAT_8_max = 4000;
parameter              TEST_N_PAT_8_min = 4000;

// 4 num MMC input
reg                    select_4;
reg              [7:0] number_4 [0:3];
// 4 num MMC output golden
reg              [7:0] result_g_4;
// 4 num MMC output
wire             [7:0] result_4;
// 8 num MMC input
reg                    select_8;
reg              [7:0] number_8 [0:7];
// 8 num MMC output golden
reg              [7:0] result_g_8;
// 8 num MMC output
wire             [7:0] result_8;

integer                file_data_4;
integer                file_data_8;
integer                file_golden_4;
integer                file_golden_8;
integer                i;
integer                err;
integer                total_err_0;
integer                total_err_1;
integer                total_err_2;
integer                total_err_3;
integer                callback;

MMS_4num MMS_4num(.result(result_4), .select(select_4), .number0(number_4[0]), .number1(number_4[1]), .number2(number_4[2]), .number3(number_4[3]));
MMS_8num MMS_8num(.result(result_8), .select(select_8), .number0(number_8[0]), .number1(number_8[1]), .number2(number_8[2]), .number3(number_8[3]), .number4(number_8[4]), .number5(number_8[5]), .number6(number_8[6]), .number7(number_8[7]));

initial begin
   err = 0;
   total_err_0 = 0;
   total_err_1 = 0;
   total_err_2 = 0;
   total_err_3 = 0;
end

initial begin
    file_data_4 = $fopen(`PATTERN_4num, "r");
    file_data_8 = $fopen(`PATTERN_8num, "r");
    if (!file_data_4 || !file_data_8) begin
        $display ("pattern handle null");
        $finish;
    end
end

initial begin
    file_golden_4 = $fopen(`EXPECT_4num,"r");
    file_golden_8 = $fopen(`EXPECT_8num,"r");
    if (!file_golden_4 || !file_golden_8) begin
        $display ("golden handle null");
        $finish;
    end
end

initial begin
    $display("-------------Stage 1 : Maximum selection with 4-input MMS-------------\n");
    for (i = 0; i < TEST_N_PAT_4_max; i = i + 1) begin
        #`CYCLE 
        callback = $fscanf(file_data_4, "%b %d %d %d %d", select_4, number_4[0], number_4[1], number_4[2], number_4[3]); 
        #`CYCLE 
        callback = $fscanf(file_golden_4, "%d", result_g_4);
        //$display("Input = %b %d %d %d %d\n", select, test_data_4[0], test_data_4[1], test_data_4[2], test_data_4[3]);
        //$display("%d %d", result_g_4, result_4);
        if(result_g_4 == result_4) begin
            //
        end
        else begin
            //$display("Pattern %3d: Expect= %d Get= %d\n", i, result_g_4, result_4);
            err = err + 1;
        end
    end
    if(err != 0) begin
		$display("-------------------There are %3d errors in stage 1!-------------------\n", err);
	end
	else begin
		$display("-------------Stage 1 :              Pass!                 -------------\n");
	end
    total_err_0 = err;
    err = 0;
    $display("-------------Stage 2 : Minimum selection with 4-input MMS-------------\n");
    for (i = 0; i < TEST_N_PAT_4_min; i = i + 1) begin
        #`CYCLE 
        callback = $fscanf(file_data_4, "%b %d %d %d %d", select_4, number_4[0], number_4[1], number_4[2], number_4[3]); 
        #`CYCLE 
        callback = $fscanf(file_golden_4, "%d", result_g_4);
        //$display("Input = %b %d %d %d %d\n", select, test_data_4[0], test_data_4[1], test_data_4[2], test_data_4[3]);
        //$display("%d %d", result_g_4, result_4);
        if(result_g_4 == result_4) begin
            //
        end
        else begin
            //$display("Pattern %3d: Expect= %d Get= %d\n", i + TEST_N_PAT_4_max, result_g_4, result_4);
            err = err + 1;
        end
    end
    if(err != 0) begin
		$display("-------------------There are %3d errors in stage 2!-------------------\n", err);
	end
	else begin
		$display("-------------Stage 2 :              Pass!                 -------------\n");
	end
    total_err_1 = err;
    err = 0;
    $display("-------------Stage 3 : Maximum selection with 8-input MMS-------------\n");
    for (i = 0; i < TEST_N_PAT_8_max; i = i + 1) begin
        #`CYCLE 
        callback = $fscanf(file_data_8, "%b %d %d %d %d %d %d %d %d", select_8, number_8[0], number_8[1], number_8[2], number_8[3], number_8[4], number_8[5], number_8[6], number_8[7]); 
        #`CYCLE 
        callback = $fscanf(file_golden_8, "%d", result_g_8);
        //$display("Input = %b %d %d %d %d\n", select, test_data_4[0], test_data_4[1], test_data_4[2], test_data_4[3]);
        //$display("%d %d", result_g_4, result_4);
        if(result_g_8 == result_8) begin
            //
        end
        else begin
            //$display("Pattern %4d: Expect= %d Get= %d\n", i, result_g_8, result_8);
            err = err + 1;
        end
    end
    if(err != 0) begin
		$display("-------------------There are %4d errors in stage 3!-------------------\n", err);
	end
	else begin
		$display("-------------Stage 3 :              Pass!                 -------------\n");
	end
    total_err_2 = err;
    err = 0;
    $display("-------------Stage 4 : Minimum selection with 8-input MMS-------------\n");
    for (i = 0; i < TEST_N_PAT_8_min; i = i + 1) begin
        #`CYCLE 
        callback = $fscanf(file_data_8, "%b %d %d %d %d %d %d %d %d", select_8, number_8[0], number_8[1], number_8[2], number_8[3], number_8[4], number_8[5], number_8[6], number_8[7]); 
        #`CYCLE 
        callback = $fscanf(file_golden_8, "%d", result_g_8);
        //$display("Input = %b %d %d %d %d\n", select, test_data_4[0], test_data_4[1], test_data_4[2], test_data_4[3]);
        //$display("%d %d", result_g_4, result_4);
        if(result_g_8 == result_8) begin
            //
        end
        else begin
            //$display("Pattern %4d: Expect= %d Get= %d\n", i + TEST_N_PAT_8_max, result_g_8, result_8);
            err = err + 1;
        end
    end
    if(err != 0) begin
		$display("-------------------There are %4d errors in stage 4!-------------------\n", err);
	end
	else begin
		$display("-------------Stage 4 :              Pass!                 -------------\n");
	end
    total_err_3 = err;
    err = 0;
    $display ("-----------------------------------------------------------------------\n");
    if(!total_err_0 && !total_err_1 && !total_err_2 && !total_err_3)
        $display("---------------      Simulation finish,  ALL PASS       ---------------\n");
    else begin
        $display("---------------            Simulation finish            ---------------\n");
        $display("---------------    There are %4d errors in stage 1!    ---------------\n", total_err_0);
        $display("---------------    There are %4d errors in stage 2!    ---------------\n", total_err_1);
        $display("---------------    There are %4d errors in stage 3!    ---------------\n", total_err_2);
        $display("---------------    There are %4d errors in stage 4!    ---------------\n", total_err_3);
    end
    $display ("-------------------------------------------------------------------");
    $fclose(file_data_4); 
    $fclose(file_golden_4); 
    $fclose(file_data_8); 
    $fclose(file_golden_8);   
    #10 $finish;
end


endmodule