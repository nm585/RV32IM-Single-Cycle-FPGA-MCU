# RV32IM full-system waveform layout for the tb_RV32IMscMCU testbench.
# Keep restoring the saved view even if an optional signal is missing.
onerror {resume}
quietly WaveActivateNextPane {} 0

# Start with the top-level clock, reset, CPU activity, memory bus, and board I/O.
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/clk_i
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/rst_i
add wave -noupdate -color Yellow -itemcolor Yellow /tb_rv32imscmcu/CORE/CORE/IFE/reset_sync_q
add wave -noupdate -color Cyan -itemcolor Cyan -radix unsigned -childformat {{/tb_rv32imscmcu/mclk_cnt_o(15) -radix hexadecimal} {/tb_rv32imscmcu/mclk_cnt_o(14) -radix hexadecimal} {/tb_rv32imscmcu/mclk_cnt_o(13) -radix hexadecimal} {/tb_rv32imscmcu/mclk_cnt_o(12) -radix hexadecimal} {/tb_rv32imscmcu/mclk_cnt_o(11) -radix hexadecimal} {/tb_rv32imscmcu/mclk_cnt_o(10) -radix hexadecimal} {/tb_rv32imscmcu/mclk_cnt_o(9) -radix hexadecimal} {/tb_rv32imscmcu/mclk_cnt_o(8) -radix hexadecimal} {/tb_rv32imscmcu/mclk_cnt_o(7) -radix hexadecimal} {/tb_rv32imscmcu/mclk_cnt_o(6) -radix hexadecimal} {/tb_rv32imscmcu/mclk_cnt_o(5) -radix hexadecimal} {/tb_rv32imscmcu/mclk_cnt_o(4) -radix hexadecimal} {/tb_rv32imscmcu/mclk_cnt_o(3) -radix hexadecimal} {/tb_rv32imscmcu/mclk_cnt_o(2) -radix hexadecimal} {/tb_rv32imscmcu/mclk_cnt_o(1) -radix hexadecimal} {/tb_rv32imscmcu/mclk_cnt_o(0) -radix hexadecimal}} -subitemconfig {/tb_rv32imscmcu/mclk_cnt_o(15) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32imscmcu/mclk_cnt_o(14) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32imscmcu/mclk_cnt_o(13) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32imscmcu/mclk_cnt_o(12) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32imscmcu/mclk_cnt_o(11) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32imscmcu/mclk_cnt_o(10) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32imscmcu/mclk_cnt_o(9) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32imscmcu/mclk_cnt_o(8) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32imscmcu/mclk_cnt_o(7) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32imscmcu/mclk_cnt_o(6) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32imscmcu/mclk_cnt_o(5) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32imscmcu/mclk_cnt_o(4) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32imscmcu/mclk_cnt_o(3) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32imscmcu/mclk_cnt_o(2) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32imscmcu/mclk_cnt_o(1) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32imscmcu/mclk_cnt_o(0) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal}} /tb_rv32imscmcu/mclk_cnt_o
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/pc_o
add wave -noupdate -color Blue -itemcolor Blue -radix hexadecimal /tb_rv32imscmcu/instruction_o
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/RegWrite_ctrl_o
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/MemWrite_ctrl_o
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/Branch_ctrl_o
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/read_data1_o
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/read_data2_o
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/write_data_o
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/alu_res_o
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/brTaken_o
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/dtcm_addr_o
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/CORE/dtcm_bus_data_in_w
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/CORE/data_bus_read_w
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/sw_i
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/ledr_o
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/hex0_o
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/hex1_o
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/hex2_o
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/hex3_o
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/hex4_o
add wave -noupdate -radix hexadecimal /tb_rv32imscmcu/hex5_o
TreeUpdate [SetDefaultTree]
quietly WaveActivateNextPane

