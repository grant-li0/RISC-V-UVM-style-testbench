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
| Plan revision | Final |
| Date | 2026-10-06 |

### Revision history

| Revision | Date | Changes |
| --- | --- | --- |
| Initial | 2026-09-24 | Initial planned tests |
| Intermediate | 2026-10-01 | Complete driver|
| Intermediate | 2026-10-02 | Complete monitor, scoreboard |
| Intermediate | 2026-10-03 | Complete directed tests, assertions |
| Final | 2026-10-05 | Complete constraint random testing, get DUT coverage, and bug hunt |

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
| 1.1 | `arithmetic_edges` | ADDI signed boundaries, ADD/SUB wraparound, and dependent register updates | Signed immediates are extended correctly, arithmetic produces the expected low 32 bits, and dependent operations use the latest values | Pass. Directed suite completed with TEST PASSED! evidence: saved simulation log.|
| 1.2 | `zero_register` | Writes to x0 through ADDI, ADD, and SUB are discarded | x0 remains zero, and instructions immediately consuming x0 calculate results using zero | Pass. Directed suite completed with TEST PASSED! evidence: saved simulation log. |
| 1.3 | `memory_dependencies` | Base-plus-offset addressing, store/load ordering, overwrite behavior, and immediate use of loaded data | Loads return the latest stored values, dependent arithmetic is correct, and adjacent memory words remain unchanged | Pass. Directed suite completed with TEST PASSED! evidence: saved simulation log. |
| 1.4 | `branch_and_halt` | BEQ decisions using newly calculated values, skipped instructions, and EBREAK termination | Both registers equal to zero causes a taken branch while nonzero causes fall through. Skipped and post-halt instructions have no effect | Pass. Directed suite completed with TEST PASSED! evidence: saved simulation log. |
| 1.5 | `shift_edges` | SLL/SRL zero filling, shifts by 0 and 31, and scarded bits | All shifts produce the expected 32-bit results, including shifts by 32 and 33 behave as 0 and 1 | Pass. Directed suite completed with TEST PASSED! evidence: saved simulation log. |
| 1.6 | `external_memory_boundaries` | External reads and writes at words 0 and 1023 of ISRAM and DSRAM using walking-one data patterns | Each boundary word returns the written value for all 32 walking-one patterns | Pass. Directed suite completed with TEST PASSED! evidence: saved simulation log. |
| 1.7 | `register_readback` | External register-window reads of all 32 registers, including x31 | x0 reads as zero. x1 through x31 return their distinct programmed values of 1 through 31 | Pass. Directed suite completed with TEST PASSED! evidence: saved simulation log. |
| 1.8 | `reset_during_execution` | Reset while the CPU is active, return of memory ownership, register clearing, and execution after reset | CPU becomes inactive, all registers read as zero, and a fresh program completes with x1 = 7 | Pass. Directed suite completed with TEST PASSED! evidence: saved simulation log. |
| 1.9 | `backward_branch` | Branching backwards, implemented to increase branch_trgt_o coverage. | First branch not taken initially (x1 != x0), then branch backward always taken. On return, branch forward taken with x1 = x0 = 0 | Pass. Directed suite completed with TEST PASSED! evidence: saved simulation log. |

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

**Final result:** Pass. Directed suite completed with TEST PASSED! evidence: saved simulation log.

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

**Final result:** Pass. Directed suite completed with TEST PASSED! evidence: saved simulation log.

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

**Final result:** Pass. Directed suite completed with TEST PASSED! evidence: saved simulation log.

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

**Final result:** Pass. Directed suite completed with TEST PASSED! evidence: saved simulation log.

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

**Final result:** Pass. Directed suite completed with TEST PASSED! evidence: saved simulation log.

### 1.6 — `external_memory_boundaries`

**Functionality:**

Checks external reads and writes at words 0 and 1023 of both instruction
and data SRAM. Walking-one patterns exercise each of the 32 data-bit positions.

**Initial state:**

- Registers: Reset
- Data memory: Tested words is written before reading
- Other setup: Keep CPU inactive

**Program:**

