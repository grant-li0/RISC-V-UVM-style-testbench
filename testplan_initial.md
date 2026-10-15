# Fall 2026 DV Onboarding Test Plan

<!--
Make two copies of this template:
  1. testplan_initial.md, submitted before implementing tests.
  2. testplan_final.md, updated after implementation and coverage closure.

Keep the initial copy unchanged after review. HTML comments are editing
instructions and disappear from rendered Markdown.
-->
## NOTE: THIS IS A TEMPLATE FOR YOU TO FOLLOW. THIS IS **NOT** A COMPREHENSIVE TESTPLAN. YOU NEED TO EXTEND IT.
## Document information

| Field | Value |
| --- | --- |
| Verification engineer | Grant Li, gran07, gli412 |
| Plan revision | Initial |
| Date | 2026-09-24 |

### Revision history

| Revision | Date | Changes |
| --- | --- | --- |
| Initial | 2026-09-24 | Initial planned tests |
| Final | YYYY-MM-DD | <!-- Tests or constraints added after debugging and coverage review --> |

## 1. Functional tests

<!--
Plan tests for the CPU functionality supported by this onboarding. Organize
related behavior together. Include both individual instruction behavior and
multi-instruction sequences where ordering or dependencies matter.

Add as many rows and detailed test records as needed. Do not put every CPU
operation into one large program: each failure should identify a reasonably
small area to debug.
-->


### Functional-test summary

| Test ID | Test name | Functionality being tested | Expected result | Status |
| --- | --- | --- | --- | --- |
| 1.1 | `arithmetic_edges` | ADDI signed boundaries, ADD/SUB wraparound, and dependent register updates | Signed immediates are extended correctly, arithmetic produces the expected low 32 bits, and dependent operations use the latest values | Planned |
| 1.2 | `zero_register` | Writes to x0 through ADDI, ADD, and SUB are discarded | x0 remains zero, and instructions immediately consuming x0 calculate results using zero | Planned |
| 1.3 | `memory_dependencies` | Base-plus-offset addressing, store/load ordering, overwrite behavior, and immediate use of loaded data | Loads return the latest stored values, dependent arithmetic is correct, and adjacent memory words remain unchanged | Planned |
| 1.4 | `branch_and_halt` | BEQ decisions using newly calculated values, skipped instructions, and EBREAK termination | Both registers equal to zero causes a taken branch while nonzero causes fall through. Skipped and post-halt instructions have no effect | Planned |
| 1.5 | `shift_edges` | SLL/SRL zero filling, shifts by 0 and 31, and scarded bits | All shifts produce the expected 32-bit results, including shifts by 32 and 33 behave as 0 and 1 | Planned |

### Functional-test details

### 1.1 — `arithmetic_edges`

**Functionality:**

Checks ADDI sign extension at the 12 bit signed immediate boundaries, ADD and ADDI
wraparound, SUB producing negative and zero results, and dependent updates
where a destination register is also a source.

**Initial state:**

- Registers: Reset
- Data memory: None
- Other setup: Reset CPU and scoreboard state, load program, and configure timeout.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(-2048)),
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(2047)),
  asm_instr(.op(OP_ADD),  .rd(3), .rs1(1), .rs2(2)),
  asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(1)),

  // Both register and immediate addition wrap FFFFFFFF to zero.
  asm_instr(.op(OP_ADD),  .rd(5), .rs1(3), .rs2(4)),
  asm_instr(.op(OP_ADDI), .rd(6), .rs1(3), .imm(1)),

  // Negative result followed by an update using the same register.
  asm_instr(.op(OP_SUB),  .rd(7), .rs1(0), .rs2(4)),
  asm_instr(.op(OP_ADDI), .rd(7), .rs1(7), .imm(-1)),
  asm_instr(.op(OP_SUB),  .rd(8), .rs1(7), .rs2(7)),

  // Negative immediate added to a nonzero positive operand.
  asm_instr(.op(OP_ADDI), .rd(9), .rs1(2), .imm(-1)),
  EBREAK_WORD
};
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'hFFFFF800` | -2048 sign-extended to 32 bits |
| `x2` | `32'h000007FF` | 2047 |
| `x3` | `32'hFFFFFFFF` | -2048 + 2047 = -1 |
| `x4` | `32'h00000001` | One |
| `x5` | `32'h00000000` | FFFFFFFF + 1 wraps to zero through ADD |
| `x6` | `32'h00000000` | Same wraparound through ADDI |
| `x7` | `32'hFFFFFFFE` | SUB produces -1 while dependent ADDI changes it to -2 |
| `x8` | `32'h00000000` | Subtracting a value from itself produces zero |
| `x9` | `32'h000007FE` | 2047 - 1 = 2046 |