# Follow the next-PC decision and instruction address through the fetch stage.
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/IFE/clk_i
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/IFE/rst_i
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/IFE/addr_gen_i
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/IFE/Branch_ctrl_i
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/IFE/brTaken_i
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/IFE/Jal_ctrl_i
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/IFE/Jalr_ctrl_i
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/IFE/alu_res_i
add wave -noupdate -expand -group IFETCH -color Magenta -itemcolor Magenta -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/IFE/pc_o
add wave -noupdate -expand -group IFETCH -color Blue -itemcolor Blue -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/IFE/pc_plus4_o
add wave -noupdate -expand -group IFETCH -color Cyan -itemcolor Cyan -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/IFE/next_pc_w
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/IFE/instruction_o
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/IFE/pc_plus4_q
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/IFE/next_pc_plus4_w
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/IFE/itcm_addr_w
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/IFE/branch_redirect_w
TreeUpdate [SetDefaultTree]
quietly WaveActivateNextPane

# Show instruction fields, immediate decoding, and register-file data together.
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/clk_i
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/rst_i
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/pc_plus4_i
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/instruction_i
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/dtcm_data_rd_i
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/alu_res_i
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/RegDst_ctrl_i
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/RegWrite_ctrl_i
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/MemtoReg_ctrl_i
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/read_data1_o
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/read_data2_o
add wave -noupdate -expand -group IDECODE -color Blue -itemcolor Blue -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/SignExt_o
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/writeback_data_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/opcode_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/rs1_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/rs2_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/rd_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/i_imm_bits_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/s_imm_bits_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/b_imm_bits_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/u_imm_bits_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/j_imm_bits_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/i_imm_ext_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/s_imm_ext_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/b_imm_ext_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/u_imm_ext_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/ID/j_imm_ext_w
TreeUpdate [SetDefaultTree]
quietly WaveActivateNextPane

# Expand all 32 registers for quick writeback and software-state checks.
add wave -noupdate -radix hexadecimal -childformat {{/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(0) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(1) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(2) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(3) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(4) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(5) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(6) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(7) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(8) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(9) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(10) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(11) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(12) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(13) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(14) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(15) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(16) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(17) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(18) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(19) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(20) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(21) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(22) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(23) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(24) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(25) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(26) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(27) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(28) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(29) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(30) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(31) -radix hexadecimal}} -expand -subitemconfig {/tb_rv32imscmcu/CORE/CORE/ID/register_file_q(0) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(1) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(2) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(3) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(4) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(5) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(6) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(7) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(8) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(9) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(10) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(11) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(12) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(13) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(14) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(15) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(16) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(17) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(18) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(19) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(20) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(21) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(22) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(23) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(24) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(25) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(26) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(27) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(28) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(29) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(30) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q(31) {-height 15 -radix hexadecimal}} /tb_rv32imscmcu/CORE/CORE/ID/register_file_q
TreeUpdate [SetDefaultTree]
quietly WaveActivateNextPane

# Group the decoded instruction classes and control outputs in one place.
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/instruction_i
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/RegDst_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/ALUSrc_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/MemtoReg_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/RegWrite_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/MemRead_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/MemWrite_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/Branch_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/Jal_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/Jalr_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/UpperIm_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/ALUOp_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/r_type_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/i_type_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/s_type_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/b_type_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/u_type_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/j_type_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/lb_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/lh_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/lw_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/lbu_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/lhu_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/lwu_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/load_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/sb_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/sh_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/sw_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/store_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/beq_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/bne_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/blt_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/bge_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/bltu_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/bgeu_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/branch_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/jal_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/jalr_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/add_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/addi_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/and_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/andi_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/or_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/ori_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/sll_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/slli_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/sra_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/srai_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/srl_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/srli_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/sub_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/xor_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/xori_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/auipc_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/lui_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/slt_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/slti_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/sltu_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/sltiu_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/CTL/opcode_w
TreeUpdate [SetDefaultTree]
quietly WaveActivateNextPane

