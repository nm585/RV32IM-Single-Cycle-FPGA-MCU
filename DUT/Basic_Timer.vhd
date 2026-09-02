-- Basic Timer with compare, PWM and input-capture support.
-- The register interface and timer datapath are implemented in one entity.
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY Basic_Timer IS
    PORT (
        smclk_i     : IN  STD_LOGIC;
        rst_i       : IN  STD_LOGIC;
        addr_i      : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
        data_wr_i   : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
        mem_read_i  : IN  STD_LOGIC;
        mem_write_i : IN  STD_LOGIC;
        capin1_i    : IN  STD_LOGIC;
        capin2_i    : IN  STD_LOGIC;

        data_rd_o   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        data_oe_o   : OUT STD_LOGIC;
        pwmout_o    : OUT STD_LOGIC;
        -- BTIFG source from Figure 7; the controller stores the sticky flag.
        btifg_o     : OUT STD_LOGIC
    );
END Basic_Timer;

ARCHITECTURE rtl OF Basic_Timer IS
    -- Software-visible registers.
    CONSTANT BTCTL1  : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"201C";
    CONSTANT BTCTL2  : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"201D";
    CONSTANT BTCMPR0 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2020";
    CONSTANT BTCMPR1 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2024";
    CONSTANT BTCAPR  : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2028";

    -- Register state retained between bus accesses.
    SIGNAL btctl1_q : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL btctl2_q : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL btcmpr0_q: STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL btcmpr1_q: STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL btcapr_q : STD_LOGIC_VECTOR(31 DOWNTO 0);

    SIGNAL btctl1_load_w : STD_LOGIC;
    SIGNAL btctl2_load_w : STD_LOGIC;
    SIGNAL btcmpr0_load_w: STD_LOGIC;
    SIGNAL btcmpr1_load_w: STD_LOGIC;
    SIGNAL btcapr_load_w : STD_LOGIC;

    SIGNAL capture_data_w  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL capture_event_w : STD_LOGIC;
    SIGNAL read_enable_w   : STD_LOGIC;

    -- BTCTL1 fields.
    SIGNAL btoutmd_w : STD_LOGIC;
    SIGNAL btouten_w : STD_LOGIC;
    SIGNAL bthold_w  : STD_LOGIC;
    -- Timer clock source selection.
    SIGNAL btssel_w  : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL btclr_w   : STD_LOGIC;
    SIGNAL btint_w   : STD_LOGIC_VECTOR(1 DOWNTO 0);

    -- BTCTL2 fields.
    SIGNAL capmd_w   : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL capisel_w : STD_LOGIC_VECTOR(1 DOWNTO 0);

    -- Timer datapath. HEU0 keeps both compare latches transparent.
    CONSTANT HEU0_C : STD_LOGIC := '1';

    -- Compare values are written to BTCMPRx and forwarded to BTCLx.
    SIGNAL btcl0_latch_q : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL btcl1_latch_q : STD_LOGIC_VECTOR(31 DOWNTO 0);

    -- Free-running divider for SMCLK, SMCLK/2, SMCLK/4 and SMCLK/8.
    SIGNAL divider_q    : STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL smclk_div2_w : STD_LOGIC;
    SIGNAL smclk_div4_w : STD_LOGIC;
    SIGNAL smclk_div8_w : STD_LOGIC;
    SIGNAL btcnt_clk_w  : STD_LOGIC;

    -- Counter state and compare results.
    SIGNAL btcnt_q             : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL btcnt_overshoot_w   : STD_LOGIC;
    SIGNAL equ0_w              : STD_LOGIC;
    SIGNAL equ1_w              : STD_LOGIC;

    -- PWM output state.
    SIGNAL pwmout_q : STD_LOGIC;

    -- Capture events cross into SMCLK through a toggle synchronizer.
    SIGNAL capture_source_w       : STD_LOGIC;
    SIGNAL capture_event_clk_w    : STD_LOGIC;
    SIGNAL BTCNT_CAPTURE          : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL capture_event_toggle_q : STD_LOGIC;
    SIGNAL capture_toggle_meta_q  : STD_LOGIC;
    SIGNAL capture_toggle_sync_q  : STD_LOGIC;
    SIGNAL capture_toggle_prev_q  : STD_LOGIC;
    SIGNAL capture_event_pulse_w  : STD_LOGIC;
