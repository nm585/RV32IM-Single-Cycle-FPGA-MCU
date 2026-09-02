--============================================================================
-- Copyright 2026 Hananya Ribo
-- Copyright 2026 Hanan Ribo
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- Instruction decode, register file and write-back
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.const_package.all;


ENTITY Idecode IS
	generic(
		PC_WIDTH 				: integer	:= 10;
		DATA_BUS_WIDTH	: integer := 32
	);
	PORT(
		--Inputs
		clk_i						: IN 	STD_LOGIC;
		rst_i						: IN 	STD_LOGIC;
		pc_plus4_i			: IN	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		instruction_i 	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		dtcm_data_rd_i 	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		alu_res_i				: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		RegDst_ctrl_i 	: IN 	STD_LOGIC;
		RegWrite_ctrl_i : IN 	STD_LOGIC;
		MemtoReg_ctrl_i : IN 	STD_LOGIC;
		int_enter_i			: IN 	STD_LOGIC;
		int_dispatch_i	: IN 	STD_LOGIC;
		int_return_addr_i: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		reti_i					: IN 	STD_LOGIC;

		--Outputs
		read_data1_o		: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		read_data2_o		: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		SignExt_o 			: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		gie_o						: OUT STD_LOGIC
	);
END Idecode;


ARCHITECTURE behavior OF Idecode IS
	TYPE register_file_t IS ARRAY (0 TO 31) OF STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	CONSTANT RESET_STACK_POINTER_C  : integer := 1024;

	SIGNAL register_file_q			: register_file_t;
	SIGNAL writeback_data_w			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	SIGNAL opcode_w						: STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL rs1_w						: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL rs2_w						: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL rd_w							: STD_LOGIC_VECTOR(4 DOWNTO 0);

	SIGNAL i_imm_bits_w						: STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL s_imm_bits_w						: STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL b_imm_bits_w					: STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL u_imm_bits_w						: STD_LOGIC_VECTOR(19 DOWNTO 0);
	SIGNAL j_imm_bits_w					: STD_LOGIC_VECTOR(19 DOWNTO 0);

	SIGNAL i_imm_ext_w		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL s_imm_ext_w		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL b_imm_ext_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL u_imm_ext_w		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL j_imm_ext_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

BEGIN
	-- Decode register fields and immediate fragments.
	opcode_w		<= instruction_i(6 DOWNTO 0);

	rs1_w		<= instruction_i(19 DOWNTO 15);
  rs2_w		<= instruction_i(24 DOWNTO 20);
  rd_w		<= instruction_i(11 DOWNTO 7);

  i_imm_bits_w 	<= instruction_i(31 DOWNTO 20);
	s_imm_bits_w 	<= instruction_i(31 DOWNTO 25) & instruction_i(11 DOWNTO 7);
	b_imm_bits_w <= instruction_i(31) & instruction_i(7) & instruction_i(30 DOWNTO 25) & instruction_i(11 DOWNTO 8);
	u_imm_bits_w 	<= instruction_i(31 DOWNTO 12);
	j_imm_bits_w <= instruction_i(31) & instruction_i(19 DOWNTO 12) & instruction_i(20) & instruction_i(30 DOWNTO 21);

	-- Read the Register 1 output of the Register-File
	read_data1_o <= register_file_q(CONV_INTEGER(rs1_w));

	-- Read the Register 2 output of the Register-File
	read_data2_o <= register_file_q(CONV_INTEGER(rs2_w));

	-- The upstream WBSrc muxes have already selected ALU/MUL/DIV/REM on
	-- alu_res_i. This mux only adds the return-address and load-data sources.
	writeback_data_w <= ((DATA_BUS_WIDTH-PC_WIDTH-1) DOWNTO 0 => '0') & pc_plus4_i
																						WHEN	RegDst_ctrl_i				ELSE
									alu_res_i(DATA_BUS_WIDTH-1 DOWNTO 0) 	WHEN	not MemtoReg_ctrl_i ELSE
									dtcm_data_rd_i;

	-- Sign Extend 16-bits to 32-bits
  i_imm_ext_w 	<=	ZEROS_IMM20 & i_imm_bits_w 	WHEN	not i_imm_bits_w(11) 	ELSE ONES_IMM20 & i_imm_bits_w;
	s_imm_ext_w 	<=	ZEROS_IMM20	& s_imm_bits_w 	WHEN 	not s_imm_bits_w(11)	ELSE ONES_IMM20 & s_imm_bits_w;
	b_imm_ext_w <=	ZEROS_IMM20	& b_imm_bits_w WHEN 	not b_imm_bits_w(11)	ELSE ONES_IMM20 & b_imm_bits_w;
	u_imm_ext_w 	<=	ZEROS_IMM12 & u_imm_bits_w 	WHEN 	not u_imm_bits_w(19) 	ELSE ONES_IMM12 & u_imm_bits_w;
	j_imm_ext_w	<=	ZEROS_IMM12 & j_imm_bits_w WHEN 	not j_imm_bits_w(19) ELSE ONES_IMM12 & j_imm_bits_w;


	-- Choose the immediate format from the instruction opcode.
	with	opcode_w select
		SignExt_o <=	i_imm_ext_w														when ITYPE_OPC,
									i_imm_ext_w														when INST_JALR(6 DOWNTO 0),
									i_imm_ext_w														when INST_LW(6 DOWNTO 0),	-- all load widths share opcode 0000011
									s_imm_ext_w														when STYPE_OPC,
									b_imm_ext_w 													when SBTYPE_OPC,
									u_imm_ext_w(19 DOWNTO 0) & ZEROS_IMM12	when INST_AUIPC(6 DOWNTO 0),
									u_imm_ext_w(19 DOWNTO 0) & ZEROS_IMM12	when INST_LUI(6 DOWNTO 0),
									j_imm_ext_w														when UJTYPE_OPC,
								(others => '0')														when others;
	--==============================================================================
	--	Register-File(RF) structure
	--==============================================================================
	REGISTER_FILE_P : process(clk_i,rst_i)
	begin
		if (rst_i='1') then
			FOR i IN 0 TO 31 LOOP
				register_file_q(i) <= CONV_STD_LOGIC_VECTOR(0,32);
			END LOOP;
			-- Seed the stack pointer for benchmarks without a startup routine.
			-- Software may replace this value during normal initialization.
			register_file_q(2) <= CONV_STD_LOGIC_VECTOR(RESET_STACK_POINTER_C,32); -- sp = top of 256-word DTCM (0x400)
		elsif (clk_i'event and clk_i='1') then
			if (RegWrite_ctrl_i = '1' AND rd_w /= 0) then	-- RF(0) hard-wired to zero
				register_file_q(CONV_INTEGER(rd_w)) <= writeback_data_w;
				-- Convert rd to the register-file array index.
			end if;

			-- Apply interrupt state updates outside normal write-back.
			if (int_enter_i = '1') then
				register_file_q(3)(0) <= '0'; -- gp[0] is the global interrupt enable
			end if;
			if (int_dispatch_i = '1') then
				-- tp holds the zero-extended interrupt return address.
				register_file_q(4) <= ((DATA_BUS_WIDTH-PC_WIDTH-1) DOWNTO 0 => '0') & int_return_addr_i;
			end if;
			if (reti_i = '1') then
				register_file_q(3)(0) <= '1';
			end if;
		end if;
	end process;

	-- GIE is stored in gp[0].
	gie_o <= register_file_q(3)(0);

END behavior;
