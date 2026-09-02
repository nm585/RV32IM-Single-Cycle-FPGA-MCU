LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE STD.ENV.ALL;
USE work.aux_package.ALL;

-- Verifies the Basic Timer's MMIO wrapper: register field masking, data-bus
-- ownership, compare-event forwarding and the hardware-updated capture register.

ENTITY tb_TimerPeripheral IS
END tb_TimerPeripheral;

ARCHITECTURE test OF tb_TimerPeripheral IS
    -- Byte addresses from the timer section of the peripheral map.
    CONSTANT CLK_PERIOD   : TIME := 20 ns;
    CONSTANT BTCTL1  : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"201C";
    CONSTANT BTCTL2  : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"201D";
    CONSTANT BTCMPR0 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2020";
    CONSTANT BTCMPR1 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2024";
    CONSTANT BTCAPR  : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2028";
    CONSTANT UNMAPPED_TIMER_ADDRESS_C : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"201E";

    -- Expected bus ownership is derived from the documented registers rather
    -- than from DUT outputs, keeping the OE assertion meaningful.
    FUNCTION timer_read_enable(
        CONSTANT reg_addr : STD_LOGIC_VECTOR(15 DOWNTO 0)
    ) RETURN STD_LOGIC IS
    BEGIN
        IF reg_addr = BTCTL1 OR reg_addr = BTCTL2 OR
           reg_addr = BTCMPR0 OR reg_addr = BTCMPR1 OR
           reg_addr = BTCAPR THEN
            RETURN '1';
        END IF;
        RETURN '0';
    END FUNCTION;

    SIGNAL clk_i       : STD_LOGIC := '0';
    SIGNAL rst_i       : STD_LOGIC := '1';
    SIGNAL addr_i      : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data_wr_i   : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL mem_read_i  : STD_LOGIC := '0';
    SIGNAL mem_write_i : STD_LOGIC := '0';
    SIGNAL capin1_i    : STD_LOGIC := '0';
    SIGNAL capin2_i    : STD_LOGIC := '0';
    SIGNAL data_rd_o   : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL data_oe_o   : STD_LOGIC;
    SIGNAL pwmout_o    : STD_LOGIC;
    SIGNAL btifg_o     : STD_LOGIC;