**Pass criteria:**

All listed register values match. No CPU data-memory writes occur.
The CPU halts at EBREAK before timeout, with no scoreboard mismatches or
assertion violations.

**Final result:** Pending implementation.

### 1.2 — `zero_register`

**Functionality:**

Checks that attempted writes to x0 through ADDI, ADD, and SUB are discarded.
Instructions immediately following those writes must still read zero from x0.

**Initial state:**

- Registers: Reset
- Data memory: None
- Other setup: Reset CPU and scoreboard state, load program, and configure timeout.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(7)),

  asm_instr(.op(OP_ADDI), .rd(0), .rs1(0), .imm(9)),
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(1)),

  asm_instr(.op(OP_ADD),  .rd(0), .rs1(1), .rs2(1)),
  asm_instr(.op(OP_ADD),  .rd(3), .rs1(0), .rs2(1)),

  asm_instr(.op(OP_SUB),  .rd(0), .rs1(0), .rs2(1)),
  asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(2)),
  EBREAK_WORD
};
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x0` | `32'h00000000` | Attempted writes are discarded |
| `x1` | `32'h00000007` | Source value remains unchanged |
| `x2` | `32'h00000001` | x0 stays zero, then x0 + 1 = 1 |
| `x3` | `32'h00000007` | x0 stays zero, then x0 + x1 = 7 |
| `x4` | `32'h00000002` | x0 stays zero, then x0 + 2 = 2 |

**Pass criteria:**

x0 remains zero and all listed register values match.
No CPU data-memory writes occur. The CPU halts at EBREAK before timeout,
with no scoreboard mismatches or assertion violations.

**Final result:** Pending implementation.

### 1.3 — `memory_dependencies`

**Functionality:**

Checks aligned memory addressing using a nonzero base and negative offset,
full-word storage of all ones, loads after stores, overwriting the same word,
and arithmetic immediately consuming loaded data.

**Initial state:**

- Registers: Reset
- Data memory:
  - `DSRAM[0] = 32'h11223344`.
  - `DSRAM[1] = 32'h00000000`.
  - `DSRAM[2] = 32'h55667788`.
- Other setup: Confirm these words are valid. Configure timeout and read back all three words after execution.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(8)),
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(-1)),

  asm_instr(.op(OP_SW), .rs1(1), .rs2(2), .imm(-4)),
  asm_instr(.op(OP_LW), .rd(3), .rs1(1), .imm(-4)),
  asm_instr(.op(OP_ADDI), .rd(4), .rs1(3), .imm(1)),

  asm_instr(.op(OP_ADDI), .rd(5), .rs1(0), .imm(9)),
  asm_instr(.op(OP_SW), .rs1(1), .rs2(5), .imm(-4)),
  asm_instr(.op(OP_LW), .rd(6), .rs1(1), .imm(-4)),
  asm_instr(.op(OP_ADD), .rd(7), .rs1(6), .rs2(6)),
  EBREAK_WORD
};
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h00000008` | Base byte address |
| `x2` | `32'hFFFFFFFF` | First store value |
| `x3` | `32'hFFFFFFFF` | First load returns all 32 stored bits |
| `x4` | `32'h00000000` | Loaded FFFFFFFF + 1 wraps to zero |
| `x5` | `32'h00000009` | Overwrite value |
| `x6` | `32'h00000009` | Second load sees the latest store |
| `x7` | `32'h00000012` | Immediately consumes the load: 9 + 9 = 18 |
| `DSRAM[0]` | `32'h11223344` | Adjacent word remains unchanged |
| `DSRAM[1]` | `32'h00000009` | Final stored value is 9 |
| `DSRAM[2]` | `32'h55667788` | Adjacent word remains unchanged |

