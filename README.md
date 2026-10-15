# RISC-V CPU Design Verification

SystemVerilog verification of a multicycle RISC-V CPU, completed as part of a design verification onboarding project. The project combines directed testing, constrained-random stimulus, assertion-based verification, and reference-model checking.

The completed testbench achieved a **98.11% DUT overall average coverage grade** and exposed reproducible bugs in a provided encrypted CPU.

## Verification environment

The testbench uses a **UVM-style, class-based architecture** implemented in SystemVerilog. It follows the component organization commonly used in UVM environments without using the UVM library.

```text
Sequencer → Driver → Interface → DUT
                         ↓
                       Monitor → Scoreboard
                                     ↑
                               Reference model
```

- **Sequencer:** Generates instruction programs and external-port transactions.
- **Driver:** Converts transactions into clocked external-port activity and handles reset, execution, halt, and bounded response waits.
- **Interface:** Groups chip-level signals and provides a clocking block for coordinated driving and sampling.
- **Monitor:** Reconstructs external accesses and CPU memory activity into observed transactions.
- **Scoreboard:** Checks observed behavior against tracked memory state and independent reference-model predictions.
- **Reference model:** Executes the supported instruction set to predict final register values, memory contents, and ordered stores.

Programs are loaded into instruction SRAM through the external port. The CPU executes independently after receiving a start pulse; the driver does not issue individual instructions during execution.

## My contributions

Starting from a provided testbench framework, I:

- Completed driver tasks for reset, external reads and writes, CPU start, bounded halt detection, and external halt requests.
- Implemented monitor transaction creation, external-read response matching, and CPU load/store reconstruction.
- Completed scoreboard prediction and checking paths for CPU execution, loads, stores, and normal halt.
- Added instruction and external-access constraints to generate legal, varied stimulus.
- Developed directed tests and constrained-random test sequences.
- Added SystemVerilog Assertions and validated their detection using intentional protocol violations.
- Analyzed coverage and debugged failures using simulation logs and chip-level waveforms.
- Documented the verification plan, results, and bug-hunt experiments in the initial and final test plans.

## Verification strategy

### Directed testing

Directed tests exercise architectural boundaries and chip-level behavior:

| Test | Main focus |
| --- | --- |
| Arithmetic edges | Signed immediates, arithmetic wraparound, and dependent operations |
| Zero register | Discarded writes to x0 and subsequent reads of zero |
| Memory dependencies | Store/load behavior and use of loaded values |
| Branch and halt | Branch decisions, control flow, and EBREAK termination |
| Shift edges | Zero filling, shifts by 31, and low-five-bit shift amounts |
| External memory boundaries | First and last SRAM words and data patterns |
| Register readback | External register-window reads, including x31 |
| Reset during execution | Execution interruption and restart after reset |

### Constrained-random testing

Random CPU programs combine supported instructions while maintaining legal execution conditions. Constraints cover:

- Encodable immediate ranges.
- Word-aligned, in-range effective memory addresses using register snapshots.
- Forward branch targets within the generated program.
- Register selection and branch-outcome distributions.

Each generated program ends with EBREAK. The testbench resets the CPU and initializes memories between programs, applies a bounded execution timeout, and reads back architectural state for checking.

A separate randomized phase exercises the external port while the CPU is inactive. Constraints restrict accesses to valid address windows, preserve alignment, prevent register-file writes, and bias write data toward useful corner values.

Failure reproduction uses the simulator’s numeric seed, test iteration, and generated instruction listing.

### Assertion-based verification

SystemVerilog Assertions check:

- External reads and writes are not asserted simultaneously.
- External access requests occur only while the CPU is inactive.
- Pending reads retain their address and read enable until a response is observed.
- Testbench control requests remain inactive during reset.

Assertions were validated with temporary protocol violations, followed by clean runs with those violations removed.

## Results

| Item | Result |
| --- | --- |
| Member-CPU verification suite | Passed |
| DUT overall average coverage grade | 98.11% |
| Assertion validation | Intentional violations detected; legal suite passed |
| Encrypted-CPU testing | Reproducible failure patterns isolated and documented |

The coverage figure is the simulator-reported **overall average grade for the DUT instance**. It is not the raw percentage of covered items or the coverage grade for the entire testbench hierarchy.

## Encrypted-CPU bug hunt

The completed environment was also applied to a provided encrypted CPU. This exercised the testbench’s ability to detect failures through observable behavior without access to the protected implementation.

Debugging followed this process:

1. Observe a failure during constrained-random testing.
2. Record the numeric simulator seed, iteration, and complete program.
3. Reproduce the failure.
4. Reduce the program and vary nearby instruction patterns.
5. Compare scoreboard diagnostics with chip-level waveform evidence.

Investigated patterns included:

- Incorrect branch behavior following a dependent instruction.
- Incorrect load data when a load immediately follows a store.
- A missing-store observation for consecutive stores with identical address and data.

The consecutive-store finding includes a request-boundary ambiguity between the CPU’s continuous signaling and the monitor’s transaction reconstruction. The report distinguishes observed mismatches from conclusions about internal root causes.

See the final test plan for reproducers, expected-versus-observed behavior, and waveform evidence.

## Repository layout

```text
.
├── README.md
├── gli412_testplan_initial.md
├── gli412_testplan_final.md
├── screenshots/
├── src/
│   └── verilog/
│       ├── tb/
│       └── ... CPU and chip-level sources
└── sim/
    └── behav/
        ├── Makefile
        └── Include/
```

- `src/`: CPU, chip-level RTL, and SystemVerilog testbench sources.
- `sim/behav/`: Simulation configuration and build targets.
- `screenshots/`: Coverage and waveform evidence.
- `gli412_testplan_initial.md`: Planned verification scope.
- `gli412_testplan_final.md`: Completed results and debugging documentation.

## Tools and execution

Tools used:

- SystemVerilog and SystemVerilog Assertions
- Cadence Xcelium
- Cadence SimVision
- GNU Make
- Linux

From `sim/behav/`:

```bash
# Run the member-CPU suite
make xrun

# Open coverage results
make coverage

# Run the provided encrypted CPU
make bug_hunt SEED=random

# Reproduce a recorded seed
make bug_hunt SEED=<numeric_seed>

# Open encrypted-CPU waveforms
make bug_hunt_simvision
```

Execution requires the appropriate Cadence installation, licenses, and source files. Encrypted-CPU targets additionally require the provided protected CPU package.

## Project scope and attribution

This repository builds on an onboarding framework that supplied the component structure, reference model, helper code, and simulation infrastructure. My work focused on completing verification behavior, developing tests and constraints, adding assertions, and analyzing failures.
