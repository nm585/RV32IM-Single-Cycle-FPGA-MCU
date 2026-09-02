LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE STD.ENV.ALL;
USE work.aux_package.ALL;

-- Integration check for the path from a Basic Timer compare event, through
-- BTIFG, to the interrupt acknowledge and service-complete handshake.

ENTITY tb_BasicTimerInterrupt IS
END tb_BasicTimerInterrupt;

ARCHITECTURE test OF tb_BasicTimerInterrupt IS
    -- These are byte addresses on the shared peripheral bus.
    CONSTANT CLK_PERIOD   : TIME := 20 ns;
    CONSTANT BTCTL1  : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"201C";
    CONSTANT BTCMPR0 : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"2020";
    CONSTANT IE      : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"202C";
    CONSTANT IFG     : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"202D";

    SIGNAL clk_i : STD_LOGIC := '0';
    SIGNAL rst_i : STD_LOGIC := '1';

    SIGNAL timer_addr_i      : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL timer_data_wr_i   : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL timer_mem_read_i  : STD_LOGIC := '0';
    SIGNAL timer_mem_write_i : STD_LOGIC := '0';
    SIGNAL timer_data_rd_o   : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL timer_data_oe_o   : STD_LOGIC;
    SIGNAL bt_event_w        : STD_LOGIC;

    SIGNAL int_addr_i      : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL int_data_wr_i   : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL int_mem_read_i  : STD_LOGIC := '0';
    SIGNAL int_mem_write_i : STD_LOGIC := '0';
    SIGNAL gie_i           : STD_LOGIC := '0';
    SIGNAL inta_n_i        : STD_LOGIC := '1';
    SIGNAL interrupt_dispatch_i: STD_LOGIC := '0';
    SIGNAL int_data_rd_o   : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL int_data_oe_o   : STD_LOGIC;
    SIGNAL intr_o          : STD_LOGIC;
    SIGNAL type_o          : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL ie_o            : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL ifg_o           : STD_LOGIC_VECTOR(7 DOWNTO 0);
BEGIN
    TIMER_DUT : Basic_Timer
        PORT MAP (
            smclk_i     => clk_i,
            rst_i       => rst_i,
            addr_i      => timer_addr_i,
            data_wr_i   => timer_data_wr_i,
            mem_read_i  => timer_mem_read_i,
            mem_write_i => timer_mem_write_i,
            capin1_i    => '0',
            capin2_i    => '0',
            data_rd_o   => timer_data_rd_o,
            data_oe_o   => timer_data_oe_o,
            pwmout_o    => OPEN,
            btifg_o     => bt_event_w
        );

    INTC_DUT : Interrupt_Controller
        PORT MAP (
            smclk_i         => clk_i,
            rst_i           => rst_i,
            addr_i          => int_addr_i,
            data_wr_i       => int_data_wr_i,
            mem_read_i      => int_mem_read_i,
            mem_write_i     => int_mem_write_i,
            gie_i           => gie_i,
            inta_n_i        => inta_n_i,
            interrupt_dispatch_i => interrupt_dispatch_i,
            bt_event_i      => bt_event_w,
            key_event_i     => (OTHERS => '0'),
            data_rd_o       => int_data_rd_o,
            data_oe_o       => int_data_oe_o,
            intr_o          => intr_o,
            type_o          => type_o,
            ie_o            => ie_o,
            ifg_o           => ifg_o
        );

    -- Both peripherals share this clock, matching their connection in the core.
    clk_i <= NOT clk_i AFTER CLK_PERIOD / 2;

    stimulus : PROCESS
        -- Delay after the edge before sampling registered state.
        PROCEDURE tick(CONSTANT count : IN POSITIVE := 1) IS
        BEGIN
            FOR i IN 1 TO count LOOP
                WAIT UNTIL rising_edge(clk_i);
                WAIT FOR 1 ns;
            END LOOP;
        END PROCEDURE;

        -- Hold a timer write request for one complete active clock edge.
        PROCEDURE timer_write(
            CONSTANT reg_addr : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            CONSTANT value    : IN STD_LOGIC_VECTOR(31 DOWNTO 0)
        ) IS
        BEGIN
            timer_addr_i      <= reg_addr;
            timer_data_wr_i   <= value;
            timer_mem_write_i <= '1';
            tick;
            timer_mem_write_i <= '0';
        END PROCEDURE;

        -- Interrupt-controller registers use the same one-cycle MMIO protocol.
        PROCEDURE int_write(
            CONSTANT reg_addr : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            CONSTANT value    : IN STD_LOGIC_VECTOR(31 DOWNTO 0)
        ) IS
        BEGIN
            int_addr_i      <= reg_addr;
            int_data_wr_i   <= value;
            int_mem_write_i <= '1';
            tick;
            int_mem_write_i <= '0';
        END PROCEDURE;
    BEGIN
        -- Let both blocks see two reset edges before starting configuration.
        tick(2);
        rst_i <= '0';
        WAIT FOR 1 ns;

        -- Configure the period while held and cleared. Once BTCMPR0 is
        -- nonzero, clear the reset-time EQU0 flag before enabling BTIE; this
        -- ensures the interrupt below comes from a real counting interval.
        timer_write(BTCTL1, x"00000024");
        timer_write(BTCMPR0, x"00000003");
        int_write(IFG, x"00000000");
        int_write(IE, x"00000004");
        gie_i <= '1';
        timer_write(BTCTL1, x"00000000");

        FOR i IN 1 TO 8 LOOP
            EXIT WHEN intr_o = '1';
            tick;
        END LOOP;

        ASSERT intr_o = '1' AND ifg_o(2) = '1'
            REPORT "Basic Timer event was not latched into BTIFG"
            SEVERITY FAILURE;
        ASSERT timer_data_oe_o = '0' AND int_data_oe_o = '0'
            REPORT "a peripheral drove the data bus without a read or acknowledge"
            SEVERITY FAILURE;

        -- The direct compare pulse has ended by now, but BTIFG must remember it
        -- until a TYPE=0x10 service reaches the completion phase.
        ASSERT bt_event_w = '0'
            REPORT "test did not reach the post-EQU0 interval"
            SEVERITY FAILURE;

        inta_n_i <= '0';
        WAIT FOR 1 ns;
        ASSERT int_data_rd_o(7 DOWNTO 0) = x"10" AND int_data_oe_o = '1'
            REPORT "Basic Timer TYPE was not driven during acknowledge"
            SEVERITY FAILURE;
        tick;
        inta_n_i <= '1';
        -- Two zero-time waits cover the combinational bus-release delta cycles.
        WAIT FOR 0 ns;
        WAIT FOR 0 ns;
        ASSERT int_data_oe_o = '0'
            REPORT "interrupt controller did not release the bus after acknowledge"
            SEVERITY FAILURE;
        ASSERT type_o = x"10"
            REPORT "Basic Timer TYPE was not captured"
            SEVERITY FAILURE;

        interrupt_dispatch_i <= '1';
        tick;
        interrupt_dispatch_i <= '0';
        ASSERT ifg_o(2) = '0' AND intr_o = '0'
            REPORT "Basic Timer service did not clear BTIFG"
            SEVERITY FAILURE;

        REPORT "tb_BasicTimerInterrupt: timer/interrupt integration passed"
            SEVERITY NOTE;
        STOP;
        WAIT;
    END PROCESS;
END test;