```systemverilog
begin : external_memory_boundaries
    logic [31:0] pattern;

    sb.set_test("external_memory_boundaries");
    $display("TEST: external_memory_boundaries");
    drv.reset_task();

    for (int bit_index = 0; bit_index < 32; bit_index++) begin
        pattern = 32'h00000001 << bit_index;

        seqr.send_write_trans(word_addr(ISRAM_BASE, 0), pattern);
        readback(0, 1, 0);

        seqr.send_write_trans(word_addr(ISRAM_BASE, 1023), pattern);
        readback(0, 1, 1023);

        seqr.send_write_trans(word_addr(DSRAM_BASE, 0), pattern);
        readback(1, 1, 0);

        seqr.send_write_trans(word_addr(DSRAM_BASE, 1023), pattern);
        readback(1, 1, 1023);
    end
end
init_memories();
```

**Expected result:**

Values below apply to each iteration, before memory reinitialization.

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `ISRAM[0]` | `32'h00000001 << bit_index` | First instruction-memory word returns the written pattern |
| `ISRAM[1023]` | `32'h00000001 << bit_index` | Last instruction-memory word returns the written pattern |
| `DSRAM[0]` | `32'h00000001 << bit_index` | First data-memory word returns the written pattern |
| `DSRAM[1023]` | `32'h00000001 << bit_index` | Last data-memory word returns the written pattern |

**Pass criteria:**

All 128 boundary-word reads match the values written across the 32 iterations.
The CPU remains inactive during external accesses. No external-read timeouts,
scoreboard mismatches, or assertion violations occur.

**Final result:** Pass. Directed suite completed with TEST PASSED! Evidence: saved simulation log.

### 1.7 — `register_readback`

**Functionality:**

Checks external register-window addressing and readback of all 32 registers,
including x31. Distinct programmed values help detect incorrect register selection.

**Initial state:**

- Registers: Reset
- Data memory: None
- Other setup: Configure execution timeout and read back all registers after normal halt

**Program:**

```systemverilog
prog.delete();

for (int reg_index = 1; reg_index < REG_COUNT; reg_index++) begin
    prog.push_back(
        asm_instr(.op(OP_ADDI),
                  .rd(reg_index),
                  .rs1(0),
                  .imm(reg_index))
    );
end

prog.push_back(EBREAK_WORD);
run_directed("register_readback", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x0` | `32'h00000000` | Zero register remains zero |
| `x1` through `x30` | Register index, from `32'h00000001` through `32'h0000001E` | Each ADDI writes its destination register number |
| `x31` | `32'h0000001F` | Last register contains 31 and is read through external address 0x207C |

**Pass criteria:**

All 32 register readbacks match their expected values and are checked by the
scoreboard. No CPU data-memory writes occur. The CPU halts at EBREAK before
timeout, with no scoreboard mismatches or assertion violations.

**Final result:** Pass. Directed suite completed with TEST PASSED! Evidence: saved simulation log

### 1.8 — `reset_during_execution`

**Functionality:**

Checks reset while the CPU is executing, return of memory ownership to the
external port, clearing of architectural registers, and successful execution
of a fresh program after reset.

**Initial state:**

- Registers: Reset
- Data memory: None
- Other setup:
  - Enable register checking in the scoreboard's DUT_RESET handler after clearing expected registers
  - Confirm cpu_active is high before issuing the mid-execution reset
  - Read back all registers after reset
  - Use the run_directed helper for the restart program

**Program:**

```systemverilog
prog.delete();

prog.push_back(
    asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(0))
);

// Keep CPU busy
for (int i = 0; i < 100; i++) begin
    prog.push_back(
        asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(1))
    );
end

prog.push_back(EBREAK_WORD);

sb.set_test("reset_during_execution");
$display("TEST: reset_during_execution");
// Run prog
drv.reset_task();
seqr.load_program(prog);
seqr.wait_for_empty();
repeat (2) @(cpu_if.cb);

drv.start_cpu();
repeat (10) @(cpu_if.cb);

if (cpu_if.cb.cpu_active !== 1'b1) begin
    sb.fail("CPU was not active before reset");
end

drv.reset_task();

if (cpu_if.cb.cpu_active !== 1'b0) begin
    sb.fail("CPU remained active after reset");
end


readback(2, REG_COUNT);

// check execution can restart
prog = '{
    asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(7)),
    EBREAK_WORD
};

run_directed("restart_after_reset", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x0` through `x31`, after mid-execution reset | `32'h00000000` | Reset clears architectural registers |
| `x1`, after restart program | `32'h00000007` | Fresh program executes ADDI successfully |
| `x0` and `x2` through `x31`, after restart program | `32'h00000000` | No instructions modify these registers |

