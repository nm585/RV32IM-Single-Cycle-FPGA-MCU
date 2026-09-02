---------------------------------------------------------------------------------------------
-- Copyright 2025 Hananya Ribo 
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- Top-level smoke test used for interactive simulation of the complete core.
-- It supplies clocks, a reset pulse and a few switch changes; detailed checking
-- is left to the focused self-checking testbenches.
---------------------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;
USE work.cond_compilation_package.all;
USE work.aux_package.all;


-- The entity/file name follows the submission name required by the assignment.
ENTITY tb_RV32IMscMCU IS
END tb_RV32IMscMCU;


ARCHITECTURE simulation OF tb_RV32IMscMCU IS
	-- Board-facing inputs driven by the testbench.
	SIGNAL rst_i		 					:	STD_LOGIC;
	SIGNAL clk_i							:	STD_LOGIC;
	SIGNAL sw_i								:	STD_LOGIC_VECTOR(9 DOWNTO 0);

	-- KEY0 is the board reset and reads low when pressed, so it is the
	-- inverse of the active-high rst_i the stimulus below drives.
	SIGNAL key0_n_w						:	STD_LOGIC;

	-- Internal observation points are exposed by FPGA_Top_SingleCycle for
	-- waveform debug and for the same SignalTap probes used on the FPGA build.
	-- The device under test is the whole MCU: the CPU proper now sits inside the
	-- top level together with the clock tree, BUS, DTCM, divider and peripherals.
	SIGNAL pc_o								:	STD_LOGIC_VECTOR(G_PC_WIDTH-1 DOWNTO 0);
	SIGNAL instruction_o			:	STD_LOGIC_VECTOR(DBUS_WIDTH-1 DOWNTO 0);
	
	SIGNAL RegWrite_ctrl_o		: STD_LOGIC;
	SIGNAL MemWrite_ctrl_o		: STD_LOGIC;
	SIGNAL Branch_ctrl_o			: STD_LOGIC;
	
	SIGNAL read_data1_o 			:	STD_LOGIC_VECTOR(DBUS_WIDTH-1 DOWNTO 0);
	SIGNAL read_data2_o 			:	STD_LOGIC_VECTOR(DBUS_WIDTH-1 DOWNTO 0);
	SIGNAL write_data_o				:	STD_LOGIC_VECTOR(DBUS_WIDTH-1 DOWNTO 0);
	
	SIGNAL alu_res_o 					:	STD_LOGIC_VECTOR(DBUS_WIDTH-1 DOWNTO 0);
	SIGNAL brTaken_o					: STD_LOGIC; 
	
	SIGNAL dtcm_addr_o				: STD_LOGIC_VECTOR(G_ADDRWIDTH-1 DOWNTO 0);
	SIGNAL ledr_o							: STD_LOGIC_VECTOR(9 DOWNTO 0);
	SIGNAL hex0_o							: STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL hex1_o							: STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL hex2_o							: STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL hex3_o							: STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL hex4_o							: STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL hex5_o							: STD_LOGIC_VECTOR(6 DOWNTO 0);
	
	SIGNAL mclk_cnt_o					:	STD_LOGIC_VECTOR(15 DOWNTO 0);
   
BEGIN
	-- Bound directly to the entity rather than through an aux_package component,
	-- so the port list can never drift out of step with the design again.
	-- MODELSIM => 1 ties MCLK, SMCLK and DIVCLK to CLOCK_50 and skips the PLLs.
	CORE : ENTITY work.FPGA_Top_SingleCycle
	generic map(
		MODELSIM => 1
	)
	PORT MAP (
		-- Board pins. KEY0 is the reset button; KEY3-KEY1 stay released and the
		-- two capture inputs stay low, so no peripheral interrupt fires here.
		CLOCK_50					=> clk_i,
		KEY0							=> key0_n_w,
		KEY1							=> '1',
		KEY2							=> '1',
		KEY3							=> '1',
		CAPIN1						=> '0',
		CAPIN2						=> '0',
		SW								=> sw_i,

		-- Board outputs.
		LEDR							=> ledr_o,
		HEX0							=> hex0_o,
		HEX1							=> hex1_o,
		HEX2							=> hex2_o,
		HEX3							=> hex3_o,
		HEX4							=> hex4_o,
		HEX5							=> hex5_o,
		PWMOUT						=> open,

		-- Pipeline observation ports, grouped by the stage that produces them.
		pc_o							=> pc_o,							-- Current fetch address.
		instruction_o			=> instruction_o,			-- Instruction at that address.

		RegWrite_ctrl_o		=> RegWrite_ctrl_o,		-- Decoded register write.
		MemWrite_ctrl_o		=> MemWrite_ctrl_o,		-- Decoded memory write.
		Branch_ctrl_o			=> Branch_ctrl_o,			-- Decoded branch request.

		read_data1_o 			=> read_data1_o,			-- First register operand.
		read_data2_o 			=> read_data2_o,			-- Second register operand.
		write_data_o			=> write_data_o,			-- Value selected for write-back.

		alu_res_o 				=> alu_res_o,					-- Execute-stage result.
		brTaken_o					=> brTaken_o,					-- Final branch decision.

		dtcm_addr_o				=> dtcm_addr_o,				-- DTCM word address.

		mclk_cnt_o				=> mclk_cnt_o					-- Free-running top-level cycle counter.
	);
	-- The reference design runs one MCLK cycle every 100 ns in simulation.
	gen_clk :
	process
  begin
		clk_i <= '1';
		wait for 50 ns;
		clk_i <= not clk_i;
		wait for 50 ns;
  end process;
	
	-- KEY0 reads low while the reset button is held.
	key0_n_w <= NOT rst_i;

	-- The top only leaves reset once KEY0 has been sampled low on a rising
	-- CLOCK_50 edge. clk_i is '1' from 0-50 ns and '0' from 50-100 ns, so the
	-- first edge rising_edge() actually accepts is at 100 ns; the transition at
	-- t=0 is 'U' -> '1', which does not qualify. The pulse therefore has to
	-- outlast 100 ns, or the press is never seen and the MCU stays in reset.
	gen_rst :
	process
  begin
		rst_i <='1','0' after 250 ns;
		wait;
  end process;

	-- Change the low switches slowly enough that software can poll each pattern.
	gen_sw :
	process
	begin
		sw_i <= (others => '0');
		wait for 2 us;
		sw_i <= "0000000001";
		wait for 2 us;
		sw_i <= "0000000010";
		wait;
	end process;

END simulation;
