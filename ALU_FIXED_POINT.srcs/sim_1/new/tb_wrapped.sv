`timescale 1ns / 1ps

module tb_wrapped;

    // =========================================================
    // Clock 125 MHz (8 ns period)
    // =========================================================
    logic clk;
    initial clk = 0;
    always #4 clk = ~clk;

    // =========================================================
    // Inputs (giống board)
    // =========================================================
    logic btn_rst_raw;
    logic btn_mode_raw;
    logic btn_next_raw;
    logic [1:0] sw;

    // =========================================================
    // Outputs
    // =========================================================
    logic [3:0] led;

    // =========================================================
    // DUT
    // =========================================================
    wrapped #(
        .N(16),
        .F(4),
        .PIPE(2)
    ) dut (
        .clk          (clk),
        .btn_rst_raw  (btn_rst_raw),
        .btn_mode_raw (btn_mode_raw),
        .btn_next_raw (btn_next_raw),
        .sw           (sw),
        .led          (led)
    );

    // =========================================================
    // TASKS (mô phỏng nút bấm)
    // =========================================================
    task pulse_next;
        begin
            btn_next_raw = 1'b1; #200;
            btn_next_raw = 1'b0; #200;
        end
    endtask

    task pulse_mode;
        begin
            btn_mode_raw = 1'b1; #200;
            btn_mode_raw = 1'b0; #200;
        end
    endtask

    task input_nibble(input [3:0] val);
        begin
            sw = val[3:2]; pulse_next();
            sw = val[1:0]; pulse_next();
        end
    endtask

    task input_byte(input [7:0] val);
        begin
            sw = val[7:6]; pulse_next();
            sw = val[5:4]; pulse_next();
            sw = val[3:2]; pulse_next();
            sw = val[1:0]; pulse_next();
        end
    endtask

    task show_result;
        begin
            pulse_next(); // nibble 1
            pulse_next(); // nibble 2
            pulse_next(); // nibble 3
            pulse_next(); // nibble 4
        end
    endtask

    // =========================================================
    // TEST SEQUENCE
    // =========================================================
    initial begin
        // ---------------- RESET (BTN0) ----------------
        btn_rst_raw  = 1'b1;   // nhấn reset
        btn_mode_raw = 0;
        btn_next_raw = 0;
        sw = 0;
        #200;
        btn_rst_raw = 1'b0;    // nhả reset

        // =====================================================
        // TEST 1: ADD 5 + 3 = 8
        // =====================================================
        $display("=== TEST 1: ADD 5 + 3 ===");
        input_nibble(4'd0);
        pulse_mode();

        input_byte(8'd5);
        pulse_mode();

        input_byte(8'd3);
        pulse_mode();   // vào CALC

        #300;
        show_result();
        pulse_mode();

        // =====================================================
        // TEST 2: SUB 7 - 2 = 5
        // =====================================================
        $display("=== TEST 2: SUB 7 - 2 ===");
        input_nibble(4'd1);
        pulse_mode();

        input_byte(8'd7);
        pulse_mode();

        input_byte(8'd2);
        pulse_mode();

        #300;
        show_result();
        pulse_mode();

        // =====================================================
        // TEST 3: MUL 4 * 6 = 24
        // =====================================================
        $display("=== TEST 3: MUL 4 * 6 ===");
        input_nibble(4'd2);
        pulse_mode();

        input_byte(8'd4);
        pulse_mode();

        input_byte(8'd6);
        pulse_mode();

        #400;
        show_result();
        pulse_mode();

        // =====================================================
        // TEST 4: ADD -3 + 2 = -1
        // =====================================================
        $display("=== TEST 4: ADD -3 + 2 ===");
        input_nibble(4'd0);
        pulse_mode();

        input_byte(8'hFD);   // -3
        pulse_mode();

        input_byte(8'd2);
        pulse_mode();

        #300;
        show_result();
        pulse_mode();
        // =====================================================
        // TEST 4: DIV 24 / 6 = 4
        // =====================================================
        $display("=== TEST 4: DIV 24 / 6 ===");
        input_nibble(4'd3); pulse_mode();
        input_byte(8'd24);  pulse_mode();
        input_byte(8'd6);   pulse_mode();

        // DIV cần chờ lâu
        #4000;
        show_result();
        pulse_mode();

        // =====================================================
        // TEST 5: DIV by zero (OVF)
        // =====================================================
        $display("=== TEST 5: DIV 5 / 0 (OVF) ===");
        input_nibble(4'd3); pulse_mode();
        input_byte(8'd5);   pulse_mode();
        input_byte(8'd0);   pulse_mode();
        #4000;
        show_result();
        pulse_mode();
        
        // =====================================================
// TEST 6: SUB so sánh A == B
// =====================================================
$display("=== TEST 6: CMP EQ (5 == 5) ===");
input_nibble(4'd1); pulse_mode();   // SUB
input_byte(8'd5);   pulse_mode();
input_byte(8'd5);   pulse_mode();
#500;
show_result();       // z = 1
pulse_mode();

// =====================================================
// TEST 7: CMP A > B
// =====================================================
$display("=== TEST 7: CMP GT (7 > 3) ===");
input_nibble(4'd1); pulse_mode();
input_byte(8'd7);   pulse_mode();
input_byte(8'd3);   pulse_mode();
#500;
show_result();       // n = 0, z = 0
pulse_mode();

// =====================================================
// TEST 8: CMP A < B
// =====================================================
$display("=== TEST 8: CMP LT (2 < 5) ===");
input_nibble(4'd1); pulse_mode();
input_byte(8'd2);   pulse_mode();
input_byte(8'd5);   pulse_mode();
#500;
show_result();       // n = 1
pulse_mode();

// =====================================================
// TEST 9: ZERO test (ADD 0 + 0)
// =====================================================
$display("=== TEST 9: ZERO (0 + 0) ===");
input_nibble(4'd0); pulse_mode();
input_byte(8'd0);   pulse_mode();
input_byte(8'd0);   pulse_mode();
#500;
show_result();       // z = 1
pulse_mode();

// =====================================================
// TEST 10: NEGATIVE result (-3 + 1 = -2)
// =====================================================
$display("=== TEST 10: NEGATIVE (-3 + 1) ===");
input_nibble(4'd0); pulse_mode();
input_byte(8'hFD);  pulse_mode();   // -3
input_byte(8'd1);   pulse_mode();
#500;
show_result();       // n = 1
pulse_mode();

// =====================================================
// TEST 11: ADD OVERFLOW
// =====================================================
$display("=== TEST 11: ADD OVF ===");
input_nibble(4'd0); pulse_mode();
input_byte(8'h7F);  pulse_mode();   // max +
input_byte(8'h7F);  pulse_mode();
#500;
show_result();       // ovf = 1
pulse_mode();

// =====================================================
// TEST 12: MUL OVERFLOW
// =====================================================
$display("=== TEST 12: MUL OVF ===");
input_nibble(4'd2); pulse_mode();
input_byte(8'h40);  pulse_mode();
input_byte(8'h40);  pulse_mode();
#800;
show_result();       // ovf = 1
pulse_mode();


        // =====================================================
        $display("=== END ALL TESTS ===");
        #500;
        $stop;
    end

endmodule
