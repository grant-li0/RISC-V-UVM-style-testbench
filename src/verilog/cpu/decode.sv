import cpu_pkg::*;

module decode (
    input logic [31:0] instr_i,
    output instr_type_e instr_type_o,
    output logic [31:0] immediate_o
);

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    assign opcode = instr_i[6:0];
    assign funct3 = instr_i[14:12];
    assign funct7 = instr_i[31:25];


    always_comb begin
        instr_type_o = NOP;
        immediate_o = '0;

        case(opcode)
            7'b0010011: begin
                if (funct3 == 3'b000) begin
                    instr_type_o = ADDI;
                    immediate_o = $signed(instr_i[31:20]);
                end
            end
            7'b0110011: begin
                if (funct3 == 3'b000) begin
                    if (funct7 == 7'b0000000) begin
                        instr_type_o = ADD;
                    end else if (funct7 == 7'b0100000) begin
                        instr_type_o = SUB;
                    end
                end else if (funct3 == 3'b001) begin
                    if (funct7 == 7'b0000000) begin
                        instr_type_o = SLL;
                    end
                end else if (funct3 == 3'b101) begin
                    if (funct7 == 7'b0000000) begin
                        instr_type_o = SRL;
                    end
                end
            end
            7'b0000011: begin
                if (funct3 == 3'b010) begin
                    instr_type_o = LOAD;
                    immediate_o = $signed(instr_i[31:20]);
                end
            end
            7'b0100011: begin
                if (funct3 == 3'b010) begin
                    instr_type_o = STORE;
                    immediate_o = $signed({instr_i[31:25], instr_i[11:7]});
                end
            end
            7'b1100011: begin
                if (funct3 == 3'b000) begin
                    instr_type_o = BEQ;
                    immediate_o = $signed({instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0});
                end
            end
        endcase

        if (instr_i == 32'h00100073) begin
            instr_type_o = EBREAK;
        end
    end

endmodule
