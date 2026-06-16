`timescale 1ns/1ps

// ===== DEFINES (INLINE) =====
`define ALU_ADD  4'd0
`define ALU_SUB  4'd1
`define ALU_SLL  4'd2
`define ALU_SLT  4'd3
`define ALU_SLTU 4'd4
`define ALU_XOR  4'd5
`define ALU_SRL  4'd6
`define ALU_SRA  4'd7
`define ALU_OR   4'd8
`define ALU_AND  4'd9
`define ALU_LUI  4'd10
`define ALU_AUIPC 4'd11

`define MU_MUL   3'd0
`define MU_MULH  3'd1
`define MU_MULHSU 3'd2
`define MU_MULHU 3'd3
`define MU_DIV   3'd4
`define MU_DIVU  3'd5
`define MU_REM   3'd6
`define MU_REMU  3'd7

`define WB_ALU 2'd0

module ex_stage (
    input  wire clk,
    input  wire rst_n,
    input  wire flush_ex,

    input  wire [31:0] id_ex_pc,
    input  wire [31:0] id_ex_pc4,
    input  wire [31:0] id_ex_rs1_data,
    input  wire [31:0] id_ex_rs2_data,
    input  wire [4:0]  id_ex_rs1,
    input  wire [4:0]  id_ex_rs2,
    input  wire [4:0]  id_ex_rd,
    input  wire [31:0] id_ex_imm,
    input  wire [3:0]  id_ex_alu_op,
    input  wire [2:0]  id_ex_mu_op,
    input  wire        id_ex_alu_src,
    input  wire        id_ex_mem_read,
    input  wire        id_ex_mem_write,
    input  wire [2:0]  id_ex_mem_size,
    input  wire        id_ex_reg_write,
    input  wire [1:0]  id_ex_wb_sel,
    input  wire        id_ex_is_muldiv,
    input  wire        id_ex_auipc,

    input  wire [31:0] fwd_mem_result,
    input  wire [31:0] fwd_wb_data,

    output wire div_stall,

    output reg [31:0] ex_mem_alu_result,
    output reg [31:0] ex_mem_rs2_data,
    output reg [31:0] ex_mem_pc4,
    output reg [4:0]  ex_mem_rd,
    output reg [2:0]  ex_mem_mem_size,
    output reg        ex_mem_mem_read,
    output reg        ex_mem_mem_write,
    output reg        ex_mem_reg_write,
    output reg [1:0]  ex_mem_wb_sel
);

    // ===== SIMPLE EXECUTION =====
    wire [31:0] op_a = id_ex_auipc ? id_ex_pc : id_ex_rs1_data;
    wire [31:0] op_b = id_ex_alu_src ? id_ex_imm : id_ex_rs2_data;

    reg [31:0] alu_result;

    always @(*) begin
        case(id_ex_alu_op)
            `ALU_ADD: alu_result = op_a + op_b;
            `ALU_SUB: alu_result = op_a - op_b;
            `ALU_SLL: alu_result = op_a << op_b[4:0];
            `ALU_SLT: alu_result = ($signed(op_a) < $signed(op_b)) ? 32'd1 : 32'd0;
            `ALU_SLTU: alu_result = (op_a < op_b) ? 32'd1 : 32'd0;
            `ALU_XOR: alu_result = op_a ^ op_b;
            `ALU_SRL: alu_result = op_a >> op_b[4:0];
            `ALU_SRA: alu_result = $signed(op_a) >>> op_b[4:0];
            `ALU_OR : alu_result = op_a | op_b;
            `ALU_AND: alu_result = op_a & op_b;
            `ALU_LUI: alu_result = id_ex_imm;
            `ALU_AUIPC: alu_result = id_ex_pc + id_ex_imm;
            default : alu_result = op_a + op_b;
        endcase
    end

    assign div_stall = 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_alu_result <= 0;
            ex_mem_rs2_data   <= 0;
            ex_mem_pc4        <= 4;
            ex_mem_rd         <= 0;
            ex_mem_mem_size   <= 0;
            ex_mem_mem_read   <= 0;
            ex_mem_mem_write  <= 0;
            ex_mem_reg_write  <= 0;
            ex_mem_wb_sel     <= `WB_ALU;
        end else if (flush_ex) begin
            ex_mem_alu_result <= 0;
            ex_mem_rs2_data   <= 0;
            ex_mem_pc4        <= 4;
            ex_mem_rd         <= 0;
            ex_mem_mem_size   <= 0;
            ex_mem_mem_read   <= 0;
            ex_mem_mem_write  <= 0;
            ex_mem_reg_write  <= 0;
            ex_mem_wb_sel     <= `WB_ALU;
        end else begin
            ex_mem_alu_result <= alu_result;
            ex_mem_rs2_data   <= id_ex_rs2_data;
            ex_mem_pc4        <= id_ex_pc4;
            ex_mem_rd         <= id_ex_rd;
            ex_mem_mem_size   <= id_ex_mem_size;
            ex_mem_mem_read   <= id_ex_mem_read;
            ex_mem_mem_write  <= id_ex_mem_write;
            ex_mem_reg_write  <= id_ex_reg_write;
            ex_mem_wb_sel     <= id_ex_wb_sel;
        end
    end

endmodule
