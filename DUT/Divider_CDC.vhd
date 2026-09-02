LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.aux_package.ALL;

-- Clock-domain bridge between MCLK and DIVCLK.
-- Requests and operands are registered before crossing into the divider.
-- DIVBUSY returns through a two-stage synchronizer.
ENTITY Divider_CDC IS
    PORT (
        MCLK     : IN  STD_LOGIC;
        MCLKRST  : IN  STD_LOGIC;
        DIVCLK   : IN  STD_LOGIC;
        DIVRST   : IN  STD_LOGIC;
        DIVENA   : IN  STD_LOGIC;
        Dividend : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
        Divisor  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
        DIVBUSY  : OUT STD_LOGIC;
        Residue  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        Quotient : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END Divider_CDC;

ARCHITECTURE rtl OF Divider_CDC IS
    -- MCLK source registers.
    SIGNAL dividend_m_q : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL divisor_m_q  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL divena_m_q   : STD_LOGIC;

    -- DIVCLK synchronizer stages.
    SIGNAL dividend_sync1_d_q : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL dividend_sync2_d_q : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL divisor_sync1_d_q  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL divisor_sync2_d_q  : STD_LOGIC_VECTOR(31 DOWNTO 0);

    SIGNAL divena_sync1_d_q : STD_LOGIC;
    SIGNAL divena_sync2_d_q : STD_LOGIC;
    SIGNAL divena_delay_d_q : STD_LOGIC;
    SIGNAL divena_d_w       : STD_LOGIC;

    SIGNAL divbusy_d_w  : STD_LOGIC;
    SIGNAL quotient_d_w : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL residue_d_w  : STD_LOGIC_VECTOR(31 DOWNTO 0);

    SIGNAL divbusy_sync1_m_q : STD_LOGIC;
    SIGNAL divbusy_sync2_m_q : STD_LOGIC;
BEGIN
    divena_d_w <= divena_sync2_d_q AND NOT divena_delay_d_q;

    DIVIDER_U : Divider_32bit
        PORT MAP (
            DIVCLK   => DIVCLK,
            DIVRST   => DIVRST,
            DIVENA   => divena_d_w,
            Dividend => dividend_sync2_d_q,
            Divisor  => divisor_sync2_d_q,
            DIVBUSY  => divbusy_d_w,
            Residue  => residue_d_w,
            Quotient => quotient_d_w
        );

    -- Register all source-domain signals before the crossing.
    SOURCE_REGISTERS_P : PROCESS(MCLK, MCLKRST)
    BEGIN
        IF MCLKRST = '1' THEN
            dividend_m_q <= (OTHERS => '0');
            divisor_m_q  <= (OTHERS => '0');
            divena_m_q   <= '0';
        ELSIF rising_edge(MCLK) THEN
            dividend_m_q <= Dividend;
            divisor_m_q  <= Divisor;
            divena_m_q   <= DIVENA;
        END IF;
    END PROCESS;

    -- Each request signal crosses through two DIVCLK registers.
    -- DIVENA edge detection uses the synchronized stage, then produces
    -- a single-cycle start pulse for the divider.
    DIVCLK_SYNCHRONIZERS_P : PROCESS(DIVCLK, DIVRST)
    BEGIN
        IF DIVRST = '1' THEN
            dividend_sync1_d_q <= (OTHERS => '0');
            dividend_sync2_d_q <= (OTHERS => '0');
            divisor_sync1_d_q  <= (OTHERS => '0');
            divisor_sync2_d_q  <= (OTHERS => '0');
            divena_sync1_d_q   <= '0';
            divena_sync2_d_q   <= '0';
            divena_delay_d_q   <= '0';
        ELSIF rising_edge(DIVCLK) THEN
            dividend_sync1_d_q <= dividend_m_q;
            dividend_sync2_d_q <= dividend_sync1_d_q;
            divisor_sync1_d_q  <= divisor_m_q;
            divisor_sync2_d_q  <= divisor_sync1_d_q;
            divena_sync1_d_q   <= divena_m_q;
            divena_sync2_d_q   <= divena_sync1_d_q;
            divena_delay_d_q   <= divena_sync2_d_q;
        END IF;
    END PROCESS;

    -- Synchronize divider status back into MCLK.
    DIVBUSY_SYNCHRONIZER_P : PROCESS(MCLK, MCLKRST)
    BEGIN
        IF MCLKRST = '1' THEN
            divbusy_sync1_m_q <= '0';
            divbusy_sync2_m_q <= '0';
        ELSIF rising_edge(MCLK) THEN
            divbusy_sync1_m_q <= divbusy_d_w;
            divbusy_sync2_m_q <= divbusy_sync1_m_q;
        END IF;
    END PROCESS;

    -- The result buses do not need separate bit-by-bit synchronizers.
    -- The divider registers and holds both results before clearing DIVBUSY,
    -- and the synchronized status reaches MCLK only after they are stable.
    DIVBUSY  <= divbusy_sync2_m_q;
    Residue  <= residue_d_w;
    Quotient <= quotient_d_w;
END rtl;