Additionally, cpu_active must be high before the mid-execution reset and low
after reset completes.

**Pass criteria:**

The CPU is confirmed active before reset and inactive afterward. All post-reset
register readbacks are checked and match zero. The restart program reaches
EBREAK before timeout and its register results match. No scoreboard mismatches
or assertion violations occur.

**Final result:** Pass. Directed suite completed with TEST PASSED! Evidence: saved simulation log, including `reset_during_execution` and `restart_after_reset`.

### 1.9 — `backward_branch`

**Functionality:**

Checks that BEQ can receive a negative immediate value and branch backwards.
This increases coverage for branch target output signal for execute.

**Initial state:**

- Registers: Reset
- Data memory: None
- Other setup: Load the program. Configure timeout.

**Program:**

```systemverilog
prog = '{
    asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(-10)),
    asm_instr(.op(OP_BEQ), .rs1(1), .rs2(0), .imm(12)),
    asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(0)),
    asm_instr(.op(OP_BEQ), .rs1(0), .rs2(0), .imm(-8)),
    EBREAK_WORD
};
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x0` | `32'h00000000` | Always 0 |
| `x1` | `32'h00000000` | Changes from -10 to 0 |

**Pass criteria:**

All listed results match. Forward branch taken initially, backward branch always taken,
x1 gets updated 0 so forward branch now taken and backward skipped. No scoreboard mismatches 
or assertion violations occur.

**Final result:** Pass. Directed suite completed with TEST PASSED! evidence: saved simulation log.

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
| `c_imm_range` | Partial | Specifies the range of values the 12 or 13-bit immediate can have | ADDI, LW, SW: range of 12 bit imm. BEQ: range of 13 bit imm with LSB kept 0 |
| `c_mem_align` | Open | Ensures load/store offset is word-aligned to prevent accessing addresses that do not represent the start of a word | reg_snapshot[rs1] + imm % 4 == 0 and restricted based on DSRAM_WORDS |
| `c_imm_unused` | Provided | Set immediate to zero for register-only instructions | No member change |
| `c_branch_target` | Partial | Ensures only forward branching, PC offset is word-aligned, and branch doesn't exceed end of program | Enables forward branching to word-aligned instructions without surpassing end of program to prevent infinite loops |
| `c_no_branch_at_end` | Provided | Prevents a branch from being added to the end of a program | No member change |
| `c_branch_taken_bias` | Open | Provides a weighted distribution making branches happen as commonly as non branches | Bias reg_snapshot[rs1] == reg_snapshot[rs2] so the solver is more likely to select random register indices that result in BEQ taken |

### External-port constraints

| Constraint | Provided, partial, or open | Behavior and purpose | Final implementation summary |
| --- | --- | --- | --- |
| `c_align` | Provided | Ensures memory address provided at the external ports is word-aligned by constraining least significant two bits to zero | No member change |
| `c_valid_window` | Partial | Limit the address window to the memory address which actually exist in that window | Restricted register access addr[11:0] < REG_WORDS * 4. SRAM memory exists perfectly with 12 bits |
| `c_reg_read_only` | Provided | Ensures the register can only be read from external ports | No member change |
| `c_data_corners` | Open | Makes special values and edge cases more likely to occur by adding bias, while still enabling normal 32-bit values | Biased all 0s, all 1s, alternating 1 then 0, and alternating 0 then 1 special patterns eqaully while still maintaining all possible 32 bit values |

### Random-program test

| Item | Plan |
| --- | --- |
| Number of programs per seed | 20 |
| Program-length range | 1-32 |
| Information logged for reproduction | Numeric `SVSEED`, iteration, and complete generated program |

**Implementation outline:**

