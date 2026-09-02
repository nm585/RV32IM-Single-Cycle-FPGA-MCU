library ieee;
use ieee.std_logic_1164.all;

-- One endpoint on a shared data bus.
-- The input always samples the bus; en controls the output driver.
entity BidirPin is
		-- Shared-bus interface.
	generic( width: integer:=16 );
	port(	-- Bus output data.
			Dout: 	in 		std_logic_vector(width-1 downto 0);
			-- Output enable.
			en:		in 		std_logic;
			-- Resolved bus input.
			Din:	out		std_logic_vector(width-1 downto 0);
			-- Shared bus pin.
			IOpin: 	inout 	std_logic_vector(width-1 downto 0)
	);
end BidirPin;

architecture combinational of BidirPin is
begin 

		-- Din continuously reflects the resolved bus value.
	Din  <= IOpin;
	IOpin <= Dout when(en='1') else (others => 'Z');
	
end combinational;