BEGIN
    DUT : Basic_Timer
        PORT MAP (
            smclk_i     => clk_i,
            rst_i       => rst_i,
            addr_i      => addr_i,
            data_wr_i   => data_wr_i,
            mem_read_i  => mem_read_i,
            mem_write_i => mem_write_i,
            capin1_i    => capin1_i,
            capin2_i    => capin2_i,
            data_rd_o   => data_rd_o,
            data_oe_o   => data_oe_o,
            pwmout_o    => pwmout_o,
            btifg_o     => btifg_o
        );

    clk_i <= NOT clk_i AFTER CLK_PERIOD / 2;

    stimulus : PROCESS
        -- Allow a short settling interval after every active clock edge.
        PROCEDURE tick(CONSTANT count : IN POSITIVE := 1) IS
        BEGIN
            FOR i IN 1 TO count LOOP
                WAIT UNTIL rising_edge(clk_i);
                WAIT FOR 1 ns;
            END LOOP;
        END PROCEDURE;

        -- Drive a synchronous register write for exactly one rising edge.
        PROCEDURE mmio_write(
            CONSTANT reg_addr : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            CONSTANT value    : IN STD_LOGIC_VECTOR(31 DOWNTO 0)
        ) IS
        BEGIN
            addr_i      <= reg_addr;
            data_wr_i   <= value;
            mem_write_i <= '1';
            tick;
            mem_write_i <= '0';
        END PROCEDURE;

        -- Read combinationally, check both data and OE, then remove MemRead and
        -- wait through two delta cycles for the shared-bus release to propagate.
        PROCEDURE expect_read(
            CONSTANT reg_addr     : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            CONSTANT value        : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            CONSTANT message_text : IN STRING
        ) IS
        BEGIN
            addr_i     <= reg_addr;
            mem_read_i <= '1';
            WAIT FOR 1 ns;
            ASSERT data_rd_o = value REPORT message_text SEVERITY FAILURE;
            ASSERT data_oe_o = timer_read_enable(reg_addr)
                REPORT message_text & ": data-bus output enable was wrong"
                SEVERITY FAILURE;
            mem_read_i <= '0';
            WAIT FOR 0 ns;
            WAIT FOR 0 ns;
            ASSERT data_oe_o = '0'
                REPORT message_text & ": timer did not release the data bus"
                SEVERITY FAILURE;
        END PROCEDURE;
    BEGIN
        -- Reset values include the read-only capture register and an unmapped
        -- address that must leave the timer's bus driver disabled.
        tick(2);
        rst_i <= '0';
        WAIT FOR 1 ns;

        expect_read(BTCTL1, x"00000000", "BTCTL1 reset/read failed");
        expect_read(BTCTL2, x"00000000", "BTCTL2 reset/read failed");
        expect_read(BTCMPR0, x"00000000", "BTCMPR0 reset/read failed");
        expect_read(BTCMPR1, x"00000000", "BTCMPR1 reset/read failed");
        expect_read(BTCAPR, x"00000000", "BTCAPR reset/read failed");
        expect_read(UNMAPPED_TIMER_ADDRESS_C, x"00000000",
                    "unsupported timer address was not zero");

        -- Write distinctive patterns through each register. BTCTL2 deliberately
        -- uses all ones so its four implemented bits and zero-filled upper bits
        -- are checked in the same readback.
        mmio_write(BTCTL1, x"000000EB");
        expect_read(BTCTL1, x"000000EB", "BTCTL1 field mapping failed");
        mmio_write(BTCTL2, x"000000FF");
        expect_read(BTCTL2, x"0000000F", "BTCTL2 upper bits are not zero");
        mmio_write(BTCMPR0, x"89ABCDEF");
        expect_read(BTCMPR0, x"89ABCDEF", "BTCMPR0 MMIO failed");
        mmio_write(BTCMPR1, x"12345678");
        expect_read(BTCMPR1, x"12345678", "BTCMPR1 MMIO failed");
        mmio_write(BTCAPR, x"89ABCDEF");
        expect_read(BTCAPR, x"89ABCDEF", "BTCAPR MMIO failed");

        -- Hold and clear the counter while loading a period of three, then run
        -- one full interval and check that btifg_o is a single-cycle pulse.
        mmio_write(BTCTL1, x"00000024");
        mmio_write(BTCMPR0, x"00000003");
        expect_read(BTCMPR0, x"00000003", "BTCMPR0 MMIO failed");
        mmio_write(BTCTL1, x"00000000");
        ASSERT btifg_o = '0'
            REPORT "timer event asserted before counting" SEVERITY FAILURE;
        tick(2);
        ASSERT btifg_o = '0'
            REPORT "timer event asserted before EQU0" SEVERITY FAILURE;
        tick;
        ASSERT btifg_o = '1'
            REPORT "timer EQU0 event was not generated" SEVERITY FAILURE;
        tick;
        ASSERT btifg_o = '0'
            REPORT "timer EQU0 did not clear after counter reset" SEVERITY FAILURE;

        -- Configure the PWM only through its software-visible registers. In
        -- output mode 0, BTCMPR1 raises PWMout and BTCMPR0 lowers it.
        rst_i <= '1';
        tick(2);
        rst_i <= '0';
        WAIT FOR 1 ns;
        -- Hold both the counter and PWM output while the two compare registers
        -- are written on separate bus cycles.
        mmio_write(BTCTL1, x"00000064");
        mmio_write(BTCMPR0, x"00000004");
        mmio_write(BTCMPR1, x"00000002");
        mmio_write(BTCTL1, x"00000000");
        tick(2);
        ASSERT pwmout_o = '0'
            REPORT "PWM mode 0 changed before BTCMPR1" SEVERITY FAILURE;
        tick;
        ASSERT pwmout_o = '1'
            REPORT "PWM mode 0 did not rise at BTCMPR1" SEVERITY FAILURE;
        tick(2);
        ASSERT pwmout_o = '0'
            REPORT "PWM mode 0 did not fall at BTCMPR0" SEVERITY FAILURE;

        -- Output mode 1 reverses both compare actions. BTOUTEN must then hold
        -- the current output even while the counter crosses both compares.
        rst_i <= '1';
        tick(2);
        rst_i <= '0';
        WAIT FOR 1 ns;
        mmio_write(BTCTL1, x"000000E4");
        mmio_write(BTCMPR0, x"00000004");
        mmio_write(BTCMPR1, x"00000002");
        mmio_write(BTCTL1, x"00000080");
        tick(4);
        ASSERT pwmout_o = '0'
            REPORT "PWM mode 1 did not remain low through BTCMPR1"
            SEVERITY FAILURE;
        tick;
        ASSERT pwmout_o = '1'
            REPORT "PWM mode 1 did not rise at BTCMPR0" SEVERITY FAILURE;
        tick(2);
        ASSERT pwmout_o = '1'
            REPORT "PWM mode 1 changed before BTCMPR1" SEVERITY FAILURE;
        tick;
        ASSERT pwmout_o = '0'
            REPORT "PWM mode 1 did not fall at BTCMPR1" SEVERITY FAILURE;
        tick(2);
        ASSERT pwmout_o = '1'
            REPORT "PWM mode 1 was not periodic" SEVERITY FAILURE;
        mmio_write(BTCTL1, x"000000C0");
        FOR i IN 1 TO 8 LOOP
            tick;
            ASSERT pwmout_o = '1'
                REPORT "BTOUTEN did not hold PWMout" SEVERITY FAILURE;
        END LOOP;

        -- BTCAPR belongs to the MMIO wrapper. A completed capture from the
        -- datapath must win over a software write on the same clock edge.
        rst_i <= '1';
        tick(2);
        rst_i <= '0';
        capin1_i <= '0';
        WAIT FOR 1 ns;
        mmio_write(BTCTL1, x"00000024");
        mmio_write(BTCTL2, x"00000004");
        mmio_write(BTCAPR, x"89ABCDEF");

        -- Launch CAPIN1 between clock edges. The synchronizer/capture pipeline
        -- is given two clocks before arranging the colliding software write.
        WAIT UNTIL falling_edge(clk_i);
        WAIT FOR 2 ns;
        capin1_i <= '1';
        WAIT FOR 1 ns;
        tick(2);

        addr_i      <= BTCAPR;
        data_wr_i   <= x"DEADBEEF";
        mem_write_i <= '1';
        tick;
        mem_write_i <= '0';
        expect_read(
            BTCAPR,
            x"00000000",
            "hardware capture did not win over simultaneous BTCAPR write"
        );

        REPORT "tb_TimerPeripheral: all MMIO tests passed" SEVERITY NOTE;
        STOP;
        WAIT;
    END PROCESS;
END test;