```systemverilog
int num_instr;
string test_name;

for (int iteration = 0; iteration < 20; iteration++) begin
    num_instr = $urandom_range(32, 1);
    test_name = $sformatf("random_cpu_%0d", iteration);

    sb.set_test(test_name);
    $display("=================================================");
    $display("TEST: %s, seed label=%s, random instructions=%0d", test_name, requested_seed, num_instr);
    $display("=================================================");

    drv.reset_task();
    init_memories();

    // Generate program and wait to finish loading program
    seqr.gen_program(num_instr, 1'b1);
    seqr.wait_for_empty();
    repeat (2) @(cpu_if.cb);

    // Run DUT
    drv.run_program(2000);

    if (drv.last_run_completed) begin
        readback(2, REG_COUNT);
        readback(1, DSRAM_WORDS);
    end else begin
        // Driver records failure
        $display("TB: Skipping %s readback after CPU timeout", test_name);
        drv.reset_task();
    end
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
| 4.3 / `CONTROLS_IDLE_DURING_RESET` | Start, halt, external read, and external write controls remain low during reset | Every rising clock edge and checked while reset is high | Reset at startup and reset during execution |

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

Temporarily asserted r_en while cpu_active was high, reset was low, and
w_en was low. Held the request across a rising clock edge and confirmed
the assertion reported: "External port access requested while CPU was active."

```systemverilog
@(cpu_if.cb);
cpu_if.cb.r_en <= 1'b1;

@(cpu_if.cb);  // Assertion samples
cpu_if.cb.r_en <= 1'b0;

repeat (2) @(cpu_if.cb);
$finish;
```

**Final evidence:**
```
Assertion cpu_tb_top.XBAR_WHEN_CPU_INACTIVE has failed 
xmsim: *E,ERRSEV (./sym_links/cpu_tb_top.sv,52): (time 146855 NS).
cpu_tb_top.assertion_fail
    146855 ASSERT: External port access requested while CPU was active

            (cpu_if.r_en && !cpu_if.rready) |=> (cpu_if.r_en && $stable(cpu_if.addr)))
```

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
- Change addr during a pending DSRAM read while keeping r_en high.
- Repeat with addr held constant and r_en deasserted early.
- Confirm the assertion fires in each case

Change addr
```systemverilog
@(cpu_if.cb);
cpu_if.cb.addr <= word_addr(DSRAM_BASE, 0);
cpu_if.cb.w_en <= 1'b0;
cpu_if.cb.r_en <= 1'b1;