**Pass criteria:**

All listed register and memory values match. CPU stores target only DSRAM[1].
The CPU halts at EBREAK before timeout, with no scoreboard mismatches or
assertion violations.

**Final result:** Pending implementation.

### 1.4 — `branch_and_halt`

**Functionality:**

Checks that BEQ uses the latest source register value for both taken and
not-taken decisions. Checks that a skipped instruction has no effect,
instructions before EBREAK complete, and instructions after EBREAK do not execute.

**Initial state:**

- Registers: Reset
- Data memory: `DSRAM[0] = 32'h00000000`.
- Other setup: Load the program. Configure timeout. Read back DSRAM[0] after the observation interval.

**Program:**

```systemverilog
prog = '{
  // Instruction indices are zero-based.
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(0)), 
  asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(0)),
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)),

  asm_instr(.op(OP_SUB), .rd(1), .rs1(1), .rs2(1)),   // x1 = 0
  asm_instr(.op(OP_BEQ), .rs1(1), .rs2(0), .imm(8)),  // PC + 8
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(99)), // skipped

  asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(1)),  // x1 = 1
  asm_instr(.op(OP_BEQ), .rs1(1), .rs2(0), .imm(8)),  // skipped
  asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(7)),  // x3 = 7

  asm_instr(.op(OP_SW), .rs1(0), .rs2(3), .imm(0)),   // store 7
  EBREAK_WORD,                                      // halt

  asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(99)), // must not execute
  asm_instr(.op(OP_SW), .rs1(0), .rs2(3), .imm(0)),   // must not execute
  EBREAK_WORD                                     
};
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h00000001` | Changes from 1 to 0, then back to 1 |
| `x2` | `32'h00000000` | Taken branch skips the write of 99 |
| `x3` | `32'h00000007` | Not-taken branch allows 7 while post-halt write of 99 does not execute |
| `DSRAM[0]` | `32'h00000007` | Pre-halt store completes and post-halt store does not execute |

**Pass criteria:**

All listed results match. The CPU halts at the first EBREAK before timeout.
During the post-halt observation interval, x3 and DSRAM[0] remain 7 and no
post-EBREAK CPU store occurs. No scoreboard mismatches or assertion violations occur.

**Final result:** Pending implementation.

### 1.5 — `shift_edges`

**Functionality:**

Checks shifts by 31, logical right-shift zero filling, discarding bits shifted
out of the register, and use of only the low five bits of the shift-amount
register. Shift amounts 32 and 33 exercise effective shifts of zero and one.

**Initial state:**

- Registers: Reset
- Data memory: None
- Other setup: Configure timeout

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)),
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(31)),
  asm_instr(.op(OP_SLL),  .rd(3), .rs1(1), .rs2(2)),
  asm_instr(.op(OP_SRL),  .rd(4), .rs1(3), .rs2(2)),

  // Low five bits of 32 are zero.
  asm_instr(.op(OP_ADDI), .rd(5), .rs1(0), .imm(32)),
  asm_instr(.op(OP_SLL),  .rd(6), .rs1(1), .rs2(5)),
  asm_instr(.op(OP_SRL),  .rd(7), .rs1(3), .rs2(5)),

  // Low five bits of 33 select a shift of one.
  asm_instr(.op(OP_ADDI), .rd(8), .rs1(0), .imm(33)),
  asm_instr(.op(OP_SLL),  .rd(9), .rs1(1), .rs2(8)),
  asm_instr(.op(OP_SRL), .rd(10), .rs1(3), .rs2(8)),

  // Shift the only set bit out of the register.
  asm_instr(.op(OP_SLL), .rd(11), .rs1(3), .rs2(1)),
  asm_instr(.op(OP_SRL), .rd(12), .rs1(1), .rs2(1)),

  // Verify zero filling with all input bits set.
  asm_instr(.op(OP_ADDI), .rd(13), .rs1(0), .imm(-1)),
  asm_instr(.op(OP_SRL),  .rd(14), .rs1(13), .rs2(1)),
  EBREAK_WORD
};
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x3` | `32'h80000000` | 1 shifted left by 31 |
| `x4` | `32'h00000001` | 80000000 shifted right by 31 |
| `x6` | `32'h00000001` | Shift amount 32 acts as zero |
| `x7` | `32'h80000000` | Shift amount 32 acts as zero |
| `x9` | `32'h00000002` | Shift amount 33 acts as one |
| `x10` | `32'h40000000` | Logical right shift inserts zero into bit 31 |
| `x11` | `32'h00000000` | The only set bit is shifted out to the left |
| `x12` | `32'h00000000` | The only set bit is shifted out to the right |
| `x13` | `32'hFFFFFFFF` | All-ones input |
| `x14` | `32'h7FFFFFFF` | Logical right shift fills with zero rather than the sign bit |

