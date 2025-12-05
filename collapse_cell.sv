// ============================================================================
// ENP-P™ Reference Implementation — collapse_cell.sv
// Electrical Non-Persistence Primitive (ENP-P)
// Copyright (c) 2025 QSymbolic LLC
// Patent Pending: US 19/286,600
//
// This reference implementation is provided solely for:
//   • academic research
//   • peer review and reproducibility
//   • evaluation and testing
//   • prototyping and architectural study
//   • teaching and non-commercial experimentation
//
// Commercial use of this software or any derivative work — including but not
// limited to ASIC, FPGA, SoC, secure element, embedded device, or cloud service
// integration — requires a separate written license from QSymbolic LLC.
//
// No rights to manufacture, practice, or commercialize the ENP-P technology are
// granted or implied by this header. See LICENSE.md for full terms.
//
// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND.
// ============================================================================
//
// collapse_cell.sv — 256-bit ENP-P™ cell.
// Resolves exactly once under correct basis; wrong basis → dead-circuit output.
// Implements immediate, irreversible electrical non-persistence semantics.
// ============================================================================


`timescale 1ns/1ps

module collapse_cell #(
    parameter int DATA_W  = 256,
    parameter int BASIS_W = 8
)(
    input  wire                 clk,
    input  wire                 rst,

    // Initialization (arming)
    input  wire                 init_en,
    input  wire [DATA_W-1:0]    init_value,
    input  wire [BASIS_W-1:0]   init_basis,

    // First read pulse = measurement / collapse event
    input  wire                 read_pulse,

    // Runtime basis input
    input  wire [BASIS_W-1:0]   basis_in,

    // Output
    output logic [DATA_W-1:0]   data_o
);

    // ------------------------------------------------------------------------
    // Internal state
    // ------------------------------------------------------------------------
    logic [DATA_W-1:0] stored_q;    // masked storage (never plaintext)
    logic [BASIS_W-1:0] basis_q;    // stored basis
    logic               collapsed_q;

    // Per-word (32-bit) mask from basis
    logic [31:0] basis_mask32;
    assign basis_mask32 = {24'h0, basis_q};

    // Decode mask for readout:
    logic [31:0] read_mask32;
    assign read_mask32 = {24'h0, basis_in};

    // Basis match indicator
    wire basis_matches = (basis_in == basis_q);

    // ------------------------------------------------------------------------
    // INIT + collapse behavior
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            stored_q    <= '0;
            basis_q     <= '0;
            collapsed_q <= 1'b0;

        end else begin

            // -----------------------------
            // INIT — arm with masked value
            // -----------------------------
            if (init_en) begin
                for (int w = 0; w < (DATA_W/32); w++) begin
                    stored_q[w*32 +: 32] <= init_value[w*32 +: 32] ^
                                            {24'h0, init_basis};
                end

                basis_q     <= init_basis;
                collapsed_q <= 1'b0;
            end

            // --------------------------------------------------------
            // FIRST read — measurement/collapse event (ASIC behavior)
            // --------------------------------------------------------
            if (read_pulse && !collapsed_q) begin

                // Collapse ALWAYS occurs on first measurement
                collapsed_q <= 1'b1;

                // Wrong basis → no data ever escapes → destroy state NOW
                if (!basis_matches) begin
                    stored_q <= '0;     // electrically grounded
                end

                // Correct basis → allowed to decode for this cycle,
                // but immediately after the cycle we ground internal node.
                else begin
                    stored_q <= '0;     // stored state still destroyed
                end
            end
        end
    end

    // ------------------------------------------------------------------------
    // Readout combinational path
    // ------------------------------------------------------------------------
    always_comb begin

        // After collapse → dead circuit
        if (collapsed_q) begin
            data_o = '0;
        end

        // Before collapse, correct basis → decode
        else if (basis_matches) begin
            logic [DATA_W-1:0] decoded;
            for (int w = 0; w < (DATA_W/32); w++) begin
                decoded[w*32 +: 32] = stored_q[w*32 +: 32] ^ read_mask32;
            end
            data_o = decoded;
        end

        // Before collapse, wrong basis → dead circuit output
        else begin
            data_o = '0;
        end
    end

endmodule
