--============================================================================
-- Copyright 2026 Hananya Ribo 
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- Build-time memory, addressing, simulation, and PLL configuration.
--============================================================================ 
library IEEE;
use ieee.std_logic_1164.all;


package cond_compilation_package is

-- M9K memories use word addressing.
	constant M9K_TCM1KiB_ADDRWIDTH 		: integer := 8;
	constant M9K_TCM2KiB_ADDRWIDTH 		: integer := 9;
	constant M9K_TCM4KiB_ADDRWIDTH 		: integer := 10;
	constant M9K_TCM8KiB_ADDRWIDTH 		: integer := 11;
	
	constant M9K_TCM1KiB_WORDSNUM 		: integer := 256;
	constant M9K_TCM2KiB_WORDSNUM 		: integer := 512;
	constant M9K_TCM4KiB_WORDSNUM 		: integer := 1024;
	constant M9K_TCM8KiB_WORDSNUM 		: integer := 2048;
-- Legacy M4K memories use byte addressing.
	constant M4K_TCM1KiB_ADDRWIDTH 		: integer := 10;
	constant M4K_TCM2KiB_ADDRWIDTH 		: integer := 11;
	constant M4K_TCM4KiB_ADDRWIDTH 		: integer := 12;
	constant M4K_TCM8KiB_ADDRWIDTH 		: integer := 13;
	
	constant M4K_TCM1KiB_WORDSNUM 		: integer := 1024;
	constant M4K_TCM2KiB_WORDSNUM 		: integer := 2048;
	constant M4K_TCM4KiB_WORDSNUM 		: integer := 4095;
	constant M4K_TCM8KiB_WORDSNUM 		: integer := 8190;
-- Program-counter width per TCM capacity.
	constant PC_WIDTH_TCM1KiB			: integer := 10;
	constant PC_WIDTH_TCM2KiB 		: integer := 11;
	constant PC_WIDTH_TCM4KiB 		: integer := 12;
	constant PC_WIDTH_TCM8KiB 		: integer := 13;
-- Memory-address width per TCM capacity.
	constant MA_WIDTH_TCM1KiB 		: integer := 10;
	constant MA_WIDTH_TCM2KiB 		: integer := 11;
	constant MA_WIDTH_TCM4KiB 		: integer := 12;
	constant MA_WIDTH_TCM8KiB 		: integer := 13;
--==================================================================================================================
-- Choose the active build profile here.
	constant G_MODELSIM					: integer	:= 0;											-- 1 selects simulation; 0 selects FPGA hardware.
	-- Keep memory family, depth and addressing consistent.
	constant G_WORD_GRANULARITY : boolean := True;									-- options{True,False}
	constant G_ADDRWIDTH 				: integer := M9K_TCM8KiB_ADDRWIDTH;	-- options{M9K_MODELSIM_ADDRWIDTH,M4K_ADDRWIDTH} 
	constant G_DATA_WORDSNUM 		: integer := M9K_TCM8KiB_WORDSNUM;	-- options{M9K_MODELSIM_WORDSNUM,M4K_WORDSNUM}
	constant G_PC_WIDTH 				: integer := PC_WIDTH_TCM8KiB;			-- options{PC_WIDTH_TCM1KiB,PC_WIDTH_TCM2KiB,...}
	constant G_MA_WIDTH 				: integer := MA_WIDTH_TCM8KiB;			-- options{MA_WIDTH_TCM1KiB,MA_WIDTH_TCM2KiB,...}
	constant DBUS_WIDTH 				: integer	:= 32;
	constant G_PLL_DIV		 			: NATURAL	:= 2;											-- 50 MHz * 2 / 5 = 20 MHz MCLK.
	constant G_PLL_MUL		 			: NATURAL	:= 1;
	constant G_SMCLK_PLL_DIV	: NATURAL	:= 2;											-- 50 MHz * 2 / 5 = 20 MHz SMCLK.
	constant G_SMCLK_PLL_MUL	: NATURAL	:= 1;
	constant G_DIVCLK_PLL_DIV	: NATURAL	:= 2;											-- 50 MHz * 5 / 2 = 125 MHz DIVCLK.
	constant G_DIVCLK_PLL_MUL	: NATURAL	:= 6;
	
-- G_MODELSIM bypasses the PLLs. Hardware builds use the configured ratios.
-- G_WORD_GRANULARITY selects word or byte addressing for both TCMs.

end cond_compilation_package;
