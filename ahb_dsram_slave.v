`timescale 1ns / 1ps

module ahb_dsram_slave #(
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
    output wire [31:0] HRDATA,
    output wire        HREADYout,
    output wire [1:0]  HRESP,
    output wire [31:0] sram_rdata_out
);

    localparam integer DEPTH = (1 << ADDR_WIDTH);

    reg [31:0] ram [0:DEPTH-1];
    integer k;

    wire trans_valid = HSEL & HTRANS[1] & HREADYin;
    wire [ADDR_WIDTH-1:0] word_addr = HADDR[ADDR_WIDTH+1:2];

`ifndef SYNTHESIS
    initial begin
        for (k = 0; k < DEPTH; k = k + 1)
            ram[k] = 32'h0000_0000;
        if (MEM_INIT_FILE != "")
            $readmemh(MEM_INIT_FILE, ram);
    end
`endif

    assign HRDATA         = ram[word_addr];
    assign sram_rdata_out = HRDATA;
    assign HREADYout      = 1'b1;
    assign HRESP          = 2'b00;

    always @(posedge HCLK) begin
        if (trans_valid && HWRITE) begin
            case (HSIZE)
                3'b010: ram[word_addr] <= HWDATA;
                3'b001: begin
                    if (HADDR[1]) ram[word_addr][31:16] <= HWDATA[15:0];
                    else          ram[word_addr][15:0]  <= HWDATA[15:0];
                end
                3'b000: begin
                    case (HADDR[1:0])
                        2'b00: ram[word_addr][7:0]   <= HWDATA[7:0];
                        2'b01: ram[word_addr][15:8]  <= HWDATA[7:0];
                        2'b10: ram[word_addr][23:16] <= HWDATA[7:0];
                        2'b11: ram[word_addr][31:24] <= HWDATA[7:0];
                        default: ;
                    endcase
                end
                default: ram[word_addr] <= HWDATA;
            endcase
        end
    end

endmodule
