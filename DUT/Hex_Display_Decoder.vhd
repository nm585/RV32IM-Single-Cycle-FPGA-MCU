-- Hexadecimal decoder for the board's active-low seven-segment displays.
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY Hex_Display_Decoder IS
	PORT(
		data_i     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		segments_o : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
	);
END Hex_Display_Decoder;

ARCHITECTURE rtl OF Hex_Display_Decoder IS
BEGIN
	-- The register is eight bits wide for the MMIO interface, but a single HEX
	-- digit needs only its low nibble. A zero in the table lights that segment.
	WITH data_i(3 DOWNTO 0) SELECT segments_o <=
		"1000000" WHEN x"0",
		"1111001" WHEN x"1",
		"0100100" WHEN x"2",
		"0110000" WHEN x"3",
		"0011001" WHEN x"4",
		"0010010" WHEN x"5",
		"0000010" WHEN x"6",
		"1111000" WHEN x"7",
		"0000000" WHEN x"8",
		"0010000" WHEN x"9",
		"0001000" WHEN x"A",
		"0000011" WHEN x"B",
		"1000110" WHEN x"C",
		"0100001" WHEN x"D",
		"0000110" WHEN x"E",
		"0001110" WHEN OTHERS;
END rtl;
