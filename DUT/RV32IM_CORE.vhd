--============================================================================
-- Copyright 2026 Hananya Ribo
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- Structural model of the single-cycle RV32IM core.
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;
USE work.cond_compilation_package.all;
USE work.aux_package.all;


ENTITY RV32IM_CORE IS
	generic(
			WORD_GRANULARITY 	: boolean 	:= G_WORD_GRANULARITY;
	    MODELSIM 					: integer 	:= G_MODELSIM;
			DATA_BUS_WIDTH 		: integer 	:= 32;
			ITCM_ADDR_WIDTH 	: integer 	:= G_ADDRWIDTH;
			DTCM_ADDR_WIDTH 	: integer 	:= G_ADDRWIDTH;
			PC_WIDTH 					: integer 	:= G_PC_WIDTH;
			MA_WIDTH 					: integer 	:= G_MA_WIDTH;
			DATA_WORDS_NUM 		: integer 	:= G_DATA_WORDSNUM;
			CLK_CNT_WIDTH 		: integer 	:= 16
	);
	PORT(
		-- Core clock and reset.
		mclk_i						:IN	STD_LOGIC;
		mclk_rst_i				:IN	STD_LOGIC;

		-- Directional connections to the external shared-bus adapters.
		data_bus_read_i		:IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		dtcm_data_wr_i		:IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		dtcm_mem_read_i		:IN	STD_LOGIC;
		dtcm_mem_write_i	:IN	STD_LOGIC;

		-- DTCM output path and address observation point.
		dtcm_data_rd_o			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		dtcm_addr_o				:OUT	STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);

		-- Divider status and results.
		divbusy_i					:IN	STD_LOGIC;
		div_quotient_i		:IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		div_residue_i			:IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

		-- Interrupt request.
		intr_i						:IN	STD_LOGIC;

		-- Memory bus commands.
		MemRead_ctrl_o		:OUT 	STD_LOGIC;
		MemWrite_ctrl_o		:OUT 	STD_LOGIC;
		DIVENA_o					:OUT 	STD_LOGIC;
		REMU_ctrl_o				:OUT 	STD_LOGIC;

		-- Interrupt handshake.
		gie_o							:OUT 	STD_LOGIC;
		inta_n_o					:OUT 	STD_LOGIC;
		int_busy_o				:OUT 	STD_LOGIC;
		int_dispatch_o		:OUT 	STD_LOGIC;

		-- Divider operands and memory address/data outputs.
		read_data1_o 			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		read_data2_o 			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		alu_res_o 				:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

		-- Verification probes.
		pc_o							:OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		instruction_o			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		RegWrite_ctrl_o		:OUT 	STD_LOGIC;
		Branch_ctrl_o			:OUT 	STD_LOGIC;
		write_data_o			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		brTaken_o					:OUT 	STD_LOGIC;
		mclk_cnt_o				:OUT	STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0)
	);
