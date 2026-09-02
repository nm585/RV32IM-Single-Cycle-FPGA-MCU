-- Focused testbench for the SMCLK-DFF GPIO peripheral from Figures 5 and 6.
-- It checks edge-triggered output registers, decoding and direct input reads.
---------------------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.aux_package.ALL;
USE STD.ENV.ALL;

ENTITY tb_GPIO_Peripheral IS
END tb_GPIO_Peripheral;

ARCHITECTURE sim OF tb_GPIO_Peripheral IS
	-- Register addresses that share a chip-select differ only in the low bit;
	-- keeping them named makes those aliasing checks easier to follow.
	CONSTANT DATA_BUS_WIDTH : integer := 32;
	CONSTANT CLK_PERIOD     : time := 20 ns;

	CONSTANT PORT_LEDR : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2000";
	CONSTANT PORT_HEX0 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2004";
	CONSTANT PORT_HEX1 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2005";
	CONSTANT PORT_HEX2 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2008";
	CONSTANT PORT_HEX3 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2009";
	CONSTANT PORT_HEX4 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"200C";
	CONSTANT PORT_HEX5 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"200D";
	CONSTANT PORT_SW   : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2010";
	CONSTANT PORT_PB   : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2014";

	TYPE addr_array_t IS ARRAY(NATURAL RANGE <>) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
	-- Gaps around the implemented registers are checked explicitly so a broad
	-- decoder cannot silently claim unused addresses.
	CONSTANT INVALID_ADDRS : addr_array_t(0 TO 11) := (
		x"2001", x"2002", x"2003",
		x"2006", x"2007",
		x"200A", x"200B",
		x"200E", x"200F",
		x"2011", x"2012", x"2013"
	);

	-- Only the input ports may claim the GPIO read bus. LEDR and HEX0...HEX5 are
	-- write-only GPO interfaces.
	FUNCTION gpio_read_enable(
		CONSTANT reg_addr : STD_LOGIC_VECTOR(15 DOWNTO 0)
	) RETURN STD_LOGIC IS
	BEGIN
		IF reg_addr = PORT_SW OR reg_addr = PORT_PB THEN
			RETURN '1';
		END IF;
		RETURN '0';
	END FUNCTION;

	SIGNAL rst_i           : STD_LOGIC := '1';
	SIGNAL smclk_i         : STD_LOGIC := '0';
	SIGNAL addr_i          : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
	SIGNAL data_wr_i       : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL mem_read_i      : STD_LOGIC := '0';
	SIGNAL mem_write_i     : STD_LOGIC := '0';
	SIGNAL sw_i            : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
	SIGNAL key_n_i         : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '1');
	SIGNAL data_rd_o       : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL data_oe_o       : STD_LOGIC;
	SIGNAL ledr_o          : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL hex0_o          : STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL hex1_o          : STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL hex2_o          : STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL hex3_o          : STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL hex4_o          : STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL hex5_o          : STD_LOGIC_VECTOR(6 DOWNTO 0);
