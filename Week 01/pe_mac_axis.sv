// pe_mac_axis.sv : One multiply–accumulate PE with four
// AXI4-Stream neighbour ports (N,E,S,W) + a config port.
//
// Copyright (c) 2025
`timescale 1ns/1ps
module pe_mac_axis #(
    parameter WIDTH = 32              // IEEE-754 single
)(
    input  logic                       aclk,
    input  logic                       aresetn,
    // AXI-Stream north input / south output
    input  logic [WIDTH-1:0]           n_tdata,
    input  logic                       n_tvalid,
    output logic                       n_tready,
    output logic [WIDTH-1:0]           s_tdata,
    output logic                       s_tvalid,
    input  logic                       s_tready,
    // AXI-Stream west input / east output
    input  logic [WIDTH-1:0]           w_tdata,
    input  logic                       w_tvalid,
    output logic                       w_tready,
    output logic [WIDTH-1:0]           e_tdata,
    output logic                       e_tvalid,
    input  logic                       e_tready,
    // Optional config stream (e.g. coefficient load)
    input  logic [WIDTH-1:0]           cfg_tdata,
    input  logic                       cfg_tvalid,
    output logic                       cfg_tready
);
    // Simple MAC:  y = a * b + c
    logic [WIDTH-1:0] a_reg, b_reg, acc_reg;
    logic ready_in, ready_out;

    // Handshake: stall internally if any egress is blocked
    assign ready_in  = n_tready & w_tready;
    assign ready_out = s_tready & e_tready;

    // Upstream back-pressure
    assign n_tready  = ready_out;
    assign w_tready  = ready_out;
    assign cfg_tready= ready_out;

    // Compute path
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            a_reg  <= '0;
            b_reg  <= '0;
            acc_reg<= '0;
        end else if (n_tvalid & w_tvalid & ready_out) begin
            a_reg   <= n_tdata;
            b_reg   <= w_tdata;
            // simple multiply–accumulate
            acc_reg <= (n_tdata * w_tdata) + acc_reg;
        end
    end

    // Forward results south and east
    assign s_tdata  = a_reg;          // pass‐through or custom op
    assign e_tdata  = acc_reg;
    assign s_tvalid = n_tvalid & w_tvalid;
    assign e_tvalid = n_tvalid & w_tvalid;
endmodule
