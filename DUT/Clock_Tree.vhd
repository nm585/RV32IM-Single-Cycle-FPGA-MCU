-- Clock generation for the CPU, peripheral and divider domains.
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.cond_compilation_package.ALL;
USE work.aux_package.ALL;

ENTITY Clock_Tree IS
	GENERIC (
		-- MODELSIM=1 bypasses the PLLs and uses CLOCK_50 for every domain.
		MODELSIM : integer := G_MODELSIM
	);
	PORT (
		clock_50_i : IN  STD_LOGIC;
		mclk_o     : OUT STD_LOGIC;
		smclk_o    : OUT STD_LOGIC;
		divclk_o   : OUT STD_LOGIC
	);
END Clock_Tree;

ARCHITECTURE structural OF Clock_Tree IS
BEGIN
	HARDWARE_CLOCKS_G : IF (MODELSIM = 0) GENERATE
		MCLK_PLL_U : PLL
		GENERIC MAP (
			OUTPUT_DIVIDE_BY   => G_PLL_DIV,
			OUTPUT_MULTIPLY_BY => G_PLL_MUL
		)
		PORT MAP (
			inclk0 => clock_50_i,
			c0     => mclk_o
		);

		SMCLK_PLL_U : PLL
		GENERIC MAP (
			OUTPUT_DIVIDE_BY   => G_SMCLK_PLL_DIV,
			OUTPUT_MULTIPLY_BY => G_SMCLK_PLL_MUL
		)
		PORT MAP (
			inclk0 => clock_50_i,
			c0     => smclk_o
		);

		DIVCLK_PLL_U : PLL
		GENERIC MAP (
			OUTPUT_DIVIDE_BY   => G_DIVCLK_PLL_DIV,
			OUTPUT_MULTIPLY_BY => G_DIVCLK_PLL_MUL
		)
		PORT MAP (
			inclk0 => clock_50_i,
			c0     => divclk_o
		);
	END GENERATE;

	SIMULATION_CLOCKS_G : IF (MODELSIM /= 0) GENERATE
		mclk_o   <= clock_50_i;
		smclk_o  <= clock_50_i;
		divclk_o <= clock_50_i;
	END GENERATE;
END structural;
