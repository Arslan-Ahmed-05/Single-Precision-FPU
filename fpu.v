`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Namal University
// Engineer: Arslan Ahmed
// 
// Create Date:    12:24:17 04/19/2025 
// Design Name: 
// Module Name:    fpu 
// Project Name: Design and Implementation of Single Precision FPU in RIS-V processor
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module fpu (
    input clk,                // Clock input 
    input [31:0] a, b,        // Floating-point inputs
    input [31:0] mem_data_in, // Data from memory (for load instruction)
    input [3:0] opcode,       // Operation selector (expanded to 4 bits to accommodate all operations)
    input load,               // Load control signal
    input store,              // Store control signal
    input [31:0] address,     // Address for load/store operations
    input [4:0] rd,           // Destination register index (0-31)
    input write_enable,       // Write enable signal for registers
    output reg [31:0] result, // Computed result
    output reg [31:0] mem_data_out // Data to store in memory
);

    // Floating-Point Register File
    reg [31:0] f[31:0];  // 32 Floating-point registers f0-f31
    reg [31:0] fcsr;     // Floating-Point Control and Status Register (fcsr)

    wire [31:0] add_sub_result, mul_result, div_result, minmax_result, sqrt_result;
    wire [31:0] cvt_w_result, cvt_s_result;
    wire feq_result, flt_result, fle_result;
    
    // Initialize fcsr and register file (for simulation)
    initial begin
        fcsr = 32'h0;
        f[0] = 32'h0; // Register f0 is hardwired to 0 in RISC-V
    end
    
    // Floating Point Operations
    fp_add_sub adder_subtractor (.a(a), .b(b), .add_sub(opcode[0]), .result(add_sub_result));
    fp_multiply multiplier (.a(a), .b(b), .result(mul_result));
    fp_divide divider (.a(a), .b(b), .result(div_result));
    fp_minmax min_max_unit (.a(a), .b(b), .op(opcode[0]), .result(minmax_result));  // MIN/MAX operation
    fp_sqrt sqrt_unit (.a(a), .result(sqrt_result));  // SQRT operation
    fp_compare compare_unit (.a(a), .b(b), .op(opcode[1:0]), .result_bit(feq_result), .result_lt(flt_result), .result_le(fle_result));
    
    // New Conversion Operations
    fp_to_int fp_to_int_unit (.a(a), .unsigned_flag(opcode[0]), .result(cvt_w_result));  // FCVT.W.S/FCVT.WU.S
    int_to_fp int_to_fp_unit (.a(a), .unsigned_flag(opcode[0]), .result(cvt_s_result));  // FCVT.S.W/FCVT.S.WU

    // Operation Selection
    // Combine operation selection and load logic into one always block
    always @(*) begin
        // Default values
        result = 32'h00000000;
        mem_data_out = 32'h00000000;

        if (load) begin
            if (address[1:0] != 2'b00) 
                fcsr[3] = 1;
            else 
                result = mem_data_in;
        end 
        else if (store) begin
            if (address[1:0] != 2'b00) 
                fcsr[3] = 1;
            else 
                mem_data_out = a;
        end 
        else begin
            case (opcode)
                4'b0000: result = add_sub_result;       // ADD
                4'b0001: result = add_sub_result;       // SUB
                4'b0010: result = mul_result;           // MUL
                4'b0011: result = div_result;           // DIV
                4'b0100: result = minmax_result;          // FMIN.S
                4'b0101: result = minmax_result;          // FMAX.S
                4'b0110: result = sqrt_result;          // FSQRT.S
                4'b1000: result = {31'b0, feq_result};  // FEQ.S
                4'b1001: result = {31'b0, flt_result};  // FLT.S
                4'b1010: result = {31'b0, fle_result};  // FLE.S
                4'b1100: result = cvt_w_result;         // FCVT.W.S
                4'b1101: result = cvt_w_result;         // FCVT.WU.S
                4'b1110: result = cvt_s_result;         // FCVT.S.W
                4'b1111: result = cvt_s_result;         // FCVT.S.WU
                default: result = 32'h00000000;
            endcase
        end
            end
    
    // Register Write Mechanism
    always @(posedge clk) begin
        if (write_enable)
            f[rd] <= result;  // Write result to selected floating-point register
    end

endmodule


// Floating-Point Adder/Subtractor (Unchanged from original)
module fp_add_sub (
    input [31:0] a, b,
    input add_sub,  // 0 for addition, 1 for subtraction
    output reg [31:0] result
);

    wire sign_a = a[31];
    wire sign_b = b[31] ^ add_sub;  // Flip sign for subtraction
    wire [7:0] exp_a = a[30:23], exp_b = b[30:23];
    wire [23:0] mant_a = {1'b1, a[22:0]};  // Implicit leading 1
    wire [23:0] mant_b = {1'b1, b[22:0]};  

    wire exp_greater = (exp_a > exp_b);
    wire [7:0] exp_diff = exp_greater ? (exp_a - exp_b) : (exp_b - exp_a);
    
    wire [23:0] mant_a_shifted = exp_greater ? mant_a : (mant_a >> exp_diff);
    wire [23:0] mant_b_shifted = exp_greater ? (mant_b >> exp_diff) : mant_b;

    wire [23:0] mant_large = exp_greater ? mant_a : mant_b;
    wire [23:0] mant_small = exp_greater ? mant_b_shifted : mant_a_shifted;
    wire [7:0] exp_large = exp_greater ? exp_a : exp_b;
    wire sign_large = exp_greater ? sign_a : sign_b;
    wire sign_small = exp_greater ? sign_b : sign_a;

    wire [24:0] mant_sum = (sign_large == sign_small) ? 
                           (mant_large + mant_small) : 
                           (mant_large - mant_small);

    reg [7:0] exp_norm;
    reg [23:0] mant_norm;
    reg sign_result;
    
    integer shift_count;

    always @(*) begin
        if (mant_sum[24]) begin
            // Overflow occurred, shift right
            exp_norm = exp_large + 1;
            mant_norm = mant_sum[24:1];
        end else begin
            // Normalize by shifting left if necessary
            mant_norm = mant_sum[23:0];
            exp_norm = exp_large;

            shift_count = 0;
            if (mant_norm[23] == 0 && exp_norm > 0) begin
                mant_norm = mant_norm << 1;
                exp_norm = exp_norm - 1;
                shift_count = shift_count + 1;
            end
        end

        // Determine final sign
        if ((sign_large != sign_small) && (mant_large < mant_small)) begin
            sign_result = sign_small;  // Result takes the sign of the larger absolute value
            mant_norm = (~mant_norm + 1);  // Two's complement for negative results
        end else begin
            sign_result = sign_large;
        end

        result = {sign_result, exp_norm, mant_norm[22:0]};
    end
endmodule

// Floating-Point Multiplier (Unchanged from original)
module fp_multiply (
    input [31:0] a, b,
    output reg [31:0] result
);

    wire sign_a = a[31], sign_b = b[31];
    wire [7:0] exp_a = a[30:23], exp_b = b[30:23];
    wire [23:0] mant_a = {1'b1, a[22:0]}, mant_b = {1'b1, b[22:0]};
    
    wire sign_result = sign_a ^ sign_b;
    wire [8:0] exp_result = exp_a + exp_b - 127;
    wire [47:0] mant_result = mant_a * mant_b;

    reg [22:0] mant_norm;
    reg [7:0] exp_norm;

    always @(*) begin
        if (mant_result[47]) begin
            mant_norm = mant_result[46:24];  
            exp_norm = exp_result + 1;
        end else begin
            mant_norm = mant_result[45:23];  
            exp_norm = exp_result;
        end
        result = {sign_result, exp_norm, mant_norm};
    end
endmodule

// Floating-Point Divider (Unchanged from original)
module fp_divide (
    input [31:0] a, b,
    output reg [31:0] result
);

    wire sign_a = a[31], sign_b = b[31];
    wire [7:0] exp_a = a[30:23], exp_b = b[30:23];
    wire [23:0] mant_a = {1'b1, a[22:0]}, mant_b = {1'b1, b[22:0]};
    
    wire sign_result = sign_a ^ sign_b;
    wire [8:0] exp_result = exp_a - exp_b + 127;
    wire [47:0] mant_result = (mant_a << 23) / mant_b;

    reg [22:0] mant_norm;
    reg [7:0] exp_norm;

    always @(*) begin
        mant_norm = mant_result[22:0];
        exp_norm = exp_result;
        result = (b == 32'h00000000) ? 32'h7fc00000 : {sign_result, exp_norm, mant_norm};
    end
endmodule

// Floating-Point Minimum and Maximum (FMIN.S, FMAX.S) - Simplified implementation
module fp_minmax (
    input [31:0] a, b,
    input op,  // 0 for FMIN, 1 for FMAX
    output reg [31:0] result
);

    // Function to check if value is NaN
    function is_nan;
        input [31:0] x;
        begin
            is_nan = (x[30:23] == 8'hFF) && (x[22:0] != 0);
        end
    endfunction
    
    // Function to check if value is zero
    function is_zero;
        input [31:0] x;
        begin
            is_zero = (x[30:23] == 0) && (x[22:0] == 0);
        end
    endfunction
    
    // Determine which value is "greater" in floating-point terms
    function a_greater_than_b;
        input [31:0] a, b;
        reg a_neg, b_neg;
        begin
            // Special case for zeros (treat -0 and +0 as equal)
            if (is_zero(a) && is_zero(b))
                a_greater_than_b = 0; // Neither is greater
            else begin
                a_neg = a[31] && !is_zero(a);
                b_neg = b[31] && !is_zero(b);
                
                if (a_neg != b_neg)
                    a_greater_than_b = !a_neg; // Positive > Negative
                else if (a_neg) // Both negative
                    a_greater_than_b = (a[30:0] < b[30:0]); // Smaller exponent/mantissa = greater value
                else // Both positive
                    a_greater_than_b = (a[30:0] > b[30:0]); // Larger exponent/mantissa = greater value
            end
        end
    endfunction

    always @(*) begin
        if (is_nan(a) && is_nan(b))
            result = 32'h7FC00000; // Canonical NaN
        else if (is_nan(a))
            result = b;
        else if (is_nan(b))
            result = a;
        else begin
            // For FMIN (op=0): return the smaller value
            // For FMAX (op=1): return the larger value
            if (op == 1) // FMAX
                result = a_greater_than_b(a, b) ? a : b;
            else // FMIN
                result = a_greater_than_b(a, b) ? b : a;
        end
    end
endmodule

// Floating-Point Square Root (FSQRT.S)
module fp_sqrt (
    input [31:0] a,
    output reg [31:0] result
);
    // Extract components
    wire sign_a = a[31];
    wire [7:0] exp_a = a[30:23];
    wire [22:0] frac_a = a[22:0];
    
    // Square root specific variables
    reg [7:0] exp_result;
    reg [22:0] frac_result;
    reg [24:0] operand;  // For normalized mantissa with guard bits
    reg [24:0] root;     // The computed square root value
    reg [24:0] remainder;
    reg [24:0] temp;
    integer i;
    
    // Handle special cases
    wire is_zero = (exp_a == 0) && (frac_a == 0);
    wire is_inf = (exp_a == 8'hFF) && (frac_a == 0);
    wire is_nan = (exp_a == 8'hFF) && (frac_a != 0);
    wire is_neg = sign_a && !is_zero;  // Negative and not zero
    
    always @(*) begin
        // Special cases handling
        if (is_zero) begin
            // Square root of zero is zero
            result = a;  // Preserve sign of zero
        end else if (is_inf && !sign_a) begin
            // Square root of +infinity is +infinity
            result = a;
        end else if (is_nan || is_neg || (is_inf && sign_a)) begin
            // Square root of NaN, negative number, or -infinity is NaN
            result = 32'h7FC00000;  // canonical NaN
        end else begin
            // Normal computation for positive finite numbers
            
            // Prepare the operand - normalize the mantissa
            operand = {1'b1, frac_a, 1'b0};  // Include implicit 1 and guard bit
            
            // Adjust exponent
            if (exp_a[0]) begin  // Odd exponent
                operand = {operand[23:0], 1'b0};  // Left shift by 1 for normalization
            end
            
            // Final exponent is half of the original (minus bias adjustment)
            exp_result = ((exp_a - 127) >> 1) + 127;
            
            // Non-restoring square root algorithm
            root = 0;
            remainder = 0;
            
            for (i = 0; i < 24; i = i + 1) begin
                remainder = {remainder[22:0], operand[24-i], operand[23-i]};
                temp = {root, 1'b1};
                
                if (remainder >= temp) begin
                    remainder = remainder - temp;
                    root = {root[22:0], 1'b1};
                end else begin
                    root = {root[22:0], 1'b0};
                end
            end
            
            // Round the result (simplified round-to-nearest)
            if (remainder > 0) begin
                root = root + 1;  // Round up if there's a remainder
            end
            
            // Normalize the result if needed
            if (root[23]) begin
                frac_result = root[22:0];
            end else begin
                frac_result = root[21:0];  // Shift left if leading bit is zero
                exp_result = exp_result - 1;
            end
            
            // Assemble the final result
            result = {1'b0, exp_result, frac_result};
        end
    end
endmodule

// Floating-Point Compare (FEQ.S, FLT.S, FLE.S)
module fp_compare (
    input [31:0] a, b,
    input [1:0] op,  // 00: FEQ, 01: FLT, 10: FLE
    output reg result_bit, // General result bit
    output reg result_lt,  // Less than result
    output reg result_le   // Less than or equal result
);
    // Check for NaN values
    function is_nan;
        input [31:0] x;
        begin
            is_nan = (x[30:23] == 8'hFF) && (x[22:0] != 0);
        end
    endfunction
    
    // Check for equality
    wire equal = (a == b) || (is_zero(a) && is_zero(b));  // Consider both +0 and -0 as equal
    
    // Check for zero value
    function is_zero;
        input [31:0] x;
        begin
            is_zero = (x[30:23] == 0) && (x[22:0] == 0);  // Exponent and fraction are zero
        end
    endfunction
    
    // Less than comparison logic
    wire a_negative = a[31] && !(is_zero(a));  // Negative and not zero
    wire b_negative = b[31] && !(is_zero(b));  // Negative and not zero
    
    wire less_than = (a_negative && !b_negative) ||                                   // a negative, b positive
                    (a_negative && b_negative && (a[30:0] > b[30:0])) ||              // both negative, |a| > |b|
                    (!a_negative && !b_negative && (a[30:0] < b[30:0]));              // both positive, a < b
    
    always @(*) begin
        if (is_nan(a) || is_nan(b)) begin
            // NaN values make all comparisons return false
            result_bit = 0;
            result_lt = 0;
            result_le = 0;
        end else begin
            // Equal comparison
            result_bit = equal;
            
            // Less than comparison
            result_lt = less_than;
            
            // Less than or equal comparison
            result_le = equal || less_than;
        end
    end
endmodule

// Floating-Point to Integer Conversion Module (FCVT.W.S, FCVT.WU.S)
module fp_to_int (
    input [31:0] a,           // Floating-point input
    input unsigned_flag,      // 0 for signed (FCVT.W.S), 1 for unsigned (FCVT.WU.S)
    output reg [31:0] result  // Integer result
);
    // Extract components
    wire sign_a = a[31];
    wire [7:0] exp_a = a[30:23];
    wire [22:0] frac_a = a[22:0];
    wire [23:0] mant_a = {1'b1, frac_a}; // Implicit leading 1
    
    // Special cases
    wire is_zero = (exp_a == 0) && (frac_a == 0);
    wire is_inf = (exp_a == 8'hFF) && (frac_a == 0);
    wire is_nan = (exp_a == 8'hFF) && (frac_a != 0);
    
    // Variables for conversion
    reg [31:0] int_value;
    reg [7:0] shift_amount;
    
    always @(*) begin
        // Handle special cases
        if (is_zero) begin
            result = 32'h00000000;  // Zero maps to zero
        end 
        else if (is_nan || is_inf) begin
            if (unsigned_flag) begin
                result = (sign_a && !is_nan) ? 32'h00000000 : 32'hFFFFFFFF;  // -Inf -> 0, +Inf/NaN -> max unsigned
            end else begin
                result = (sign_a && !is_nan) ? 32'h80000000 : 32'h7FFFFFFF;  // -Inf -> min signed, +Inf/NaN -> max signed
            end
        end
        else begin
            // Calculate unbiased exponent
            shift_amount = exp_a - 127;
            
            if (shift_amount > 31) begin
                // Overflow cases
                if (unsigned_flag) begin
                    result = (sign_a) ? 32'h00000000 : 32'hFFFFFFFF;  // Negative -> 0, Positive -> max unsigned
                end else begin
                    result = (sign_a) ? 32'h80000000 : 32'h7FFFFFFF;  // Negative -> min signed, Positive -> max signed
                end
            end
            else if (shift_amount < 0) begin
                // Fractional numbers between -1 and 1
                result = 32'h00000000;  // Truncate to zero
            end
            else begin
                // Normal conversion
                if (shift_amount <= 23) begin
                    // Shift mantissa according to exponent value
                    int_value = mant_a >> (23 - shift_amount);
                end else begin
                    // Need to shift left for large exponents
                    int_value = mant_a << (shift_amount - 23);
                end
                
                // Handle sign for signed integers
                if (sign_a) begin
                    if (unsigned_flag)
                        result = 32'h00000000;  // Negative float to unsigned int is 0
                    else
                        result = (~int_value + 1);  // Two's complement for negative
                end else begin
                    result = int_value;  // Positive value stays the same
                end
            end
        end
    end
endmodule

// Integer to Floating-Point Conversion Module (FCVT.S.W, FCVT.S.WU)
module int_to_fp (
    input [31:0] a,           // Integer input
    input unsigned_flag,      // 0 for signed (FCVT.S.W), 1 for unsigned (FCVT.S.WU)
    output reg [31:0] result  // Floating-point result (IEEE-754 format)
);
    // Extract components
    wire sign_a = a[31] & ~unsigned_flag;  // Sign bit is 0 for unsigned conversion
    
    // Special case for zero
    wire is_zero = (a == 32'h00000000);
    
    // Variables for conversion
    reg [31:0] abs_value;
    reg [7:0] exponent;
    reg [22:0] mantissa;
    reg [5:0] leading_zeros;
    integer i;
    
    // Function to count leading zeros - synthesizable method without break
    function [5:0] count_leading_zeros;
        input [31:0] value;
        reg found_one;
        begin
            count_leading_zeros = 0;
            found_one = 0;
            
            for (i = 31; i >= 0; i = i - 1) begin
                if (!found_one) begin
                    if (value[i] == 1'b1)
                        found_one = 1;
                    else
                        count_leading_zeros = count_leading_zeros + 1;
                end
            end
        end
    endfunction
    
    always @(*) begin
        // Handle special case - zero
        if (is_zero) begin
            result = 32'h00000000;  // Zero in floating-point
        end else begin
            // Take absolute value for signed numbers
            if (sign_a) begin
                abs_value = (~a + 1);  // Two's complement to get absolute value
            end else begin
                abs_value = a;
            end
            
            // Count leading zeros to normalize using our function
            leading_zeros = count_leading_zeros(abs_value);
            
            // Calculate exponent (bias 127)
            exponent = 8'd127 + 8'd31 - leading_zeros;
            
            // Extract mantissa (normalized, implicit leading 1)
            if (leading_zeros == 0) begin
                // Handle the case where the MSB is already set
                mantissa = abs_value[30:8];
            end else begin
                // Shift left to normalize
                mantissa = (abs_value << leading_zeros) >> 8;
            end
            
            // Assemble IEEE-754 single precision format
            result = {sign_a, exponent, mantissa};
        end
    end
endmodule
