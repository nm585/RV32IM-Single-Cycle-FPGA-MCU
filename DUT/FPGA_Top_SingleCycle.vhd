LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.cond_compilation_package.ALL;
USE work.aux_package.ALL;
-- MCU board wrapper with a global Address-BUS and one resolved shared Data-BUS.
-- Generic BidirPin adapters surround the directional modules; bus decode and
-- command qualification stay here, while DTCM stays in RV32IM_CORE.
-- Verification probes are exposed for simulation and SignalTap.

ENTITY FPGA_Top_SingleCycle IS
    GENERIC (
        -- MODELSIM=1 bypasses the PLLs and uses CLOCK_50 for all domains.
        MODELSIM : integer := G_MODELSIM
    );
    PORT (
        -- Board pins.
        CLOCK_50 : IN  STD_LOGIC;
        KEY0     : IN  STD_LOGIC;
        KEY1     : IN  STD_LOGIC;
        KEY2     : IN  STD_LOGIC;
        KEY3     : IN  STD_LOGIC;
        CAPIN1   : IN  STD_LOGIC;
        CAPIN2   : IN  STD_LOGIC;
        SW       : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
        LEDR     : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        HEX0     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        HEX1     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        HEX2     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        HEX3     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        HEX4     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        HEX5     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        PWMOUT   : OUT STD_LOGIC;

        -- Verification outputs.
        pc_o             : OUT STD_LOGIC_VECTOR(G_PC_WIDTH-1 DOWNTO 0);
        instruction_o    : OUT STD_LOGIC_VECTOR(DBUS_WIDTH-1 DOWNTO 0);

        RegWrite_ctrl_o  : OUT STD_LOGIC;
        MemWrite_ctrl_o  : OUT STD_LOGIC;
        Branch_ctrl_o    : OUT STD_LOGIC;

        read_data1_o     : OUT STD_LOGIC_VECTOR(DBUS_WIDTH-1 DOWNTO 0);
        read_data2_o     : OUT STD_LOGIC_VECTOR(DBUS_WIDTH-1 DOWNTO 0);
        write_data_o     : OUT STD_LOGIC_VECTOR(DBUS_WIDTH-1 DOWNTO 0);

        alu_res_o        : OUT STD_LOGIC_VECTOR(DBUS_WIDTH-1 DOWNTO 0);
        brTaken_o        : OUT STD_LOGIC;

        dtcm_addr_o      : OUT STD_LOGIC_VECTOR(G_ADDRWIDTH-1 DOWNTO 0);

        mclk_cnt_o       : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
END FPGA_Top_SingleCycle;
-------------------------------------------------------------------------------

ARCHITECTURE structural OF FPGA_Top_SingleCycle IS

    CONSTANT DATA_BUS_WIDTH       : integer := DBUS_WIDTH;
    CONSTANT DTCM_ADDR_PREFIX_C   : STD_LOGIC_VECTOR(2 DOWNTO 0) := "000";
    -- Hold reset until KEY0 is pressed once after configuration.
    SIGNAL key0_pressed_seen_q  : STD_LOGIC := '0';
    SIGNAL rst_req_w            : STD_LOGIC;
    SIGNAL rst_sync_q           : STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS => '1');
    SIGNAL rst_w                : STD_LOGIC;

    -- System and accelerator clocks.
    SIGNAL mclk_w               : STD_LOGIC;
    SIGNAL divclk_w             : STD_LOGIC;
    SIGNAL smclk_w              : STD_LOGIC;

    -- Core probes and divider operands.
    SIGNAL core_mem_read_w      : STD_LOGIC;
    SIGNAL core_mem_write_w     : STD_LOGIC;
    SIGNAL read_data1_w         : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL read_data2_w         : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL alu_res_w            : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

    -- Global Address-BUS and resolved shared Data-BUS.
    SIGNAL address_bus_w        : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL data_bus_w           : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL data_bus_read_w      : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL dtcm_bus_data_in_w   : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL gpio_bus_data_in_w   : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL timer_bus_data_in_w  : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL interrupt_controller_bus_data_in_w : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

    SIGNAL dtcm_data_rd_w       : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL gpio_data_rd_w       : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL timer_data_rd_w      : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL interrupt_controller_data_rd_w : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL gpio_data_oe_w       : STD_LOGIC;
    SIGNAL timer_data_oe_w      : STD_LOGIC;
    SIGNAL interrupt_controller_data_oe_w : STD_LOGIC;

    SIGNAL dtcm_cs_w            : STD_LOGIC;
    SIGNAL bus_mem_read_w       : STD_LOGIC;
    SIGNAL bus_mem_write_w      : STD_LOGIC;
    SIGNAL dtcm_mem_read_w      : STD_LOGIC;
    SIGNAL dtcm_mem_write_w     : STD_LOGIC;

    -- Peripheral state.
    SIGNAL gpio_ledr_w          : STD_LOGIC_VECTOR(7 DOWNTO 0);

    -- Divider request, status and results.
    SIGNAL divena_w             : STD_LOGIC;
    SIGNAL divbusy_w            : STD_LOGIC;
    SIGNAL div_quotient_w       : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL div_residue_w        : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL remu_ctrl_w          : STD_LOGIC;

    -- Peripheral events and interrupt handshake.
    SIGNAL key_n_w              : STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL key_pressed_w        : STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL btifg_set_w          : STD_LOGIC;
    SIGNAL pwmout_w             : STD_LOGIC;
    SIGNAL gie_w                : STD_LOGIC;
    SIGNAL intr_w               : STD_LOGIC;
    SIGNAL inta_n_w             : STD_LOGIC;
    SIGNAL interrupt_busy_w     : STD_LOGIC;
    SIGNAL interrupt_dispatch_w : STD_LOGIC;