@(cpu_if.cb);
if (cpu_if.cb.rready !== 1'b0) begin
    $fatal(1, "Expected a pending SRAM read for assertion validation");
end

cpu_if.cb.addr <= word_addr(DSRAM_BASE, 1);

@(cpu_if.cb);  // assertion triggers
cpu_if.cb.r_en <= 1'b0;

repeat (2) @(cpu_if.cb);
$finish;
```

Change r_en
```systemverilog
@(cpu_if.cb);
cpu_if.cb.addr <= word_addr(DSRAM_BASE, 0);
cpu_if.cb.w_en <= 1'b0;
cpu_if.cb.r_en <= 1'b1;

@(cpu_if.cb);
if (cpu_if.cb.rready !== 1'b0) begin
    $fatal(1, "Expected a pending SRAM read for assertion validation");
end

cpu_if.cb.r_en <= 1'b0;

@(cpu_if.cb);  // assertion triggers
cpu_if.cb.r_en <= 1'b0;

repeat (2) @(cpu_if.cb);
$finish;
```
Remove all temporary violations and rerun confirm no assertion failures occur.

**Final evidence:**
```
Simulation log in both cases:
Assertion cpu_tb_top.XBAR_READ_HELD_UNTIL_READY has failed (2 cycles, starting 41045 NS)
xmsim: *E,ERRSEV (./sym_links/cpu_tb_top.sv,52): (time 41055 NS).
cpu_tb_top.assertion_fail
     41055 ASSERT: External read request changed before response was observed
```

### 4.3 — `CONTROLS_IDLE_DURING_RESET`

**Timing requirement in words:**

At every rising clock edge, if reset is high, en_cpu, halt_cpu, w_en, and
r_en must all be low. This checks that the testbench does not request CPU
start, external halt, or external memory access during reset.

```systemverilog
CONTROLS_IDLE_DURING_RESET:
  assert property (@(posedge clk)
      rst |-> (!cpu_if.en_cpu && !cpu_if.halt_cpu && !cpu_if.w_en && !cpu_if.r_en))
  else assertion_fail("Start, halt, read, or write request was active during reset");
```

**Evidence that it detects a violation:**
Added a temporary test that asserts reset and en_cpu together while
halt_cpu, w_en, and r_en remain low. The signals are held across a rising
clock edge.

Expected failure message:
"Start, halt, read, or write request was active during reset."

Repeated separately with halt_cpu, w_en, and r_en asserted during reset.
Remove all temporary violations and rerun confirm no assertion failures occur.

```systemverilog
@(cpu_if.cb);
cpu_if.cb.reset    <= 1'b1;
cpu_if.cb.en_cpu   <= 1'b1;  // en_cpu
cpu_if.cb.halt_cpu <= 1'b0;
cpu_if.cb.w_en     <= 1'b0;
cpu_if.cb.r_en     <= 1'b0;

@(cpu_if.cb);  // assertion triggers
cpu_if.cb.en_cpu <= 1'b0;

repeat (2) @(cpu_if.cb);
$finish;
```
Other tests are same program as above but enabling halt_cpu, w_en, r_en.

**Final evidence:**
```
Simulation log in all cases:
Assertion cpu_tb_top.CONTROLS_IDLE_DURING_RESET has failed 
xmsim: *E,ERRSEV (./sym_links/cpu_tb_top.sv,52): (time 41045 NS).
cpu_tb_top.assertion_fail
     41045 ASSERT: Start, halt, read, or write request was active during reset

     41045 Mon: Reset asserted
```

## 4. Encrypted CPU Bug Hunt

### 4.1 Random discovery

| Field                    | Evidence                      |
| ------------------------ | ----------------------------- |
| Discovery command        | `make bug_hunt SEED=random`   |
| Numeric `SVSEED`         | `-2146377026`                 |
| Failing iteration        |  `10`                         |
| First failure message    | `xmsim: *E,ERRSEV (./sym_links/cpu_sb.svh,58): (time 920095 NS).cpu_tb_pkg::cpu_sb.fail 920095 SB: [random_cpu_10] CPU_STORE #1 mismatch: expected DSRAM[261]=0x00000000, actual DSRAM[196]=0x00000000`                                           |
| Reproduction command     | `make bug_hunt SEED=-2146377026` |
| Reproduces consistently? | `Yes`                     |

**Original failing program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_BEQ),  .rs1(11), .rs2(28), .imm(24)),   
  asm_instr(.op(OP_SUB),  .rd(18), .rs1(5), .rs2(1)),      
  asm_instr(.op(OP_SRL),  .rd(3), .rs1(4), .rs2(2)),       
  asm_instr(.op(OP_LW),   .rd(20), .rs1(20), .imm(1192)),  
  asm_instr(.op(OP_LW),   .rd(0), .rs1(2), .imm(128)),     
  asm_instr(.op(OP_BEQ),  .rs1(9), .rs2(6), .imm(8)),      
  asm_instr(.op(OP_LW),   .rd(8), .rs1(2), .imm(1960)),    
  asm_instr(.op(OP_BEQ),  .rs1(2), .rs2(8), .imm(28)),    
  asm_instr(.op(OP_SLL),  .rd(6), .rs1(29), .rs2(7)),     
  asm_instr(.op(OP_SRL),  .rd(7), .rs1(15), .rs2(16)),     
  asm_instr(.op(OP_ADD),  .rd(5), .rs1(0), .rs2(0)),      
  asm_instr(.op(OP_ADDI), .rd(6), .rs1(3), .imm(-1677)),   
  asm_instr(.op(OP_SW),   .rs1(2), .rs2(0), .imm(1044)),  
  asm_instr(.op(OP_LW),   .rd(15), .rs1(5), .imm(1332)),   
  asm_instr(.op(OP_SLL),  .rd(6), .rs1(5), .rs2(18)),     
  asm_instr(.op(OP_BEQ),  .rs1(8), .rs2(4), .imm(28)),     
  asm_instr(.op(OP_SRL),  .rd(1), .rs1(18), .rs2(4)),      
  asm_instr(.op(OP_SW),   .rs1(6), .rs2(6), .imm(784)),    
  asm_instr(.op(OP_BEQ),  .rs1(2), .rs2(5), .imm(4)),      
  asm_instr(.op(OP_SRL),  .rd(6), .rs1(5), .rs2(4)),
  asm_instr(.op(OP_ADD),  .rd(7), .rs1(3), .rs2(5)),
  asm_instr(.op(OP_LW),   .rd(5), .rs1(7), .imm(1236)),
  asm_instr(.op(OP_SRL),  .rd(6), .rs1(4), .rs2(2)),
  asm_instr(.op(OP_SUB),  .rd(5), .rs1(3), .rs2(5)),
  EBREAK_WORD
};
```

### Expected vs. actual

| Instruction / event | Expected | Actual | Cycle/time |
| ------------------- | -------- | ------ | ---------- |
|  lw x8, 1960(x2) | x8 = 0xb883b637  | x8 = 0xb883b637 | 920025 ns |
|  beq x2, x8, 28   | not taken | taken  |     not monitored      |

**First architectural divergence:**

A BEQ instruction using a register that was updated by a LW instruction immediately preceding it results in BEQ being taken

### Minimization

**Minimized reproducer:**

```systemverilog
data = '{32'h00000001}; // data can be any nonzero
preload_dmem(data, 490);
prog = '{
  asm_instr(.op(OP_LW),   .rd(8), .rs1(2), .imm(1960)),
  asm_instr(.op(OP_BEQ),  .rs1(2), .rs2(8), .imm(8)),
  asm_instr(.op(OP_ADDI), .rd(15), .rs1(0), .imm(7)),
  EBREAK_WORD
};
```

### Waveform evidence

![Bug 1 Waveform](<screenshots/bug1 wvf.png>)

### Conclusion

**Trigger:**

A BEQ instruction immediately follows a LW instruction and the rd of the LW is used as a source register in BEQ.

**Expected behavior:**

BEQ uses the updated rd value after loading a word from DSRAM.

**Observed behavior:**

Branch compares the old rd value which may result in the wrong branch behavior.

**Behavioral characterization:**

When a LW instruction immediately precedes a BEQ and the rd is being used as a source register in BEQ, BEQ will not update the register's value to the value most recently loaded in.

### 4.2 Random discovery

| Field                    | Evidence                      |
| ------------------------ | ----------------------------- |
| Discovery command        | `make bug_hunt SEED=random`   |
| Numeric `SVSEED`         | `1152736707`                 |
| Failing iteration        |  `5`                         |
| First failure message    | `xmsim: *E,ERRSEV (./sym_links/cpu_sb.svh,58): (time 555135 NS) cpu_tb_pkg::cpu_sb.fail 555135 SB: [random_cpu_5] read of register x17 returned 0x00000000, expected 0xdd1192f8`                                           |
| Reproduction command     | `make bug_hunt SEED=1152736707` |
| Reproduces consistently? | `Yes`                     |

**Original failing program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADD), .rd(2), .rs1(0), .rs2(30)),     
  asm_instr(.op(OP_BEQ), .rs1(1), .rs2(31), .imm(40)),  
  asm_instr(.op(OP_SLL), .rd(6), .rs1(4), .rs2(8)),       
  asm_instr(.op(OP_ADD), .rd(4), .rs1(2), .rs2(22)),      
  asm_instr(.op(OP_SUB), .rd(3), .rs1(4), .rs2(30)),      
  asm_instr(.op(OP_ADD), .rd(0), .rs1(4), .rs2(11)),     
  asm_instr(.op(OP_SUB), .rd(7), .rs1(4), .rs2(5)),       
  asm_instr(.op(OP_LW), .rd(21), .rs1(3), .imm(1248)),    
  asm_instr(.op(OP_LW), .rd(4), .rs1(0), .imm(1672)),     
  asm_instr(.op(OP_SRL), .rd(0), .rs1(4), .rs2(6)),       
  asm_instr(.op(OP_SUB), .rd(7), .rs1(7), .rs2(5)),       
  asm_instr(.op(OP_BEQ), .rs1(3), .rs2(1), .imm(4)),     
  asm_instr(.op(OP_SRL), .rd(4), .rs1(0), .rs2(7)),       
  asm_instr(.op(OP_SUB), .rd(31), .rs1(1), .rs2(0)),      
  asm_instr(.op(OP_SW), .rs1(2), .rs2(0), .imm(1900)),    
  asm_instr(.op(OP_ADD), .rd(1), .rs1(1), .rs2(6)),       
  asm_instr(.op(OP_SW), .rs1(15), .rs2(15), .imm(1800)),  
  asm_instr(.op(OP_LW), .rd(3), .rs1(14), .imm(692)),     
  asm_instr(.op(OP_SUB), .rd(5), .rs1(6), .rs2(3)),       
  asm_instr(.op(OP_SUB), .rd(0), .rs1(2), .rs2(3)),       
  asm_instr(.op(OP_SW), .rs1(15), .rs2(15), .imm(1172)),  
  asm_instr(.op(OP_LW), .rd(17), .rs1(1), .imm(1748)),    
  asm_instr(.op(OP_ADD), .rd(25), .rs1(16), .rs2(12)),   
  asm_instr(.op(OP_LW), .rd(14), .rs1(1), .imm(1928)),   
  EBREAK_WORD                                          
};
```

