LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE STD.ENV.ALL;
USE work.aux_package.ALL;

-- Self-checking coverage for the interrupt controller's register map, source
-- latches, acknowledge bus cycle and fixed-priority service behavior.

ENTITY tb_Interrupt_Controller IS
END tb_Interrupt_Controller;

ARCHITECTURE test OF tb_Interrupt_Controller IS
    -- IE, IFG and TYPE occupy consecutive byte addresses in the peripheral map.
    CONSTANT CLK_PERIOD : TIME := 20 ns;
    CONSTANT IE     : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"202C";
    CONSTANT IFG    : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"202D";
    CONSTANT \TYPE\ : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"202E";

    SIGNAL clk_i           : STD_LOGIC := '0';
    SIGNAL rst_i           : STD_LOGIC := '1';
    SIGNAL addr_i          : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data_wr_i       : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL mem_read_i      : STD_LOGIC := '0';
    SIGNAL mem_write_i     : STD_LOGIC := '0';
    SIGNAL gie_i           : STD_LOGIC := '0';
    SIGNAL inta_n_i        : STD_LOGIC := '1';
    SIGNAL interrupt_dispatch_i: STD_LOGIC := '0';
    SIGNAL bt_event_i      : STD_LOGIC := '0';
    SIGNAL key_event_i     : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data_rd_o       : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL data_oe_o       : STD_LOGIC;
    SIGNAL intr_o          : STD_LOGIC;
    SIGNAL type_o          : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL ie_o            : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL ifg_o           : STD_LOGIC_VECTOR(7 DOWNTO 0);
