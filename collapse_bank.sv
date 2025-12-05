// ============================================================================
// ENP-P™ Reference Implementation — collapse_bank.sv
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
// collapse_bank.sv — ENP-P™ bank with shared entropy.
// Exposes per-cell mismatch-ground flags for STATUS/demo.
// ============================================================================


`timescale 1ns/1ps

module collapse_bank #(
    parameter int N        = 64,
    parameter int DATA_W   = 256,
    parameter int BASIS_W  = 8,
    parameter int ADDR_W   = $clog2(N)
)(
    input  wire               clk,
    input  wire               rst,

    // INIT
    input  wire [ADDR_W-1:0]  init_addr,
    input  wire [DATA_W-1:0]  init_value,
    input  wire [BASIS_W-1:0] init_basis,
    input  wire               init_strobe,

    // READ
    input  wire [ADDR_W-1:0]  read_addr,
    input  wire [BASIS_W-1:0] basis_in,
    input  wire               read_pulse,

    // Data out from selected cell
    output logic [DATA_W-1:0] data_o,

    // New: per-cell mismatch-ground flags (for STATUS/demo)
    output logic [N-1:0]      mismatch_ground_vec
);

    // (entropy/TRNG code unchanged; omitted here if you already have it)
    // ... your existing RO + von Neumann + LFSR entropy pipeline ...

    // For brevity here, assume entropy_byte exists:
    wire [DATA_W-1:0] entropy_byte;
    // (keep your existing definition)

    // --------------------------------------------------------------
    // Per-cell control: one-hot init/read strobes
    // --------------------------------------------------------------
    logic [N-1:0] init_sel;
    logic [N-1:0] read_sel;

    genvar gi;
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : DECODE
            assign init_sel[gi] = init_strobe && (init_addr == gi[ADDR_W-1:0]);
            assign read_sel[gi] = read_pulse  && (read_addr == gi[ADDR_W-1:0]);
        end
    endgenerate

    // --------------------------------------------------------------
    // Cell instances
    // --------------------------------------------------------------
    logic [DATA_W-1:0] cell_data [N];

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : CELLS
            collapse_cell #(
                .DATA_W (DATA_W),
                .BASIS_W(BASIS_W)
            ) U_CELL (
                .clk              (clk),
                .rst              (rst),

                .init_en          (init_sel[i]),
                .init_value       (init_value),
                .init_basis       (init_basis),

                .read_pulse       (read_sel[i]),
                .basis_in         (basis_in),

                .data_o           (cell_data[i]),

                // new demo/status flag
                .mismatch_ground_q(mismatch_ground_vec[i])
            );
        end
    endgenerate

    // --------------------------------------------------------------
    // Read data mux
    // --------------------------------------------------------------
    always_comb begin
        data_o = '0;
        for (int k = 0; k < N; k = k + 1) begin
            if (read_addr == k[ADDR_W-1:0]) begin
                data_o = cell_data[k];
            end
        end
    end

endmodule