### Expected vs. actual

| Instruction / event | Expected | Actual | Cycle/time |
| ------------------- | -------- | ------ | ---------- |
|  sw x15, 1172(x15) | DSRAM[0x125] = 0  | DSRAM[0x125] = 0 | 554685 ns |
|  lw x17, 1748(x1)  | x17 = 0xDD1192F8 | x17 = 0x00000000  | 554705 ns |

**First architectural divergence:**

A LW immediately following a SW loaded 0x00000000 into x17 instead of the value stored DSRAM[437]

### Minimization

**Minimized reproducer:**

```systemverilog
drv.reset_task();
data = '{32'h13579BDF};   // data can be any nonzero
preload_dmem(data, 437);

prog = '{
    asm_instr(.op(OP_ADDI), .rd(15), .rs1(0), .imm(102)),
    asm_instr(.op(OP_SW),   .rs1(0), .rs2(15), .imm(1172)),
    asm_instr(.op(OP_LW),   .rd(17), .rs1(0), .imm(1748)),
    EBREAK_WORD
};
run_directed("store_load_data_source", prog);
```

### Waveform evidence

![Bug 2 Waveform](<screenshots/bug2 wvf.png>)

### Conclusion

**Trigger:**

A LW instruction that immediately follows a SW instruction.

**Expected behavior:**

