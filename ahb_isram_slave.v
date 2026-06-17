`timescale 1ns / 1ps

module ahb_isram_slave #(
    parameter integer ADDR_WIDTH    = 14,
    parameter         MEM_INIT_FILE = ""
)(
    input  wire        HCLK,
    input  wire        HRESETn,
    input  wire        HSEL,
    input  wire [31:0] HADDR,
    input  wire [1:0]  HTRANS,
    input  wire        HWRITE,
    input  wire [2:0]  HSIZE,
    input  wire [31:0] HWDATA,
    input  wire        HREADYin,

    output reg  [31:0] HRDATA,
    output wire        HREADYout,
    output wire [1:0]  HRESP,
    output wire [31:0] sram_rdata_out
);

    localparam integer DEPTH = (1 << ADDR_WIDTH);

    reg [31:0] ram [0:DEPTH-1];
    integer k;

    reg [ADDR_WIDTH-1:0] addr_latched;
    reg                  valid_latched;
    reg                  write_latched;
    reg [2:0]            size_latched;
    reg [1:0]            byte_off_latched;

`ifndef SYNTHESIS
    initial begin
        for (k = 0; k < DEPTH; k = k + 1)
            ram[k] = 32'h00000000;

        if (MEM_INIT_FILE != "") begin
            $display("[MEM] Loading %s", MEM_INIT_FILE);
            $readmemh(MEM_INIT_FILE, ram);
        end
    end
`endif

    // ============================
    // ADDRESS PHASE LATCH
    // ============================
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            addr_latched     <= 0;
            valid_latched    <= 0;
            write_latched    <= 0;
            size_latched     <= 0;
            byte_off_latched <= 0;
        end 
        else if (HREADYin) begin
            valid_latched <= HSEL && HTRANS[1]; // NONSEQ/SEQ

            if (HSEL && HTRANS[1]) begin
                addr_latched     <= HADDR[ADDR_WIDTH+1:2];
                write_latched    <= HWRITE;
                size_latched     <= HSIZE;
                byte_off_latched <= HADDR[1:0];
            end
        end
    end

    // ============================
    // WRITE (DATA PHASE)
    // ============================
    always @(posedge HCLK) begin
        if (valid_latched && write_latched && HREADYin) begin
            case (size_latched)
                3'b010: ram[addr_latched] <= HWDATA;

                3'b001: begin
                    if (byte_off_latched[1])
                        ram[addr_latched][31:16] <= HWDATA[15:0];
                    else
                        ram[addr_latched][15:0]  <= HWDATA[15:0];
                end

                3'b000: begin
                    case (byte_off_latched)
                        2'b00: ram[addr_latched][7:0]   <= HWDATA[7:0];
                        2'b01: ram[addr_latched][15:8]  <= HWDATA[7:0];
                        2'b10: ram[addr_latched][23:16] <= HWDATA[7:0];
                        2'b11: ram[addr_latched][31:24] <= HWDATA[7:0];
                    endcase
                end
            endcase
        end
    end

    // ============================
    // READ (FIXED - CRITICAL)
    // ============================
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            HRDATA <= 32'h00000000;
        else if (valid_latched && !write_latched && HREADYin)
            HRDATA <= ram[addr_latched];
    end

    assign sram_rdata_out = HRDATA;
    assign HREADYout      = 1'b1;   // zero wait-state
    assign HRESP          = 2'b00;  // OKAY

endmodule
