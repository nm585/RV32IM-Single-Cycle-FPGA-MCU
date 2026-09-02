-- Interrupt controller for the timer and the three pushbuttons.
-- Events are latched, masked and prioritized before CPU acknowledgement.
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY Interrupt_Controller IS
    PORT (
        -- Clock and the register interface.
        smclk_i          : IN  STD_LOGIC;
        rst_i            : IN  STD_LOGIC;
        addr_i           : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
        data_wr_i        : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
        mem_read_i       : IN  STD_LOGIC;
        mem_write_i      : IN  STD_LOGIC;

        -- Handshake with the interrupt sequencer in the core.
        gie_i            : IN  STD_LOGIC;
        inta_n_i         : IN  STD_LOGIC;
        interrupt_dispatch_i : IN STD_LOGIC;

        -- Active-high timer and key events.
        bt_event_i  : IN  STD_LOGIC;
        key_event_i : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);

        data_rd_o        : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        data_oe_o        : OUT STD_LOGIC;
        intr_o           : OUT STD_LOGIC;
        type_o           : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        ie_o             : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        ifg_o            : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
END Interrupt_Controller;

ARCHITECTURE rtl OF Interrupt_Controller IS
    -- Interrupt-controller register addresses.
    CONSTANT IE     : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"202C";
    CONSTANT IFG    : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"202D";
    CONSTANT \TYPE\ : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"202E";

    -- TYPE values are byte offsets into the vector table.
    CONSTANT TYPE_BT   : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"10";
    CONSTANT TYPE_KEY1 : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"14";
    CONSTANT TYPE_KEY2 : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"18";
    CONSTANT TYPE_KEY3 : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"1C";

    -- IE stores one enable bit per source.
    SIGNAL ie_q : STD_LOGIC_VECTOR(7 DOWNTO 0);

    -- Sticky event flags-IFG.
    SIGNAL bt_irq_q   : STD_LOGIC;
    SIGNAL key1_irq_q : STD_LOGIC;
    SIGNAL key2_irq_q : STD_LOGIC;
    SIGNAL key3_irq_q : STD_LOGIC;

    SIGNAL type_q : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL ifg_w  : STD_LOGIC_VECTOR(7 DOWNTO 0);

    -- Pending flags after applying IE.
    SIGNAL btifg_w   : STD_LOGIC;
    SIGNAL key1ifg_w : STD_LOGIC;
    SIGNAL key2ifg_w : STD_LOGIC;
    SIGNAL key3ifg_w : STD_LOGIC;
    SIGNAL enabled_interrupt_pending_w : STD_LOGIC;
    SIGNAL priority_type_w              : STD_LOGIC_VECTOR(7 DOWNTO 0);

    SIGNAL ie_write_w          : STD_LOGIC;
    SIGNAL ifg_write_w         : STD_LOGIC;
    SIGNAL bt_irq_clear_n_w          : STD_LOGIC;
    SIGNAL key1_irq_clear_n_w        : STD_LOGIC;
    SIGNAL key2_irq_clear_n_w        : STD_LOGIC;
    SIGNAL key3_irq_clear_n_w        : STD_LOGIC;
    SIGNAL mmio_read_enable_w        : STD_LOGIC;
    SIGNAL type_bus_drive_enable_w   : STD_LOGIC;
