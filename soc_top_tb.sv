`timescale 1ns/1ps

module soc_top_tb;

    timeunit 1ns;
    timeprecision 1ps;

    localparam real CLK_PERIOD_NS = 6.666;

    logic clk;
    logic rst_n;

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS/2.0) clk = ~clk;
    end

    logic [1:0]  ext_irq_pad_i;
    logic [31:0] gpio_in_pad;
    logic [31:0] gpio_out_pad;
    logic [31:0] gpio_dir_pad;

    logic uart_rxd;
    logic uart_txd;

    logic spi_slave_sclk;
    logic spi_slave_mosi;
    logic spi_slave_ss_n;
    wire  spi_slave_miso;

    logic spi_master_miso;
    logic spi_master_sclk;
    logic spi_master_mosi;
    logic spi_master_ss_n;

    logic [31:0] debug_pc;
    logic [31:0] debug_alu_result;

    assign uart_rxd = uart_txd;

    assign spi_slave_sclk  = spi_master_sclk;
    assign spi_slave_mosi  = spi_master_mosi;
    assign spi_slave_ss_n  = spi_master_ss_n;
    assign spi_master_miso = spi_slave_miso;

    soc_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .ext_irq_pad_i(ext_irq_pad_i),
        .gpio_in_pad(gpio_in_pad),
        .gpio_out_pad(gpio_out_pad),
        .gpio_dir_pad(gpio_dir_pad),
        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),
        .spi_slave_sclk(spi_slave_sclk),
        .spi_slave_mosi(spi_slave_mosi),
        .spi_slave_miso(spi_slave_miso),
        .spi_slave_ss_n(spi_slave_ss_n),
        .spi_master_sclk(spi_master_sclk),
        .spi_master_mosi(spi_master_mosi),
        .spi_master_miso(spi_master_miso),
        .spi_master_ss_n(spi_master_ss_n),
        .debug_pc(debug_pc),
        .debug_alu_result(debug_alu_result)
    );

    initial begin
        #1;
`ifndef SYNTHESIS
        $display("[ROM0..3] %h %h %h %h",
                 uut.BOOT_ROM.rom_data[0], uut.BOOT_ROM.rom_data[1],
                 uut.BOOT_ROM.rom_data[2], uut.BOOT_ROM.rom_data[3]);
        $display("[ISRAM0..4] %h %h %h %h %h",
                 uut.ISRAM.ram[0], uut.ISRAM.ram[1], uut.ISRAM.ram[2],
                 uut.ISRAM.ram[3], uut.ISRAM.ram[4]);
`endif
    end

    logic saw_valid_pc;
    logic saw_gpio;
    logic saw_uart;
    logic saw_spi;
    logic saw_timer_clic;
    logic saw_plic_clic;
    logic saw_timer_cfg;
    logic test_failed;

    integer dbg_count;

    initial begin
        rst_n         = 1'b0;
        ext_irq_pad_i = 2'b00;
        gpio_in_pad   = 32'h0;

        repeat (30) @(posedge clk);
        rst_n = 1'b1;
    end

    initial begin
        wait(rst_n);
        repeat (1000) @(posedge clk);
        ext_irq_pad_i[0] = 1'b1;
        repeat (200) @(posedge clk);
        ext_irq_pad_i[0] = 1'b0;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            saw_valid_pc   <= 1'b0;
            saw_gpio       <= 1'b0;
            saw_uart       <= 1'b0;
            saw_spi        <= 1'b0;
            saw_timer_cfg  <= 1'b0;
            saw_timer_clic <= 1'b0;
            saw_plic_clic  <= 1'b0;
            test_failed    <= 1'b0;
            dbg_count      <= 0;
        end else begin
            if (!$isunknown(debug_pc))
                saw_valid_pc <= 1'b1;

            if (dbg_count < 120) begin
                $display("[DBG] T=%0t PC=%h ID_INSTR=%h EX_MEM_WR=%b MEM_WR=%b DHWRITE=%b DHTRANS=%b DHADDR=%h DHWDATA=%h DHREADY=%b",
                         $time,
                         debug_pc,
                         uut.CORE.id_instr,
                         uut.CORE.ex_mem_write,
                         uut.CORE.mem_mem_write,
                         uut.dhwrite,
                         uut.dhtrans,
                         uut.dhaddr,
                         uut.dhwdata,
                         uut.dhready_bus);
                dbg_count <= dbg_count + 1;
            end

            if (uut.dhwrite && uut.dhready_bus) begin
                $display("[DBUS WRITE] T=%0t addr=%h data=%h", $time, uut.dhaddr, uut.dhwdata);

                if ((uut.dhaddr == 32'h4000_3000) ||
                    (uut.dhaddr == 32'h4000_3004))
                    saw_gpio <= 1'b1;

                if ((uut.dhaddr == 32'h4000_4008) ||
                    (uut.dhaddr == 32'h4000_400C) ||
                    (uut.dhaddr == 32'h4000_4010))
                    saw_timer_cfg <= 1'b1;
            end

            if (!uut.UART0.u_rx_fifo.empty)
                saw_uart <= 1'b1;

            if (uut.SPI_MASTER.busy || (uut.SPI_SLAVE.stored_data != 32'h0))
                saw_spi <= 1'b1;

            if (saw_timer_cfg && ((uut.timer_irq_bus != 4'b0000) || uut.clic_irq))
                saw_timer_clic <= 1'b1;

            if (uut.plic_irq && uut.clic_irq && uut.CORE.irq_i)
                saw_plic_clic <= 1'b1;

            if ($isunknown(debug_pc))
                test_failed <= 1'b1;
        end
    end

    initial begin
        wait(rst_n);
        #50000000;

        $display("FINAL PC=%h GPIO_OUT=%h GPIO_DIR=%h", debug_pc, gpio_out_pad, gpio_dir_pad);
        $display("FLAGS: valid_pc=%0d gpio=%0d uart=%0d spi=%0d timer_cfg=%0d timer_clic=%0d plic_clic=%0d failed=%0d",
                 saw_valid_pc, saw_gpio, saw_uart, saw_spi, saw_timer_cfg, saw_timer_clic, saw_plic_clic, test_failed);

        if (saw_valid_pc &&
            saw_gpio &&
            saw_uart &&
            saw_spi &&
            saw_timer_cfg &&
            saw_timer_clic &&
            saw_plic_clic &&
            !test_failed)
            $display("[PASS] SOC_BASIC_FUNCTIONAL_TEST");
        else
            $display("[FAIL] SOC_BASIC_FUNCTIONAL_TEST");

        $finish;
    end

endmodule
