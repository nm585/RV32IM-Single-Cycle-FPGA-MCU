-- Memory-mapped GPIO for LEDs, displays, switches and pushbuttons.
-- LEDR and HEX0..HEX5 are outputs; SW and the active-low keys are inputs.
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.aux_package.ALL;

ENTITY GPIO_Peripheral IS
	GENERIC(
		DATA_BUS_WIDTH : integer := 32
	);
	PORT(
		-- Data Memory BUS
		smclk_i         : IN  STD_LOGIC;
		rst_i           : IN  STD_LOGIC;
		addr_i          : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
		data_wr_i       : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		mem_read_i      : IN  STD_LOGIC;
		mem_write_i     : IN  STD_LOGIC;
		data_rd_o       : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		data_oe_o       : OUT STD_LOGIC;

		-- I/O devices
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
END GPIO_Peripheral;

ARCHITECTURE structural OF GPIO_Peripheral IS
	-- GPIO register addresses.
	CONSTANT PORT_LEDR : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2000";
	CONSTANT PORT_HEX0 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2004";
	CONSTANT PORT_HEX1 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2005";
	CONSTANT PORT_HEX2 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2008";
	CONSTANT PORT_HEX3 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2009";
	CONSTANT PORT_HEX4 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"200C";
	CONSTANT PORT_HEX5 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"200D";
	CONSTANT PORT_SW   : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2010";
	CONSTANT PORT_PB   : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2014";

	-- Group decode with A0 selecting each display in a pair.
	SIGNAL local_a0_w            : STD_LOGIC;
	SIGNAL chip_select_w         : STD_LOGIC_VECTOR(5 DOWNTO 0);
	SIGNAL output_write_enable_w : STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL sw_read_enable_w      : STD_LOGIC;
	SIGNAL pb_read_enable_w      : STD_LOGIC;

	-- Registered outputs and local read data.
	SIGNAL ledr_latch_q   : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL hex0_latch_q   : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL hex1_latch_q   : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL hex2_latch_q   : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL hex3_latch_q   : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL hex4_latch_q   : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL hex5_latch_q   : STD_LOGIC_VECTOR(7 DOWNTO 0);
BEGIN
	-- Decode the register group before selecting the display byte.
	local_a0_w <= addr_i(0);

	WITH addr_i SELECT chip_select_w <=
		"000001" WHEN PORT_LEDR, -- CS0: PORT_LEDR
		"000010" WHEN PORT_HEX0 | PORT_HEX1, -- CS1: PORT_HEX0/PORT_HEX1
		"000100" WHEN PORT_HEX2 | PORT_HEX3, -- CS2: PORT_HEX2/PORT_HEX3
		"001000" WHEN PORT_HEX4 | PORT_HEX5, -- CS3: PORT_HEX4/PORT_HEX5
		"010000" WHEN PORT_SW, -- CS4: PORT_SW
		"100000" WHEN PORT_PB, -- CS5: PORT_PB
		"000000" WHEN OTHERS;

	-- Board inputs are read directly.
	sw_read_enable_w <= chip_select_w(4) AND mem_read_i;
	pb_read_enable_w <= chip_select_w(5) AND mem_read_i;

	-- LEDR and HEX0..HEX5 are write-only.
	output_write_enable_w(0) <= chip_select_w(0) AND mem_write_i;

	output_write_enable_w(1) <= chip_select_w(1) AND (NOT local_a0_w) AND mem_write_i;
	output_write_enable_w(2) <= chip_select_w(1) AND local_a0_w AND mem_write_i;

	output_write_enable_w(3) <= chip_select_w(2) AND (NOT local_a0_w) AND mem_write_i;
	output_write_enable_w(4) <= chip_select_w(2) AND local_a0_w AND mem_write_i;

	output_write_enable_w(5) <= chip_select_w(3) AND (NOT local_a0_w) AND mem_write_i;
	output_write_enable_w(6) <= chip_select_w(3) AND local_a0_w AND mem_write_i;

	-- Register GPIO writes on the rising edge of SMCLK.
	GPIO_OUTPUT_REGISTERS_P : PROCESS(smclk_i, rst_i)
	BEGIN
		IF rst_i = '1' THEN
			ledr_latch_q <= (OTHERS => '0');
			hex0_latch_q <= (OTHERS => '0');
			hex1_latch_q <= (OTHERS => '0');
			hex2_latch_q <= (OTHERS => '0');
			hex3_latch_q <= (OTHERS => '0');
			hex4_latch_q <= (OTHERS => '0');
			hex5_latch_q <= (OTHERS => '0');
		ELSIF rising_edge(smclk_i) THEN
			IF output_write_enable_w(0) = '1' THEN
				ledr_latch_q <= data_wr_i(7 DOWNTO 0);
			END IF;
			IF output_write_enable_w(1) = '1' THEN
				hex0_latch_q <= data_wr_i(7 DOWNTO 0);
			END IF;
			IF output_write_enable_w(2) = '1' THEN
				hex1_latch_q <= data_wr_i(7 DOWNTO 0);
			END IF;
			IF output_write_enable_w(3) = '1' THEN
				hex2_latch_q <= data_wr_i(7 DOWNTO 0);
			END IF;
			IF output_write_enable_w(4) = '1' THEN
				hex3_latch_q <= data_wr_i(7 DOWNTO 0);
			END IF;
			IF output_write_enable_w(5) = '1' THEN
				hex4_latch_q <= data_wr_i(7 DOWNTO 0);
			END IF;
			IF output_write_enable_w(6) = '1' THEN
				hex5_latch_q <= data_wr_i(7 DOWNTO 0);
			END IF;
		END IF;
	END PROCESS;

	-- Enable the shared-bus driver for valid GPIO reads.
	data_oe_o <= sw_read_enable_w OR pb_read_enable_w;

	-- Switches and active-low pushbuttons are read without storage and
	-- zero-extended to the CPU bus width. BidirPin alone owns tri-state control.
	READ_DATA_MUX_P : PROCESS(ALL)
	BEGIN
		data_rd_o <= (OTHERS => '0');
		IF sw_read_enable_w = '1' THEN
			data_rd_o(7 DOWNTO 0) <= sw_i;
		ELSIF pb_read_enable_w = '1' THEN
			data_rd_o(7 DOWNTO 0) <= "00000" & key_n_i;
		END IF;
	END PROCESS;

	-- Drive the LED outputs.
	ledr_o <= ledr_latch_q;

	-- Decode each display byte independently.
	HEX0_ENCODER : Hex_Display_Decoder PORT MAP(data_i => hex0_latch_q, segments_o => hex0_o);
	HEX1_ENCODER : Hex_Display_Decoder PORT MAP(data_i => hex1_latch_q, segments_o => hex1_o);
	HEX2_ENCODER : Hex_Display_Decoder PORT MAP(data_i => hex2_latch_q, segments_o => hex2_o);
	HEX3_ENCODER : Hex_Display_Decoder PORT MAP(data_i => hex3_latch_q, segments_o => hex3_o);
	HEX4_ENCODER : Hex_Display_Decoder PORT MAP(data_i => hex4_latch_q, segments_o => hex4_o);
	HEX5_ENCODER : Hex_Display_Decoder PORT MAP(data_i => hex5_latch_q, segments_o => hex5_o);
END structural;
