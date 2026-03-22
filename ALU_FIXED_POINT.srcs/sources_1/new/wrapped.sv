`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module wrapped #(
    parameter int N    = 16,
    parameter int F    = 4,
    parameter int PIPE = 2
)(
    input  logic        clk,

    // board inputs
    input  logic        btn_rst_raw,
    input  logic        btn_mode_raw,
    input  logic        btn_next_raw,
    input  logic [1:0]  sw,

    // board outputs
    output logic [3:0]  led
);

    // =========================================================
    // Reset from button (active-high button → active-low rst_n)
    // =========================================================
    logic rst_n;
    assign rst_n = ~btn_rst_raw;

    // =========================================================
    // Button pulse (no rst button pulse needed)
    // =========================================================
    logic btn_mode, btn_next;

    btn_pulse u_btn_mode (
        .clk     (clk),
        .rst_n   (rst_n),
        .btn_raw (btn_mode_raw),
        .pulse   (btn_mode)
    );

    btn_pulse u_btn_next (
        .clk     (clk),
        .rst_n   (rst_n),
        .btn_raw (btn_next_raw),
        .pulse   (btn_next)
    );

    // =========================================================
    // FSM
    // =========================================================
    typedef enum logic [1:0] {
        ST_OPCODE = 2'd0,
        ST_A      = 2'd1,
        ST_B      = 2'd2,
        ST_CALC   = 2'd3
    } state_t;

    state_t state, state_n;

    // =========================================================
    // Input registers (8-bit only)
    // =========================================================
    logic signed [7:0] A_in, B_in;
    logic        [3:0] op_reg;

    logic signed [N-1:0] A_reg, B_reg;
    assign A_reg = {{(N-8){A_in[7]}}, A_in} << F;
    assign B_reg = {{(N-8){B_in[7]}}, B_in} << F;

    // =========================================================
    // ALU control & result
    // =========================================================
    logic en;

    logic signed [N-1:0] alu_y;
    logic alu_ovf, alu_z, alu_n;

    alu_fixed_point #(
        .N(N), .F(F), .PIPE(PIPE)
    ) u_alu (
        .clk   (clk),
        .rst_n (rst_n),
        .en    (en),
        .a     (A_reg),
        .b     (B_reg),
        .op    (op_reg),
        .y     (alu_y),
        .ovf   (alu_ovf),
        .z     (alu_z),
        .n     (alu_n)
    );

    // =========================================================
    // FSM state register
    // =========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= ST_OPCODE;
        else if (btn_mode)
            state <= state_n;
    end

    always_comb begin
        state_n = state;
        case (state)
            ST_OPCODE: state_n = ST_A;
            ST_A:      state_n = ST_B;
            ST_B:      state_n = ST_CALC;
            ST_CALC:   state_n = ST_OPCODE;
            default:   state_n = ST_OPCODE;
        endcase
    end

    // =========================================================
    // Input shifting logic
    // =========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            op_reg <= 4'd0;
            A_in   <= 8'd0;
            B_in   <= 8'd0;
        end
        else if (btn_next) begin
            case (state)
                ST_OPCODE: op_reg <= {op_reg[1:0], sw};   // 2 x next = 4 bit
                ST_A:      A_in   <= {A_in[5:0], sw};     // 4 x next = 8 bit
                ST_B:      B_in   <= {B_in[5:0], sw};
                default: ;
            endcase
        end
    end

    // =========================================================
    // ALU enable & valid handling
    // =========================================================
    logic [$clog2(PIPE+1)-1:0] wait_cnt;
    logic        result_valid;
    logic [15:0] y_hold;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en           <= 1'b0;
            wait_cnt     <= '0;
            result_valid <= 1'b0;
            y_hold       <= 16'd0;
        end
        else begin
            en <= 1'b0;

            // Reset result_valid when changing state
            if (btn_mode) begin
                result_valid <= 1'b0;
            end

            // Start ALU when entering CALC (transition from ST_B to ST_CALC)
            if (state == ST_B && btn_mode) begin
                en       <= 1'b1;
                wait_cnt <= PIPE;
            end
            // Count down wait counter
            else if (wait_cnt != 0) begin
                wait_cnt <= wait_cnt - 1'b1;
                if (wait_cnt == 1) begin
                    result_valid <= 1'b1;
                    y_hold       <= alu_y[15:0];
                end
            end
        end
    end

    // =========================================================
    // Output paging - SIMPLIFIED (no next_pending)
    // =========================================================
    logic [2:0] out_page;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            out_page <= 3'd0;
        else if (state != ST_CALC)
            out_page <= 3'd0;                          // Reset when not in CALC
        else if (btn_next && result_valid)             // Only increment when result is ready
            out_page <= (out_page == 3'd4) ? 3'd0 : out_page + 1'b1;
    end

    // =========================================================
    // LED output mux
    // =========================================================
    always_comb begin
        if (state != ST_CALC) begin
            led = 4'b0000;                             // Off when not in CALC
        end
        else if (!result_valid) begin
            led = 4'b0000;                             // Off when result not ready
        end
        else begin
            case (out_page)
                3'd0: led = {result_valid, alu_ovf, alu_z, alu_n}; // FLAGS
                3'd1: led = y_hold[15:12];             // MSB
                3'd2: led = y_hold[11:8];
                3'd3: led = y_hold[7:4];
                3'd4: led = y_hold[3:0];               // LSB
                default: led = 4'b0000;
            endcase
        end
    end

endmodule