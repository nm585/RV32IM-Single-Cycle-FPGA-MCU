LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE STD.ENV.ALL;
USE work.cond_compilation_package.ALL;
USE work.aux_package.ALL;

-- Core-level test for the divider benchmark already loaded by IFETCH/DMEMORY.
-- The testbench does not replace either memory. Their existing init_file paths
-- load ITCM.hex and DTCM.hex from Benchmark apps/RV32IM/test1/gcc_compiled.
ENTITY tb_core_divider IS
    GENERIC (
        MCLK_PERIOD   : TIME := 40 ns;
        DIVCLK_PERIOD : TIME := 8 ns
    );
END tb_core_divider;

ARCHITECTURE test OF tb_core_divider IS
    CONSTANT DATA_BUS_WIDTH_C : INTEGER := 32;

    TYPE word_array_t IS ARRAY (0 TO 7) OF STD_LOGIC_VECTOR(31 DOWNTO 0);

    -- test1.s divides, multiplies and calculates the remainder of:
    -- arr1=(1,2,3,4,5,6,7,8), arr2=(8,7,6,5,4,3,2,1).
    CONSTANT EXPECTED_QUOTIENT_C : word_array_t := (
        x"00000000", x"00000000", x"00000000", x"00000000",
        x"00000001", x"00000002", x"00000003", x"00000008"
    );
    CONSTANT EXPECTED_PRODUCT_C : word_array_t := (
        x"00000008", x"0000000E", x"00000012", x"00000014",
        x"00000014", x"00000012", x"0000000E", x"00000008"
    );
    CONSTANT EXPECTED_REMAINDER_C : word_array_t := (
        x"00000001", x"00000002", x"00000003", x"00000004",
        x"00000001", x"00000000", x"00000001", x"00000000"
    );

    SIGNAL rst_s          : STD_LOGIC := '1';
    SIGNAL mclk_s         : STD_LOGIC := '0';
    SIGNAL divclk_s       : STD_LOGIC := '0';

    SIGNAL shared_data_bus_s : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => 'Z');
    SIGNAL data_bus_read_s    : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL dtcm_bus_data_in_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL dtcm_data_rd_s     : STD_LOGIC_VECTOR(31 DOWNTO 0);

    SIGNAL mem_read_s       : STD_LOGIC;
    SIGNAL mem_write_s      : STD_LOGIC;
    SIGNAL bus_mem_read_s   : STD_LOGIC;
    SIGNAL bus_mem_write_s  : STD_LOGIC;
    SIGNAL dtcm_mem_read_s  : STD_LOGIC;
    SIGNAL dtcm_mem_write_s : STD_LOGIC;
    SIGNAL dtcm_cs_s        : STD_LOGIC;

    SIGNAL divena_s       : STD_LOGIC;
    SIGNAL remu_s         : STD_LOGIC;
    SIGNAL divbusy_s      : STD_LOGIC;
    SIGNAL div_quotient_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL div_residue_s  : STD_LOGIC_VECTOR(31 DOWNTO 0);

    SIGNAL int_busy_s     : STD_LOGIC;
    SIGNAL int_dispatch_s : STD_LOGIC;

    SIGNAL read_data1_s  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL read_data2_s  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL alu_res_s     : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL dtcm_addr_s   : STD_LOGIC_VECTOR(G_ADDRWIDTH-1 DOWNTO 0);
    SIGNAL pc_s          : STD_LOGIC_VECTOR(G_PC_WIDTH-1 DOWNTO 0);
    SIGNAL instruction_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL reg_write_s   : STD_LOGIC;
    SIGNAL branch_s      : STD_LOGIC;
    SIGNAL write_data_s  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL br_taken_s    : STD_LOGIC;
    SIGNAL mclk_count_s  : STD_LOGIC_VECTOR(15 DOWNTO 0);
