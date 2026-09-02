LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE STD.ENV.ALL;
USE work.aux_package.ALL;

-- Checks the short interrupt-entry state machine independently of the core and
-- interrupt controller, including its interaction with a stalled divider.

ENTITY tb_Interrupt_Service_Unit IS
END tb_Interrupt_Service_Unit;

ARCHITECTURE test OF tb_Interrupt_Service_Unit IS
    -- A small PC width keeps return-address values readable in the waveform.
    CONSTANT CLK_PERIOD : TIME := 20 ns;
    SIGNAL clk_i         : STD_LOGIC := '0';
    SIGNAL rst_i         : STD_LOGIC := '1';
    SIGNAL intr_i        : STD_LOGIC := '0';
    SIGNAL pc_hold_i     : STD_LOGIC := '0';
    SIGNAL next_pc_i     : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data_bus_i    : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL busy_o        : STD_LOGIC;
    SIGNAL pc_hold_o     : STD_LOGIC;
    SIGNAL inta_n_o      : STD_LOGIC;
    SIGNAL enter_o       : STD_LOGIC;
    SIGNAL dispatch_o    : STD_LOGIC;
    SIGNAL return_addr_o : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL captured_type_o : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL vector_pc_o   : STD_LOGIC_VECTOR(9 DOWNTO 0);
BEGIN
    DUT : Interrupt_Service_Unit
        GENERIC MAP (PC_WIDTH => 10)
        PORT MAP (
            clk_i         => clk_i,
            rst_i         => rst_i,
            intr_i        => intr_i,
            pc_hold_i     => pc_hold_i,
            next_pc_i     => next_pc_i,
            data_bus_i    => data_bus_i,
            busy_o        => busy_o,
            pc_hold_o     => pc_hold_o,
            inta_n_o      => inta_n_o,
            enter_o       => enter_o,
            dispatch_o    => dispatch_o,
            return_addr_o => return_addr_o,
            captured_type_o => captured_type_o,
            vector_pc_o   => vector_pc_o
        );

    clk_i <= NOT clk_i AFTER CLK_PERIOD / 2;

    stimulus : PROCESS
        -- Wait for registered outputs and their combinational derivatives to settle.
        PROCEDURE tick IS
        BEGIN
            WAIT UNTIL rising_edge(clk_i);
            WAIT FOR 1 ns;
        END PROCEDURE;
    BEGIN
        -- Establish the idle/reset contract before presenting an interrupt.
        tick;
        tick;
        rst_i <= '0';
        tick;
        ASSERT busy_o = '0' AND inta_n_o = '1'
            REPORT "service unit reset state is wrong" SEVERITY FAILURE;

        -- Hold the PC (core stalled) while INTR is high. Acceptance must wait, but
        -- the level request must still be seen as soon as the stall clears.
        intr_i <= '1';
        pc_hold_i <= '1';
        next_pc_i <= "0100100100";
        WAIT FOR 1 ns;
        ASSERT enter_o = '0' REPORT "interrupt accepted while core was stalled" SEVERITY FAILURE;
        -- The first busy cycle is INTA: the PC stays frozen while the controller
        -- places TYPE on the data bus and the return address remains latched.
        tick;
        pc_hold_i <= '0';
        WAIT FOR 1 ns;
        ASSERT enter_o = '1' REPORT "pending interrupt was not accepted" SEVERITY FAILURE;

        tick;
        ASSERT busy_o = '1' AND pc_hold_o = '1' AND inta_n_o = '0'
            REPORT "INTA cycle outputs are wrong" SEVERITY FAILURE;
        ASSERT return_addr_o = "0100100100"
            REPORT "next PC was not captured as return address" SEVERITY FAILURE;

        -- On the following edge, release INTA and dispatch using the captured TYPE.
        intr_i <= '0';
        data_bus_i <= x"00000018";
        tick;
        ASSERT busy_o = '1' AND pc_hold_o = '0' AND inta_n_o = '1' AND dispatch_o = '1'
            REPORT "dispatch cycle outputs are wrong" SEVERITY FAILURE;
        ASSERT captured_type_o = x"18"
            REPORT "TYPE was not captured from the Data Bus on the INTA edge"
            SEVERITY FAILURE;

        -- During dispatch the zero-based vector-table entry replaces TYPE on
        -- the same Data Bus and must pass directly to the physical ITCM PC.
        data_bus_i <= x"0000005C";
        WAIT FOR 1 ns;
        ASSERT vector_pc_o = "0001011100"
            REPORT "zero-based vector address did not pass through to the ITCM PC"
            SEVERITY FAILURE;

        -- TYPE remains private even though the live bus now carries vector data.
        ASSERT captured_type_o = x"18"
            REPORT "captured TYPE changed during dispatch" SEVERITY FAILURE;

        -- Check a second physical ITCM address as well.
        data_bus_i <= x"000000A4";
        WAIT FOR 1 ns;
        ASSERT vector_pc_o = "0010100100"
            REPORT "second zero-based vector address did not pass through"
            SEVERITY FAILURE;

        -- Dispatch lasts one cycle; the next edge must return the unit to idle.
        tick;
        ASSERT busy_o = '0' AND dispatch_o = '0'
            REPORT "service unit did not return to IDLE" SEVERITY FAILURE;

        REPORT "tb_Interrupt_Service_Unit: all tests passed" SEVERITY NOTE;
        STOP;
        WAIT;
    END PROCESS;
END test;
