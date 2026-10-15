/*
 * Top-level testbench
 */
module cpu_tb_top;

    import cpu_tb_pkg::*;

    parameter int DataSize = DATA_W;
    parameter int AddrSize = XBAR_AW;

    string requested_seed = "default";

    int assertion_errors = 0;

    logic clk = 0;
    always #5 clk = ~clk;

    // IF instantiation
    cpu_if #(.DataSize(DataSize), .AddrSize(AddrSize)) cpu_if(.clk(clk));

    // DUT instantiation
    chip_top dut (
        .clk_i(clk),
        .rst_i(cpu_if.cpu.reset),
        .en_cpu_i(cpu_if.cpu.en_cpu),
        .halt_cpu_i(cpu_if.cpu.halt_cpu),
        .cpu_halted_o(cpu_if.cpu.cpu_halted),
        .addr_i(cpu_if.cpu.addr),
        .wdata_i(cpu_if.cpu.wdata),
        .w_en_i(cpu_if.cpu.w_en),
        .r_en_i(cpu_if.cpu.r_en),
        .rdata_o(cpu_if.cpu.rdata),
        .rready_o(cpu_if.cpu.rready)
    );

    // Observation signals from the DUT memory path
    assign cpu_if.cpu_active     = dut.cpu_enable_q;
    assign cpu_if.dsram_en       = dut.dsram_en;
    assign cpu_if.dsram_write_en = dut.dsram_write_en;
    assign cpu_if.dsram_addr     = dut.dsram_addr;
    assign cpu_if.dsram_wdata    = dut.dsram_wdata;
    assign cpu_if.dsram_rdata    = dut.dsram_rdata;

    cpu_tb_pkg::cpu_sequencer #(.DataSize(DataSize), .AddrSize(AddrSize)) seqr;
    cpu_tb_pkg::cpu_driver #(.DataSize(DataSize), .AddrSize(AddrSize))    drv;
    cpu_tb_pkg::cpu_monitor #(.DataSize(DataSize), .AddrSize(AddrSize))   mon;
    cpu_tb_pkg::cpu_sb #(.DataSize(DataSize), .AddrSize(AddrSize))        sb;

    // Record failed assertion
    function void assertion_fail(input string message);
        assertion_errors++;
        $error($stime, " ASSERT: %s\n", message);
    endfunction: assertion_fail

    // Initialize both memories through the DUT's external memory port
    task automatic init_memories();
        $display($stime, " TB: Initializing instruction and data memories\n");
        mon.log_transactions = 1'b0;
        sb.log_transactions = 1'b0;
        for (int i = 0; i < ISRAM_WORDS; i++) begin
            seqr.send_write_trans(word_addr(ISRAM_BASE, i), EBREAK_WORD);
        end
        for (int i = 0; i < DSRAM_WORDS; i++) begin
            seqr.send_write_trans(word_addr(DSRAM_BASE, i), $urandom());
        end
        seqr.wait_for_empty();
        repeat (2) @(cpu_if.cb);
        mon.log_transactions = 1'b1;
        sb.log_transactions = 1'b1;
        $display($stime, " TB: Memory initialization complete\n");
    endtask: init_memories

    // Queue external reads on a memory window
    task automatic readback(input int window, input int num_words, input int start_word=0);
        logic [AddrSize-1:0] base;

        case (window)
            0: base = ISRAM_BASE;
            1: base = DSRAM_BASE;
            2: base = REG_BASE;
            default: base = REG_BASE;
        endcase

        for (int i = 0; i < num_words; i++) begin
            seqr.send_read_trans(word_addr(base, start_word + i));
        end
        seqr.wait_for_empty();
        repeat (4) @(cpu_if.cb);
    endtask: readback

    task automatic preload_dmem(input logic [31:0] values [$], input int start_word=0);
        foreach (values[i]) begin
            seqr.send_write_trans(word_addr(DSRAM_BASE, start_word + i), values[i]);
        end
        seqr.wait_for_empty();
        repeat (2) @(cpu_if.cb);
    endtask: preload_dmem

    // Run a directed test
    task automatic run_directed(input string name, const ref logic [31:0] program_words [$],
            input int max_cycles=2000, input int dmem_words=16);
        $display("");
        $display("=================================================================");
        $display(" TEST: %s", name);
        $display("=================================================================");
        sb.set_test(name);

        drv.reset_task();
        seqr.load_program(program_words);
        seqr.wait_for_empty();
        repeat (2) @(cpu_if.cb);
        drv.run_program(max_cycles);

        if (drv.last_run_completed) begin
            readback(2, REG_COUNT);
            readback(1, dmem_words);
        end else begin
            $display($stime, " TB: Skipping %s readback after CPU timeout\n", name);
            drv.reset_task();
        end
    endtask: run_directed

    // Basic smoke test for loading, running, and observing a program that halts
    task automatic run_smoke_test();
        logic [31:0] smoke_prog [$];
        smoke_prog = '{ EBREAK_WORD };
        run_directed("smoke_ebreak", smoke_prog, 100, 1);
    endtask: run_smoke_test

    // Smoke test for stopping the CPU from outside the program
    // Readback is skipped because the CPU stops before the program completes
    task automatic run_external_halt_smoke();
        logic [31:0] long_prog [$];

        for (int i = 0; i < 32; i++) begin
            long_prog.push_back(asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(1)));
        end
        long_prog.push_back(EBREAK_WORD);

        $display("");
        $display("=================================================================");
        $display(" TEST: smoke_external_halt");
        $display("=================================================================");
        sb.set_test("smoke_external_halt");

        drv.reset_task();
        seqr.load_program(long_prog);
        seqr.wait_for_empty();
        repeat (2) @(cpu_if.cb);
        drv.start_cpu();
        repeat (12) @(cpu_if.cb);
        drv.halt_cpu_now();
        drv.reset_task();
    endtask: run_external_halt_smoke

    

    // TEST PROGRAM
    logic [31:0] prog [$];
    logic [31:0] data [$];

    int NUM_RANDOM_PROGRAMS = 20;
    int NUM_RANDOM_XBAR = 300;

    initial begin
        int total_errors;

        mon = new(cpu_if);
        sb = new(mon.mon_box);
        seqr = new();
        drv = new(cpu_if, seqr.xbar_box);

        void'($value$plusargs("NUM_RANDOM_PROGRAMS=%d", NUM_RANDOM_PROGRAMS));
        void'($value$plusargs("NUM_RANDOM_XBAR=%d", NUM_RANDOM_XBAR));
        if ($test$plusargs("REF_TRACE")) begin
            sb.ref_model.trace = 1'b1;
        end

        fork
            mon.run();
            sb.run();
            drv.run();
        join_none

        drv.reset_task();
        init_memories();

        run_smoke_test();
        run_external_halt_smoke();


        // DIRECTED TESTS
        drv.reset_task();
        init_memories();

        // Done: Add directed test cases from the test plan
        // Use the existing helpers
        
        // 1.1 Arithmetic Edges
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
        run_directed("arithmetic_edges", prog);

        // 1.2 Zero Register
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
        run_directed("zero_register", prog);

        // 1.3 Memory Dependencies
        data = '{32'h11223344, 32'h00000000, 32'h55667788};
        preload_dmem(data);
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
        run_directed("memory_dependencies", prog);

        // 1.4 Branch and Halt
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
        run_directed("branch_and_halt", prog);

        // 1.5 Shift Edges
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
        run_directed("shift_edges", prog);

        // 1.6 external_memory_boundaries
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

        // 1.7 register_readback
        prog.delete();

        for (int reg_index = 1; reg_index < REG_COUNT; reg_index++) begin
            prog.push_back(asm_instr(.op(OP_ADDI), .rd(reg_index), .rs1(0), .imm(reg_index)));
        end

        prog.push_back(EBREAK_WORD);
        run_directed("register_readback", prog);

        // 1.8 reset_during_execution
        prog.delete();

        prog.push_back(
            asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(0))
        );

        // Keep CPU busy
        for (int i = 0; i < 100; i++) begin
            prog.push_back(asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(1)));
        end

        prog.push_back(EBREAK_WORD);

        // Run prog
        sb.set_test("reset_during_execution");
        $display("TEST: reset_during_execution");

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

        // 1.9 Backward branch
        prog = '{
            asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(-10)),
            asm_instr(.op(OP_BEQ), .rs1(1), .rs2(0), .imm(12)),
            asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(0)),
            asm_instr(.op(OP_BEQ), .rs1(0), .rs2(0), .imm(-8)),
            EBREAK_WORD
        };
        run_directed("backward_branch", prog);

        // CONSTRAINED-RANDOM TESTS
        // TODO: Add constrained-randomized testing for cpu_seq_item and cpu_xbar_item
        // For every random CPU program:
        //   1. print an iteration label so the seed and failure are reproducible,
        //   2. reset the CPU and call init_memories() before gen_program(),
        //   3. wait for program writes, run with the supplied bounded helper,
        //   4. queue the register and relevant memory reads needed by the scoreboard.
        // Keep randomized external-port traffic in a phase where the CPU is stopped.
        // The README explains why memory must be reinitialized every iteration.
        begin: random_cpu_tests
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
        end

        // Random external port test
        sb.set_test("random_external_port");
        $display("TEST: random_external_port");

        drv.reset_task();
        init_memories();

        seqr.gen_xbar(NUM_RANDOM_XBAR, 1'b1);
        seqr.wait_for_empty();
        repeat (4) @(cpu_if.cb);

        readback(0, ISRAM_WORDS);
        readback(1, DSRAM_WORDS);
        readback(2, REG_COUNT);

        // TEST FINISH
        repeat (20) @(cpu_if.cb);
        total_errors = sb.errors + drv.timeouts + mon.errors + assertion_errors;
        if (sb.checks == 0) begin
            $error("Testbench performed zero checks; no results were verified");
        end

        $display("=================================================================");
        $display("  Scoreboard mismatches : %0d", sb.errors);
        $display("  Driver timeouts       : %0d", drv.timeouts);
        $display("  Monitor protocol errs : %0d", mon.errors);
        $display("  Assertion failures    : %0d", assertion_errors);
        $display("=================================================================");
        $display();

        if (total_errors == 0) begin
            $display("=================================================================");
            $display(" TEST PASSED!");
            $display("=================================================================");
        end else begin
            $display("=================================================================");
            $display(" TEST FAILED: %0d error(s)", total_errors);
            $display("=================================================================");
        end
        $finish;
    end

    // Stop a broken DUT or testbench instead of letting the simulation run forever
    initial begin
        #10ms;
        $display(" TEST FAILED - global timeout");
        $fatal(1, "global timeout");
    end

    initial begin
        void'($value$plusargs("SEED_LABEL=%s", requested_seed));
        if ($test$plusargs("BUG_HUNT_WAVES")) begin
            $shm_open("bug_hunt_waves.shm");
        end else begin
            $shm_open("waves.shm");
        end
        $shm_probe("AC");
    end

    wire rst = cpu_if.reset;
    // Done: Add the required protocol or control assertions from the testplan

    // Example assertion
    // It checks one interface rule and sends failures through the testbench counter
    NO_SIMULTANEOUS_READ_WRITE:
        assert property (@(posedge clk) disable iff (rst)
            !(cpu_if.w_en && cpu_if.r_en))
        else assertion_fail("w_en_i and r_en_i were asserted together");
    
    XBAR_WHEN_CPU_INACTIVE:
        assert property (@(posedge clk) disable iff (rst)
            (cpu_if.w_en || cpu_if.r_en) |-> !cpu_if.cpu_active)
        else assertion_fail("External port access requested while CPU was active");
    
    XBAR_READ_HELD_UNTIL_READY:
        assert property (@(posedge clk) disable iff (rst)
            (cpu_if.r_en && !cpu_if.rready) |=> (cpu_if.r_en && $stable(cpu_if.addr)))
        else assertion_fail("External read request changed before response was observed");
    
    CONTROLS_IDLE_DURING_RESET:
        assert property (@(posedge clk)
            rst |-> (!cpu_if.en_cpu && !cpu_if.halt_cpu && !cpu_if.w_en && !cpu_if.r_en))
        else assertion_fail("Start, halt, read, or write request was active during reset");

endmodule: cpu_tb_top
