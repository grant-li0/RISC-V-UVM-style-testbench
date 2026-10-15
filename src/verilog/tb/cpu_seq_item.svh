/*
 * One randomized instruction used to build a program. Constraints must turn
 * random fields into useful, legal stimulus and keep generated control flow
 * able to reach the ebreak appended by the sequencer.
 *
 * All cpu_seq_item transactions get converted into cpu_xbar_item transactions by
 * the sequencer.
 */
class cpu_seq_item #(int DataSize=32, int AddrSize=14);

    // Randomizable instruction fields
    rand instr_e     op;
    rand logic [4:0] rs1;
    rand logic [4:0] rs2;
    rand logic [4:0] rd;
    rand int         imm;

    // Set by the sequencer before randomize()
    int idx;        // Position of this instruction in the program
    int prog_len;   // Length used by branch constraints

    // Architectural register values when this instruction would execute.
    // The sequencer supplies this context before randomize(). rs1 is still
    // randomized; this array tells a constraint the value of the selected
    // base register without reserving or forcing an address register.
    logic [REG_COUNT-1:0][31:0] reg_snapshot;

    // Keep generated instructions within the supported instruction set
    constraint c_opcode {
        op inside {OP_ADD, OP_ADDI, OP_SUB, OP_SLL, OP_SRL, OP_LW, OP_SW, OP_BEQ};
    }

    // Weighted distributions for registers to increase likelihood of register x0 in testing
    constraint c_reg_bias {
        rd  dist { 0 :/ 5,  [1:7] :/ 70, [8:31] :/ 25 };
        rs1 dist { 0 :/ 10, [1:7] :/ 70, [8:31] :/ 20 };
        rs2 dist { 0 :/ 10, [1:7] :/ 70, [8:31] :/ 20 };
    }

    // Done: Complete the immediate constraint
    constraint c_imm_range {
        (op inside {OP_ADDI, OP_LW, OP_SW}) -> (imm >= -2048) && (imm <= 2047);
        (op == OP_BEQ) -> (imm >= -4096) && (imm <= 4094);
    }

    // Done: Keep each load/store effective byte address word-aligned and
    // inside data SRAM. Checking imm by itself is not sufficient because the
    // address also depends on the runtime value of the randomized rs1.
    // Use reg_snapshot to describe the legal relationship while preserving
    // the existing rs1 distribution; do not solve this by forcing rs1 to x0
    // or to a dedicated address register.
    constraint c_mem_align {
        (op inside {OP_LW, OP_SW}) -> {
            (reg_snapshot[rs1] + imm) % 4 == 0;
            (reg_snapshot[rs1] + imm) <= (DSRAM_WORDS * 4 - 4);
        }
    }

    // Immediate values are constrained to 0 during these register-only instructions
    constraint c_imm_unused {
        (op inside {OP_ADD, OP_SUB, OP_SLL, OP_SRL}) -> imm == 0;
    }

    // Done: Complete the branch constraint to avoid loops
    constraint c_branch_target {
        (op == OP_BEQ) -> (imm % 4 == 0) && (imm >= 4) && (imm <= (prog_len - 1 - idx) * 4);
    }

    // Prevent a branch in the final generated slot
    constraint c_no_branch_at_end {
        (prog_len - idx < 2) -> op != OP_BEQ;
    }

    // Done: Randomly-generated registers rarely compare equal. Bias the operands
    // so both branch outcomes occur often enough to close coverage.
    constraint c_branch_taken_bias {
        (op == OP_BEQ) -> {
            (reg_snapshot[rs1] == reg_snapshot[rs2])
                dist {1'b1 := 50, 1'b0 := 50};
        }
    }

    // Constructor
    function new();
        idx = 0;
        prog_len = 1;
        reg_snapshot = '0;
    endfunction: new

    // Encode the instruction fields into an instruction-memory word
    function logic [31:0] encode();
        logic [31:0] word;
        logic [11:0] i_imm;
        logic [11:0] s_imm;
        logic [12:0] b_imm;

        i_imm = imm[11:0];
        s_imm = imm[11:0];
        b_imm = imm[12:0];
        word = '0;

        case (op)
            OP_ADD: word = {7'b0000000, rs2, rs1, 3'b000, rd, 7'b0110011};
            OP_SUB: word = {7'b0100000, rs2, rs1, 3'b000, rd, 7'b0110011};
            OP_SLL: word = {7'b0000000, rs2, rs1, 3'b001, rd, 7'b0110011};
            OP_SRL: word = {7'b0000000, rs2, rs1, 3'b101, rd, 7'b0110011};
            OP_ADDI: word = {i_imm, rs1, 3'b000, rd, 7'b0010011};
            OP_LW: word = {i_imm, rs1, 3'b010, rd, 7'b0000011};
            OP_SW: word = {s_imm[11:5], rs2, rs1, 3'b010, s_imm[4:0], 7'b0100011};
            OP_BEQ: word = {b_imm[12], b_imm[10:5], rs2, rs1, 3'b000, b_imm[4:1], b_imm[11], 7'b1100011};
            OP_EBREAK: word = EBREAK_WORD;
            default: word = '0;   // Decodes to a NOP
        endcase

        return word;
    endfunction: encode

    // Format the instruction for logs and scoreboard failures
    function string asm();
        case (op)
            OP_ADD: return $sformatf("add x%0d, x%0d, x%0d", rd, rs1, rs2);
            OP_SUB: return $sformatf("sub x%0d, x%0d, x%0d", rd, rs1, rs2);
            OP_SLL: return $sformatf("sll x%0d, x%0d, x%0d", rd, rs1, rs2);
            OP_SRL: return $sformatf("srl x%0d, x%0d, x%0d", rd, rs1, rs2);
            OP_ADDI: return $sformatf("addi x%0d, x%0d, %0d",  rd, rs1, imm);
            OP_LW: return $sformatf("lw x%0d, %0d(x%0d)",  rd, imm, rs1);
            OP_SW: return $sformatf("sw x%0d, %0d(x%0d)",  rs2, imm, rs1);
            OP_BEQ: return $sformatf("beq x%0d, x%0d, %0d",  rs1, rs2, imm);
            OP_EBREAK: return "ebreak";
            default: return "nop";
        endcase
    endfunction: asm

    function void display();
        $display($stime, " Seq: [%0d] 0x%08x  %s\n", idx, encode(), asm());
    endfunction: display

endclass: cpu_seq_item
