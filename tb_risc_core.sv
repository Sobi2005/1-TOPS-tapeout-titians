`timescale 1ns/1ps

module tb_risc_core;

    timeunit 1ns;
    timeprecision 1ps;

    logic clk;
    logic rst_n;

    // -----------------------------
    // Instruction AHB-lite interface
    // -----------------------------
    wire [31:0] IHADDR;
    wire [1:0]  IHTRANS;
    wire        IHWRITE;
    wire [2:0]  IHSIZE;
    logic [31:0] IHRDATA;
    wire        IHREADY;

    // -----------------------------
    // Data AHB-lite interface
    // -----------------------------
    wire [31:0] DHADDR;
    wire [31:0] DHWDATA;
    wire        DHWRITE;
    wire [2:0]  DHSIZE;
    wire [1:0]  DHTRANS;
    logic [31:0] DHRDATA;
    wire        DHREADY;

    wire [31:0] debug_pc;
    wire [31:0] debug_alu_result;

    // -----------------------------
    // Memories
    // -----------------------------
    logic [31:0] instr_mem [0:1023];
    logic [31:0] data_mem  [0:1023];

    assign IHREADY = 1'b1;
    assign DHREADY = 1'b1;

    integer i;

    initial begin
        $display("[TB] Loading program.mem");
        $readmemh("program.mem", instr_mem);

        for (i = 0; i < 1024; i = i + 1)
            data_mem[i] = 32'h0;
    end

    // -----------------------------
    // Instruction memory model
    // Registered instruction return
    // -----------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            IHRDATA <= 32'h0000_0013; // NOP
        end else begin
            IHRDATA <= instr_mem[IHADDR[11:2]];
        end
    end

    // -----------------------------
    // Data memory model
    // Zero-wait combinational read,
    // synchronous write.
    // -----------------------------
    always @(*) begin
        DHRDATA = data_mem[DHADDR[11:2]];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 1024; i = i + 1)
                data_mem[i] <= 32'h0;
        end else begin
            if (DHTRANS[1] && DHWRITE && DHREADY) begin
                data_mem[DHADDR[11:2]] <= DHWDATA;
            end
        end
    end

    // -----------------------------
    // DUT
    // -----------------------------
    risc_core_top dut (
        .clk(clk),
        .rst_n(rst_n),

        .IHADDR(IHADDR),
        .IHTRANS(IHTRANS),
        .IHWRITE(IHWRITE),
        .IHSIZE(IHSIZE),
        .IHRDATA(IHRDATA),
        .IHREADY(IHREADY),

        .DHADDR(DHADDR),
        .DHWDATA(DHWDATA),
        .DHWRITE(DHWRITE),
        .DHSIZE(DHSIZE),
        .DHTRANS(DHTRANS),
        .DHRDATA(DHRDATA),
        .DHREADY(DHREADY),

        .irq_i(1'b0),
        .irq_id_i(3'b000),
        .irq_ack_o(),

        .debug_pc(debug_pc),
        .debug_alu_result(debug_alu_result)
    );

    // -----------------------------
    // Clock / Reset
    // -----------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
    end

    // -----------------------------
    // Scoreboard flags
    // -----------------------------
    logic saw_valid_pc;
    logic saw_dbus_write;
    logic saw_wb_x21_a5;
    logic saw_wb_x21_ee;
    logic test_done;
    logic test_pass;
    logic test_failed;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            saw_valid_pc    <= 1'b0;
            saw_dbus_write  <= 1'b0;
            saw_wb_x21_a5   <= 1'b0;
            saw_wb_x21_ee   <= 1'b0;
            test_done       <= 1'b0;
            test_pass       <= 1'b0;
            test_failed     <= 1'b0;
        end else begin
            if (!$isunknown(debug_pc))
                saw_valid_pc <= 1'b1;

            if ($time < 2000) begin
                $display("[CORE] T=%0t PC=%h ALU=%h IADDR=%h INSTR=%h",
                         $time, debug_pc, debug_alu_result, IHADDR, IHRDATA);
            end

            if (dut.wb_reg_write_en && dut.wb_rd_addr != 5'd0) begin
                $display("[WB] T=%0t rd=%0d data=%h",
                         $time, dut.wb_rd_addr, dut.wb_write_data);

                if (dut.wb_rd_addr == 5'd21 && dut.wb_write_data == 32'h0000_00A5)
                    saw_wb_x21_a5 <= 1'b1;

                if (dut.wb_rd_addr == 5'd21 && dut.wb_write_data == 32'h0000_00EE)
                    saw_wb_x21_ee <= 1'b1;
            end

            if (DHTRANS[1] && DHWRITE && DHREADY) begin
                saw_dbus_write <= 1'b1;

                $display("[DBUS WRITE] T=%0t addr=%h data=%h",
                         $time, DHADDR, DHWDATA);

                if (DHADDR == 32'h4000_3004 && DHWDATA == 32'h0000_00A5) begin
                    test_done <= 1'b1;
                    test_pass <= 1'b1;
                    $display("[PASS SIGNATURE] addr=%h data=%h", DHADDR, DHWDATA);
                end

                if (DHADDR == 32'h4000_3004 && DHWDATA == 32'h0000_00EE) begin
                    test_done   <= 1'b1;
                    test_failed <= 1'b1;
                    $display("[FAIL SIGNATURE] addr=%h data=%h", DHADDR, DHWDATA);
                end
            end

            if ($isunknown(debug_pc)) begin
                test_failed <= 1'b1;
                $display("[FATAL] debug_pc is X");
            end
        end
    end

    // -----------------------------
    // Final check
    // -----------------------------
    initial begin
        wait(rst_n);

        wait(test_done || test_failed || ($time > 50000));

        $display("");
        $display("===== CORE FUNCTIONAL TEST RESULT =====");
        $display("FINAL PC        = %h", debug_pc);
        $display("FINAL ALU       = %h", debug_alu_result);
        $display("saw_valid_pc    = %0d", saw_valid_pc);
        $display("saw_dbus_write  = %0d", saw_dbus_write);
        $display("saw_wb_x21_a5   = %0d", saw_wb_x21_a5);
        $display("saw_wb_x21_ee   = %0d", saw_wb_x21_ee);
        $display("test_done       = %0d", test_done);
        $display("test_pass       = %0d", test_pass);

        if (!test_failed &&
            saw_valid_pc &&
            saw_dbus_write &&
            saw_wb_x21_a5 &&
            test_done &&
            test_pass)
            $display("[PASS] CORE_FUNCTIONAL_TEST");
        else
            $display("[FAIL] CORE_FUNCTIONAL_TEST");

        $finish;
    end

endmodule
