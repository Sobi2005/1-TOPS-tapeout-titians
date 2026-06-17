`timescale 1ns / 1ps

module execute_stage_tb;

    // ================= SIGNALS =================
    reg clk;
    reg rst_n;

    reg [31:0] ex_pc;
    reg [31:0] rdata1, rdata2;
    reg [31:0] imm;

    reg [2:0] funct3;
    reg [6:0] funct7;

    reg [4:0] alu_ctrl;
    reg [1:0] op1_src;
    reg       alu_src_ctrl;
    reg       m_ext_ctrl;
    reg       jump_ctrl;
    reg       branch_ctrl;

    reg [31:0] mem_alu_result;
    reg [31:0] wb_data;
    reg [1:0]  forward_a;
    reg [1:0]  forward_b;

    wire [31:0] final_result;
    wire [31:0] branch_target;
    wire [31:0] jump_target;
    wire        branch_taken;
    wire        m_unit_busy;
    wire [31:0] fwd_rs2_out;

    // ================= DUT =================
    execute_stage dut (
        .*   // connects all signals automatically
    );

    // ================= CLOCK =================
    always #5 clk = ~clk;

    // ================= RESET =================
    task reset_dut();
    begin
        rst_n = 0;
        #20;
        rst_n = 1;
    end
    endtask

    // ================= INIT =================
    initial begin
        clk = 0;

        reset_dut();

        // Default values
        ex_pc = 32'h1000;
        rdata1 = 10;
        rdata2 = 5;
        imm = 4;

        alu_ctrl = 5'b00000; // ADD
        op1_src = 0;
        alu_src_ctrl = 0;
        m_ext_ctrl = 0;
        jump_ctrl = 0;
        branch_ctrl = 0;

        forward_a = 2'b00;
        forward_b = 2'b00;

        mem_alu_result = 20;
        wb_data = 30;

        funct3 = 3'b000;
        funct7 = 7'b0000000;

        // Run tests
        #10 test_add();
        #10 test_forwarding();
        #10 test_branch_beq();
        #10 test_branch_bne();
        #10 test_jump();
        #10 test_m_extension();

        #50;
        $display("ALL TESTS DONE");
        $finish;
    end

    // ================= TESTS =================

    // -------- ADD --------
    task test_add();
    begin
        $display("TEST: ADD");

        alu_src_ctrl = 0;
        op1_src = 0;

        rdata1 = 15;
        rdata2 = 5;

        #10;

        if (final_result !== 20)
            $error("ADD FAILED: %h", final_result);
    end
    endtask


    // -------- FORWARDING --------
    task test_forwarding();
    begin
        $display("TEST: FORWARDING");

        forward_a = 2'b10; // from MEM
        forward_b = 2'b01; // from WB

        #10;

        if (fwd_rs2_out !== wb_data)
            $error("Forwarding B FAILED");
    end
    endtask


    // -------- BEQ --------
    task test_branch_beq();
    begin
        $display("TEST: BEQ");

        branch_ctrl = 1;
        funct3 = 3'b000;

        rdata1 = 10;
        rdata2 = 10;

        alu_src_ctrl = 0;

        #10;

        if (!branch_taken)
            $error("BEQ FAILED");
    end
    endtask


    // -------- BNE --------
    task test_branch_bne();
    begin
        $display("TEST: BNE");

        branch_ctrl = 1;
        funct3 = 3'b001;

        rdata1 = 10;
        rdata2 = 5;

        #10;

        if (!branch_taken)
            $error("BNE FAILED");
    end
    endtask


    // -------- JUMP --------
    task test_jump();
    begin
        $display("TEST: JUMP");

        jump_ctrl = 1;
        funct3 = 3'b000;

        imm = 8;

        #10;

        if (jump_target !== ((rdata1 + imm) & 32'hFFFF_FFFE))
            $error("JUMP FAILED");
    end
    endtask


    // -------- M EXT --------
    task test_m_extension();
    begin
        $display("TEST: M EXT");

        m_ext_ctrl = 1;

        rdata1 = 6;
        rdata2 = 3;

        #20; // M unit may take time

        if (final_result == 0)
            $error("M EXT FAILED");
    end
    endtask


    // ================= ASSERTIONS =================

    // ALU input B check
    property alu_b_sel;
        @(posedge clk)
        disable iff (!rst_n)
        alu_src_ctrl |-> (dut.alu_in_b == imm);
    endproperty

    assert property (alu_b_sel)
        else $error("ALU B SEL FAILED");

    // Forwarding check
    property forward_check_a;
        @(posedge clk)
        disable iff (!rst_n)
        (forward_a == 2'b10) |-> (dut.fwd_rs1 == mem_alu_result);
    endproperty

    assert property (forward_check_a)
        else $error("FORWARD A FAILED");

endmodule
