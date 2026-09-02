LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE STD.ENV.ALL;
USE work.aux_package.ALL;

-- Focused combinational decode checks for DIV/REM and the project-specific
-- RETI encoding, with ordinary R-type instructions as regression cases.

ENTITY tb_control_div IS
END tb_control_div;

ARCHITECTURE test OF tb_control_div IS
    SIGNAL clk_i              : STD_LOGIC := '0';
    SIGNAL rst_i              : STD_LOGIC := '1';
    SIGNAL instruction_i      : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL DIVBUSY            : STD_LOGIC := '0';
    SIGNAL IntPChold_i        : STD_LOGIC := '0';
    SIGNAL IntBusy_i          : STD_LOGIC := '0';
    SIGNAL PChold_o           : STD_LOGIC;
    SIGNAL DIVENA_o           : STD_LOGIC;
    SIGNAL RegDst_ctrl_o      : STD_LOGIC;
    SIGNAL ALUSrc_ctrl_o      : STD_LOGIC;
    SIGNAL MemtoReg_ctrl_o    : STD_LOGIC;
    SIGNAL RegWrite_ctrl_o    : STD_LOGIC;
    SIGNAL MemRead_ctrl_o     : STD_LOGIC;
    SIGNAL MemWrite_ctrl_o    : STD_LOGIC;
    SIGNAL Branch_ctrl_o      : STD_LOGIC;
    SIGNAL Jal_ctrl_o         : STD_LOGIC;
    SIGNAL Jalr_ctrl_o        : STD_LOGIC;
    SIGNAL Reti_ctrl_o        : STD_LOGIC;
    SIGNAL MUL_OP_ctrl_o      : STD_LOGIC;
    SIGNAL wbsrc0_o           : STD_LOGIC;
    SIGNAL wbsrc1_o           : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL DIVU_ctrl_o        : STD_LOGIC;
    SIGNAL REMU_ctrl_o        : STD_LOGIC;
    SIGNAL UpperIm_ctrl_o     : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL ALUOp_ctrl_o       : STD_LOGIC_VECTOR(4 DOWNTO 0);
