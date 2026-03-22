`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/03/2026 09:20:57 PM
// Design Name: 
// Module Name: btn_pulse
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module btn_pulse #(
    parameter int CNT_MAX = 10   // ~8ms với clk 100MHz
)(
    input  logic clk,
    input  logic rst_n,
    input  logic btn_raw,   // nút bấm thô từ board
    output logic pulse      // xung 1 clock
);

    // =========================================================
    // Synchronizer (2 FF)
    // =========================================================
    logic btn_sync1, btn_sync2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync1 <= 1'b0;
            btn_sync2 <= 1'b0;
        end else begin
            btn_sync1 <= btn_raw;
            btn_sync2 <= btn_sync1;
        end
    end

    // =========================================================
    // Debounce counter
    // =========================================================
    logic [$clog2(CNT_MAX+1)-1:0] cnt;
    logic btn_stable;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt        <= '0;
            btn_stable <= 1'b0;
        end
        else if (btn_sync2 == btn_stable) begin
            cnt <= '0;
        end
        else begin
            if (cnt == CNT_MAX) begin
                btn_stable <= btn_sync2;
                cnt <= '0;
            end
            else begin
                cnt <= cnt + 1'b1;
            end
        end
    end

    // =========================================================
    // Rising edge detect → pulse
    // =========================================================
    logic btn_stable_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            btn_stable_d <= 1'b0;
        else
            btn_stable_d <= btn_stable;
    end

    assign pulse = btn_stable & ~btn_stable_d;

endmodule