**Pass criteria:**

All listed register values match. No CPU data-memory writes occur.
The CPU halts at EBREAK before timeout, with no scoreboard mismatches or
assertion violations.

**Final result:** Pending implementation.

## 2. Constrained-random tests

### Instruction constraints

<!--
Explain the provided constraints, then record how the partial and open
constraints are completed. State what each constraint permits, excludes, or
biases and why the resulting programs remain useful and terminating.
-->

| Constraint | Provided, partial, or open | Behavior and purpose | Final implementation summary |
| --- | --- | --- | --- |
| `c_opcode` | Provided | Ensures selection of operations supported by CPU | No member change |
| `c_reg_bias` | Provided | Provides a weighted distributions for selecting registers in the instruction | No member change |
| `c_imm_range` | Partial | Specifies the range of values the 12-bit immediate can have | TBD |
| `c_mem_align` | Open | Ensures load/store offset is word-aligned to prevent accessing addresses that do not represent the start of a word | TBD |
| `c_imm_unused` | Provided | Set immediate to zero for register-only instructions | No member change |
| `c_branch_target` | Partial | Ensures only forward branching and that PC offset is word-aligned | TBD |
| `c_no_branch_at_end` | Provided | Prevents a branch from being added to the end of a program | No member change |
| `c_branch_taken_bias` | Open | Provides a weighted distribution making branches happen as commonly as non branches | TBD |

### External-port constraints

| Constraint | Provided, partial, or open | Behavior and purpose | Final implementation summary |
| --- | --- | --- | --- |
| `c_align` | Provided | Ensures memory address provided at the external ports is word-aligned by constraining least significant two bits to zero | No member change |
| `c_valid_window` | Partial | Limit the address window to the memory address which actually exist in that window | TBD |
| `c_reg_read_only` | Provided | Ensures the register can only be read from external ports | No member change |
| `c_data_corners` | Open | Makes special values and edge cases more likely to occur by adding bias, while still enabling normal 32-bit values | TBD |

### Random-program test

| Item | Plan |
| --- | --- |
| Number of programs per seed | 10 |
| Program-length range | 10-30 plus EBREAK |
| Information logged for reproduction | Numeric `SVSEED`, iteration, and complete generated program |

**Implementation outline:**

```systemverilog
int num_instr;

for (int iteration = 0; iteration < 10; iteration++) begin
  num_instr = $urandom_range(30, 10);

  // Reset CPU and scoreboard, initialize data memory if required.

  // Log numeric SVSEED, iteration, num_instr, and initial setup.
  // gen_program displays the generated instructions and appends EBREAK,
  seqr.gen_program(num_instr);

  // Wait for all program writes to ISRAM to complete.
  // Start CPU execution and wait for halt with a timeout.
  // Complete monitor processing and scoreboard checks.
  // Log this iteration's pass/fail result.
end
```

## 3. Assertions

<!--
Plan at least two assertions in addition to the supplied example. Write the
timing rule in English first. In the final plan, include the exact SVA and
evidence from a temporary violation proving that the assertion can fire.
-->

### Assertion summary