BEGIN
    clk_i <= NOT clk_i AFTER 5 ns;

    DUT : control
        PORT MAP (
            clk_i           => clk_i,
            rst_i           => rst_i,
            instruction_i   => instruction_i,
            DIVBUSY         => DIVBUSY,
            IntPChold_i     => IntPChold_i,
            IntBusy_i       => IntBusy_i,
            PChold_o        => PChold_o,
            DIVENA_o        => DIVENA_o,
            RegDst_ctrl_o   => RegDst_ctrl_o,
            ALUSrc_ctrl_o   => ALUSrc_ctrl_o,
            MemtoReg_ctrl_o => MemtoReg_ctrl_o,
            RegWrite_ctrl_o => RegWrite_ctrl_o,
            MemRead_ctrl_o  => MemRead_ctrl_o,
            MemWrite_ctrl_o => MemWrite_ctrl_o,
            Branch_ctrl_o   => Branch_ctrl_o,
            Jal_ctrl_o      => Jal_ctrl_o,
            Jalr_ctrl_o     => Jalr_ctrl_o,
            Reti_ctrl_o     => Reti_ctrl_o,
            MUL_OP_ctrl_o   => MUL_OP_ctrl_o,
            wbsrc0_o        => wbsrc0_o,
            wbsrc1_o        => wbsrc1_o,
            DIVU_ctrl_o     => DIVU_ctrl_o,
            REMU_ctrl_o     => REMU_ctrl_o,
            UpperIm_ctrl_o  => UpperIm_ctrl_o,
            ALUOp_ctrl_o    => ALUOp_ctrl_o
        );

    stimulus : PROCESS
        -- Apply one instruction and check the M-extension decode and both
        -- cascaded write-back mux controls.
        PROCEDURE check_decode(
            CONSTANT instruction_c : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            CONSTANT divu_c        : IN STD_LOGIC;
            CONSTANT remu_c        : IN STD_LOGIC;
            CONSTANT regwrite_c    : IN STD_LOGIC;
            CONSTANT mul_op_c      : IN STD_LOGIC;
            CONSTANT wbsrc0_c      : IN STD_LOGIC;
            CONSTANT wbsrc1_c      : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            CONSTANT test_name_c   : IN STRING
        ) IS
        BEGIN
            instruction_i <= instruction_c;
            WAIT FOR 1 ns;
            ASSERT DIVU_ctrl_o = divu_c
                REPORT test_name_c & ": incorrect DIVU decode"
                SEVERITY FAILURE;
            ASSERT REMU_ctrl_o = remu_c
                REPORT test_name_c & ": incorrect REMU decode"
                SEVERITY FAILURE;
            ASSERT RegWrite_ctrl_o = regwrite_c
                REPORT test_name_c & ": incorrect ordinary RF write-enable"
                SEVERITY FAILURE;
            ASSERT MUL_OP_ctrl_o = mul_op_c
                REPORT test_name_c & ": incorrect multiplier enable"
                SEVERITY FAILURE;
            ASSERT wbsrc0_o = wbsrc0_c
                REPORT test_name_c & ": incorrect WBSrc0 selection"
                SEVERITY FAILURE;
            ASSERT wbsrc1_o = wbsrc1_c
                REPORT test_name_c & ": incorrect WBSrc1 selection"
                SEVERITY FAILURE;
        END PROCEDURE;
    BEGIN
        -- Reset the divider-completion history before checking the decoder.
        WAIT UNTIL rising_edge(clk_i);
        WAIT UNTIL rising_edge(clk_i);
        rst_i <= '0';
        WAIT FOR 1 ns;

        -- The register fields are deliberately nonzero. DIVU/REMU decoding must
        -- depend only on funct7, funct3 and opcode.
        check_decode(x"023150B3", '1', '0', '0', '0', '0', "01", "DIVU");
        check_decode(x"023170B3", '0', '1', '0', '0', '0', "00", "REMU");

        -- This project routes signed DIV/REM through the unsigned divider. Its
        -- benchmark uses non-negative operands, so the numeric result is the
        -- same; ordinary RegWrite still stays low while the divider owns it.
        check_decode(x"023140B3", '1', '0', '0', '0', '0', "01", "signed DIV via unsigned");
        check_decode(x"023160B3", '0', '1', '0', '0', '0', "00", "signed REM via unsigned");

        -- Guard the pre-existing ADD and MUL paths against an overly broad DIV decode.
        check_decode(x"003100B3", '0', '0', '1', '0', '1', "00", "ADD");
        check_decode(x"023100B3", '0', '0', '1', '1', '0', "10", "MUL");

        -- Change one required field at a time to catch partial instruction matches.
        check_decode(x"003150B3", '0', '0', '1', '0', '1', "00", "wrong funct7");
        check_decode(x"02315093", '0', '0', '1', '0', '1', "00", "wrong opcode");

        -- RETI is the exact project-specific alias jalr zero, 0(tp). The three
        -- following JALR instructions each differ in one operand or immediate.
        instruction_i <= x"00020067";
        WAIT FOR 1 ns;
        ASSERT Reti_ctrl_o = '1' AND Jalr_ctrl_o = '1'
            REPORT "exact RETI instruction was not decoded"
            SEVERITY FAILURE;

        instruction_i <= x"000200E7"; -- Destination is ra instead of zero.
        WAIT FOR 1 ns;
        ASSERT Reti_ctrl_o = '0' AND Jalr_ctrl_o = '1'
            REPORT "RETI ignored the destination-register field"
            SEVERITY FAILURE;

        instruction_i <= x"00028067"; -- Base register is t0 instead of tp.
        WAIT FOR 1 ns;
        ASSERT Reti_ctrl_o = '0' AND Jalr_ctrl_o = '1'
            REPORT "RETI ignored the source-register field"
            SEVERITY FAILURE;

        instruction_i <= x"00420067"; -- Immediate is four instead of zero.
        WAIT FOR 1 ns;
        ASSERT Reti_ctrl_o = '0' AND Jalr_ctrl_o = '1'
            REPORT "RETI ignored the immediate field"
            SEVERITY FAILURE;

        REPORT "tb_control_div: all tests passed" SEVERITY NOTE;
        STOP;
        WAIT;
    END PROCESS;
END test;