BEGIN
    -- The same memory/address profile used by the current COPY_COPY project.
    CORE : ENTITY work.RV32IM_CORE
        GENERIC MAP (
            WORD_GRANULARITY => G_WORD_GRANULARITY,
            MODELSIM         => G_MODELSIM,
            DATA_BUS_WIDTH   => DATA_BUS_WIDTH_C,
            ITCM_ADDR_WIDTH  => G_ADDRWIDTH,
            DTCM_ADDR_WIDTH  => G_ADDRWIDTH,
            PC_WIDTH         => G_PC_WIDTH,
            MA_WIDTH         => G_MA_WIDTH,
            DATA_WORDS_NUM   => G_DATA_WORDSNUM,
            CLK_CNT_WIDTH    => 16
        )
        PORT MAP (
            mclk_i           => mclk_s,
            mclk_rst_i       => rst_s,
            data_bus_read_i  => data_bus_read_s,
            dtcm_data_wr_i   => dtcm_bus_data_in_s,
            dtcm_mem_read_i  => dtcm_mem_read_s,
            dtcm_mem_write_i => dtcm_mem_write_s,
            dtcm_data_rd_o   => dtcm_data_rd_s,
            dtcm_addr_o      => dtcm_addr_s,
            divbusy_i        => divbusy_s,
            div_quotient_i   => div_quotient_s,
            div_residue_i    => div_residue_s,
            intr_i           => '0',
            MemRead_ctrl_o   => mem_read_s,
            MemWrite_ctrl_o  => mem_write_s,
            DIVENA_o         => divena_s,
            REMU_ctrl_o      => remu_s,
            gie_o            => OPEN,
            inta_n_o         => OPEN,
            int_busy_o       => int_busy_s,
            int_dispatch_o   => int_dispatch_s,
            read_data1_o     => read_data1_s,
            read_data2_o     => read_data2_s,
            alu_res_o        => alu_res_s,
            pc_o             => pc_s,
            instruction_o    => instruction_s,
            RegWrite_ctrl_o  => reg_write_s,
            Branch_ctrl_o    => branch_s,
            write_data_o     => write_data_s,
            brTaken_o        => br_taken_s,
            mclk_cnt_o       => mclk_count_s
        );

    -- Reproduce the DTCM part of the shared bus used by FPGA_Top_SingleCycle.
    dtcm_cs_s <= '1' WHEN alu_res_s(15 DOWNTO 13) = "000" ELSE '0';

    bus_mem_read_s  <= mem_read_s  AND NOT int_busy_s;
    bus_mem_write_s <= mem_write_s AND NOT int_busy_s;

    dtcm_mem_read_s  <= int_dispatch_s OR (bus_mem_read_s AND dtcm_cs_s);
    dtcm_mem_write_s <= bus_mem_write_s AND dtcm_cs_s;

    CPU_DATA_BUS_U : BidirPin
        GENERIC MAP (width => DATA_BUS_WIDTH_C)
        PORT MAP (
            Dout  => read_data2_s,
            en    => bus_mem_write_s,
            Din   => data_bus_read_s,
            IOpin => shared_data_bus_s
        );

    DTCM_DATA_BUS_U : BidirPin
        GENERIC MAP (width => DATA_BUS_WIDTH_C)
        PORT MAP (
            Dout  => dtcm_data_rd_s,
            en    => dtcm_mem_read_s,
            Din   => dtcm_bus_data_in_s,
            IOpin => shared_data_bus_s
        );

    DIVIDER_U : ENTITY work.Divider_CDC
        PORT MAP (
            MCLK     => mclk_s,
            MCLKRST  => rst_s,
            DIVCLK   => divclk_s,
            DIVRST   => rst_s,
            DIVENA   => divena_s,
            Dividend => read_data1_s,
            Divisor  => read_data2_s,
            DIVBUSY  => divbusy_s,
            Residue  => div_residue_s,
            Quotient => div_quotient_s
        );

    mclk_s   <= NOT mclk_s AFTER MCLK_PERIOD / 2;
    divclk_s <= NOT divclk_s AFTER DIVCLK_PERIOD / 2;

    RESET_P : PROCESS
    BEGIN
        rst_s <= '1';
        WAIT FOR 4 * MCLK_PERIOD;
        WAIT UNTIL falling_edge(mclk_s);
        rst_s <= '0';
        WAIT;
    END PROCESS;

    RESULT_MONITOR_P : PROCESS
        VARIABLE quotient_count_v  : NATURAL := 0;
        VARIABLE product_count_v   : NATURAL := 0;
        VARIABLE remainder_count_v : NATURAL := 0;
        VARIABLE divider_count_v   : NATURAL := 0;
        VARIABLE cycles_v          : NATURAL := 0;
        VARIABLE address_v         : INTEGER;
        VARIABLE index_v           : INTEGER;
        VARIABLE previous_busy_v   : STD_LOGIC := '0';
    BEGIN
        WAIT UNTIL rst_s = '0';

        WHILE cycles_v < 5000 LOOP
            -- DTCM writes occur on the falling MCLK edge in DMEMORY.VHD.
            WAIT UNTIL falling_edge(mclk_s);
            WAIT FOR 1 ns;
            cycles_v := cycles_v + 1;

            IF previous_busy_v = '1' AND divbusy_s = '0' THEN
                divider_count_v := divider_count_v + 1;
            END IF;
            previous_busy_v := divbusy_s;

            IF dtcm_mem_write_s = '1' THEN
                address_v := CONV_INTEGER(dtcm_addr_s);

                IF address_v >= 16 AND address_v <= 23 THEN
                    IF quotient_count_v < 8 THEN
                        index_v := quotient_count_v;
                        ASSERT address_v = 16 + index_v
                            REPORT "Unexpected DIV result address"
                            SEVERITY FAILURE;
                        ASSERT dtcm_bus_data_in_s = EXPECTED_QUOTIENT_C(index_v)
                            REPORT "Incorrect DIV result at res1 index " & INTEGER'IMAGE(index_v)
                            SEVERITY FAILURE;
                        quotient_count_v := quotient_count_v + 1;
                    ELSE
                        ASSERT FALSE REPORT "More than 8 DIV results were written"
                            SEVERITY FAILURE;
                    END IF;

                ELSIF address_v >= 24 AND address_v <= 31 THEN
                    IF product_count_v < 8 THEN
                        index_v := product_count_v;
                        ASSERT address_v = 24 + index_v
                            REPORT "Unexpected MUL result address"
                            SEVERITY FAILURE;
                        ASSERT dtcm_bus_data_in_s = EXPECTED_PRODUCT_C(index_v)
                            REPORT "Incorrect MUL result at res2 index " & INTEGER'IMAGE(index_v)
                            SEVERITY FAILURE;
                        product_count_v := product_count_v + 1;
                    ELSE
                        ASSERT FALSE REPORT "More than 8 MUL results were written"
                            SEVERITY FAILURE;
                    END IF;

                ELSIF address_v >= 32 AND address_v <= 39 THEN
                    IF remainder_count_v < 8 THEN
                        index_v := remainder_count_v;
                        ASSERT address_v = 32 + index_v
                            REPORT "Unexpected REM result address"
                            SEVERITY FAILURE;
                        ASSERT dtcm_bus_data_in_s = EXPECTED_REMAINDER_C(index_v)
                            REPORT "Incorrect REM result at res3 index " & INTEGER'IMAGE(index_v)
                            SEVERITY FAILURE;
                        remainder_count_v := remainder_count_v + 1;
                    ELSE
                        ASSERT FALSE REPORT "More than 8 REM results were written"
                            SEVERITY FAILURE;
                    END IF;
                END IF;
            END IF;

            IF quotient_count_v = 8 AND product_count_v = 8 AND
               remainder_count_v = 8 THEN
                ASSERT divider_count_v = 16
                    REPORT "Expected 16 completed divider operations, observed " &
                           INTEGER'IMAGE(divider_count_v)
                    SEVERITY FAILURE;

                REPORT "tb_core_divider: PASS - 8 DIV, 8 MUL and 8 REM results were written correctly"
                    SEVERITY NOTE;
                STOP;
                WAIT;
            END IF;
        END LOOP;

        ASSERT FALSE
            REPORT "tb_core_divider timeout before all benchmark results were written"
            SEVERITY FAILURE;
        WAIT;
    END PROCESS;
END test;
