`timescale 1ns/1ps

module fetch_stage_tb;

  reg clk;
  reg rst_n;

  reg branch_taken;
  reg jump;
  reg [31:0] branch_target;
  reg [31:0] jump_target;
  reg stall_all;

  wire [31:0] IHADDR;
  wire [1:0]  IHTRANS;
  wire        IHWRITE;
  wire [2:0]  IHSIZE;
  reg         IHREADY;
  reg [31:0]  IHRDATA;

  wire [31:0] pc_out;
  wire [31:0] instr_out;

  // -------------------------
  // DUT
  // -------------------------
  fetch_stage dut (
    .clk(clk),
    .rst_n(rst_n),

    .branch_taken(branch_taken),
    .jump(jump),
    .branch_target(branch_target),
    .jump_target(jump_target),

    .stall_all(stall_all),

    .IHADDR(IHADDR),
    .IHTRANS(IHTRANS),
    .IHWRITE(IHWRITE),
    .IHSIZE(IHSIZE),
    .IHREADY(IHREADY),
    .IHRDATA(IHRDATA),

    .pc_out(pc_out),
    .instr_out(instr_out)
  );

  // -------------------------
  // CLOCK
  // -------------------------
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // -------------------------
  // PAST VALID GUARD
  // Avoid false assertion immediately after reset.
  // -------------------------
  reg [1:0] past_valid_cnt;
  wire past_valid = past_valid_cnt[1];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      past_valid_cnt <= 2'b00;
    else if (!past_valid)
      past_valid_cnt <= past_valid_cnt + 2'b01;
  end

  // -------------------------
  // ASSERTIONS
  // -------------------------

  property pc_internal_inc;
    @(posedge clk)
    disable iff (!rst_n || !past_valid)
    $past(IHREADY && !stall_all && !branch_taken && !jump)
    |-> (dut.pc == $past(dut.pc) + 32'd4);
  endproperty

  assert property (pc_internal_inc)
    else $error("ASSERT_FAIL: PC did not increment by 4");

  property branch_check;
    @(posedge clk)
    disable iff (!rst_n || !past_valid)
    $past(IHREADY && !stall_all && branch_taken)
    |-> (dut.pc == $past(branch_target));
  endproperty

  assert property (branch_check)
    else $error("ASSERT_FAIL: Branch target not loaded into PC");

  property jump_check;
    @(posedge clk)
    disable iff (!rst_n || !past_valid)
    $past(IHREADY && !stall_all && !branch_taken && jump)
    |-> (dut.pc == $past(jump_target));
  endproperty

  assert property (jump_check)
    else $error("ASSERT_FAIL: Jump target not loaded into PC");

  property stall_check;
    @(posedge clk)
    disable iff (!rst_n || !past_valid)
    $past(stall_all)
    |-> (dut.pc == $past(dut.pc));
  endproperty

  assert property (stall_check)
    else $error("ASSERT_FAIL: PC changed during stall");

  property ihready_wait_check;
    @(posedge clk)
    disable iff (!rst_n || !past_valid)
    $past(!IHREADY)
    |-> (dut.pc == $past(dut.pc));
  endproperty

  assert property (ihready_wait_check)
    else $error("ASSERT_FAIL: PC changed while IHREADY low");

  property ihaddr_matches_pc;
    @(posedge clk)
    disable iff (!rst_n)
    IHADDR == dut.pc;
  endproperty

  assert property (ihaddr_matches_pc)
    else $error("ASSERT_FAIL: IHADDR does not match internal PC");

  property ahb_outputs_const;
    @(posedge clk)
    disable iff (!rst_n)
    (IHWRITE == 1'b0) && (IHSIZE == 3'b010);
  endproperty

  assert property (ahb_outputs_const)
    else $error("ASSERT_FAIL: Bad AHB fetch output controls");

  property pc_not_x;
    @(posedge clk)
    disable iff (!rst_n)
    !$isunknown(dut.pc);
  endproperty

  assert property (pc_not_x)
    else $error("ASSERT_FAIL: PC became X");

  property instr_not_x_when_ready;
    @(posedge clk)
    disable iff (!rst_n)
    (IHREADY && !stall_all) |-> !$isunknown(instr_out);
  endproperty

  assert property (instr_not_x_when_ready)
    else $error("ASSERT_FAIL: instr_out became X when ready");

  // -------------------------
  // DEBUG PRINT
  // -------------------------
  always @(posedge clk) begin
    if (rst_n) begin
      $display("T=%0t | pc=%h | pc_out=%h | IHADDR=%h | IHREADY=%b | stall=%b | branch=%b | jump=%b",
        $time, dut.pc, pc_out, IHADDR, IHREADY, stall_all, branch_taken, jump);
    end
  end

  // -------------------------
  // STIMULUS
  // Drive controls on negedge to avoid posedge race.
  // -------------------------
  initial begin
    rst_n         = 1'b0;
    branch_taken  = 1'b0;
    jump          = 1'b0;
    branch_target = 32'h0000_0000;
    jump_target   = 32'h0000_0000;
    stall_all     = 1'b0;
    IHREADY       = 1'b1;
    IHRDATA       = 32'h0000_0013;

    repeat (4) @(negedge clk);
    rst_n = 1'b1;

    // NORMAL FLOW
    repeat (5) @(negedge clk);

    // STALL CASE
    stall_all = 1'b1;
    repeat (3) @(negedge clk);
    stall_all = 1'b0;

    // NORMAL ONE CYCLE
    repeat (2) @(negedge clk);

    // BRANCH CASE
    branch_target = 32'h0001_0100;
    branch_taken  = 1'b1;
    @(negedge clk);
    branch_taken  = 1'b0;

    // NORMAL
    repeat (4) @(negedge clk);

    // JUMP CASE
    jump_target = 32'h0001_0200;
    jump        = 1'b1;
    @(negedge clk);
    jump        = 1'b0;

    // NORMAL
    repeat (3) @(negedge clk);

    // IHREADY LOW CASE
    IHREADY = 1'b0;
    repeat (3) @(negedge clk);
    IHREADY = 1'b1;

    repeat (5) @(negedge clk);

    $display("[TB PASS] fetch_stage assertion test completed");
    $finish;
  end

endmodule
