LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE STD.ENV.ALL;
USE work.aux_package.ALL;

-- Exercises the Basic Timer datapath (Figures 7 and 8).
--
-- The datapath used to be an entity of its own with the control fields on
-- ports, and this testbench drove those ports directly. Since the merge the
-- only way in is BTCTL1 and BTCTL2, so every stimulus below is a register
-- write instead.
-- The datapath cases themselves are unchanged: divider sweep, BTHOLD, BTCLR,
-- immediate BTCL0 transfer, compare priority, BTINT selection and all capture
-- sources. PWM output modes and BTOUTEN are covered at the same MMIO level by
-- tb_TimerPeripheral and are not repeated here.

ENTITY tb_BasicTimer IS
END tb_BasicTimer;

ARCHITECTURE test OF tb_BasicTimer IS
    -- Keeping the clock fairly slow makes edge-aligned capture checks readable
    -- in a waveform while still keeping the full divider sweep short.
    CONSTANT CLK_PERIOD : TIME := 20 ns;

    -- Byte addresses from the timer section of the peripheral map.
    CONSTANT BTCTL1  : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"201C";
    CONSTANT BTCTL2  : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"201D";
    CONSTANT BTCMPR0 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2020";
    CONSTANT BTCMPR1 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2024";
    CONSTANT BTCAPR  : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2028";

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

    -- Free-running source clock used by both the counter and the test helpers.
    smclk_i <= NOT smclk_i AFTER CLK_PERIOD / 2;

    stimulus : PROCESS
        -- Sample one nanosecond after each active edge so registered outputs
        -- and their delta-cycle updates have settled before an assertion.
        PROCEDURE tick(CONSTANT count : IN POSITIVE := 1) IS
        BEGIN
            FOR i IN 1 TO count LOOP
                WAIT UNTIL rising_edge(smclk_i);
                WAIT FOR 1 ns;
            END LOOP;
        END PROCEDURE;

        -- Drive a synchronous register write for exactly one rising edge. Each
        -- call therefore also advances the timer by one SMCLK cycle.
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

        -- Combinational read; leaves MemRead low again so the DUT releases the
        -- shared bus between checks.
        PROCEDURE mmio_read(
            CONSTANT reg_addr : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
            VARIABLE value    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        ) IS
        BEGIN
            addr_i     <= reg_addr;
            mem_read_i <= '1';
            WAIT FOR 1 ns;
            value      := data_rd_o;
            mem_read_i <= '0';
            WAIT FOR 1 ns;
        END PROCEDURE;

        -- Restore reset and every capture input. Control registers are cleared
        -- by the reset itself, so each phase starts from the same state.
        PROCEDURE reset_dut IS
        BEGIN
            mem_read_i  <= '0';
            mem_write_i <= '0';
            capin1_i    <= '0';
            capin2_i    <= '0';
            rst_i       <= '1';
            WAIT FOR 1 ns;
            tick(2);
            rst_i <= '0';
            WAIT FOR 1 ns;
        END PROCEDURE;

        -- Generate a clean CAPIN1 rising edge, then give the capture toggle
        -- time to cross into SMCLK and land in BTCAPR before reading it back.
        PROCEDURE capture_counter(
            VARIABLE captured_value : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        ) IS
        BEGIN
            capin1_i <= '0';
            WAIT FOR 1 ns;
            capin1_i <= '1';
            WAIT FOR 1 ns;
            tick(5);
            mmio_read(BTCAPR, captured_value);
        END PROCEDURE;

        -- Measure one complete EQU0 interval in SMCLK edges. The initial flag
        -- may already be high at count zero, so first wait for it to drop.
        PROCEDURE check_clock_period(
            CONSTANT selection             : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            CONSTANT expected_smclk_cycles : IN POSITIVE
        ) IS
            VARIABLE control_v   : STD_LOGIC_VECTOR(7 DOWNTO 0);
            VARIABLE cycle_count : NATURAL;
            VARIABLE saw_low     : BOOLEAN;
        BEGIN
            reset_dut;
            control_v := (OTHERS => '0');
            control_v(5) := '1';                 -- BTHOLD
            control_v(4 DOWNTO 3) := selection;  -- BTSSEL
            control_v(2) := '1';                 -- BTCLR
            mmio_write(BTCTL1, x"000000" & control_v);
            mmio_write(BTCMPR0, x"00000003");
            control_v(5) := '0';
            control_v(2) := '0';
            mmio_write(BTCTL1, x"000000" & control_v);

            IF btifg_o /= '1' THEN
                WAIT UNTIL btifg_o = '1';
                WAIT FOR 1 ns;
            END IF;

            cycle_count := 0;
            saw_low := FALSE;
            LOOP
                tick;
                cycle_count := cycle_count + 1;
                IF btifg_o = '0' THEN
                    saw_low := TRUE;
                ELSIF saw_low THEN
                    EXIT;
                END IF;
                ASSERT cycle_count <= expected_smclk_cycles + 2
                    REPORT "timer period did not complete"
                    SEVERITY FAILURE;
            END LOOP;

            ASSERT cycle_count = expected_smclk_cycles
                REPORT "BTSSEL clock division is incorrect"
                SEVERITY FAILURE;
        END PROCEDURE;

        VARIABLE captured_1_v       : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE captured_2_v       : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE capture_irq_seen_v : BOOLEAN;
    BEGIN
        -- Start with the externally visible reset state before testing modes
        -- that deliberately leave internal state behind.
        reset_dut;
        mmio_read(BTCAPR, captured_1_v);
        ASSERT captured_1_v = x"00000000"
            REPORT "capture datapath reset failed" SEVERITY FAILURE;
        ASSERT pwmout_o = '0'
            REPORT "PWMout reset failed" SEVERITY FAILURE;
        -- btifg_o is deliberately not checked here: after reset BTCNT and
        -- BTCL0 are both zero, so EQU0 - the BTINT=00 default source - is
        -- legitimately high until BTCMPR0 is programmed.

        -- There is no direct counter output, so use a capture before and after
        -- the hold interval to prove that BTCNT stopped. Then sample once more
        -- with BTCLR asserted to confirm that it returned to zero.
        reset_dut;
        mmio_write(BTCTL1, x"00000024");   -- BTHOLD + BTCLR
        mmio_write(BTCMPR0, x"FFFFFFFF");
        mmio_write(BTCTL2, x"00000004");   -- CAPMD = rising, CAPISEL = CAPIN1
        mmio_write(BTCTL1, x"00000000");
        tick(3);
        mmio_write(BTCTL1, x"00000020");   -- BTHOLD only
        capture_counter(captured_1_v);
        tick(3);
        capture_counter(captured_2_v);
        ASSERT captured_1_v = captured_2_v
            REPORT "BTHOLD did not hold BTCNT" SEVERITY FAILURE;
        mmio_write(BTCTL1, x"00000024");
        capture_counter(captured_1_v);
        ASSERT captured_1_v = x"00000000"
            REPORT "BTCLR did not clear BTCNT" SEVERITY FAILURE;

        -- BTCLR is level-sensitive, not a one-shot command: the counter must
        -- remain at zero for as long as the bit stays set and resume afterward.
        reset_dut;
        mmio_write(BTCMPR0, x"FFFFFFFF");
        mmio_write(BTCTL2, x"00000004");
        mmio_write(BTCTL1, x"00000004");   -- BTCLR only
        tick(4);
        capture_counter(captured_1_v);
        ASSERT captured_1_v = x"00000000"
            REPORT "BTCLR did not hold BTCNT at zero" SEVERITY FAILURE;
        mmio_write(BTCTL1, x"00000000");
        tick(3);
        capture_counter(captured_1_v);
        ASSERT captured_1_v /= x"00000000"
            REPORT "BTCNT did not resume after BTCLR was released"
            SEVERITY FAILURE;

        -- Sweep the four BTSSEL encodings. With BTCMPR0=3, one timer period is
        -- four selected-clock edges, which makes the expected lengths 4..32.
        check_clock_period("00", 4);
        check_clock_period("01", 8);
        check_clock_period("10", 16);
        check_clock_period("11", 32);

        -- HEU0 is hard-wired on in this design, so changing BTCMPR0 while the
        -- timer runs must move the compare boundary immediately to BTCL0. The
        -- BTCMPR0 write below lands on the same edge that takes BTCNT to 3.
        reset_dut;
        mmio_write(BTCTL1, x"00000024");
        mmio_write(BTCMPR0, x"00000008");
        mmio_write(BTCTL1, x"00000000");
        tick(2);
        mmio_write(BTCMPR0, x"00000003");
        ASSERT btifg_o = '1'
            REPORT "BTCMPR0 was not transferred immediately to BTCL0"
            SEVERITY FAILURE;
        tick;
        ASSERT btifg_o = '0'
            REPORT "BTCNT did not reset at the updated BTCL0 boundary"
            SEVERITY FAILURE;

        -- Force EQU0 and EQU1 on the same count to check the documented
        -- priority rather than relying on two events on different cycles.
        reset_dut;
        mmio_write(BTCTL1, x"00000024");
        mmio_write(BTCMPR0, x"00000002");
        mmio_write(BTCMPR1, x"00000002");
        mmio_write(BTCTL1, x"00000000");
        tick(3);
        ASSERT pwmout_o = '0'
            REPORT "EQU0 did not win over EQU1 in Output Mode 0"
            SEVERITY FAILURE;

        reset_dut;
        mmio_write(BTCTL1, x"000000A4");   -- BTOUTMD = 1
        mmio_write(BTCMPR0, x"00000002");
        mmio_write(BTCMPR1, x"00000002");
        mmio_write(BTCTL1, x"00000080");
        tick(3);
        ASSERT pwmout_o = '1'
            REPORT "EQU0 did not win over EQU1 in Output Mode 1"
            SEVERITY FAILURE;

        -- Route EQU1 to BTIFG and verify that the earlier compare, not EQU0,
        -- is the event visible at the interrupt output.
        reset_dut;
        mmio_write(BTCTL1, x"00000025");   -- BTINT = EQU1
        mmio_write(BTCMPR0, x"00000004");
        mmio_write(BTCMPR1, x"00000002");
        mmio_write(BTCTL1, x"00000001");
        tick(2);
        ASSERT btifg_o = '1'
            REPORT "BTINT did not select EQU1" SEVERITY FAILURE;

        -- Move the CAPIN1 edge away from SMCLK so the expected captured value
        -- is unambiguous, then allow for the capture-to-interrupt pipeline.
        reset_dut;
        mmio_write(BTCTL1, x"00000026");   -- BTINT = capture
        mmio_write(BTCMPR0, x"FFFFFFFF");
        mmio_write(BTCTL2, x"00000004");   -- CAPMD = rising, CAPISEL = CAPIN1
        mmio_write(BTCTL1, x"00000002");
        tick(3);
        WAIT UNTIL falling_edge(smclk_i);
        WAIT FOR 2 ns;
        capin1_i <= '1';
        WAIT FOR 1 ns;
        capture_irq_seen_v := FALSE;
        FOR i IN 1 TO 6 LOOP
            tick;
            IF btifg_o = '1' THEN
                capture_irq_seen_v := TRUE;
            END IF;
        END LOOP;
        ASSERT capture_irq_seen_v
            REPORT "capture event did not reach BTINT=10" SEVERITY FAILURE;
        mmio_read(BTCAPR, captured_1_v);
        ASSERT captured_1_v = x"00000003"
            REPORT "CAPIN1 rising-edge capture failed" SEVERITY FAILURE;

        -- Repeat the capture path through CAPIN2, this time using a falling
        -- edge and the second capture interrupt selection.
        reset_dut;
        capin2_i <= '1';
        mmio_write(BTCTL1, x"00000027");   -- BTINT = capture (11)
        mmio_write(BTCMPR0, x"FFFFFFFF");
        mmio_write(BTCTL2, x"00000009");   -- CAPMD = falling, CAPISEL = CAPIN2
        mmio_write(BTCTL1, x"00000003");
        tick(3);
        WAIT UNTIL falling_edge(smclk_i);
        WAIT FOR 2 ns;
        capin2_i <= '0';
        WAIT FOR 1 ns;
        capture_irq_seen_v := FALSE;
        FOR i IN 1 TO 6 LOOP
            tick;
            IF btifg_o = '1' THEN
                capture_irq_seen_v := TRUE;
            END IF;
        END LOOP;
        ASSERT capture_irq_seen_v
            REPORT "capture event did not reach BTINT=11" SEVERITY FAILURE;
        mmio_read(BTCAPR, captured_1_v);
        ASSERT captured_1_v = x"00000003"
            REPORT "CAPIN2 falling-edge capture failed" SEVERITY FAILURE;

        -- CAPMD encodings 00 and 11 are disabled. BTCNT is left free-running
        -- here so that an unwanted capture would store a non-zero value and
        -- therefore cannot hide behind a counter that is held at zero.
        reset_dut;
        mmio_write(BTCMPR0, x"FFFFFFFF");
        mmio_write(BTCTL2, x"00000000");   -- CAPMD = 00, capture disabled
        capin1_i <= '1';
        tick(4);
        mmio_read(BTCAPR, captured_1_v);
        ASSERT captured_1_v = x"00000000"
            REPORT "CAPMD=00 did not disable capture" SEVERITY FAILURE;

        mmio_write(BTCTL2, x"0000000C");   -- CAPMD = 11, capture disabled
        capin1_i <= '0';
        WAIT FOR 1 ns;
        capin1_i <= '1';
        tick(4);
        mmio_read(BTCAPR, captured_1_v);
        ASSERT captured_1_v = x"00000000"
            REPORT "CAPMD=11 did not disable capture" SEVERITY FAILURE;

        -- The constant VCC/GND selections create an edge when CAPISEL changes.
        -- These checks cover those less obvious mux paths without external
        -- pins. The captured value depends on where the CAPISEL write lands
        -- relative to BTCNT, so only "a capture happened" is asserted.
        reset_dut;
        mmio_write(BTCTL1, x"00000024");
        mmio_write(BTCMPR0, x"FFFFFFFF");
        mmio_write(BTCTL1, x"00000000");
        tick(3);
        mmio_write(BTCTL2, x"00000006");   -- CAPMD = rising, CAPISEL = VCC
        tick(4);
        mmio_read(BTCAPR, captured_1_v);
        ASSERT captured_1_v /= x"00000000"
            REPORT "CAPISEL VCC rising capture failed" SEVERITY FAILURE;

        reset_dut;
        mmio_write(BTCTL1, x"00000024");
        mmio_write(BTCMPR0, x"FFFFFFFF");
        mmio_write(BTCTL1, x"00000000");
        tick(3);
        mmio_write(BTCTL2, x"0000000B");   -- CAPMD = falling, CAPISEL = GND
        tick(4);
        mmio_read(BTCAPR, captured_1_v);
        ASSERT captured_1_v /= x"00000000"
            REPORT "CAPISEL GND falling capture failed" SEVERITY FAILURE;

        REPORT "tb_BasicTimer: all Figure 7/8 datapath tests passed"
            SEVERITY NOTE;
        STOP;
        WAIT;
    END PROCESS;
END test;
