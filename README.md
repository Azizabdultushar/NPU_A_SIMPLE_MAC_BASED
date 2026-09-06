# NPU_A_SIMPLE_MAC_BASED

A minimal Neural Processing Unit (NPU) accelerator core built around a single Multiply-Accumulate (MAC) unit.

## Overview

| Property             | Value                                   |
|----------------------|------------------------------------------|
| MAC units             | 1                                       |
| Input precision       | INT8 (activation and weight)            |
| Accumulator precision | INT32                                   |
| Throughput            | 1 MAC operation per clock cycle         |
| Control               | Single `valid` enable signal            |

This design is intentionally simple: no pipelining, no parallel lanes, no memory interface — just one MAC datapath with a synchronous accumulator register. It's meant as a baseline / teaching example before scaling up to array-based (systolic) NPU architectures.

---

## Metadata

| Field         | Value                     |
|---------------|---------------------------|
| Company       | Bohemian                  |
| Author        | Tusher Aziz               |
| Create Date   | 06.09.2026 10:17:35       |
| Module Name   | `simple_mac_npu` (Behavioral) |
| Entity Name   | `Simple_NPU`               |
| Revision      | 0.01 – File Created       |

---

## Port Definition

| Port      | Direction | Type              | Width | Description                                                        |
|-----------|-----------|-------------------|-------|---------------------------------------------------------------------|
| `clk`     | in        | `STD_LOGIC`       | 1     | System clock                                                        |
| `rst`     | in        | `STD_LOGIC`       | 1     | Synchronous reset, clears the accumulator                          |
| `act_in`  | in        | `SIGNED`          | 8     | INT8 activation input                                               |
| `wgt_in`  | in        | `SIGNED`          | 8     | INT8 weight input                                                   |
| `valid`   | in        | `STD_LOGIC`       | 1     | Enable signal — `1` performs a MAC operation, `0` holds the current accumulator value |
| `result`  | out       | `SIGNED`          | 32    | Current accumulator value (running MAC result)                     |

---

## Internal Signals

| Signal        | Type            | Width | Purpose                                          |
|---------------|-----------------|-------|---------------------------------------------------|
| `acc`         | `SIGNED`        | 32    | Accumulator register, holds the running sum        |
| `mult_result` | `SIGNED` (variable) | 16 | Temporary storage for the INT8 × INT8 product      |

---

## Bit-Width Justification

**Multiplication (INT8 × INT8):**
- Largest magnitude product: `127 × 127 = 16129`
- Representing 16129 requires 15 magnitude bits + 1 sign bit → **16 bits** is sufficient for `mult_result`.

**Accumulation (INT32):**
- After N MAC operations, worst case sum ≈ `N × 16129`.
- Example: 1000 accumulations → `1000 × 16129 = 16,129,000`, well within INT32 range.
- A 16-bit accumulator would overflow almost immediately (range: −32,768 to 32,767).
- A 32-bit signed accumulator supports a range of **−2,147,483,648 to +2,147,483,647**, which comfortably accommodates thousands of MAC operations before overflow.

---

## Behavior

The core operates as a single synchronous process sensitive to `clk`:

1. **Reset (`rst = '1'`)** — On the rising edge, the accumulator `acc` is cleared to zero. Reset takes priority over `valid`.
2. **MAC Operation (`valid = '1'`)** — On the rising edge:
   - Compute `mult_result := act_in * wgt_in` (INT8 × INT8 → 16-bit signed product).
   - Resize `mult_result` to 32 bits (sign-extended) and add it to `acc`.
   - `acc <= acc + resize(mult_result, 32)`
3. **Idle (`valid = '0'`)** — The accumulator holds its current value; no update occurs.
4. **Output** — `result` is a continuous (combinational) assignment reflecting the current value of `acc`.

### Timing Diagram (conceptual)

```
clk        : _|‾|_|‾|_|‾|_|‾|_|‾|_
rst        : ‾|_______________|___
valid      : ___|‾‾‾‾‾‾‾‾‾|_______
act_in     :    A0  A1  A2
wgt_in     :    W0  W1  W2
acc        : 0  0  A0W0  A0W0+A1W1  A0W0+A1W1+A2W2
```

---

## Priority Logic

The reset/valid decision follows this priority order each rising clock edge:

1. `rst = '1'` → clear accumulator (highest priority)
2. else if `valid = '1'` → perform MAC and accumulate
3. else → hold current accumulator value (implicit, since `acc` is not reassigned)

---

## Notes / Design Considerations

- **No pipelining**: The multiply and accumulate happen in the same clock cycle, so the critical path includes both the 8×8 multiplier and the 32-bit adder. For higher clock frequencies, this could be split into a pipelined multiply stage followed by an accumulate stage.
- **No overflow protection**: The 32-bit accumulator will wrap around (or produce undefined results in simulation if not handled) if enough large-magnitude products accumulate beyond `±2^31`. For very long accumulation sequences, saturation logic or periodic accumulator read-out/reset would be needed.
- **Single MAC unit**: Only one multiply-accumulate operation can be issued per clock cycle, making this suitable as a scalar baseline core rather than a high-throughput array (e.g., systolic array or SIMD MAC lanes) design.
- **Synchronous reset**: Reset is evaluated only on the rising clock edge (not asynchronous), which is generally preferred for timing closure and glitch-free FPGA/ASIC synthesis.

---

## Possible Extensions

- Add pipeline registers between multiply and accumulate stages to improve `Fmax`.
- Add an accumulator clear/read control (e.g., `acc_clear`, `acc_valid_out`) separate from global `rst`, to support layer-by-layer accumulation without a full reset.
- Extend to multiple parallel MAC units for vector dot-product acceleration.
- Add saturation arithmetic to guard against accumulator overflow.