BEGIN
    DUT : Interrupt_Controller
        PORT MAP (
            smclk_i         => clk_i,
            rst_i           => rst_i,
            addr_i          => addr_i,
            data_wr_i       => data_wr_i,
            mem_read_i      => mem_read_i,
            mem_write_i     => mem_write_i,
            gie_i           => gie_i,
            inta_n_i        => inta_n_i,
            interrupt_dispatch_i => interrupt_dispatch_i,
            bt_event_i      => bt_event_i,
            key_event_i     => key_event_i,
            data_rd_o       => data_rd_o,
            data_oe_o       => data_oe_o,
            intr_o          => intr_o,
            type_o          => type_o,
            ie_o            => ie_o,
            ifg_o           => ifg_o
        );

    -- Event inputs are intentionally not tied to this clock; several checks
    -- below pulse them entirely between system-clock edges.
    clk_i <= NOT clk_i AFTER CLK_PERIOD / 2;

    stimulus : PROCESS
        -- Registered state is sampled one nanosecond after the active edge.
        PROCEDURE tick IS
        BEGIN
            WAIT UNTIL rising_edge(clk_i);
            WAIT FOR 1 ns;
        END PROCEDURE;

        -- Present an eight-bit register write for one complete rising edge.
        PROCEDURE write_reg(
            CONSTANT reg_addr : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            CONSTANT value    : IN STD_LOGIC_VECTOR(7 DOWNTO 0)
        ) IS
        BEGIN
            addr_i      <= reg_addr;
            data_wr_i   <= x"000000" & value;
            mem_write_i <= '1';
            tick;
            mem_write_i <= '0';
        END PROCEDURE;

        -- Validate both the returned byte and ownership of the shared data bus.
        -- The zero-time waits let OE deassert through its combinational deltas.
        PROCEDURE expect_read(
            CONSTANT reg_addr    : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            CONSTANT value       : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            CONSTANT message_text: IN STRING
        ) IS
        BEGIN
            addr_i     <= reg_addr;
            mem_read_i <= '1';
            WAIT FOR 1 ns;
            ASSERT data_rd_o = x"000000" & value
                REPORT message_text SEVERITY FAILURE;
            ASSERT data_oe_o = '1'
                REPORT message_text & ": interrupt controller did not enable the data bus"
                SEVERITY FAILURE;
            mem_read_i <= '0';
            WAIT FOR 0 ns;
            WAIT FOR 0 ns;
            ASSERT data_oe_o = '0'
                REPORT message_text & ": interrupt controller did not release the data bus"
                SEVERITY FAILURE;
        END PROCEDURE;

        -- IFG writes are clear masks; zero therefore clears every source latch.
        PROCEDURE clear_ifg IS
        BEGIN
            write_reg(IFG, x"00");
        END PROCEDURE;

        -- Perform the address-independent interrupt acknowledge cycle, capture
        -- TYPE on its active edge, and cross-check the later MMIO readback.
        PROCEDURE inta_cycle(
            CONSTANT expected_type : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            CONSTANT message_text  : IN STRING
        ) IS
        BEGIN
            -- Page 15 puts TYPE on the data bus without an address transaction.
            -- An unrelated address makes accidental MMIO decoding visible.
            addr_i     <= x"7BAD";
            mem_read_i <= '0';
            inta_n_i   <= '0';
            WAIT FOR 1 ns;
            ASSERT data_rd_o = x"000000" & expected_type
                REPORT message_text & ": TYPE on INTA Data Bus was stale"
                SEVERITY FAILURE;
            IF expected_type = x"00" THEN
                ASSERT data_oe_o = '0'
                    REPORT message_text & ": empty INTA enabled the data bus"
                    SEVERITY FAILURE;
            ELSE
                ASSERT data_oe_o = '1'
                    REPORT message_text & ": INTA did not enable the TYPE data-bus driver"
                    SEVERITY FAILURE;
            END IF;
            tick;
            ASSERT type_o = expected_type
                REPORT message_text & ": TYPE was not latched during INTA"
                SEVERITY FAILURE;
            inta_n_i <= '1';
            WAIT FOR 1 ns;
            expect_read(\TYPE\, expected_type,
                        message_text & ": TYPE MMIO readback failed");
        END PROCEDURE;

        -- Model the core's one-cycle service-complete pulse.
        PROCEDURE service IS
        BEGIN
            interrupt_dispatch_i <= '1';
            tick;
            interrupt_dispatch_i <= '0';
        END PROCEDURE;

        PROCEDURE pulse_source(SIGNAL source : OUT STD_LOGIC) IS
        BEGIN
            -- Place the complete source pulse between system-clock edges. This
            -- proves that the event, rather than clk_i, clocks the IRQ latch
            -- shown in the assignment diagram.
            WAIT UNTIL falling_edge(clk_i);
            WAIT FOR 1 ns;
            source <= '1';
            WAIT FOR 2 ns;
            source <= '0';
            WAIT FOR 1 ns;
        END PROCEDURE;
    BEGIN
        -- Keep reset asserted across two clocks before looking at architectural
        -- state and bus ownership.
        tick;
        tick;

        -- RESET/NMI TYPE is 00h and is not a normal maskable request.
        ASSERT ie_o = x"00" AND ifg_o = x"00" AND type_o = x"00"
            REPORT "reset did not clear IE, IFG, and TYPE" SEVERITY FAILURE;
        ASSERT intr_o = '0'
            REPORT "INTR was active during reset" SEVERITY FAILURE;
        ASSERT data_oe_o = '0'
            REPORT "interrupt controller drove the data bus without a read or INTA"
            SEVERITY FAILURE;
        expect_read(\TYPE\, x"00", "TYPE reset read failed");

        rst_i <= '0';
        tick;

        -- Try to write all bits, including the reserved positions. Only the
        -- four implemented sources in bits 5:2 may survive in IE or IFG.
        write_reg(IE, x"FF");
        ASSERT ie_o = x"3C" REPORT "reserved IE bits were writable" SEVERITY FAILURE;
        expect_read(IE, x"3C", "reserved IE readback failed");
        gie_i <= '1';
        write_reg(IFG, x"C3");
        ASSERT ifg_o = x"00" REPORT "reserved IFG bits were writable" SEVERITY FAILURE;
        ASSERT intr_o = '0' REPORT "reserved IFG bits asserted INTR" SEVERITY FAILURE;
        ASSERT type_o = x"00" REPORT "reserved IFG bits selected a TYPE" SEVERITY FAILURE;
        expect_read(IFG, x"00", "reserved IFG readback failed");
        inta_cycle(x"00", "reserved IFG positions");

        -- The raw irq is latched before its enable gate. Trigger KEY1 while it
        -- is disabled, then turn IE on to expose the already pending request.
        write_reg(IE, x"00");
        pulse_source(key_event_i(0));
        ASSERT ifg_o = x"00" AND intr_o = '0'
            REPORT "disabled irq appeared before the IFG AND gate"
            SEVERITY FAILURE;
        expect_read(IFG, x"00", "disabled irq leaked into IFG readback");
        write_reg(IE, x"08");
        ASSERT ifg_o = x"08" AND intr_o = '1'
            REPORT "enabling eint did not expose the latched irq as IFG"
            SEVERITY FAILURE;
        expect_read(IFG, x"08", "enabled irq was absent from IFG readback");
        write_reg(IE, x"00");
        ASSERT ifg_o = x"00" AND intr_o = '0'
            REPORT "IFG did not follow irq AND eint"
            SEVERITY FAILURE;
        clear_ifg;
        write_reg(IE, x"3C");
        ASSERT ifg_o = x"00"
            REPORT "software clear did not clear the irq latch behind IFG"
            SEVERITY FAILURE;

        -- IFG is clear-only from software: writing ones preserves flags but
        -- cannot manufacture a request without an event edge.
        write_reg(IFG, x"3C");
        ASSERT ifg_o = x"00"
            REPORT "writing ones to IFG created an interrupt without IS"
            SEVERITY FAILURE;

        -- GIE only masks the final INTR output; the pending KEY3 flag must remain
        -- visible and assert as soon as GIE comes back.
        gie_i <= '0';
        pulse_source(key_event_i(2));
        WAIT FOR 1 ns;
        ASSERT intr_o = '0' AND ifg_o = x"20"
            REPORT "GIE masking changed IFG or failed to mask INTR" SEVERITY FAILURE;
        gie_i <= '1';
        WAIT FOR 1 ns;
        ASSERT intr_o = '1' REPORT "GIE did not release pending INTR" SEVERITY FAILURE;

        -- Establish a KEY3 TYPE, clear the source, and issue an empty INTA. The
        -- controller must neither drive the bus nor overwrite the saved TYPE.
        inta_cycle(x"1C", "KEY3");
        clear_ifg;
        ASSERT type_o = x"1C" REPORT "TYPE did not remain stable" SEVERITY FAILURE;
        addr_i <= x"7BAD";
        inta_n_i <= '0';
        WAIT FOR 1 ns;
        ASSERT data_rd_o = x"00000000" AND data_oe_o = '0'
            REPORT "empty INTA drove a maskable TYPE" SEVERITY FAILURE;
        tick;
        inta_n_i <= '1';
        ASSERT intr_o = '0' AND type_o = x"1C"
            REPORT "empty INTA changed TYPE or asserted INTR" SEVERITY FAILURE;

        -- Basic Timer is the only source cleared automatically at service end.
        pulse_source(bt_event_i);
        inta_cycle(x"10", "Basic Timer");
        service;
        ASSERT ifg_o(2) = '0' REPORT "BTIFG did not clear on service" SEVERITY FAILURE;

        -- Key flags deliberately remain pending after service and require an
        -- explicit IFG write. Exercise KEY1 and KEY2 through separate vectors.
        key_event_i(0) <= '1';
        tick;
        key_event_i(0) <= '0';
        inta_cycle(x"14", "KEY1");
        service;
        ASSERT ifg_o(3) = '1' REPORT "KEY1IFG auto-cleared" SEVERITY FAILURE;
        clear_ifg;
        ASSERT ifg_o(3) = '0'
            REPORT "software could not clear KEY1IFG" SEVERITY FAILURE;

        key_event_i(1) <= '1';
        tick;
        key_event_i(1) <= '0';
        inta_cycle(x"18", "KEY2");
        clear_ifg;

        -- A software clear and a KEY3 edge arrive on the same active clock. The
        -- asynchronous clear bubble in the design makes clear the winner.
        addr_i         <= IFG;
        data_wr_i      <= (OTHERS => '0');
        mem_write_i    <= '1';
        key_event_i(2) <= '1';
        tick;
        mem_write_i    <= '0';
        key_event_i(2) <= '0';
        ASSERT ifg_o = x"00"
            REPORT "software clr_irq did not dominate a simultaneous IS edge"
            SEVERITY FAILURE;

        -- Timer service uses that same clear path, so a simultaneous timer event
        -- is also suppressed. A later clean edge must still be accepted.
        pulse_source(bt_event_i);
        inta_cycle(x"10", "timer before simultaneous service/event");
        interrupt_dispatch_i <= '1';
        bt_event_i <= '1';
        tick;
        interrupt_dispatch_i <= '0';
        bt_event_i <= '0';
        ASSERT ifg_o(2) = '0'
            REPORT "automatic clr_irq did not dominate a simultaneous IS edge"
            SEVERITY FAILURE;
        pulse_source(bt_event_i);
        ASSERT ifg_o(2) = '1'
            REPORT "a new timer IS edge did not set BTIFG after clear"
            SEVERITY FAILURE;
        service;
        ASSERT ifg_o(2) = '0'
            REPORT "timer flag did not clear after a new event"
            SEVERITY FAILURE;

        -- Queue every implemented source at once and walk the fixed priority
        -- order, clearing sticky key flags between acknowledgements as needed.
        pulse_source(bt_event_i);
        pulse_source(key_event_i(0));
        pulse_source(key_event_i(1));
        pulse_source(key_event_i(2));
        inta_cycle(x"10", "fixed priority");
        service;
        inta_cycle(x"14", "priority after Basic Timer");
        service;
        write_reg(IFG, x"30"); -- Keep KEY2/KEY3 set while clearing KEY1.
        inta_cycle(x"18", "priority after KEY1");
        service;
        write_reg(IFG, x"20"); -- Keep KEY3 set while clearing KEY2.
        inta_cycle(x"1C", "priority after KEY2");
        service;
        clear_ifg;

        -- Assert reset with a live timer request to check both the visible
        -- registers and the hidden source latch are cleared together.
        pulse_source(bt_event_i);
        ASSERT intr_o = '1'
            REPORT "reset test did not create a pending interrupt" SEVERITY FAILURE;
        rst_i <= '1';
        WAIT FOR 1 ns;
        ASSERT ie_o = x"00" AND ifg_o = x"00" AND type_o = x"00"
            REPORT "pending reset did not clear IE/IFG/TYPE" SEVERITY FAILURE;
        ASSERT intr_o = '0'
            REPORT "pending reset did not clear INTR" SEVERITY FAILURE;
        expect_read(\TYPE\, x"00", "TYPE read after pending reset failed");

        -- One final timer service proves the controller starts cleanly again.
        rst_i <= '0';
        tick;
        write_reg(IE, x"04");
        gie_i <= '1';
        pulse_source(bt_event_i);
        inta_cycle(x"10", "Basic Timer after reset");
        service;
        ASSERT ifg_o = x"00" AND intr_o = '0'
            REPORT "Basic Timer did not clear after reset test"
            SEVERITY FAILURE;

        REPORT "tb_Interrupt_Controller: all tests passed" SEVERITY NOTE;
        STOP;
        WAIT;
    END PROCESS;
END test;
