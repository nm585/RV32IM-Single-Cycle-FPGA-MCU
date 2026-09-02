LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE STD.ENV.ALL;
USE work.aux_package.ALL;

-- Fixed 75% PWM testbench for the Basic Timer output unit.
--
-- The timer is configured once and then left alone. Nothing is reprogrammed
-- while it runs, so PWMout settles into one steady square wave and the
-- waveform shows the same pulse width from start to finish.
--
-- Everything goes through BTCTL1/BTCMPR0/BTCMPR1 at the MMIO level, which is
-- the only way into the merged Basic_Timer entity. No capture source, no BTINT
-- selection and no register masking is exercised here.
--
-- Output mode 0 with BTSSEL = SMCLK, so one BTCNT step is one SMCLK cycle:
--
--   period = BTCMPR0 + 1          BTCNT runs 0 .. BTCMPR0, then clears
--   high   = BTCMPR0 - BTCMPR1    EQU1 raises PWMout, EQU0 lowers it
--
-- With BTCMPR1 = BTCMPR0 / 4 the output is high for three quarters of the
-- count range, which is the 75% setting the test4 benchmark selects on its
-- second KEY2 press.

ENTITY tb_PWM IS
END tb_PWM;

ARCHITECTURE test OF tb_PWM IS
    CONSTANT CLK_PERIOD : TIME := 50 ns;      -- 20 MHz SMCLK

    -- Byte addresses from the timer section of the peripheral map.
    CONSTANT BTCTL1  : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"201C";
    CONSTANT BTCMPR0 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2020";
    CONSTANT BTCMPR1 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2024";

    -- BTCTL1 encodings. BTSSEL stays 00 so BTCNT counts SMCLK directly.
    --   bit7 BTOUTMD, bit6 BTOUTEN, bit5 BTHOLD, bit4:3 BTSSEL,
    --   bit2 BTCLR,   bit1:0 BTINT
    CONSTANT CTL_LOAD_C : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00000064"; -- OUTEN + HOLD + CLR
    CONSTANT CTL_RUN_C  : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00000040"; -- OUTEN, counter released

    -- Counting period. 64 keeps a full cycle readable in a waveform. Raise it
    -- to 4000 for the benchmark's 5 kHz output at SMCLK = 20 MHz; every value
    -- below is derived from it.
    CONSTANT PERIOD_C : NATURAL := 64;

    -- 75% duty: PWMout is high for three of the four quarters of the range.
    CONSTANT DUTY_CMP_C : NATURAL := PERIOD_C / 4;

    CONSTANT EXPECTED_HIGH_C   : NATURAL := PERIOD_C - DUTY_CMP_C;
    CONSTANT EXPECTED_PERIOD_C : NATURAL := PERIOD_C + 1;

    -- How many consecutive periods must come out identical.
    CONSTANT PERIODS_CHECKED_C : NATURAL := 8;

    -- Guard so a stuck output fails with a message instead of hanging.
    CONSTANT TIMEOUT_C : NATURAL := 4 * PERIOD_C + 64;

    SIGNAL smclk_i     : STD_LOGIC := '0';
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
            smclk_i     => smclk_i,
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

    smclk_i <= NOT smclk_i AFTER CLK_PERIOD / 2;

    stimulus : PROCESS
        -- Sample one nanosecond after each active edge so the registered
        -- PWMout value has settled before it is read.
        PROCEDURE tick(CONSTANT count : IN POSITIVE := 1) IS
        BEGIN
            FOR i IN 1 TO count LOOP
                WAIT UNTIL rising_edge(smclk_i);
                WAIT FOR 1 ns;
            END LOOP;
        END PROCEDURE;

        -- One synchronous register write. Each call also advances BTCNT by one
        -- SMCLK cycle, which is why the compares are loaded while BTHOLD is set.
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

        -- Count one complete cycle starting from the first edge of a high
        -- phase. Counting in SMCLK ticks is exact because BTSSEL selects SMCLK.
        PROCEDURE measure_period(
            VARIABLE high_v   : OUT NATURAL;
            VARIABLE period_v : OUT NATURAL
        ) IS
            VARIABLE h_v : NATURAL := 0;
            VARIABLE p_v : NATURAL := 0;
        BEGIN
            WHILE pwmout_o = '1' LOOP
                h_v := h_v + 1;
                p_v := p_v + 1;
                tick;
                ASSERT p_v < TIMEOUT_C
                    REPORT "PWMout stuck high" SEVERITY FAILURE;
            END LOOP;
            WHILE pwmout_o = '0' LOOP
                p_v := p_v + 1;
                tick;
                ASSERT p_v < TIMEOUT_C
                    REPORT "PWMout stuck low" SEVERITY FAILURE;
            END LOOP;
            high_v   := h_v;
            period_v := p_v;
        END PROCEDURE;

        VARIABLE high_v   : NATURAL;
        VARIABLE period_v : NATURAL;
        VARIABLE guard_v  : NATURAL;
    BEGIN
        -- PWMout must come out of reset low before any compare is programmed.
        rst_i <= '1';
        tick(2);
        rst_i <= '0';
        WAIT FOR 1 ns;
        ASSERT pwmout_o = '0'
            REPORT "PWMout was not low after reset" SEVERITY FAILURE;

        -- Load both compares while the counter is held and cleared, then start
        -- it. BTOUTEN stays set the whole time: clearing it would freeze the
        -- output unit and no edge would ever appear.
        mmio_write(BTCTL1,  CTL_LOAD_C);
        mmio_write(BTCMPR0, CONV_STD_LOGIC_VECTOR(PERIOD_C, 32));
        mmio_write(BTCMPR1, CONV_STD_LOGIC_VECTOR(DUTY_CMP_C, 32));
        mmio_write(BTCTL1,  CTL_RUN_C);

        REPORT "PWM configured: BTCMPR0=" & INTEGER'IMAGE(PERIOD_C) &
               "  BTCMPR1=" & INTEGER'IMAGE(DUTY_CMP_C) &
               "  target duty=" &
               INTEGER'IMAGE((EXPECTED_HIGH_C * 100) / PERIOD_C) & "%"
            SEVERITY NOTE;

        -- The counter starts partway through its range after the register
        -- writes, so discard the first partial pulse and begin measuring at a
        -- clean rising edge.
        guard_v := 0;
        WHILE pwmout_o /= '0' LOOP
            tick;
            guard_v := guard_v + 1;
            ASSERT guard_v < TIMEOUT_C
                REPORT "PWMout never went low after configuration"
                SEVERITY FAILURE;
        END LOOP;
        WHILE pwmout_o /= '1' LOOP
            tick;
            guard_v := guard_v + 1;
            ASSERT guard_v < TIMEOUT_C
                REPORT "PWMout never went high after configuration"
                SEVERITY FAILURE;
        END LOOP;

        -- Nothing is reprogrammed from here on, so every period must be
        -- identical. Checking several in a row is what proves the duty cycle
        -- is steady rather than only correct once.
        FOR i IN 1 TO PERIODS_CHECKED_C LOOP
            measure_period(high_v, period_v);

            ASSERT period_v = EXPECTED_PERIOD_C
                REPORT "period " & INTEGER'IMAGE(i) & " was " &
                       INTEGER'IMAGE(period_v) & " SMCLK cycles, expected " &
                       INTEGER'IMAGE(EXPECTED_PERIOD_C)
                SEVERITY FAILURE;
            ASSERT high_v = EXPECTED_HIGH_C
                REPORT "period " & INTEGER'IMAGE(i) & " high time was " &
                       INTEGER'IMAGE(high_v) & " SMCLK cycles, expected " &
                       INTEGER'IMAGE(EXPECTED_HIGH_C)
                SEVERITY FAILURE;

            REPORT "period " & INTEGER'IMAGE(i) &
                   ": high=" & INTEGER'IMAGE(high_v) &
                   "  low=" & INTEGER'IMAGE(period_v - high_v) &
                   "  period=" & INTEGER'IMAGE(period_v)
                SEVERITY NOTE;
        END LOOP;

        REPORT "tb_PWM: " & INTEGER'IMAGE(PERIODS_CHECKED_C) &
               " consecutive periods held a steady 75% duty cycle"
            SEVERITY NOTE;
        STOP;
        WAIT;
    END PROCESS;
END test;
