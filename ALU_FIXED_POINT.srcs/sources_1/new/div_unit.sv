`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/13/2025 05:14:01 AM
// Design Name: 
// Module Name: div_unit
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


// ============================================================
// Chia fixed-point: (a << F) / b
// - N?u b == 0: ovf = 1, y clamp v? MAXV/MINV t�y d?u a
// - D�ng to�n t? / cho m� ph?ng, synth s? t?o m?ch chia HW
//   (ch?p nh?n cho project n�y, n?u mu?n t?i ?u h?n c� th?
//    thay b?ng Newton-Raphson, LUT reciprocal, v.v.)
// ============================================================
module div_unit #(
    parameter int N = 8,
    parameter int F = 4
)(
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 en,
    input  logic signed [N-1:0]  a,
    input  logic signed [N-1:0]  b,
    output logic signed [N-1:0]  y,
    output logic                 ovf
);
    localparam logic signed [N-1:0] MAXV = {1'b0, {(N-1){1'b1}}};
    localparam logic signed [N-1:0] MINV = {1'b1, {(N-1){1'b0}}};

    logic signed [2*N-1:0] num;

    // scale numerator l�n F bit fractional
    always_comb begin
        num = $signed(a) <<< F; // gi? nguy�n d?u
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y   <= '0;
            ovf <= 1'b0;
        end else if (en) begin
            if (b == '0) begin
                // chia 0 -> b�o ovf + clamp
                ovf <= 1'b1;
                y   <= a[N-1] ? MINV : MAXV;
            end else begin
                ovf <= 1'b0;
                y   <= num / $signed(b);
            end
        end
    end

endmodule