BEGIN

    -- KEY0 is active low and must be pressed once before execution starts.
    REMEMBER_FIRST_RESET_PRESS_P : PROCESS (CLOCK_50)
    begin
        if rising_edge(CLOCK_50) then
            if KEY0 = '0' then
                key0_pressed_seen_q <= '1';
            end if;
        end if;
    END PROCESS;

    -- Assert reset before the first press and while KEY0 is held.
    rst_req_w <= '1' when (key0_pressed_seen_q = '0') or (KEY0 = '0') else '0';

    -- Two-stage reset conditioning in the CLOCK_50 domain.
    SYNCHRONIZE_RESET_P : PROCESS (CLOCK_50)
    begin
        if rising_edge(CLOCK_50) then
            rst_sync_q <= rst_sync_q(0) & rst_req_w;
        end if;
    END PROCESS;

    -- Common reset for all clock domains.
    rst_w   <= rst_sync_q(1);
    key_n_w <= (2 => KEY3, 1 => KEY2, 0 => KEY1);

	CLOCK_TREE_U : Clock_Tree
	GENERIC MAP (
		MODELSIM => MODELSIM
	)
	PORT MAP (
		clock_50_i => CLOCK_50,
		mclk_o     => mclk_w,
		smclk_o    => smclk_w,
		divclk_o   => divclk_w
	);

    -- CPU core, clocked by MCLK.
    CORE : RV32IM_CORE
        PORT MAP (
            mclk_i            => mclk_w,
            mclk_rst_i        => rst_w,

            data_bus_read_i   => data_bus_read_w,
            dtcm_data_wr_i    => dtcm_bus_data_in_w,
            dtcm_mem_read_i   => dtcm_mem_read_w,
            dtcm_mem_write_i  => dtcm_mem_write_w,
            dtcm_data_rd_o    => dtcm_data_rd_w,
            dtcm_addr_o       => dtcm_addr_o,
            divbusy_i         => divbusy_w,
            div_quotient_i    => div_quotient_w,
            div_residue_i     => div_residue_w,
            intr_i            => intr_w,

            MemRead_ctrl_o    => core_mem_read_w,
            MemWrite_ctrl_o   => core_mem_write_w,
            DIVENA_o          => divena_w,
            REMU_ctrl_o       => remu_ctrl_w,

            gie_o             => gie_w,
            inta_n_o          => inta_n_w,
            int_busy_o        => interrupt_busy_w,
            int_dispatch_o    => interrupt_dispatch_w,

            read_data1_o      => read_data1_w,
            read_data2_o      => read_data2_w,
            alu_res_o         => alu_res_w,

            pc_o              => pc_o,
            instruction_o     => instruction_o,
            RegWrite_ctrl_o   => RegWrite_ctrl_o,
            Branch_ctrl_o     => Branch_ctrl_o,
            write_data_o      => write_data_o,
            brTaken_o         => brTaken_o,
            mclk_cnt_o        => mclk_cnt_o
        );

	-- The core drives one global Address-BUS. Control signals remain separate,
	-- while BidirPin implements the resolved bidirectional Data-BUS.
	address_bus_w <= alu_res_w(15 DOWNTO 0);
	dtcm_cs_w <= '1'
		WHEN address_bus_w(15 DOWNTO 13) = DTCM_ADDR_PREFIX_C ELSE '0';

	-- Interrupt entry owns the bus, so normal instruction commands are blocked.

    -- Normal read request from the core.
	bus_mem_read_w  <= core_mem_read_w  AND NOT interrupt_busy_w; 
    -- Normal write request from the core.
	bus_mem_write_w <= core_mem_write_w AND NOT interrupt_busy_w; 
    -- Enables the DTCM data output for an interrupt-vector fetch or a normal core read from DTCM. 
	dtcm_mem_read_w  <= interrupt_dispatch_w OR (bus_mem_read_w AND dtcm_cs_w); 

	dtcm_mem_write_w <= bus_mem_write_w AND dtcm_cs_w;

	-- Each BidirPin is the external adapter shown between a directional module
	-- and the shared DataBUS. Only IOpin is bidirectional.
	CPU_DATA_BUS_U : BidirPin
	GENERIC MAP (width => DATA_BUS_WIDTH)
	PORT MAP (
		Dout  => read_data2_w,
		en    => bus_mem_write_w,
		Din   => data_bus_read_w,
		IOpin => data_bus_w
	);

	DTCM_DATA_BUS_U : BidirPin
	GENERIC MAP (width => DATA_BUS_WIDTH)
	PORT MAP (
		Dout  => dtcm_data_rd_w,
		en    => dtcm_mem_read_w,
		Din   => dtcm_bus_data_in_w,
		IOpin => data_bus_w
	);

	GPIO_DATA_BUS_U : BidirPin
	GENERIC MAP (width => DATA_BUS_WIDTH)
	PORT MAP (
		Dout  => gpio_data_rd_w,
		en    => gpio_data_oe_w,
		Din   => gpio_bus_data_in_w,
		IOpin => data_bus_w
	);

	TIMER_DATA_BUS_U : BidirPin
	GENERIC MAP (width => DATA_BUS_WIDTH)
	PORT MAP (
		Dout  => timer_data_rd_w,
		en    => timer_data_oe_w,
		Din   => timer_bus_data_in_w,
		IOpin => data_bus_w
	);

	INTC_DATA_BUS_U : BidirPin
	GENERIC MAP (width => DATA_BUS_WIDTH)
	PORT MAP (
		Dout  => interrupt_controller_data_rd_w,
		en    => interrupt_controller_data_oe_w,
		Din   => interrupt_controller_bus_data_in_w,
		IOpin => data_bus_w
	);

	DIV_CDC_U : Divider_CDC
	PORT MAP (
		MCLK     => mclk_w,
		MCLKRST  => rst_w,
		DIVCLK   => divclk_w,
		DIVRST   => rst_w,
		DIVENA   => divena_w,
		Dividend => read_data1_w,
		Divisor  => read_data2_w,
		DIVBUSY  => divbusy_w,
		Residue  => div_residue_w,
		Quotient => div_quotient_w
	);

		-- Each peripheral uses its local address decoder on the shared MMIO bus.
		GPIO: GPIO_Peripheral
	generic map(
		DATA_BUS_WIDTH		=> 	DATA_BUS_WIDTH
	)
	PORT MAP (
		smclk_i                     => smclk_w,
		rst_i 						=> rst_w,
		addr_i 						=> address_bus_w,
		data_wr_i 				=> gpio_bus_data_in_w,
		mem_read_i 				=> bus_mem_read_w,
		-- GPIO registers are clocked by SMCLK.
		mem_write_i 			=> bus_mem_write_w,
		sw_i 							=> SW(7 DOWNTO 0),
		key_n_i                    => key_n_w,
		data_rd_o 				=> gpio_data_rd_w,
		data_oe_o 				=> gpio_data_oe_w,
		ledr_o 						=> gpio_ledr_w,
		hex0_o 						=> HEX0,
		hex1_o 						=> HEX1,
		hex2_o 						=> HEX2,
		hex3_o 						=> HEX3,
		hex4_o 						=> HEX4,
		hex5_o 						=> HEX5
	);

	-- Convert active-low key inputs to active-high press events.
	key_pressed_w <= NOT key_n_w;

		-- Timer capture, compare and PWM interface.
		TIMER_U : Basic_Timer
	PORT MAP (
		smclk_i     => smclk_w,
		rst_i       => rst_w,
		addr_i      => address_bus_w,
		data_wr_i   => timer_bus_data_in_w,
		mem_read_i  => bus_mem_read_w,
		mem_write_i => bus_mem_write_w,
		capin1_i    => CAPIN1,
		capin2_i    => CAPIN2,
		data_rd_o   => timer_data_rd_w,
		data_oe_o   => timer_data_oe_w,
		pwmout_o    => pwmout_w,
		btifg_o     => btifg_set_w
	);

		-- Interrupt flag storage and priority arbitration.
	INTC_U : Interrupt_Controller
	PORT MAP (
		smclk_i         => smclk_w,
		rst_i           => rst_w,
		addr_i          => address_bus_w,
		data_wr_i       => interrupt_controller_bus_data_in_w,
		mem_read_i      => bus_mem_read_w,
		mem_write_i     => bus_mem_write_w,
		gie_i           => gie_w,
		inta_n_i        => inta_n_w,
		interrupt_dispatch_i => interrupt_dispatch_w,
		bt_event_i      => btifg_set_w,
		key_event_i     => key_pressed_w,
		data_rd_o       => interrupt_controller_data_rd_w,
		data_oe_o       => interrupt_controller_data_oe_w,
		intr_o          => intr_w,
		type_o          => OPEN,
		ie_o            => OPEN,
		ifg_o           => OPEN
	);

	-- Board outputs and verification probes.
	LEDR					<=	"00" & gpio_ledr_w;												-- GPIO maps only LEDR7-LEDR0
	PWMOUT				<=	pwmout_w;
	MemWrite_ctrl_o	<=	core_mem_write_w;													-- CONTROL output
	read_data1_o 	<= 	read_data1_w;																-- IDECODE output
	read_data2_o 	<= 	read_data2_w;																-- IDECODE output
	alu_res_o 		<= 	alu_res_w;																	-- EXECUTE output

END structural;