END RV32IM_CORE;
--============================================================================
ARCHITECTURE structural OF RV32IM_CORE IS
	-- Instruction and datapath signals.
	SIGNAL pc_w 					: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL pc_plus4_w 		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL next_pc_w			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL read_data1_w 	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL read_data2_w 	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL sign_extend_w 	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL addr_gen_w 		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL alu_res_w 			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL mul_res_w 			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL m_extension_res_w : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL writeback_res_w 	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	-- Local DTCM address and read-data path.
	SIGNAL dtcm_addr_w 			: STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL dtcm_data_rd_w		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL dtcm_byte_addr_w	: STD_LOGIC_VECTOR(MA_WIDTH-1 DOWNTO 0);

	-- Control signals.
	SIGNAL alu_src_w 			: STD_LOGIC;
	SIGNAL branch_w 			: STD_LOGIC;
	SIGNAL Jal_ctrl_w 		: STD_LOGIC;
	SIGNAL Jalr_ctrl_w 		: STD_LOGIC;
	SIGNAL reg_write_w 		: STD_LOGIC;
	SIGNAL reg_dst_w 			: STD_LOGIC;
	SIGNAL brTaken_w 			: STD_LOGIC;
	SIGNAL mem_write_w 		: STD_LOGIC;
	SIGNAL MemtoReg_w 		: STD_LOGIC;
	SIGNAL mem_read_w 		: STD_LOGIC;
	SIGNAL upper_im_w			: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL alu_op_w 			: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL mul_op_w			: STD_LOGIC;
	SIGNAL wbsrc0_w			: STD_LOGIC;
	SIGNAL wbsrc1_w			: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL divu_ctrl_w		: STD_LOGIC;
	SIGNAL remu_ctrl_w		: STD_LOGIC;
	SIGNAL instruction_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	-- Divider and fetch-hold controls.
	SIGNAL divena_w				: STD_LOGIC;
	SIGNAL pc_hold_w			: STD_LOGIC;
	SIGNAL mclk_cnt_q			: STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);

	-- Interrupt entry state.
	SIGNAL gie_w				: STD_LOGIC;
	SIGNAL inta_n_w			: STD_LOGIC;
	SIGNAL interrupt_type_w : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL interrupt_busy_w : STD_LOGIC;
	SIGNAL interrupt_pc_hold_w : STD_LOGIC;
	SIGNAL interrupt_enter_w : STD_LOGIC;
	SIGNAL interrupt_dispatch_w : STD_LOGIC;
	SIGNAL reti_ctrl_w		: STD_LOGIC;
	SIGNAL interrupt_return_pc_w : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL interrupt_vector_pc_w : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);