# Inspect ALU inputs, branch comparisons, and the staged shifter results.
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/read_data1_i
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/read_data2_i
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/UpperIm_ctrl_i
add wave -noupdate -expand -group EXECUTE -radix hexadecimal -childformat {{/tb_rv32imscmcu/CORE/CORE/EXE/ALUOp_ctrl_i(4) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/EXE/ALUOp_ctrl_i(3) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/EXE/ALUOp_ctrl_i(2) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/EXE/ALUOp_ctrl_i(1) -radix hexadecimal} {/tb_rv32imscmcu/CORE/CORE/EXE/ALUOp_ctrl_i(0) -radix hexadecimal}} -subitemconfig {/tb_rv32imscmcu/CORE/CORE/EXE/ALUOp_ctrl_i(4) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/EXE/ALUOp_ctrl_i(3) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/EXE/ALUOp_ctrl_i(2) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/EXE/ALUOp_ctrl_i(1) {-height 15 -radix hexadecimal} /tb_rv32imscmcu/CORE/CORE/EXE/ALUOp_ctrl_i(0) {-height 15 -radix hexadecimal}} /tb_rv32imscmcu/CORE/CORE/EXE/ALUOp_ctrl_i
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/ALUSrc_ctrl_i
add wave -noupdate -expand -group EXECUTE -color {Violet Red} -itemcolor {Violet Red} -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/pc_i
add wave -noupdate -expand -group EXECUTE -color Navy -itemcolor Navy -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/sign_extend_i
add wave -noupdate -expand -group EXECUTE -color Cyan -itemcolor Cyan -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/addr_gen_o
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/subtract_result_w
add wave -noupdate -expand -group EXECUTE -color Magenta -itemcolor Magenta -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/alu_operand_a_w
add wave -noupdate -expand -group EXECUTE -color Blue -itemcolor Blue -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/alu_operand_b_w
add wave -noupdate -expand -group EXECUTE -color Cyan -itemcolor Cyan -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/alu_res_o
add wave -noupdate -expand -group EXECUTE -color {Medium Spring Green} -itemcolor {Medium Spring Green} -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/brTaken_o
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/unsigned_less_than_w
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/operands_equal_w
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/operand_signs_differ_w
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/branch_taken_w
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/alu_result_w
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/shift_left_after_1_w
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/shift_left_after_2_w
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/shift_left_after_4_w
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/shift_left_after_8_w
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/shift_right_after_1_w
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/shift_right_after_2_w
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/shift_right_after_4_w
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/shift_right_after_8_w
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/EXE/shift_right_fill_w
TreeUpdate [SetDefaultTree]
quietly WaveActivateNextPane

# Keep data-memory requests and return data beside the memory controls.
add wave -noupdate -expand -group DMEMORY -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/MEM/clk_i
add wave -noupdate -expand -group DMEMORY -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/MEM/rst_i
add wave -noupdate -expand -group DMEMORY -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/MEM/dtcm_addr_i
add wave -noupdate -expand -group DMEMORY -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/MEM/dtcm_data_wr_i
add wave -noupdate -expand -group DMEMORY -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/MEM/MemRead_ctrl_i
add wave -noupdate -expand -group DMEMORY -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/MEM/MemWrite_ctrl_i
add wave -noupdate -expand -group DMEMORY -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/MEM/dtcm_data_rd_o
add wave -noupdate -expand -group DMEMORY -radix hexadecimal /tb_rv32imscmcu/CORE/CORE/MEM/dtcm_write_clk_w