BEGIN
    -- Bus interface with one write strobe per register.
    btctl1_load_w  <= '1' WHEN mem_write_i = '1' AND addr_i = BTCTL1 ELSE '0';
    btctl2_load_w  <= '1' WHEN mem_write_i = '1' AND addr_i = BTCTL2 ELSE '0';
    btcmpr0_load_w <= '1' WHEN mem_write_i = '1' AND addr_i = BTCMPR0 ELSE '0';
    btcmpr1_load_w <= '1' WHEN mem_write_i = '1' AND addr_i = BTCMPR1 ELSE '0';
    btcapr_load_w  <= '1' WHEN mem_write_i = '1' AND addr_i = BTCAPR ELSE '0';

    read_enable_w <= '1' WHEN mem_read_i = '1' AND
        (addr_i = BTCTL1 OR addr_i = BTCTL2 OR
         addr_i = BTCMPR0 OR addr_i = BTCMPR1 OR
         addr_i = BTCAPR) ELSE '0';
    data_oe_o <= read_enable_w;

    -- Register bank. A hardware capture has priority over a BTCAPR write.
    REGISTER_BANK_P : PROCESS (smclk_i, rst_i)
    BEGIN
        IF rst_i = '1' THEN
            btctl1_q <= (OTHERS => '0');
            btctl2_q <= (OTHERS => '0');
            btcmpr0_q <= (OTHERS => '0');
            btcmpr1_q <= (OTHERS => '0');
            btcapr_q <= (OTHERS => '0');
        ELSIF rising_edge(smclk_i) THEN
            IF btctl1_load_w = '1' THEN
                btctl1_q <= data_wr_i(7 DOWNTO 0);
            END IF;

            IF btctl2_load_w = '1' THEN
                btctl2_q <= "0000" &
                    data_wr_i(3 DOWNTO 0);
            END IF;

            IF btcmpr0_load_w = '1' THEN
                btcmpr0_q <= data_wr_i;
            END IF;

            IF btcmpr1_load_w = '1' THEN
                btcmpr1_q <= data_wr_i;
            END IF;

            IF capture_event_w = '1' THEN
                btcapr_q <= capture_data_w;
            ELSIF btcapr_load_w = '1' THEN
                btcapr_q <= data_wr_i;
            END IF;
        END IF;
    END PROCESS;

    -- Decode the control-register fields.
    btoutmd_w <= btctl1_q(7);
    btouten_w <= btctl1_q(6);
    bthold_w  <= btctl1_q(5);
    btssel_w  <= btctl1_q(4 DOWNTO 3);
    btclr_w   <= btctl1_q(2);
    btint_w   <= btctl1_q(1 DOWNTO 0);

    capmd_w   <= btctl2_q(3 DOWNTO 2);
    capisel_w <= btctl2_q(1 DOWNTO 0);

    -- Transparent compare latches update with BTCMPRx.
    BTCL0_LATCH_P : PROCESS (rst_i, btcmpr0_q)
    BEGIN
        IF rst_i = '1' THEN
            btcl0_latch_q <= (OTHERS => '0');
        ELSIF HEU0_C = '1' THEN
            btcl0_latch_q <= btcmpr0_q;
        END IF;
    END PROCESS;

    BTCL1_LATCH_P : PROCESS (rst_i, btcmpr1_q)
    BEGIN
        IF rst_i = '1' THEN
            btcl1_latch_q <= (OTHERS => '0');
        ELSIF HEU0_C = '1' THEN
            btcl1_latch_q <= btcmpr1_q;
        END IF;
    END PROCESS;

    -- SMCLK divider and timer clock selection.
    CLOCK_DIVIDER_P : PROCESS (smclk_i, rst_i)
    BEGIN
        IF rst_i = '1' THEN
            divider_q <= (OTHERS => '0');
        ELSIF rising_edge(smclk_i) THEN
            divider_q <= divider_q + 1;
        END IF;
    END PROCESS;

    smclk_div2_w <= divider_q(0);
    smclk_div4_w <= divider_q(1);
    smclk_div8_w <= divider_q(2);

    WITH btssel_w SELECT
        btcnt_clk_w <=
            smclk_i      WHEN "00",
            smclk_div2_w WHEN "01",
            smclk_div4_w WHEN "10",
            smclk_div8_w WHEN OTHERS;

    -- Clear BTCNT on BTCLR or an EQU0 match.
    -- The overshoot check also handles a compare value lowered below BTCNT,
    -- avoiding a full counter wrap before the next clear.
    btcnt_overshoot_w <= '1' WHEN btcnt_q > btcl0_latch_q ELSE '0';
    equ0_w            <= '1' WHEN btcnt_q = btcl0_latch_q ELSE '0';
    equ1_w            <= '1' WHEN btcnt_q = btcl1_latch_q ELSE '0';

    BTCNT_TIMER_P : PROCESS (btcnt_clk_w, rst_i, btclr_w)
    BEGIN
        IF rst_i = '1' OR btclr_w = '1' THEN
            btcnt_q <= (OTHERS => '0');
        ELSIF rising_edge(btcnt_clk_w) THEN
            IF btcnt_overshoot_w = '1' THEN
                btcnt_q <= (OTHERS => '0');
            ELSIF bthold_w = '0' THEN
                IF equ0_w = '1' THEN
                    btcnt_q <= (OTHERS => '0');
                ELSE
                    btcnt_q <= btcnt_q + 1;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- PWM modes exchange the set and clear roles of EQU0 and EQU1.
    -- BTOUTEN freezes the current output value.
    -- EQU0 has priority when both compares match together.
    OUTPUT_UNIT_P : PROCESS (btcnt_clk_w, rst_i)
    BEGIN
        IF rst_i = '1' THEN
            pwmout_q <= '0';
        ELSIF rising_edge(btcnt_clk_w) THEN
            IF btouten_w = '1' THEN
                IF equ0_w = '1' THEN
                    pwmout_q <= btoutmd_w;
                ELSIF equ1_w = '1' THEN
                    pwmout_q <= NOT btoutmd_w;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- CAPISEL chooses the capture source and CAPMD chooses the active edge.
    -- The source edge captures BTCNT in its own clock domain.
    -- A toggle synchronizer transfers one capture event into SMCLK.
    WITH capisel_w SELECT
        capture_source_w <=
            capin1_i WHEN "00",
            capin2_i WHEN "01",
            '1'      WHEN "10",
            '0'      WHEN OTHERS;

    capture_event_clk_w <=
        capture_source_w     WHEN capmd_w = "01" ELSE
        NOT capture_source_w WHEN capmd_w = "10" ELSE
        '0';

    CAPTURE_ON_EVENT_P : PROCESS (capture_event_clk_w, rst_i)
    BEGIN
        IF rst_i = '1' THEN
            BTCNT_CAPTURE          <= (OTHERS => '0');
            capture_event_toggle_q <= '0';
        ELSIF rising_edge(capture_event_clk_w) THEN
            BTCNT_CAPTURE          <= btcnt_q;
            capture_event_toggle_q <= NOT capture_event_toggle_q;
        END IF;
    END PROCESS;

    CAPTURE_EVENT_SYNCHRONIZER_P : PROCESS (smclk_i, rst_i)
    BEGIN
        IF rst_i = '1' THEN
            capture_toggle_meta_q <= '0';
            capture_toggle_sync_q <= '0';
            capture_toggle_prev_q <= '0';
        ELSIF rising_edge(smclk_i) THEN
            capture_toggle_meta_q <= capture_event_toggle_q;
            capture_toggle_sync_q <= capture_toggle_meta_q;
            capture_toggle_prev_q <= capture_toggle_sync_q;
        END IF;
    END PROCESS;

    -- Toggle edge detection creates one SMCLK pulse per capture.
    capture_event_pulse_w <= capture_toggle_sync_q XOR capture_toggle_prev_q;

    -- BTINT selects EQU0, EQU1 or capture as the interrupt source.
    WITH btint_w SELECT
        btifg_o <=
            equ0_w                WHEN "00",
            equ1_w                WHEN "01",
            capture_event_pulse_w WHEN "10",
            capture_event_pulse_w WHEN OTHERS;

    -- Transfer the stable snapshot with the synchronized event.
    capture_data_w  <= BTCNT_CAPTURE;
    capture_event_w <= capture_event_pulse_w;
    pwmout_o        <= pwmout_q;

    -- Register readback is zero-extended to the CPU bus width.
    READ_REGISTER_BANK_P : PROCESS (ALL)
    BEGIN
        data_rd_o <= (OTHERS => '0');
        IF read_enable_w = '1' THEN
            CASE addr_i IS
                WHEN BTCTL1 =>
                    data_rd_o(7 DOWNTO 0) <= btctl1_q;
                WHEN BTCTL2 =>
                    data_rd_o(7 DOWNTO 0) <= btctl2_q;
                WHEN BTCMPR0 =>
                    data_rd_o <= btcmpr0_q;
                WHEN BTCMPR1 =>
                    data_rd_o <= btcmpr1_q;
                WHEN BTCAPR =>
                    data_rd_o <= btcapr_q;
                WHEN OTHERS =>
                    NULL;
            END CASE;
        END IF;
    END PROCESS;
END rtl;
