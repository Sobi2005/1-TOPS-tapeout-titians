`timescale 1ns/1ps

module decode_stage_tb;

  reg clk;
  reg rst_n;

  reg [31:0] instr;
  reg [31:0] pc;

  reg        wb_reg_write_en;
  reg [4:0]  wb_rd_addr;
  reg [31:0] wb_data;

  reg        m_unit_busy;
  reg        ex_mem_read;
  reg [4:0]  ex_rd_addr;

  wire [31:0] rdata1;
  wire [31:0] rdata2;
  wire [31:0] imm;

  wire [4:0] rs1_addr;
  wire [4:0] rs2_addr;
  wire [4:0] rd_addr;
  wire [2:0] funct3;
  wire [6:0] funct7;

  wire       reg_write;
  wire       mem_read;
  wire       mem_write;
  wire       alu_src;
  wire       branch;
  wire       jump;
  wire       m_ext;

  wire [1:0] mem_to_reg;
  wire [1:0] op1_src;
  wire [4:0] alu_ctrl;

  wire pc_write;
  wire if_id_write;
  wire ctrl_mux_sel;

  // -------------------------
  // DUT
  // -------------------------
  decode_stage dut (
    .clk(clk),
    .rst_n(rst_n),
    .instr(instr),
    .pc(pc),

    .wb_reg_write_en(wb_reg_write_en),
    .wb_rd_addr(wb_rd_addr),
    .wb_data(wb_data),

    .m_unit_busy(m_unit_busy),
    .ex_mem_read(ex_mem_read),
    .ex_rd_addr(ex_rd_addr),

    .rdata1(rdata1),
    .rdata2(rdata2),
    .imm(imm),
    .rs1_addr(rs1_addr),
    .rs2_addr(rs2_addr),
    .rd_addr(rd_addr),
    .funct3(funct3),
    .funct7(funct7),

    .reg_write(reg_write),
    .mem_read(mem_read),
    .mem_write(mem_write),
    .alu_src(alu_src),
    .branch(branch),
    .jump(jump),
    .m_ext(m_ext),
    .mem_to_reg(mem_to_reg),
    .op1_src(op1_src),
    .alu_ctrl(alu_ctrl),

    .pc_write(pc_write),
    .if_id_write(if_id_write),
    .ctrl_mux_sel(ctrl_mux_sel)
  );

  // -------------------------
  // CLOCK
  // -------------------------
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // -------------------------
  // ASSERTIONS
  // -------------------------

  property no_x_outputs;
    @(posedge clk)
    disable iff (!rst_n)
    !$isunknown({
      rs1_addr, rs2_addr, rd_addr, funct3, funct7,
      reg_write, mem_read, mem_write, alu_src,
      branch, jump, m_ext, mem_to_reg, op1_src,
      alu_ctrl, pc_write, if_id_write, ctrl_mux_sel
    });
  endproperty

  assert property (no_x_outputs)
    else $error("ASSERT_FAIL: decode output has X");

  property instr_fields_match;
    @(posedge clk)
    disable iff (!rst_n)
    (rs1_addr == instr[19:15]) &&
    (rs2_addr == instr[24:20]) &&
    (rd_addr  == instr[11:7])  &&
    (funct3   == instr[14:12]) &&
    (funct7   == instr[31:25]);
  endproperty

  assert property (instr_fields_match)
    else $error("ASSERT_FAIL: decoded fields mismatch instruction bits");

  property load_use_hazard_stalls;
    @(posedge clk)
    disable iff (!rst_n)
    (ex_mem_read && (ex_rd_addr != 5'd0) &&
    ((ex_rd_addr == rs1_addr) || (ex_rd_addr == rs2_addr)))
    |-> (!pc_write && !if_id_write && ctrl_mux_sel);
  endproperty

  assert property (load_use_hazard_stalls)
    else $error("ASSERT_FAIL: load-use hazard did not stall");

  property m_busy_stalls;
    @(posedge clk)
    disable iff (!rst_n)
    m_unit_busy |-> (!pc_write && !if_id_write && ctrl_mux_sel);
  endproperty

  assert property (m_busy_stalls)
    else $error("ASSERT_FAIL: m_unit_busy did not stall");

  property ctrl_mux_kills_controls;
    @(posedge clk)
    disable iff (!rst_n)
    ctrl_mux_sel |-> (
      !reg_write &&
      !mem_read &&
      !mem_write &&
      !branch &&
      !jump &&
      !m_ext &&
      (mem_to_reg == 2'b00) &&
      (op1_src == 2'b00)
    );
  endproperty

  assert property (ctrl_mux_kills_controls)
    else $error("ASSERT_FAIL: ctrl_mux_sel did not kill controls");

  // -------------------------
  // TASKS
  // -------------------------

  task apply_instr(input [31:0] value);
    begin
      @(negedge clk);
      instr = value;
      ex_mem_read = 1'b0;
      ex_rd_addr = 5'd0;
      m_unit_busy = 1'b0;
      @(posedge clk);
      #1;
      $display("T=%0t instr=%h opcode=%b rd=%0d rs1=%0d rs2=%0d reg_wr=%b mem_rd=%b mem_wr=%b branch=%b jump=%b alu_src=%b m_ext=%b imm=%h",
               $time, instr, instr[6:0], rd_addr, rs1_addr, rs2_addr,
               reg_write, mem_read, mem_write, branch, jump, alu_src, m_ext, imm);
    end
  endtask

  task check_i_type;
    begin
      apply_instr(32'h00500093); // addi x1,x0,5
      if (!(reg_write && alu_src && !mem_read && !mem_write && !branch && !jump && rd_addr == 5'd1 && imm == 32'd5))
        $error("CHECK_FAIL: I-type ADDI decode failed");
    end
  endtask

  task check_r_type;
    begin
      apply_instr(32'h002081b3); // add x3,x1,x2
      if (!(reg_write && !alu_src && !mem_read && !mem_write && rd_addr == 5'd3 && rs1_addr == 5'd1 && rs2_addr == 5'd2))
        $error("CHECK_FAIL: R-type ADD decode failed");
    end
  endtask

  task check_load;
    begin
      apply_instr(32'h00052603); // lw x12,0(x10)
      if (!(reg_write && mem_read && !mem_write && alu_src && mem_to_reg == 2'b01 && rd_addr == 5'd12 && rs1_addr == 5'd10))
        $error("CHECK_FAIL: LOAD decode failed");
    end
  endtask

  task check_store;
    begin
      apply_instr(32'h00b52023); // sw x11,0(x10)
      if (!(!reg_write && !mem_read && mem_write && alu_src && rs1_addr == 5'd10 && rs2_addr == 5'd11 && imm == 32'd0))
        $error("CHECK_FAIL: STORE decode failed");
    end
  endtask

  task check_branch;
    begin
      apply_instr(32'h00208663); // beq x1,x2,+12
      if (!(!reg_write && !mem_read && !mem_write && branch && !jump && rs1_addr == 5'd1 && rs2_addr == 5'd2))
        $error("CHECK_FAIL: BRANCH decode failed");
    end
  endtask

  task check_jal;
    begin
      apply_instr(32'h010000ef); // jal x1,+16
      if (!(reg_write && jump && mem_to_reg == 2'b10 && op1_src == 2'b01 && rd_addr == 5'd1))
        $error("CHECK_FAIL: JAL decode failed");
    end
  endtask

  task check_lui;
    begin
      apply_instr(32'h12345bb7); // lui x23,0x12345
      if (!(reg_write && alu_src && rd_addr == 5'd23 && imm == 32'h12345000))
        $error("CHECK_FAIL: LUI decode failed");
    end
  endtask

  task check_mul;
    begin
      apply_instr(32'h022081b3); // mul x3,x1,x2
      if (!(reg_write && m_ext && rd_addr == 5'd3 && rs1_addr == 5'd1 && rs2_addr == 5'd2))
        $error("CHECK_FAIL: M-extension MUL decode failed");
    end
  endtask

  task check_load_use_hazard;
    begin
      @(negedge clk);
      instr = 32'h002081b3; // add x3,x1,x2
      ex_mem_read = 1'b1;
      ex_rd_addr = 5'd1;
      m_unit_busy = 1'b0;

      @(posedge clk);
      #1;

      $display("T=%0t load-use hazard pc_write=%b if_id_write=%b ctrl_mux=%b",
               $time, pc_write, if_id_write, ctrl_mux_sel);

      if (!(pc_write == 1'b0 && if_id_write == 1'b0 && ctrl_mux_sel == 1'b1))
        $error("CHECK_FAIL: load-use hazard stall failed");

      @(negedge clk);
      ex_mem_read = 1'b0;
      ex_rd_addr = 5'd0;
    end
  endtask

  task check_m_busy_hazard;
    begin
      @(negedge clk);
      instr = 32'h00500093; // addi x1,x0,5
      m_unit_busy = 1'b1;
      ex_mem_read = 1'b0;
      ex_rd_addr = 5'd0;

      @(posedge clk);
      #1;

      $display("T=%0t m_busy pc_write=%b if_id_write=%b ctrl_mux=%b",
               $time, pc_write, if_id_write, ctrl_mux_sel);

      if (!(pc_write == 1'b0 && if_id_write == 1'b0 && ctrl_mux_sel == 1'b1))
        $error("CHECK_FAIL: m_unit_busy stall failed");

      @(negedge clk);
      m_unit_busy = 1'b0;
    end
  endtask

  task check_register_file_write_read;
    begin
      @(negedge clk);
      wb_reg_write_en = 1'b1;
      wb_rd_addr = 5'd5;
      wb_data = 32'hCAFE_BABE;
      instr = 32'h00028233; // add x4,x5,x0 -> rs1=x5

      @(posedge clk);
      #1;

      if (rdata1 != 32'hCAFE_BABE)
        $error("CHECK_FAIL: register file write/read forwarding failed. rdata1=%h", rdata1);
      else
        $display("T=%0t RF forwarding PASS rdata1=%h", $time, rdata1);

      @(negedge clk);
      wb_reg_write_en = 1'b0;
      wb_rd_addr = 5'd0;
      wb_data = 32'h0;
    end
  endtask

  // -------------------------
  // STIMULUS
  // -------------------------
  initial begin
    rst_n = 1'b0;
    instr = 32'h0000_0013;
    pc = 32'h0000_0000;

    wb_reg_write_en = 1'b0;
    wb_rd_addr = 5'd0;
    wb_data = 32'h0;

    m_unit_busy = 1'b0;
    ex_mem_read = 1'b0;
    ex_rd_addr = 5'd0;

    repeat (4) @(negedge clk);
    rst_n = 1'b1;

    check_i_type();
    check_r_type();
    check_load();
    check_store();
    check_branch();
    check_jal();
    check_lui();
    check_mul();
    check_load_use_hazard();
    check_m_busy_hazard();
    check_register_file_write_read();

    repeat (5) @(negedge clk);

    $display("[TB PASS] decode_stage assertion/function test completed");
    $finish;
  end

endmodule