# Follow the global Address-BUS, resolved Data-BUS and separate controls.
add wave -noupdate -expand -group BUS -radix hexadecimal /tb_rv32imscmcu/CORE/data_bus_w
add wave -noupdate -expand -group BUS -radix hexadecimal /tb_rv32imscmcu/CORE/address_bus_w
add wave -noupdate -expand -group BUS -radix hexadecimal /tb_rv32imscmcu/CORE/bus_mem_read_w
add wave -noupdate -expand -group BUS -radix hexadecimal /tb_rv32imscmcu/CORE/bus_mem_write_w
add wave -noupdate -expand -group BUS -radix hexadecimal /tb_rv32imscmcu/CORE/dtcm_cs_w
add wave -noupdate -expand -group BUS -radix hexadecimal /tb_rv32imscmcu/CORE/dtcm_mem_read_w
add wave -noupdate -expand -group BUS -radix hexadecimal /tb_rv32imscmcu/CORE/dtcm_mem_write_w

# GPIO decoding, bus data, and output latches are grouped for software I/O checks.
add wave -noupdate -expand -group GPIO -radix hexadecimal /tb_rv32imscmcu/CORE/GPIO/rst_i
add wave -noupdate -expand -group GPIO -radix hexadecimal /tb_rv32imscmcu/CORE/GPIO/addr_i
add wave -noupdate -expand -group GPIO -radix hexadecimal /tb_rv32imscmcu/CORE/GPIO/data_wr_i
add wave -noupdate -expand -group GPIO -radix hexadecimal /tb_rv32imscmcu/CORE/GPIO/data_rd_o
add wave -noupdate -expand -group GPIO -radix binary /tb_rv32imscmcu/CORE/GPIO/data_oe_o
add wave -noupdate -expand -group GPIO -radix hexadecimal /tb_rv32imscmcu/CORE/GPIO/mem_read_i
add wave -noupdate -expand -group GPIO -radix hexadecimal /tb_rv32imscmcu/CORE/GPIO/mem_write_i
add wave -noupdate -expand -group GPIO -radix binary /tb_rv32imscmcu/CORE/GPIO/local_a0_w
add wave -noupdate -expand -group GPIO -radix binary /tb_rv32imscmcu/CORE/GPIO/chip_select_w
add wave -noupdate -expand -group GPIO -radix binary /tb_rv32imscmcu/CORE/GPIO/output_write_enable_w
add wave -noupdate -expand -group GPIO -radix binary /tb_rv32imscmcu/CORE/GPIO/sw_read_enable_w
add wave -noupdate -expand -group GPIO -radix hexadecimal /tb_rv32imscmcu/CORE/GPIO/sw_i
add wave -noupdate -group GPIO -radix hexadecimal /tb_rv32imscmcu/CORE/GPIO/ledr_latch_q
add wave -noupdate -group GPIO -radix hexadecimal /tb_rv32imscmcu/CORE/GPIO/hex0_latch_q
add wave -noupdate -group GPIO -radix hexadecimal /tb_rv32imscmcu/CORE/GPIO/hex1_latch_q
add wave -noupdate -group GPIO -radix hexadecimal /tb_rv32imscmcu/CORE/GPIO/hex2_latch_q
add wave -noupdate -group GPIO -radix hexadecimal /tb_rv32imscmcu/CORE/GPIO/hex3_latch_q
add wave -noupdate -group GPIO -radix hexadecimal /tb_rv32imscmcu/CORE/GPIO/hex4_latch_q
add wave -noupdate -group GPIO -radix hexadecimal /tb_rv32imscmcu/CORE/GPIO/hex5_latch_q
TreeUpdate [SetDefaultTree]

# Restore the saved cursors, column sizes, time scale, and useful zoom window.
WaveRestoreCursors {{Cursor 1} {52700000 ps} 1} {{Cursor 2} {52799569 ps} 1}
quietly wave cursor active 1
configure wave -namecolwidth 314
configure wave -valuecolwidth 194
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {52345291 ps} {53965184 ps}

# Preserve the two reference regions used during instruction-level inspection.
bookmark add wave bookmark2 {{36 ps} {116 ps}} 0
bookmark add wave bookmark3 {{0 ps} {1 ns}} 0