LW retrieves the value from DSRAM[rs1 + imm] and loads it into rd.

**Observed behavior:**

LW retrieves the value from the previous SW's rs2.

**Behavioral characterization:**

When a SW instruction immediately precedes a LW, LW retrieves the value stored in the previous instruction at the previous dsram_addr instead of the value from the new dsram_addr.

### 4.3 Random discovery

| Field                    | Evidence                      |
| ------------------------ | ----------------------------- |
| Discovery command        | `make bug_hunt SEED=random`   |
| Numeric `SVSEED`         | `-583231952`                 |
| Failing iteration        |  `14`                         |
| First failure message    | `xmsim: *E,ERRSEV (./sym_links/cpu_sb.svh,58): (time 1211305 NS).cpu_tb_pkg::cpu_sb.fail 1211305 SB: [random_cpu_14] CPU_STORE #2 mismatch: expected DSRAM[172]=0x00000000, actual DSRAM[95]=0x00000000`                                       |
| Reproduction command     | `make bug_hunt SEED=-583231952` |
| Reproduces consistently? | `Yes`                     |

**Original failing program:**

```systemverilog
prog = '{
    asm_instr(.op(OP_ADD),  .rd(6),  .rs1(4),  .rs2(1)),
    asm_instr(.op(OP_SUB),  .rd(0),  .rs1(5),  .rs2(17)),
    asm_instr(.op(OP_ADD),  .rd(4),  .rs1(0),  .rs2(29)),
    asm_instr(.op(OP_ADDI), .rd(15), .rs1(7),  .imm(-1002)),
    asm_instr(.op(OP_BEQ),  .rs1(5), .rs2(29), .imm(28)),
    asm_instr(.op(OP_ADDI), .rd(31), .rs1(28), .imm(-1965)),
    asm_instr(.op(OP_ADD),  .rd(22), .rs1(6),  .rs2(2)),
    asm_instr(.op(OP_LW),   .rd(4),  .rs1(5),  .imm(1680)),
    asm_instr(.op(OP_SRL),  .rd(1),  .rs1(7),  .rs2(4)),
    asm_instr(.op(OP_SRL),  .rd(19), .rs1(30), .rs2(7)),
    asm_instr(.op(OP_SLL),  .rd(6),  .rs1(7),  .rs2(3)),
    asm_instr(.op(OP_SW),   .rs1(3), .rs2(4),  .imm(688)),
    asm_instr(.op(OP_SW),   .rs1(1), .rs2(14), .imm(688)),
    asm_instr(.op(OP_SUB),  .rd(1),  .rs1(0),  .rs2(6)),
    asm_instr(.op(OP_ADDI), .rd(4),  .rs1(5),  .imm(337)),
    asm_instr(.op(OP_LW),   .rd(13), .rs1(7),  .imm(272)),
    asm_instr(.op(OP_SLL),  .rd(1),  .rs1(4),  .rs2(30)),
    asm_instr(.op(OP_BEQ),  .rs1(15), .rs2(5), .imm(12)),
    asm_instr(.op(OP_BEQ),  .rs1(15), .rs2(5), .imm(24)),
    asm_instr(.op(OP_ADD),  .rd(3),  .rs1(7),  .rs2(5)),
    asm_instr(.op(OP_ADD),  .rd(6),  .rs1(1),  .rs2(6)),
    asm_instr(.op(OP_ADDI), .rd(0),  .rs1(4),  .imm(-807)),
    asm_instr(.op(OP_BEQ),  .rs1(28), .rs2(4), .imm(16)),
    asm_instr(.op(OP_SLL),  .rd(1),  .rs1(29), .rs2(4)),
    asm_instr(.op(OP_SW),   .rs1(2), .rs2(18), .imm(380)),
    asm_instr(.op(OP_ADD),  .rd(2),  .rs1(20), .rs2(1)),
    asm_instr(.op(OP_SRL),  .rd(3),  .rs1(3),  .rs2(4)),
    asm_instr(.op(OP_ADD),  .rd(5),  .rs1(14), .rs2(6)),
    asm_instr(.op(OP_SW),   .rs1(28), .rs2(2), .imm(4)),
    asm_instr(.op(OP_ADD),  .rd(13), .rs1(7),  .rs2(0)),
    EBREAK_WORD
};
```

