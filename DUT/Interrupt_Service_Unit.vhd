-- Two-cycle interrupt entry state machine for the single-cycle core.
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY Interrupt_Service_Unit IS
    GENERIC (
        PC_WIDTH : INTEGER := 13
    );
    PORT (
        clk_i             : IN  STD_LOGIC;
        rst_i             : IN  STD_LOGIC;
        intr_i            : IN  STD_LOGIC;
        pc_hold_i         : IN  STD_LOGIC;
        next_pc_i         : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        data_bus_i        : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);

        busy_o            : OUT STD_LOGIC;
        pc_hold_o         : OUT STD_LOGIC;
        inta_n_o          : OUT STD_LOGIC;
        enter_o           : OUT STD_LOGIC;
        dispatch_o        : OUT STD_LOGIC;
        return_addr_o     : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        captured_type_o   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        vector_pc_o       : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0)
    );
END Interrupt_Service_Unit;

ARCHITECTURE rtl OF Interrupt_Service_Unit IS
    -- IDLE waits for the current instruction to complete.
    -- INTA_CYCLE captures TYPE while holding the PC.
    -- SERVICE_CYCLE loads the vector and redirects instruction fetch.
    TYPE state_t IS (IDLE, INTA_CYCLE, SERVICE_CYCLE);
    SIGNAL state_q       : state_t;
    SIGNAL return_addr_q : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
    SIGNAL captured_type_q : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL interrupt_accept_w : STD_LOGIC;
BEGIN
    -- Accept interrupts only after the current instruction completes.
    interrupt_accept_w <= '1'
        WHEN state_q = IDLE AND intr_i = '1' AND pc_hold_i = '0' ELSE '0';

    -- Save next_pc so RETI resumes after the completed instruction.
    INTERRUPT_SEQUENCE_P : PROCESS (clk_i, rst_i)
    BEGIN
        IF rst_i = '1' THEN
            state_q       <= IDLE;
            return_addr_q <= (OTHERS => '0');
            captured_type_q <= (OTHERS => '0');
        ELSIF rising_edge(clk_i) THEN
            CASE state_q IS
                WHEN IDLE =>
                    IF interrupt_accept_w = '1' THEN
                        return_addr_q <= next_pc_i;
                        state_q       <= INTA_CYCLE;
                    END IF;
                WHEN INTA_CYCLE =>
                    -- Capture TYPE at the end of the acknowledgement cycle.
                    captured_type_q <= data_bus_i(7 DOWNTO 0);
                    state_q <= SERVICE_CYCLE;
                WHEN SERVICE_CYCLE =>
                    state_q <= IDLE;
            END CASE;
        END IF;
    END PROCESS;

    -- Decode one-cycle entry, hold, acknowledge and dispatch controls.
    busy_o        <= '0' WHEN state_q = IDLE ELSE '1';
    pc_hold_o     <= '1' WHEN state_q = INTA_CYCLE ELSE '0';
    inta_n_o      <= '0' WHEN state_q = INTA_CYCLE ELSE '1';
    enter_o       <= interrupt_accept_w;
    dispatch_o    <= '1' WHEN state_q = SERVICE_CYCLE ELSE '0';
    return_addr_o <= return_addr_q;
    captured_type_o <= captured_type_q;

    -- TYPE selects a zero-based vector-table entry in DTCM.
    vector_pc_o <= data_bus_i(PC_WIDTH-1 DOWNTO 0);
END rtl;