| Assertion ID/name | Behavior checked | When it is sampled/disabled | Activating test |
| --- | --- | --- | --- |
| 4.1 / `XBAR_WHEN_CPU_INACTIVE` | External reads and writes only requested when CPU is inactive | Every rising clock edge and disabled when reset | Program loading, data memory initialization, register/memory readback |
| 4.2 / `XBAR_READ_HELD_UNTIL_READY` | During an external read request, if response is not ready, the address and read enable must hold until the next rising clock edge | Every rising clock edge and disabled when reset | External DSRAM memory readback |

### 4.1 — `XBAR_WHEN_CPU_INACTIVE`

**Timing requirement in words:**

At every rising clock edge outside reset, if an external read or write is requested, cpu_active must be low. The external port is serviced only while the CPU is inactive. This assertion checks that the testbench requests access only during that permitted period.

```systemverilog
XBAR_WHEN_CPU_INACTIVE:
  assert property (@(posedge clk) disable iff (rst)
    (cpu_if.w_en || cpu_if.r_en) |-> !cpu_if.cpu_active
  )
  else assertion_fail("External port access requested while CPU was active");
```

**Evidence that it detects a violation:**

Planned validation: Run a program and, while cpu_active is high and reset is low, temporarily assert external r_en while keeping w_en low. Hold the request across a rising clock edge while the CPU remains active. Confirm that XBAR_WHEN_CPU_INACTIVE reports a failure. Save the failure log and a waveform showing reset low, cpu_active high, r_en high, and w_en low at the failing edge.

Remove the temporary violation and rerun with legal external accesses while the CPU is inactive to confirm no assertion failure occurs.

Final evidence: Pending implementation.

### 4.2 — `XBAR_READ_HELD_UNTIL_READY`

**Timing requirement in words:**

At every rising clock edge outside reset, if r_en is high and rready is low, r_en must remain high and addr must remain unchanged at the next rising clock edge. This checks that a pending external read request is held.

```systemverilog
XBAR_READ_HELD_UNTIL_READY:
  assert property (@(posedge clk) disable iff (rst)
    (cpu_if.r_en && !cpu_if.rready) |=> (cpu_if.r_en && $stable(cpu_if.addr))
  )
  else assertion_fail("External read request changed before response was observed");
```

**Evidence that it detects a violation:**

Planned validation: While the CPU is inactive and reset is low, issue an external DSRAM read with w_en low. After a rising edge samples r_en high and rready low, temporarily change addr before the next rising edge, keeping r_en high. Confirm that XBAR_READ_HELD_UNTIL_READY reports a failure at the next rising edge. Save the failure log and a waveform showing addr, r_en,
rready, and reset at both sampled edges.

Remove the address violation and repeat with addr held constant but r_en deasserted before the next rising edge. Confirm that this also causes an assertion failure.

Remove all temporary violations and rerun a legal read request, holding the request through the response. Confirm that no assertion failure occurs.

Final evidence: Pending implementation.

## 4. Encrypted CPU Bug Hunt

### Random discovery

| Field                    | Evidence                      |
| ------------------------ | ----------------------------- |
| Discovery command        | `make bug_hunt SEED=random`   |
| Numeric `SVSEED`         |                               |
| Failing iteration        |                               |
| First failure message    |                               |
| Reproduction command     | `make bug_hunt SEED=________` |
| Reproduces consistently? | Yes / No                      |

**Original failing program:**

```systemverilog
prog = '{
  // Paste original generated sequence
  EBREAK_WORD
};
```

### Expected vs. actual

| Instruction / event | Expected | Actual | Cycle/time |
| ------------------- | -------- | ------ | ---------- |
|                     |          |        |            |

**First architectural divergence:**

<!-- State the first register, memory, or control-flow result that becomes incorrect. -->

### Minimization

**Minimized reproducer:**

```systemverilog
prog = '{
  // Smallest sequence that still fails
  EBREAK_WORD
};
```

### Waveform evidence

Include a screenshot showing the offending instruction and the first incorrect architectural result.

### Conclusion

**Trigger:**

<!-- Smallest condition that causes the failure. -->

**Expected behavior:**

<!-- ISA-correct behavior. -->

**Observed behavior:**

<!-- What the encrypted CPU does instead. -->

**Behavioral characterization:**

<!-- One precise sentence. Do not speculate about hidden RTL. -->

