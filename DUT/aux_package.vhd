---------------------------------------------------------------------------------------------
-- Copyright 2025 Hananya Ribo 
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
---------------------------------------------------------------------------------------------
library IEEE;
use ieee.std_logic_1164.all;
USE work.cond_compilation_package.all;


package aux_package is

	-- Component declarations used by the DUT.
	component RV32IM_CORE is
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

			-- Divider status and separate result buses.
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
		end component;
	-- Divider operating in the DIVCLK domain.
	component Divider_32bit is
		PORT(
			DIVCLK   : IN  STD_LOGIC;
			DIVRST   : IN  STD_LOGIC;
			DIVENA   : IN  STD_LOGIC;
			Dividend : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			Divisor  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			DIVBUSY  : OUT STD_LOGIC;
			Residue  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			Quotient : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	end component;
	-- MCLK-to-DIVCLK bridge.
	component Divider_CDC is
		PORT(
			MCLK     : IN  STD_LOGIC;
			MCLKRST  : IN  STD_LOGIC;
			DIVCLK   : IN  STD_LOGIC;
			DIVRST   : IN  STD_LOGIC;
			DIVENA   : IN  STD_LOGIC;
			Dividend : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			Divisor  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			DIVBUSY  : OUT STD_LOGIC;
			Residue  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			Quotient : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	end component;
	-- Shared-bus endpoint.
	component BidirPin is
		GENERIC(
			width : INTEGER := 16
		);
		PORT(
			Dout  : IN    STD_LOGIC_VECTOR(width-1 DOWNTO 0);
			en    : IN    STD_LOGIC;
			Din   : OUT   STD_LOGIC_VECTOR(width-1 DOWNTO 0);
			IOpin : INOUT STD_LOGIC_VECTOR(width-1 DOWNTO 0)
		);
	end component;
	-- Active-low hexadecimal decoder used by every board display.
	component Hex_Display_Decoder is
		PORT(
			data_i     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			segments_o : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
		);
	end component;
	-- LEDs, switches, pushbuttons and the six displays.
	component GPIO_Peripheral is
		generic(
			DATA_BUS_WIDTH : integer := 32
		);
		PORT(
			smclk_i         : IN  STD_LOGIC;
			rst_i           : IN  STD_LOGIC;
			addr_i          : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			data_wr_i       : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			mem_read_i      : IN  STD_LOGIC;
			mem_write_i     : IN  STD_LOGIC;
			data_rd_o       : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			data_oe_o       : OUT STD_LOGIC;
			sw_i            : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			key_n_i         : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
			ledr_o          : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			hex0_o          : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
			hex1_o          : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
			hex2_o          : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
			hex3_o          : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
			hex4_o          : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
			hex5_o          : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
		);
	end component;
	-- Basic Timer with capture, compare and PWM support.
	component Basic_Timer is
		PORT(
			smclk_i     : IN  STD_LOGIC;
			rst_i       : IN  STD_LOGIC;
			addr_i      : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			data_wr_i   : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			mem_read_i  : IN  STD_LOGIC;
			mem_write_i : IN  STD_LOGIC;
			capin1_i    : IN  STD_LOGIC;
			capin2_i    : IN  STD_LOGIC;
			data_rd_o   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			data_oe_o   : OUT STD_LOGIC;
			pwmout_o    : OUT STD_LOGIC;
			btifg_o     : OUT STD_LOGIC
		);
	end component;
	-- Interrupt flags, masks, priority and TYPE generation.
	component Interrupt_Controller is
		PORT(
			smclk_i         : IN  STD_LOGIC;
			rst_i           : IN  STD_LOGIC;
			addr_i          : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			data_wr_i       : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			mem_read_i      : IN  STD_LOGIC;
			mem_write_i     : IN  STD_LOGIC;
			gie_i           : IN  STD_LOGIC;
			inta_n_i        : IN  STD_LOGIC;
			interrupt_dispatch_i: IN STD_LOGIC;
			bt_event_i      : IN  STD_LOGIC;
			key_event_i     : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
			data_rd_o       : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			data_oe_o       : OUT STD_LOGIC;
			intr_o          : OUT STD_LOGIC;
			type_o          : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			ie_o            : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			ifg_o           : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
		);
	end component;
	-- Two-cycle interrupt acknowledge and dispatch.
	component Interrupt_Service_Unit is
		GENERIC(
			PC_WIDTH : INTEGER := 13
		);
		PORT(
			clk_i           : IN  STD_LOGIC;
			rst_i           : IN  STD_LOGIC;
			intr_i          : IN  STD_LOGIC;
			pc_hold_i       : IN  STD_LOGIC;
			next_pc_i       : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			data_bus_i      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			busy_o          : OUT STD_LOGIC;
			pc_hold_o       : OUT STD_LOGIC;
			inta_n_o        : OUT STD_LOGIC;
			enter_o         : OUT STD_LOGIC;
			dispatch_o      : OUT STD_LOGIC;
			return_addr_o   : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			captured_type_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			vector_pc_o     : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0)
		);
	end component;
	-- Instruction decoder and PC-hold control.
	component control is
		PORT( 
		-- Control inputs.
		clk_i					: IN	STD_LOGIC;
		rst_i					: IN	STD_LOGIC;
		instruction_i 		: IN 	STD_LOGIC_VECTOR(31 DOWNTO 0);
		DIVBUSY				: IN	STD_LOGIC;
		IntPChold_i			: IN	STD_LOGIC;
		IntBusy_i				: IN	STD_LOGIC;
		
		-- Datapath and memory controls.
		PChold_o				: OUT	STD_LOGIC;
		DIVENA_o				: OUT	STD_LOGIC;
		RegDst_ctrl_o 		: OUT 	STD_LOGIC;
		ALUSrc_ctrl_o 		: OUT 	STD_LOGIC;
		MemtoReg_ctrl_o 	: OUT 	STD_LOGIC;
		RegWrite_ctrl_o 	: OUT 	STD_LOGIC;
		MemRead_ctrl_o 		: OUT 	STD_LOGIC;
		MemWrite_ctrl_o	 	: OUT 	STD_LOGIC;
		Branch_ctrl_o 		: OUT 	STD_LOGIC;
		Jal_ctrl_o 				: OUT 	STD_LOGIC;
		Jalr_ctrl_o 			: OUT 	STD_LOGIC;
		Reti_ctrl_o        : OUT  STD_LOGIC;
		MUL_OP_ctrl_o		: OUT 	STD_LOGIC;
		wbsrc0_o			: OUT 	STD_LOGIC;
		wbsrc1_o			: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0);
		DIVU_ctrl_o			: OUT 	STD_LOGIC;
		REMU_ctrl_o			: OUT 	STD_LOGIC;
		UpperIm_ctrl_o		: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0);
		ALUOp_ctrl_o	 		: OUT 	STD_LOGIC_VECTOR(4 DOWNTO 0)
	);
	end component;
	-- Data memory interface.
	component dmemory is
		generic(
			DATA_BUS_WIDTH 	: integer := 32;
			DTCM_ADDR_WIDTH : integer := 8;
			WORDS_NUM 			: integer := 256
		);
		PORT(	
			-- Directional DTCM interface.
			clk_i						: IN 	STD_LOGIC;
			rst_i						: IN 	STD_LOGIC;
			dtcm_addr_i 		: IN 	STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
			dtcm_data_wr_i 	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MemRead_ctrl_i  : IN 	STD_LOGIC;
			MemWrite_ctrl_i : IN 	STD_LOGIC;
			dtcm_data_rd_o 	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	end component;
	-- Execute datapath.
	component Execute is
		generic(
			DATA_BUS_WIDTH 	: integer := 32;
			PC_WIDTH 				: integer := 10
		);
		PORT(	
			-- Execute inputs.
			read_data1_i 		: IN 	STD_LOGIC_VECTOR(31 DOWNTO 0);
			read_data2_i 		: IN 	STD_LOGIC_VECTOR(31 DOWNTO 0);
			sign_extend_i 	: IN 	STD_LOGIC_VECTOR(31 DOWNTO 0);
			UpperIm_ctrl_i	: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);
			ALUOp_ctrl_i	 	: IN 	STD_LOGIC_VECTOR(4 DOWNTO 0);
			ALUSrc_ctrl_i 	: IN 	STD_LOGIC;
			MUL_OP_ctrl_i		: IN 	STD_LOGIC;
			pc_i						: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
				
			-- Execute outputs.
			brTaken_o 			: OUT	STD_LOGIC;
			alu_res_o 			: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			mul_res_o 			: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			addr_gen_o 			: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0)
		);
	end component;
	-- Register file, immediate decode and write-back.
	component Idecode is
		generic(
			PC_WIDTH 				: integer	:= 10;
			DATA_BUS_WIDTH	: integer := 32
		);
		PORT(
			-- Decode and write-back inputs.
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
			
			-- Decode outputs.
			read_data1_o		: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			read_data2_o		: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			SignExt_o 			: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			gie_o						: OUT STD_LOGIC
		);
	end component;
	-- PC control and instruction memory.
	component Ifetch is
		generic(
			WORD_GRANULARITY 	: boolean	:= False;
			DATA_BUS_WIDTH 		: integer	:= 32;
			PC_WIDTH 					: integer	:= 10;
			ITCM_ADDR_WIDTH 	: integer	:= 8;
			WORDS_NUM 				: integer	:= 256
		);
		PORT(
			-- Fetch inputs.
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
			
			-- Fetch outputs.
			pc_o 					: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			pc_plus4_o 		: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			next_pc_o			: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			instruction_o : OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	end component;
	-- PLL wrapper for generated clocks.
	COMPONENT PLL IS
		GENERIC(
			OUTPUT_DIVIDE_BY   : NATURAL := G_PLL_DIV;
			OUTPUT_MULTIPLY_BY : NATURAL := G_PLL_MUL
		);
		port(
			areset		: IN STD_LOGIC  := '0';
			inclk0		: IN STD_LOGIC  := '0';
			c0     		: OUT STD_LOGIC ;
			locked		: OUT STD_LOGIC
		);
	END COMPONENT;
	-- CPU, peripheral and divider clock generation.
	COMPONENT Clock_Tree IS
		GENERIC (
			MODELSIM : integer := G_MODELSIM
		);
		PORT (
			clock_50_i : IN  STD_LOGIC;
			mclk_o     : OUT STD_LOGIC;
			smclk_o    : OUT STD_LOGIC;
			divclk_o   : OUT STD_LOGIC
		);
	END COMPONENT;
	-- Execute-stage multiplier.
	component Multiplier_16bit is
		generic(
			DATA_BUS_WIDTH : integer := 32
		);
		PORT(
			Ain       : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			Bin       : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MULOP     : IN  STD_LOGIC;
			MUL_res_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	end component;
	-- Implementations are provided in separate source files.

end aux_package;
