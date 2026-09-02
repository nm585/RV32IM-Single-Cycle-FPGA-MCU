--============================================================================
-- Copyright 2026 Hananya Ribo
-- Copyright 2026 Hanan Ribo
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- Instruction fetch, PC control and ITCM
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;


ENTITY Ifetch IS
	generic(
		WORD_GRANULARITY 	: boolean	:= False;
		DATA_BUS_WIDTH 		: integer	:= 32;
		PC_WIDTH 					: integer	:= 10;
		ITCM_ADDR_WIDTH 	: integer	:= 8;
		WORDS_NUM 				: integer	:= 256
	);
	PORT(
		--Inputs
		clk_i					: IN 	STD_LOGIC;
		rst_i 				: IN 	STD_LOGIC;
		PChold_i			: IN 	STD_LOGIC;
		addr_gen_i 		: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
    Branch_ctrl_i	: IN 	STD_LOGIC;
    brTaken_i 		: IN 	STD_LOGIC;
		Jal_ctrl_i		: IN 	STD_LOGIC;
		Jalr_ctrl_i		: IN 	STD_LOGIC;
		alu_res_i 		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		interrupt_dispatch_i : IN STD_LOGIC;
		int_addr_i		: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);

		--Outputs
		pc_o 					: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		pc_plus4_o 		: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		next_pc_o			: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		instruction_o : OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
	);
END Ifetch;


ARCHITECTURE behavior OF Ifetch IS
	SIGNAL pc_q						: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL pc_plus4_q			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL next_pc_plus4_w 		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL itcm_addr_w		: STD_LOGIC_VECTOR(ITCM_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL next_pc_w  		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL branch_redirect_w  		: STD_LOGIC;
	SIGNAL reset_sync_q  				: STD_LOGIC;

	BEGIN
		--=======================================
		-- ITCM (ROM) connection
	--=======================================
	ITCM_U : altsyncram
	GENERIC MAP (
		operation_mode					=> "ROM",
		width_a 								=> DATA_BUS_WIDTH,
		widthad_a 							=> ITCM_ADDR_WIDTH,
		numwords_a 							=> WORDS_NUM,
		lpm_hint 								=> "ENABLE_RUNTIME_MOD = YES,INSTANCE_NAME = ITCM",
		lpm_type 								=> "altsyncram",
		outdata_reg_a 					=> "UNREGISTERED",
		init_file 							=> "C:\final_project\Benchmark apps\Intrrupt-based IO\test1\bin\M9K-intel\ITCM.hex",
		intended_device_family	=> "Cyclone"
	)
	PORT MAP (
		clock0    => clk_i,
		address_a	=> itcm_addr_w,
		q_a 	   	=> instruction_o
	);
	-------------------------------------------------------------------------------------
-- rst_i synchronization
-- Asynchronous assertion and synchronous release.
-------------------------------------------------------------------------------------
RESET_SYNC_P : PROCESS (clk_i, rst_i)
	BEGIN
		IF rst_i = '1' THEN
			-- asserted reset state
			reset_sync_q <= '1';	-- preset
		ELSIF(clk_i'EVENT  AND clk_i='1') THEN
			reset_sync_q <= rst_i;
		END IF;
END PROCESS;

	-----------------------------------------------------------------------------------
		-- Adder to execute PC+4
  next_pc_plus4_w(PC_WIDTH-1 DOWNTO 0)	<= next_pc_w(PC_WIDTH-1 DOWNTO 0) + 4;

	-----------------------------------------------------------------------------------
		-- Decision MUX for the next PC value
			-- Priority: reset, interrupt, hold, jump, branch, sequential.
	branch_redirect_w <= 	Branch_ctrl_i AND brTaken_i;

	next_pc_w	<=	(others => '0') 									WHEN	reset_sync_q 									ELSE
								int_addr_i(PC_WIDTH-1 DOWNTO 0)	WHEN	interrupt_dispatch_i			ELSE
								pc_q(PC_WIDTH-1 DOWNTO 0)				WHEN	PChold_i								ELSE
								-- case of jalr
								alu_res_i(PC_WIDTH-1 DOWNTO 0)		WHEN	Jalr_ctrl_i							ELSE	-- JALR target
								-- case of Branch Taken or jal
								addr_gen_i(PC_WIDTH-1 DOWNTO 0)		WHEN	branch_redirect_w or Jal_ctrl_i ELSE	-- taken branch or JAL target
								-- case of Branch Not-Taken
								pc_plus4_q(PC_WIDTH-1 DOWNTO 0);																			-- sequential PC
	-----------------------------------------------------------------------------------
-- pc_plus4 register
-------------------------------------------------------------------------------------
PC_PLUS4_REG_P : PROCESS (clk_i, rst_i)
	BEGIN
		IF rst_i = '1' THEN
			pc_plus4_q(PC_WIDTH-1 DOWNTO 0) <= (OTHERS => '0') ;
		ELSIF(clk_i'EVENT  AND clk_i='1') THEN
			IF PChold_i = '0' THEN
			pc_plus4_q(PC_WIDTH-1 DOWNTO 0) <= next_pc_plus4_w;
			END IF;
		END IF;
END PROCESS;

	-----------------------------------------------------------------------------------
-- pc register
-------------------------------------------------------------------------------------
PC_REG_P : PROCESS (clk_i, rst_i)
	BEGIN
		IF rst_i = '1' THEN
			pc_q(PC_WIDTH-1 DOWNTO 0) <= (OTHERS => '0') ;
		ELSIF(clk_i'EVENT  AND clk_i='1') THEN
			IF PChold_i = '0' THEN
			pc_q(PC_WIDTH-1 DOWNTO 0) <= next_pc_w;
			END IF;
		END IF;
END PROCESS;
	-----------------------------------------------------------------------------------
		-- send address to inst. memory address register
		ITCM_ADDRESS_GRANULARITY_G:
		-- i.e. each WORD has unike address
		if (WORD_GRANULARITY = True) generate 			-- word-addressed ITCM
			itcm_addr_w <= next_pc_w(PC_WIDTH-1 DOWNTO 2);
		-- i.e. each BYTE has unike address
		elsif (WORD_GRANULARITY = False) generate 	-- byte-addressed ITCM
		itcm_addr_w <= next_pc_w;
	end generate;
---------------------------------------------------------------------------------------
		-- Export the fetch state.
	pc_o 				<= 	pc_q;
	pc_plus4_o	<= 	pc_plus4_q;
	next_pc_o		<=	next_pc_w;
---------------------------------------------------------------------------------------

END behavior;
