`timescale 1ns / 1ps

module fpu_tb;

    // Testbench signals
    reg clk;
    reg [31:0] a, b;
    reg [31:0] mem_data_in;
    reg [3:0] opcode;
    reg load;
    reg store;
    reg [31:0] address;
    reg [4:0] rd;
    reg write_enable;
    wire [31:0] result;
    wire [31:0] mem_data_out;
    
    // Additional signals for wave analysis
    reg [127:0] test_name;
    reg [31:0] expected_result;
    reg [7:0] test_counter;

    // Instantiate the FPU
    fpu uut (
        .clk(clk),
        .a(a),
        .b(b),
        .mem_data_in(mem_data_in),
        .opcode(opcode),
        .load(load),
        .store(store),
        .address(address),
        .rd(rd),
        .write_enable(write_enable),
        .result(result),
        .mem_data_out(mem_data_out)
    );

    // Clock generation - slower for better wave visualization
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50MHz clock (20ns period)
    end

    // Test values in IEEE-754 32-bit format
    parameter FLOAT_2_759    = 32'h40307AE1;  // 2.759
    parameter FLOAT_NEG3_875 = 32'hC0780000;  // -3.875
    parameter FLOAT_0_000663 = 32'h3A2E147B;  // 0.000663
    parameter FLOAT_10_2283  = 32'h4123A3D7;  // 10.2283
    
    // Operation codes for easy identification in wave
    parameter OP_ADD     = 4'b0000;
    parameter OP_SUB     = 4'b0001;
    parameter OP_MUL     = 4'b0010;
    parameter OP_DIV     = 4'b0011;
    parameter OP_MIN     = 4'b0100;
    parameter OP_MAX     = 4'b0101;
    parameter OP_SQRT    = 4'b0110;
    parameter OP_FEQ     = 4'b1000;
    parameter OP_FLT     = 4'b1001;
    parameter OP_FLE     = 4'b1010;
    parameter OP_CVT_WS  = 4'b1100;
    parameter OP_CVT_WUS = 4'b1101;
    parameter OP_CVT_SW  = 4'b1110;
    parameter OP_CVT_SWU = 4'b1111;

    // Main test sequence
    initial begin
        // Initialize all signals
        initialize_signals();
        
        // Wait for reset
        #50;
        
        $display("=== FPU ModelSim Testbench Started ===");
        $display("Clock Period: 20ns (50MHz)");
        $display("Test Values:");
        $display("  2.759    = 0x%08h", FLOAT_2_759);
        $display("  -3.875   = 0x%08h", FLOAT_NEG3_875);
        $display("  0.000663 = 0x%08h", FLOAT_0_000663);
        $display("  10.2283  = 0x%08h", FLOAT_10_2283);
        
        // Run test sequences with proper timing for wave analysis
        test_arithmetic_operations();
        test_comparison_operations();
        test_conversion_operations();
        test_memory_operations();
        test_register_operations();
        
        // Hold final state for wave analysis
        #200;
        $display("=== Testbench Completed - Check Wave Window ===");
        $stop; // Use $stop instead of $finish for ModelSim interaction
    end

    // Initialize all signals
    task initialize_signals;
        begin
            a = 32'h00000000;
            b = 32'h00000000;
            mem_data_in = 32'h00000000;
            opcode = 4'b0000;
            load = 1'b0;
            store = 1'b0;
            address = 32'h00000000;
            rd = 5'b00000;
            write_enable = 1'b0;
            test_name = "INIT";
            expected_result = 32'h00000000;
            test_counter = 8'h00;
        end
    endtask

    // Test arithmetic operations
    task test_arithmetic_operations;
        begin
            $display("\n=== Testing Arithmetic Operations ===");
            
            // Test 1: Addition 2.759 + (-3.875) = -1.116
            execute_test("ADD_2759_NEG3875", FLOAT_2_759, FLOAT_NEG3_875, OP_ADD, 32'hBF8F5C29);
            
            // Test 2: Addition 0.000663 + 10.2283 = 10.228963
            execute_test("ADD_0663_10283", FLOAT_0_000663, FLOAT_10_2283, OP_ADD, 32'h4123A7BB);
            
            // Test 3: Subtraction 2.759 - (-3.875) = 6.634
            execute_test("SUB_2759_NEG3875", FLOAT_2_759, FLOAT_NEG3_875, OP_SUB, 32'h40D47AE1);
            
            // Test 4: Subtraction 10.2283 - 0.000663 = 10.227637
            execute_test("SUB_10283_0663", FLOAT_10_2283, FLOAT_0_000663, OP_SUB, 32'h41239F45);
            
            // Test 5: Multiplication 2.759 * (-3.875) = -10.691
            execute_test("MUL_2759_NEG3875", FLOAT_2_759, FLOAT_NEG3_875, OP_MUL, 32'hC12B1EB8);
            
            // Test 6: Multiplication 0.000663 * 10.2283 = 0.0067813
            execute_test("MUL_0663_10283", FLOAT_0_000663, FLOAT_10_2283, OP_MUL, 32'h3BDDF3B6);
            
            // Test 7: Division 2.759 / (-3.875) = -0.712
            execute_test("DIV_2759_NEG3875", FLOAT_2_759, FLOAT_NEG3_875, OP_DIV, 32'hBF36872B);
            
            // Test 8: Division 10.2283 / 0.000663 = 15428.67
            execute_test("DIV_10283_0663", FLOAT_10_2283, FLOAT_0_000663, OP_DIV, 32'h46F0D057);
        end
    endtask

    // Test comparison operations
    task test_comparison_operations;
        begin
            $display("\n=== Testing Comparison Operations ===");
            
            // Test MIN/MAX operations
            execute_test("MIN_2759_NEG3875", FLOAT_2_759, FLOAT_NEG3_875, OP_MIN, FLOAT_NEG3_875);
            execute_test("MAX_2759_NEG3875", FLOAT_2_759, FLOAT_NEG3_875, OP_MAX, FLOAT_2_759);
            execute_test("MIN_0663_10283", FLOAT_0_000663, FLOAT_10_2283, OP_MIN, FLOAT_0_000663);
            execute_test("MAX_0663_10283", FLOAT_0_000663, FLOAT_10_2283, OP_MAX, FLOAT_10_2283);
            
            // Test SQRT operations (single operand)
            execute_sqrt_test("SQRT_2759", FLOAT_2_759, 32'h3FD4B5DC); // ~1.661
            execute_sqrt_test("SQRT_10283", FLOAT_10_2283, 32'h404095F6); // ~3.198
            execute_sqrt_test("SQRT_0663", FLOAT_0_000663, 32'h3D07F7A1); // ~0.0257
            
            // Test equality comparisons
            execute_test("FEQ_2759_2759", FLOAT_2_759, FLOAT_2_759, OP_FEQ, 32'h00000001);
            execute_test("FEQ_2759_NEG3875", FLOAT_2_759, FLOAT_NEG3_875, OP_FEQ, 32'h00000000);
            
            // Test less than comparisons
            execute_test("FLT_NEG3875_2759", FLOAT_NEG3_875, FLOAT_2_759, OP_FLT, 32'h00000001);
            execute_test("FLT_0663_10283", FLOAT_0_000663, FLOAT_10_2283, OP_FLT, 32'h00000001);
            
            // Test less than or equal comparisons
            execute_test("FLE_2759_10283", FLOAT_2_759, FLOAT_10_2283, OP_FLE, 32'h00000001);
            execute_test("FLE_10283_2759", FLOAT_10_2283, FLOAT_2_759, OP_FLE, 32'h00000000);
        end
    endtask

    // Test conversion operations
    task test_conversion_operations;
        begin
            $display("\n=== Testing Conversion Operations ===");
            
            // Float to signed integer
            execute_test("CVT_WS_2759", FLOAT_2_759, 32'h00000000, OP_CVT_WS, 32'h00000002); // 2.759 -> 2
            execute_test("CVT_WS_NEG3875", FLOAT_NEG3_875, 32'h00000000, OP_CVT_WS, 32'hFFFFFFFC); // -3.875 -> -4
            execute_test("CVT_WS_10283", FLOAT_10_2283, 32'h00000000, OP_CVT_WS, 32'h0000000A); // 10.2283 -> 10
            
            // Float to unsigned integer
            execute_test("CVT_WUS_2759", FLOAT_2_759, 32'h00000000, OP_CVT_WUS, 32'h00000002); // 2.759 -> 2
            execute_test("CVT_WUS_10283", FLOAT_10_2283, 32'h00000000, OP_CVT_WUS, 32'h0000000A); // 10.2283 -> 10
            execute_test("CVT_WUS_NEG3875", FLOAT_NEG3_875, 32'h00000000, OP_CVT_WUS, 32'h00000000); // -3.875 -> 0
            
            // Signed integer to float
            execute_test("CVT_SW_3", 32'h00000003, 32'h00000000, OP_CVT_SW, 32'h40400000); // 3 -> 3.0
            execute_test("CVT_SW_NEG5", 32'hFFFFFFFB, 32'h00000000, OP_CVT_SW, 32'hC0A00000); // -5 -> -5.0
            
            // Unsigned integer to float
            execute_test("CVT_SWU_10", 32'h0000000A, 32'h00000000, OP_CVT_SWU, 32'h41200000); // 10 -> 10.0
            execute_test("CVT_SWU_255", 32'h000000FF, 32'h00000000, OP_CVT_SWU, 32'h437F0000); // 255 -> 255.0
        end
    endtask

    // Test memory operations
    task test_memory_operations;
        begin
            $display("\n=== Testing Memory Operations ===");
            
            test_name = "LOAD_ALIGNED";
            test_counter = test_counter + 1;
            mem_data_in = FLOAT_2_759;
            address = 32'h00001000; // Aligned address
            load = 1'b1;
            store = 1'b0;
            opcode = 4'b0000;
            #40; // Wait for result
            load = 1'b0;
            #20;
            
            test_name = "LOAD_MISALIGNED";
            test_counter = test_counter + 1;
            mem_data_in = FLOAT_NEG3_875;
            address = 32'h00001001; // Misaligned address
            load = 1'b1;
            #40;
            load = 1'b0;
            #20;
            
            test_name = "STORE_ALIGNED";
            test_counter = test_counter + 1;
            a = FLOAT_10_2283;
            address = 32'h00002000; // Aligned address
            store = 1'b1;
            load = 1'b0;
            #40;
            store = 1'b0;
            #20;
            
            test_name = "STORE_MISALIGNED";
            test_counter = test_counter + 1;
            a = FLOAT_0_000663;
            address = 32'h00002003; // Misaligned address
            store = 1'b1;
            #40;
            store = 1'b0;
            #20;
        end
    endtask

    // Test register write operations
    task test_register_operations;
        begin
            $display("\n=== Testing Register Operations ===");
            
            test_name = "REG_WRITE_F5";
            test_counter = test_counter + 1;
            a = FLOAT_2_759;
            b = FLOAT_0_000663;
            opcode = OP_ADD;
            rd = 5'd5;
            write_enable = 1'b1;
            load = 1'b0;
            store = 1'b0;
            #20; // Wait for combinational logic
            @(posedge clk); // Wait for register write
            #20;
            write_enable = 1'b0;
            
            test_name = "REG_WRITE_F15";
            test_counter = test_counter + 1;
            a = FLOAT_10_2283;
            b = FLOAT_NEG3_875;
            opcode = OP_MUL;
            rd = 5'd15;
            write_enable = 1'b1;
            #20;
            @(posedge clk);
            #20;
            write_enable = 1'b0;
            
            test_name = "REG_WRITE_F31";
            test_counter = test_counter + 1;
            a = FLOAT_2_759;
            opcode = OP_SQRT;
            rd = 5'd31;
            write_enable = 1'b1;
            #20;
            @(posedge clk);
            #20;
            write_enable = 1'b0;
        end
    endtask

    // Execute a standard test with two operands
    task execute_test;
        input [127:0] name;
        input [31:0] operand_a;
        input [31:0] operand_b;
        input [3:0] operation;
        input [31:0] expected;
        begin
            test_name = name;
            test_counter = test_counter + 1;
            expected_result = expected;
            
            a = operand_a;
            b = operand_b;
            opcode = operation;
            load = 1'b0;
            store = 1'b0;
            write_enable = 1'b0;
            
            #40; // Wait for combinational logic to settle
            
            $display("Test %0d: %s", test_counter, name);
            $display("  Input A: 0x%08h, Input B: 0x%08h", operand_a, operand_b);
            $display("  Result:  0x%08h, Expected: 0x%08h", result, expected);
            if (result == expected)
                $display("  PASS");
            else
                $display("  FAIL - Mismatch detected");
                
            #20; // Hold for wave analysis
        end
    endtask

    // Execute square root test (single operand)
    task execute_sqrt_test;
        input [127:0] name;
        input [31:0] operand_a;
        input [31:0] expected;
        begin
            test_name = name;
            test_counter = test_counter + 1;
            expected_result = expected;
            
            a = operand_a;
            b = 32'h00000000;
            opcode = OP_SQRT;
            load = 1'b0;
            store = 1'b0;
            write_enable = 1'b0;
            
            #40;
            
            $display("Test %0d: %s", test_counter, name);
            $display("  Input A: 0x%08h", operand_a);
            $display("  Result:  0x%08h, Expected: 0x%08h", result, expected);
            
            #20;
        end
    endtask

endmodule