BEGIN

	-- Instruction fetch and PC control.
	IFE : Ifetch
	generic map(
		WORD_GRANULARITY	=> 	WORD_GRANULARITY,
		DATA_BUS_WIDTH		=> 	DATA_BUS_WIDTH,
		PC_WIDTH					=>	PC_WIDTH,
		ITCM_ADDR_WIDTH		=>	ITCM_ADDR_WIDTH,
		WORDS_NUM					=>	DATA_WORDS_NUM
	)
	PORT MAP (
			-- PC control inputs.
		clk_i 					=> mclk_i,
		rst_i 					=> mclk_rst_i,
		PChold_i				=> pc_hold_w,
		addr_gen_i 			=> addr_gen_w,
		Branch_ctrl_i 	=> branch_w,
		brTaken_i				=> brTaken_w,
		Jal_ctrl_i 			=> Jal_ctrl_w,
		Jalr_ctrl_i			=> Jalr_ctrl_w,
		alu_res_i				=> alu_res_w,
		interrupt_dispatch_i => interrupt_dispatch_w,
		int_addr_i			=> interrupt_vector_pc_w,

			-- Fetch outputs.
		pc_o 						=> pc_w,
		pc_plus4_o	 		=> pc_plus4_w,
		next_pc_o				=> next_pc_w,
		instruction_o 	=> instruction_w
	);

	-- Register decode and write-back.
	ID : Idecode
	generic map(
		PC_WIDTH				=>	PC_WIDTH,
		DATA_BUS_WIDTH	=>  DATA_BUS_WIDTH
	)
	PORT MAP (
			-- Decode and write-back inputs.
		clk_i 					=> mclk_i,
		rst_i 					=> mclk_rst_i,
		pc_plus4_i	 		=> pc_plus4_w,
		instruction_i 	=> instruction_w,
		dtcm_data_rd_i 	=> data_bus_read_i,
		alu_res_i 			=> writeback_res_w,
		RegDst_ctrl_i		=> reg_dst_w,
		RegWrite_ctrl_i => reg_write_w AND NOT interrupt_busy_w,
		MemtoReg_ctrl_i => MemtoReg_w,
		int_enter_i			=> interrupt_enter_w,
		int_dispatch_i	=> interrupt_dispatch_w,
		int_return_addr_i => interrupt_return_pc_w,
		reti_i					=> reti_ctrl_w AND NOT interrupt_busy_w,

			-- Decode outputs.
		read_data1_o 		=> read_data1_w,
		read_data2_o 		=> read_data2_w,
		SignExt_o 			=> sign_extend_w,
		gie_o						=> gie_w
	);

	-- Instruction control decoder.
	CTL:   control
	PORT MAP (
			-- Control inputs.
		clk_i					=> mclk_i,
		rst_i					=> mclk_rst_i,
		instruction_i 		=> instruction_w,
		DIVBUSY					=> divbusy_i,
		IntPChold_i			=> interrupt_pc_hold_w,
		IntBusy_i				=> interrupt_busy_w,

			-- Decoded controls.
		PChold_o					=> pc_hold_w,
		DIVENA_o					=> divena_w,
		RegDst_ctrl_o			=> reg_dst_w,
		ALUSrc_ctrl_o 		=> alu_src_w,
		MemtoReg_ctrl_o 	=> MemtoReg_w,
		RegWrite_ctrl_o 	=> reg_write_w,
		MemRead_ctrl_o 		=> mem_read_w,
		MemWrite_ctrl_o 	=> mem_write_w,
		Branch_ctrl_o 		=> branch_w,
		Jal_ctrl_o 				=> Jal_ctrl_w,
		Jalr_ctrl_o				=> Jalr_ctrl_w,
		Reti_ctrl_o       => reti_ctrl_w,
		UpperIm_ctrl_o 		=> upper_im_w,
		ALUOp_ctrl_o 			=> alu_op_w,
		MUL_OP_ctrl_o			=> mul_op_w,
		wbsrc0_o 				=> wbsrc0_w,
		wbsrc1_o 				=> wbsrc1_w,
		DIVU_ctrl_o				=> divu_ctrl_w,
		REMU_ctrl_o				=> remu_ctrl_w
	);

	-- ALU, branch comparison and target generation.
	EXE:  Execute
	generic map(
		DATA_BUS_WIDTH 	=> 	DATA_BUS_WIDTH,
		PC_WIDTH 				=>	PC_WIDTH
	)
	PORT MAP (
			-- Execute inputs.
		read_data1_i 		=> read_data1_w,
		read_data2_i 		=> read_data2_w,
		sign_extend_i 	=> sign_extend_w,
		UpperIm_ctrl_i 	=> upper_im_w,
		ALUOp_ctrl_i 		=> alu_op_w,
		ALUSrc_ctrl_i 	=> alu_src_w,
		MUL_OP_ctrl_i		=> mul_op_w,
		pc_i						=> pc_w,

			-- Execute outputs.
		brTaken_o 			=> brTaken_w,
		alu_res_o				=> alu_res_w,
		mul_res_o				=> mul_res_w,
		addr_gen_o 			=> addr_gen_w
	);

	-- WBSrc1 controls the first (3:1) mux: 00 selects the divider remainder,
	-- 01 selects the divider quotient, and 10 selects the multiplier result.
	WITH wbsrc1_w SELECT
		m_extension_res_w <= div_residue_i  WHEN "00",
							 div_quotient_i WHEN "01",
							 mul_res_w      WHEN "10",
							 (OTHERS => '0') WHEN OTHERS;

	-- WBSrc0 controls the second (2:1) mux. Input zero is the first mux output;
	-- input one is the ordinary ALU result.
	WITH wbsrc0_w SELECT
		writeback_res_w <= m_extension_res_w WHEN '0',
						   alu_res_w        WHEN '1',
						   (OTHERS => '0')  WHEN OTHERS;

	-- Interrupt dispatch uses TYPE as a byte address; normal accesses use the
	-- ALU result. The top level owns shared-bus decode and command qualification.
	dtcm_byte_addr_w <= CONV_STD_LOGIC_VECTOR(CONV_INTEGER(interrupt_type_w), MA_WIDTH)
		WHEN interrupt_dispatch_w = '1' ELSE alu_res_w(MA_WIDTH-1 DOWNTO 0);

	DTCM_ADDRESS_GRANULARITY_G:
	if (WORD_GRANULARITY = True) generate
		dtcm_addr_w <= dtcm_byte_addr_w(MA_WIDTH-1 DOWNTO 2);
	elsif (WORD_GRANULARITY = False) generate
		dtcm_addr_w <= dtcm_byte_addr_w(MA_WIDTH-1 DOWNTO 0);
	end generate;

	-- DTCM storage remains below the core. Its directional data ports connect
	-- to the external DTCM BidirPin adapter in the shared-bus fabric.
	MEM : dmemory
	GENERIC MAP (
		DATA_BUS_WIDTH  => DATA_BUS_WIDTH,
		DTCM_ADDR_WIDTH => DTCM_ADDR_WIDTH,
		WORDS_NUM       => DATA_WORDS_NUM
	)
	PORT MAP (
		clk_i            => mclk_i,
		rst_i            => mclk_rst_i,
		dtcm_addr_i      => dtcm_addr_w,
		dtcm_data_wr_i   => dtcm_data_wr_i,
		MemRead_ctrl_i   => dtcm_mem_read_i,
		MemWrite_ctrl_i  => dtcm_mem_write_i,
		dtcm_data_rd_o   => dtcm_data_rd_w
	);

		-- Interrupt acknowledge and vector dispatch sequencing.
		INT_SERVICE_U : Interrupt_Service_Unit
	GENERIC MAP (
		PC_WIDTH => PC_WIDTH
	)
	PORT MAP (
		clk_i         => mclk_i,
		rst_i         => mclk_rst_i,
		intr_i        => intr_i,
		pc_hold_i     => pc_hold_w,
		next_pc_i     => next_pc_w,
		data_bus_i    => data_bus_read_i,
		busy_o        => interrupt_busy_w,
		pc_hold_o     => interrupt_pc_hold_w,
		inta_n_o      => inta_n_w,
		enter_o       => interrupt_enter_w,
		dispatch_o    => interrupt_dispatch_w,
		return_addr_o => interrupt_return_pc_w,
		captured_type_o => interrupt_type_w,
		vector_pc_o   => interrupt_vector_pc_w
	);

		-- Free-running verification counter.
	MCLK_COUNTER_P : process (mclk_i, mclk_rst_i)
	begin
		if mclk_rst_i = '1' then
			mclk_cnt_q	<=	(others	=> '0');
		elsif rising_edge(mclk_i) then
			mclk_cnt_q	<=	mclk_cnt_q + '1';
		end if;
	end process;

	-- Commands and handshake outputs.
	MemRead_ctrl_o		<=	mem_read_w;
	MemWrite_ctrl_o 	<= 	mem_write_w;																-- CONTROL output
	dtcm_data_rd_o			<=	dtcm_data_rd_w;
	dtcm_addr_o				<=	dtcm_addr_w;
	DIVENA_o					<=	divena_w;
	REMU_ctrl_o				<=	remu_ctrl_w;
	gie_o							<=	gie_w;																			-- IDECODE output
	inta_n_o					<=	inta_n_w;
	int_busy_o				<=	interrupt_busy_w;
	int_dispatch_o		<=	interrupt_dispatch_w;

	-- Verification outputs.
	pc_o							<=	pc_w;																				-- IFETCH output
  instruction_o 		<= 	instruction_w;															-- IFETCH output

	RegWrite_ctrl_o 	<= 	reg_write_w;																-- CONTROL output
	Branch_ctrl_o 		<= 	branch_w;																		-- CONTROL output

  read_data1_o 			<= 	read_data1_w;																-- IDECODE output
  read_data2_o 			<= 	read_data2_w;																-- IDECODE output
	write_data_o  		<= 	data_bus_read_i WHEN MemtoReg_w = '1' ELSE	-- IDECODE input (Write-Back)
												writeback_res_w;
  alu_res_o 				<= 	alu_res_w;																	-- EXECUTE output
  brTaken_o 				<= 	brTaken_w;																	-- EXECUTE output

	mclk_cnt_o				<=	mclk_cnt_q;																	-- TOP output

---------------------------------------------------------------------------------------

END structural;
