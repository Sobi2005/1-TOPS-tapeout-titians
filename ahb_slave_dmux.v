`timescale 1ns / 1ps

module ahb_slave_dmux (
    input  wire        HCLK,
    input  wire        HRESETn,
    input  wire        HREADYin,

    input  wire        HSEL_ROM,
    input  wire        HSEL_ISRAM,
    input  wire        HSEL_DSRAM,
    input  wire        HSEL_APB,
    input  wire        HSEL_NOMAP,

    input  wire [31:0] HRDATA_ROM,
    input  wire [31:0] HRDATA_ISRAM,
    input  wire [31:0] HRDATA_DSRAM,
    input  wire [31:0] HRDATA_APB,

    input  wire        HREADY_ROM,
    input  wire        HREADY_ISRAM,
    input  wire        HREADY_DSRAM,
    input  wire        HREADY_APB,

    output reg  [31:0] HRDATA,
    output reg         HREADY,
    output reg  [1:0]  HRESP
);

    // ============================================================
    // PIPELINED SELECT (ADDRESS → DATA PHASE)
    // ============================================================

    reg [4:0] sel_dphase;

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            sel_dphase <= 5'b00000;
        else if (HREADYin)
            sel_dphase <= {HSEL_ROM, HSEL_ISRAM, HSEL_DSRAM, HSEL_APB, HSEL_NOMAP};
    end

    // ============================================================
    // DATA PHASE MUX
    // ============================================================

    always @(*) begin
        HRDATA = 32'h00000000;
        HREADY = 1'b1;
        HRESP  = 2'b00;

        if (sel_dphase[4]) begin
            HRDATA = HRDATA_ROM;
            HREADY = HREADY_ROM;
        end
        else if (sel_dphase[3]) begin
            HRDATA = HRDATA_ISRAM;
            HREADY = HREADY_ISRAM;
        end
        else if (sel_dphase[2]) begin
            HRDATA = HRDATA_DSRAM;
            HREADY = HREADY_DSRAM;
        end
        else if (sel_dphase[1]) begin
            HRDATA = HRDATA_APB;
            HREADY = HREADY_APB;
        end
        else begin
            HRDATA = 32'hDEAD_BEEF;
            HREADY = 1'b1;
            HRESP  = 2'b01; // ERROR
        end
    end

endmodule
