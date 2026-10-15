import cpu_pkg::*;

module execute (
    input logic [31:0] pc_i,
    input instr_type_e instr_type_i,
    input logic [31:0] immediate_i,
    input logic [31:0] rs1_data_i,
    input logic [31:0] rs2_data_i,


    output logic [31:0] rd_data_o,
    output logic rd_write_en_o,
    output logic [31:0] mem_addr_o,

    output logic branch_taken_o,
    output logic [31:0] branch_trgt_o
);

    always_comb begin
        rd_write_en_o = 1'b0;
        rd_data_o = '0;
        mem_addr_o = '0;
        branch_taken_o = '0;
        branch_trgt_o = '0;

        case(instr_type_i)
            ADD: begin
                rd_write_en_o = 1'b1;
                rd_data_o = rs1_data_i + rs2_data_i;
            end
            ADDI: begin
                rd_write_en_o = 1'b1;
                rd_data_o = rs1_data_i + immediate_i;
            end
            SUB: begin
                rd_write_en_o = 1'b1;
                rd_data_o = rs1_data_i - rs2_data_i;
            end
            SLL: begin
                rd_write_en_o = 1'b1;
                rd_data_o = rs1_data_i << rs2_data_i[4:0];
            end
            SRL: begin
                rd_write_en_o = 1'b1;
                rd_data_o = rs1_data_i >> rs2_data_i[4:0];
            end
            LOAD: begin
                mem_addr_o = rs1_data_i + immediate_i;
            end
            STORE: begin
                mem_addr_o = rs1_data_i + immediate_i;
            end
            BEQ: begin
                if (rs1_data_i == rs2_data_i) begin
                    branch_taken_o = 1'b1;
                    branch_trgt_o = pc_i + immediate_i;
                end
            end
        endcase
    end

endmodule