BEGIN
    -- INTA has priority over software reads on the local data output.

    -- Assert when the CPU writes to the Interrupt Enable register.
    ie_write_w  <= '1' WHEN mem_write_i = '1' AND addr_i = IE ELSE '0';

    -- Assert when the CPU writes to the Interrupt Flag register.
    ifg_write_w <= '1' WHEN mem_write_i = '1' AND addr_i = IFG ELSE '0';

    
    -- Enable the controller output during a software read of IE, IFG or TYPE.
    mmio_read_enable_w <= '1' WHEN mem_read_i = '1' AND
        (addr_i = IE OR addr_i = IFG OR addr_i = \TYPE\) ELSE '0';
    -- Cycle 1 of the INTA handshake: while active-low INTA is asserted,
    -- drive the selected TYPE onto the data bus for capture by the CPU.
    type_bus_drive_enable_w <= (NOT inta_n_i) AND enabled_interrupt_pending_w;
    data_oe_o <= type_bus_drive_enable_w OR mmio_read_enable_w;

    -- Apply the source enables to the latched events.
    btifg_w   <= bt_irq_q   AND ie_q(2);
    key1ifg_w <= key1_irq_q AND ie_q(3);
    key2ifg_w <= key2_irq_q AND ie_q(4);
    key3ifg_w <= key3_irq_q AND ie_q(5);

    ifg_w <= "00" & key3ifg_w & key2ifg_w & key1ifg_w &
             btifg_w & "00";

    -- Assert INTR when an enabled source is pending and GIE is set.
    enabled_interrupt_pending_w <=
        btifg_w OR key1ifg_w OR key2ifg_w OR key3ifg_w;
    intr_o <= gie_i AND enabled_interrupt_pending_w;

    -- Fixed priority: timer, KEY1, KEY2, KEY3.
    priority_type_w <= TYPE_BT         WHEN btifg_w = '1' ELSE
                       TYPE_KEY1       WHEN key1ifg_w = '1' ELSE
                       TYPE_KEY2       WHEN key2ifg_w = '1' ELSE
                       TYPE_KEY3       WHEN key3ifg_w = '1' ELSE
                       x"00";

    -- Writing zero to an IFG bit clears its source.
    -- The timer flag also clears after service completes.
    bt_irq_clear_n_w <= '0' WHEN rst_i = '1' OR
                                     (interrupt_dispatch_i = '1' AND type_q = TYPE_BT) OR
                                     (ifg_write_w = '1' AND data_wr_i(2) = '0')
                        ELSE '1';
    key1_irq_clear_n_w <= '0' WHEN rst_i = '1' OR
                                       (ifg_write_w = '1' AND data_wr_i(3) = '0')
                          ELSE '1';
    key2_irq_clear_n_w <= '0' WHEN rst_i = '1' OR
                                       (ifg_write_w = '1' AND data_wr_i(4) = '0')
                          ELSE '1';
    key3_irq_clear_n_w <= '0' WHEN rst_i = '1' OR
                                       (ifg_write_w = '1' AND data_wr_i(5) = '0')
                          ELSE '1';

    -- TYPE is latched only during a valid acknowledgement.
    REGISTER_IE_AND_TYPE_P : PROCESS (smclk_i, rst_i)
    BEGIN
        IF rst_i = '1' THEN
            ie_q <= (OTHERS => '0');
            -- Reset TYPE value.
            type_q <= x"00";
        ELSIF rising_edge(smclk_i) THEN
            IF ie_write_w = '1' THEN
                -- Preserve unused IE bits as zero.
                ie_q <= "00" & data_wr_i(5 DOWNTO 2) & "00";
            END IF;

            -- Capture the selected TYPE during INTA.
            IF inta_n_i = '0' AND enabled_interrupt_pending_w = '1' THEN
                type_q <= priority_type_w;
            END IF;
        END IF;
    END PROCESS;

    -- Each event edge sets a sticky source flag independently of MCLK.
    -- Software clear and service completion reset the relevant flag
    -- through the active-low asynchronous clear path.
    LATCH_BT_INTERRUPT_P : PROCESS (bt_event_i, bt_irq_clear_n_w)
    BEGIN
        IF bt_irq_clear_n_w = '0' THEN
            bt_irq_q <= '0';
        ELSIF rising_edge(bt_event_i) THEN
            bt_irq_q <= '1';
        END IF;
    END PROCESS;

    -- Key flags use the same event-latch structure.
    LATCH_KEY1_INTERRUPT_P : PROCESS (
        key_event_i(0), key1_irq_clear_n_w)
    BEGIN
        IF key1_irq_clear_n_w = '0' THEN
            key1_irq_q <= '0';
        ELSIF rising_edge(key_event_i(0)) THEN
            key1_irq_q <= '1';
        END IF;
    END PROCESS;

    LATCH_KEY2_INTERRUPT_P : PROCESS (
        key_event_i(1), key2_irq_clear_n_w)
    BEGIN
        IF key2_irq_clear_n_w = '0' THEN
            key2_irq_q <= '0';
        ELSIF rising_edge(key_event_i(1)) THEN
            key2_irq_q <= '1';
        END IF;
    END PROCESS;

    LATCH_KEY3_INTERRUPT_P : PROCESS (
        key_event_i(2), key3_irq_clear_n_w)
    BEGIN
        IF key3_irq_clear_n_w = '0' THEN
            key3_irq_q <= '0';
        ELSIF rising_edge(key_event_i(2)) THEN
            key3_irq_q <= '1';
        END IF;
    END PROCESS;

    -- Drive TYPE during active-low INTA; normal reads use the register mux.
    DRIVE_DATA_BUS_P : PROCESS (ALL)
    BEGIN
        data_rd_o <= (OTHERS => '0');

        -- INTA transfers TYPE independently of the MMIO address.
        -- The CPU remains the address-bus master while the controller drives
        -- the selected TYPE value onto the shared data bus.
        IF type_bus_drive_enable_w = '1' THEN
            data_rd_o(7 DOWNTO 0) <= priority_type_w;
        ELSIF mmio_read_enable_w = '1' THEN
            CASE addr_i IS
                WHEN IE =>
                    data_rd_o(7 DOWNTO 0) <= ie_q;
                WHEN IFG =>
                    data_rd_o(7 DOWNTO 0) <= ifg_w;
                WHEN \TYPE\ =>
                    data_rd_o(7 DOWNTO 0) <= type_q;
                WHEN OTHERS =>
                    NULL;
            END CASE;
        END IF;
    END PROCESS;

    -- Expose controller state for verification.
    type_o <= type_q;
    ie_o   <= ie_q;
    ifg_o  <= ifg_w;
END rtl;