### Expected vs. actual

| Instruction / event | Expected | Actual | Cycle/time |
| --- | --- | --- | --- |
| `sw x4, 688(x3)` | DSRAM[0xAC] = 0, first CPU_STORE observation | DSRAM[0xAC] = 0 observed | 1211135 ns |
| `sw x14, 688(x1)` | A second CPU_STORE observation for DSRAM[0xAC], also with data zero | No separate transaction reported and the monitor treats the unchanged request as a continuation | not observed |
| Next observed store | Next queued store is still DSRAM[0xAC] = 0 | DSRAM[0x5F] = 0, causing a store-order mismatch | 1211295 ns |

**First observed divergence:**

There should be two consecutive stores to DSRAM[0xAC], but only one reported. The next observed store therefore mismatches or diverges from the remaining predicted store.

### Minimization

**Minimized reproducer:**

```systemverilog
prog = '{
    asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(17)),
    asm_instr(.op(OP_SW), .rs1(0), .rs2(4), .imm(688)),
    asm_instr(.op(OP_SW), .rs1(0), .rs2(4), .imm(688)),
    EBREAK_WORD
};
```

### Waveform evidence

![Bug 3 Waveform](<screenshots/bug3 wvf.png>)

The encrypted-CPU waveform shows dsram_en and dsram_write_en continuously asserted with dsram_addr = 0x0AC and dsram_wdata = 0x00000011 across the consecutive stores. 

### Conclusion

**Trigger:**

Consecutive SW instructions writing same data to the same DSRAM address.

**Expected behavior:**

Both instructions execute their stores, and the monitor reports two ordered CPU_STORE transactions matching the reference prediction.

**Observed behavior:**

The encrypted CPU presents a continuous, unchanged store request. The monitor reports one transaction, leaving one expected store remaining at halt, leading to a scoreboard mismatch.

**Behavioral characterization:**

The mismatch reproduces when there is back to back SW requests with identical address/data and disappears when the data differs. dsram_en and dsram_write_en do not distinguish two identical consecutive stores from one held request.

## 5. CPU_TB_TOP Coverage
![IMC Coverage](<screenshots/cpu_dut coverage.png>)