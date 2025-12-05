# ENP-P: Electrical Non-Persistence Primitive  
### Reference FPGA Artifact — 64×256-bit Single-Use Measurement Cells  

**Author:** Francis X. Cunnane III (QSymbolic LLC)  
**Paper:** *A CMOS Electrical Non-Persistence Primitive for Single-Use Secrets*  
**Repository:** https://github.com/fcunnane/ENP-P  

**Patent Pending:** US 19/286,600


---

## Overview

This repository contains the **reference implementation**, **FPGA bitstream**, and **System Console test scripts** for the Electrical Non-Persistence Primitive (ENP-P) architecture described in the associated research paper.

ENP-P is a CMOS-compatible primitive that enforces the physical rule:

> **A read returns the true secret or a dead circuit — nothing in between.**

Each ENP-P cell reveals its stored 256-bit value **exactly once** under the correct 8-bit basis.  
Any read (match or mismatch) immediately destroys the internal encoding, leaving **no electrically recoverable state**.  
This implementation demonstrates deterministic single-use behavior, wrong-basis inertness, and post-consumption indistinguishability across a 64-cell array.

This repository provides the *exact* FPGA configuration used to produce the resource-utilization, timing, and functional results reported in the paper.

---

## Directory Structure

```

ENP-P/
│
├── collapse_cell.sv        # 256-bit ENP-P collapse cell
├── collapse_bank.sv        # 64-cell array wrapper (ROOM / Atomic Memory)
├── 256.sof                 # Quartus Prime FPGA bitstream (Cyclone V)
│
└── scripts/                # System Console test suite
├── test_correct_basis.tcl
├── test_wrong_basis.tcl
├── test_all_cells.tcl
├── README.md           # Testing instructions

````

---

## Hardware Requirements

This artifact targets:

- **Intel Cyclone V SoC:** 5CSEBA6U23I7 (DE10-Nano or equivalent)
- **Quartus Prime 25.1** (Standard or Lite)
- **Intel System Console** (included with Quartus)

FPGA analog behavior cannot reproduce ASIC grounding physics,  
but the FPGA faithfully models the **logical semantics**:

- correct-basis: one-time disclosure  
- wrong-basis: dead-circuit output  
- subsequent reads: always inert  
- mismatch, consumed, and uninitialized cells are indistinguishable  

---

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/fcunnane/ENP-P.git
cd ENP-P
````

### 2. Program the FPGA

Using Quartus Programmer:

```
256.sof
```

Program to the Cyclone V device.

### 3. Run Tests in System Console

Start System Console:

```bash
system-console
```

Then run any test:

```tcl
source scripts/test_correct_basis.tcl
source scripts/test_wrong_basis.tcl
source scripts/test_all_cells.tcl
```

Each script automatically:

* detects the JTAG master,
* exercises initialization, basis provisioning, first-read semantics,
* verifies inert post-collapse behavior,
* emits PASS/FAIL summaries.

---

## RTL Components

### `collapse_cell.sv`

Implements one **256-bit ENP-P cell** with:

* per-bit masked encode graph `E(v, b) = v ⊕ b`
* no internal node equal to the true secret
* basis-conditioned decode path
* single-read collapse latch and destruction of stored state
* inert output after consumption or mismatched basis

### `collapse_bank.sv`

Implements the **64-cell ROOM array**:

* per-cell address decoding
* basis input routing
* collapse propagation and output muxing
* Avalon-MM slave wrapper for testing

### `256.sof`

Fully routed FPGA bitstream:

* 64 × 256-bit ENP-P cells
* exact resource figures match paper Table 2
* timing closure at >66 MHz across worst-case corners

---

## Scripts

All tests expect the Avalon-MM map:

| Offset | Register | Description                         |
| ------ | -------- | ----------------------------------- |
| 0x00   | DATA0    | Read output (32-bit word 0)         |
| 0x04   | ADDR     | Selects cell [0..63]                |
| 0x08   | INIT     | Initialize masked data (write-only) |
| 0x0C   | TRIG     | Triggers read/collapse              |
| 0x10   | STATUS   | Collapse state, debug               |
| 0x14   | CTRL     | Basis input                         |
| 0x18   | ID       | Static “ROOM” identifier            |

Scripts included:

* **`test_correct_basis.tcl`**

  * correct basis → exact 256-bit reveal
  * second read → inert

* **`test_wrong_basis.tcl`**

  * wrong basis → inert output on first read
  * same output as consumed or uninitialized

* **`test_all_cells.tcl`**

  * randomized values + bases
  * full-array verification
  * PASS/FAIL summary

Scripts return deterministic output matching the evaluation in the paper.

---

## Known Limitations

This artifact validates the *logical* semantics of ENP-P.
It does **not** model:

* transistor-level grounding discharge physics
* analog collapse timing skew
* side-channel behavior during collapse
* ASIC layout or parasitics

ASIC tapeout is required for full analog verification.

---

## Licensing

The ENP-P artifact is provided **for academic and research use only**.

Commercial licensing, ASIC instantiation rights, and integration into secure hardware products are available from **QSymbolic LLC**.

Contact: **[frank@qsymbolic.com](mailto:frank@qsymbolic.com)**

---

## Citation

If you use this artifact in academic work, please cite:

**F. X. Cunnane III, “A CMOS Electrical Non-Persistence Primitive for Single-Use Secrets,” 2025.**

---

## Contact

For questions or collaboration:

**Francis X. Cunnane III**
QSymbolic LLC
Email: *[frank@qsymbolic.com](mailto:frank@qsymbolic.com)*