BEGIN
	DUT : GPIO_Peripheral
	PORT MAP(
		smclk_i         => smclk_i,
		rst_i           => rst_i,
		addr_i          => addr_i,
		data_wr_i       => data_wr_i,
		mem_read_i      => mem_read_i,
		mem_write_i     => mem_write_i,
		sw_i            => sw_i,
		key_n_i         => key_n_i,
		data_rd_o       => data_rd_o,
		data_oe_o       => data_oe_o,
		ledr_o          => ledr_o,
		hex0_o          => hex0_o,
		hex1_o          => hex1_o,
		hex2_o          => hex2_o,
		hex3_o          => hex3_o,
		hex4_o          => hex4_o,
		hex5_o          => hex5_o
	);

	smclk_i <= NOT smclk_i AFTER CLK_PERIOD / 2;

	stimulus : PROCESS
		PROCEDURE tick IS
		BEGIN
			WAIT UNTIL rising_edge(smclk_i);
			WAIT FOR 1 ns;
		END PROCEDURE;

		-- Hold a complete write transaction stable across one rising SMCLK edge.
		PROCEDURE mmio_write(
			CONSTANT reg_addr : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			CONSTANT value    : IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		) IS
		BEGIN
			addr_i      <= reg_addr;
			data_wr_i   <= value;
			mem_write_i <= '1';
			tick;
			ASSERT data_oe_o = '0'
				REPORT "GPIO drove the read bus during an MMIO write" SEVERITY error;
			mem_write_i <= '0';
			data_wr_i   <= (OTHERS => '0');
			WAIT FOR 1 ns;
		END PROCEDURE;

		-- Check the selected data and OE together, then confirm that the GPIO block
		-- releases the shared bus as soon as MemRead is removed.
		PROCEDURE expect_read(
			CONSTANT reg_addr : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			CONSTANT value    : IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			CONSTANT msg      : IN string
		) IS
		BEGIN
			addr_i     <= reg_addr;
			mem_read_i <= '1';
			WAIT FOR 1 ns;
			ASSERT data_rd_o = value REPORT msg SEVERITY error;
			ASSERT data_oe_o = gpio_read_enable(reg_addr)
				REPORT msg & ": data-bus output enable was wrong" SEVERITY error;
			mem_read_i <= '0';
			WAIT FOR 1 ns;
			ASSERT data_oe_o = '0'
				REPORT msg & ": data-bus output remained enabled" SEVERITY error;
		END PROCEDURE;
	BEGIN
		-- Reset is asynchronous; release it before the first active clock edge.
		tick;
		rst_i <= '0';
		tick;

		ASSERT ledr_o = x"00" REPORT "PORT_LEDR was not reset" SEVERITY error;
		ASSERT hex0_o = "1000000" REPORT "PORT_HEX0 was not reset to zero" SEVERITY error;
		ASSERT hex1_o = "1000000" REPORT "PORT_HEX1 was not reset to zero" SEVERITY error;
		ASSERT hex2_o = "1000000" REPORT "PORT_HEX2 was not reset to zero" SEVERITY error;
		ASSERT hex3_o = "1000000" REPORT "PORT_HEX3 was not reset to zero" SEVERITY error;
		ASSERT hex4_o = "1000000" REPORT "PORT_HEX4 was not reset to zero" SEVERITY error;
		ASSERT hex5_o = "1000000" REPORT "PORT_HEX5 was not reset to zero" SEVERITY error;

		-- A legal address by itself is harmless without MemWrite at the edge.
		addr_i      <= PORT_LEDR;
		data_wr_i   <= x"000000FF";
		tick;
		ASSERT ledr_o = x"00" REPORT "Write occurred while MemWrite was low" SEVERITY error;

		-- Likewise, the switch input must not reach the bus without MemRead.
		sw_i       <= x"FF";
		addr_i     <= PORT_SW;
		WAIT FOR 1 ns;
		ASSERT data_rd_o = x"00000000" REPORT "Read data was driven while MemRead was low" SEVERITY error;
		ASSERT data_oe_o = '0' REPORT "GPIO enabled the shared bus while MemRead was low" SEVERITY error;

		-- A DFF changes only on the active edge: changing DataBUS between edges
		-- must not leak to the output even while MemWrite remains asserted.
		addr_i      <= PORT_LEDR;
		mem_write_i <= '1';
		data_wr_i   <= x"0000003C";
		tick;
		ASSERT ledr_o = x"3C" REPORT "PORT_LEDR DFF missed the rising-edge write" SEVERITY error;
		data_wr_i <= x"000000A5";
		WAIT FOR 2 ns;
		ASSERT ledr_o = x"3C" REPORT "PORT_LEDR changed between clock edges" SEVERITY error;
		tick;
		ASSERT ledr_o = x"A5" REPORT "PORT_LEDR DFF missed the second rising-edge write" SEVERITY error;
		mem_write_i <= '0';
		data_wr_i   <= x"000000FF";
		tick;
		ASSERT ledr_o = x"A5" REPORT "PORT_LEDR DFF did not hold its value" SEVERITY error;
		data_wr_i <= (OTHERS => '0');

		-- Program a distinct byte into every output register.
		mmio_write(PORT_LEDR, x"000000A5");
		mmio_write(PORT_HEX0, x"000000B5");
		mmio_write(PORT_HEX1, x"000000C6");
		mmio_write(PORT_HEX2, x"000000A7");
		mmio_write(PORT_HEX3, x"000000B8");
		mmio_write(PORT_HEX4, x"000000C9");
		mmio_write(PORT_HEX5, x"000000DA");

		ASSERT ledr_o = x"A5" REPORT "PORT_LEDR output failed" SEVERITY error;
		ASSERT hex0_o = "0010010" REPORT "PORT_HEX0 did not decode low nibble 5" SEVERITY error;
		ASSERT hex1_o = "0000010" REPORT "PORT_HEX1 did not decode low nibble 6" SEVERITY error;
		ASSERT hex2_o = "1111000" REPORT "PORT_HEX2 did not decode low nibble 7" SEVERITY error;
		ASSERT hex3_o = "0000000" REPORT "PORT_HEX3 did not decode low nibble 8" SEVERITY error;
		ASSERT hex4_o = "0010000" REPORT "PORT_HEX4 did not decode low nibble 9" SEVERITY error;
		ASSERT hex5_o = "0001000" REPORT "PORT_HEX5 did not decode low nibble A" SEVERITY error;

		-- A CPU read from any GPO address must leave the shared bus released even
		-- when its output register contains a nonzero value.
		expect_read(PORT_LEDR, x"00000000", "PORT_LEDR incorrectly drove read data");
		expect_read(PORT_HEX0, x"00000000", "PORT_HEX0 incorrectly drove read data");
		expect_read(PORT_HEX1, x"00000000", "PORT_HEX1 incorrectly drove read data");
		expect_read(PORT_HEX2, x"00000000", "PORT_HEX2 incorrectly drove read data");
		expect_read(PORT_HEX3, x"00000000", "PORT_HEX3 incorrectly drove read data");
		expect_read(PORT_HEX4, x"00000000", "PORT_HEX4 incorrectly drove read data");
		expect_read(PORT_HEX5, x"00000000", "PORT_HEX5 incorrectly drove read data");
		ASSERT ledr_o = x"A5" REPORT "GPO read changed PORT_LEDR" SEVERITY error;
		ASSERT hex0_o = "0010010" REPORT "GPO read changed PORT_HEX0" SEVERITY error;
		ASSERT hex1_o = "0000010" REPORT "GPO read changed PORT_HEX1" SEVERITY error;
		ASSERT hex2_o = "1111000" REPORT "GPO read changed PORT_HEX2" SEVERITY error;
		ASSERT hex3_o = "0000000" REPORT "GPO read changed PORT_HEX3" SEVERITY error;
		ASSERT hex4_o = "0010000" REPORT "GPO read changed PORT_HEX4" SEVERITY error;
		ASSERT hex5_o = "0001000" REPORT "GPO read changed PORT_HEX5" SEVERITY error;

		-- With no active MemRead, every interface must release the internal bus;
		-- the wrapper turns the resulting all-Z value into a zero read result.
		addr_i     <= PORT_LEDR;
		mem_read_i <= '0';
		WAIT FOR 1 ns;
		ASSERT data_rd_o = x"00000000" REPORT "Released tri-state bus did not read zero" SEVERITY error;
		ASSERT data_oe_o = '0' REPORT "GPIO did not release its shared-bus output" SEVERITY error;

		-- PORT_HEX0 and PORT_HEX1 share a group chip-select. Write each low-bit
		-- variant and confirm through the physical outputs that A0 prevents the
		-- neighboring register from changing.
		mmio_write(PORT_HEX0, x"00000011");
		ASSERT hex0_o = "1111001" REPORT "A0=0 did not select PORT_HEX0" SEVERITY error;
		ASSERT hex1_o = "0000010" REPORT "A0=0 changed PORT_HEX1" SEVERITY error;
		mmio_write(PORT_HEX1, x"00000022");
		ASSERT hex0_o = "1111001" REPORT "A0=1 changed PORT_HEX0" SEVERITY error;
		ASSERT hex1_o = "0100100" REPORT "A0=1 did not select PORT_HEX1" SEVERITY error;

		-- PORT_SW is a direct input path, so consecutive reads should follow switch
		-- changes without any clock or storage delay.
		sw_i <= x"5A";
		expect_read(PORT_SW, x"0000005A", "PORT_SW direct read failed");
		sw_i <= x"A6";
		expect_read(PORT_SW, x"000000A6", "PORT_SW did not update without a clock");

		-- PORT_PB is equally direct and preserves the board's active-low levels.
		-- The bit order is KEY1, KEY2, KEY3 from least to most significant.
		key_n_i <= "110";
		expect_read(PORT_PB, x"00000006", "PORT_PB KEY1 direct read failed");
		key_n_i <= "101";
		expect_read(PORT_PB, x"00000005", "PORT_PB KEY2 direct read failed");
		key_n_i <= "011";
		expect_read(PORT_PB, x"00000003", "PORT_PB KEY3 direct read failed");
		key_n_i <= "111";
		expect_read(PORT_PB, x"00000007", "PORT_PB release read failed");

		-- Both input registers are read-only, so CPU writes must be ignored.
		mmio_write(PORT_SW, x"000000FF");
		mmio_write(PORT_PB, x"00000000");
		ASSERT ledr_o = x"A5" REPORT "Input-port write changed PORT_LEDR" SEVERITY error;
		ASSERT hex0_o = "1111001" REPORT "Input-port write changed PORT_HEX0" SEVERITY error;
		ASSERT hex1_o = "0100100" REPORT "Input-port write changed PORT_HEX1" SEVERITY error;
		ASSERT hex2_o = "1111000" REPORT "Input-port write changed PORT_HEX2" SEVERITY error;
		ASSERT hex3_o = "0000000" REPORT "Input-port write changed PORT_HEX3" SEVERITY error;
		ASSERT hex4_o = "0010000" REPORT "Input-port write changed PORT_HEX4" SEVERITY error;
		ASSERT hex5_o = "0001000" REPORT "Input-port write changed PORT_HEX5" SEVERITY error;

		-- First prove unused addresses never claim the read bus, then spray writes
		-- across the same gaps and inspect all physical outputs for corruption.
		FOR i IN INVALID_ADDRS'RANGE LOOP
			expect_read(INVALID_ADDRS(i), x"00000000", "Invalid GPIO address drove read data");
		END LOOP;

		FOR i IN INVALID_ADDRS'RANGE LOOP
			mmio_write(INVALID_ADDRS(i), x"000000FF");
		END LOOP;
		ASSERT ledr_o = x"A5" REPORT "Invalid address changed PORT_LEDR" SEVERITY error;
		ASSERT hex0_o = "1111001" REPORT "Invalid address changed PORT_HEX0" SEVERITY error;
		ASSERT hex1_o = "0100100" REPORT "Invalid address changed PORT_HEX1" SEVERITY error;
		ASSERT hex2_o = "1111000" REPORT "Invalid address changed PORT_HEX2" SEVERITY error;
		ASSERT hex3_o = "0000000" REPORT "Invalid address changed PORT_HEX3" SEVERITY error;
		ASSERT hex4_o = "0010000" REPORT "Invalid address changed PORT_HEX4" SEVERITY error;
		ASSERT hex5_o = "0001000" REPORT "Invalid address changed PORT_HEX5" SEVERITY error;

		ASSERT false REPORT "tb_GPIO_Peripheral completed successfully" SEVERITY note;
		STOP;
		WAIT;
	END PROCESS;
END sim;
