`timescale 1ns / 1ps

module sync_fifo #(
    parameter integer WIDTH = 8,
    parameter integer DEPTH = 16
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             wr_en,
    input  wire [WIDTH-1:0] wr_data,
    input  wire             rd_en,
    output wire [WIDTH-1:0] rd_data,
    output wire             full,
    output wire             empty
);
    localparam integer ADDR_W = (DEPTH <= 2) ? 1 : $clog2(DEPTH);

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_W-1:0] wr_ptr;
    reg [ADDR_W-1:0] rd_ptr;
    reg [ADDR_W:0]   count;

    wire do_write = wr_en && !full;
    wire do_read  = rd_en && !empty;

    assign empty  = (count == {ADDR_W+1{1'b0}});
    assign full   = (count == DEPTH);
    assign rd_data = mem[rd_ptr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= {ADDR_W{1'b0}};
            rd_ptr <= {ADDR_W{1'b0}};
            count  <= {(ADDR_W+1){1'b0}};
        end else begin
            if (do_write) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr <= wr_ptr + 1'b1;
            end

            if (do_read) begin
                rd_ptr <= rd_ptr + 1'b1;
            end

            case ({do_write, do_read})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: ;
            endcase
        end
    end
endmodule
