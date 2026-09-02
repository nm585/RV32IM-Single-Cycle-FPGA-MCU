--============================================================================
-- Copyright 2026 Hananya Ribo
-- Copyright 2026 Hanan Ribo
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- Execute module: ALU, branch logic and multiplier
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_SIGNED.ALL;
USE work.const_package.all;
USE work.aux_package.all;


ENTITY  Execute IS
	generic(
		DATA_BUS_WIDTH 	: integer := 32;
		PC_WIDTH 				: integer := 10
	);
	PORT(
		--Inputs
		read_data1_i 		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		read_data2_i 		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		sign_extend_i 	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		UpperIm_ctrl_i	: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);
		ALUOp_ctrl_i	 	: IN 	STD_LOGIC_VECTOR(4 DOWNTO 0);
		ALUSrc_ctrl_i 	: IN 	STD_LOGIC;
		MUL_OP_ctrl_i		: IN 	STD_LOGIC;
		pc_i						: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);

		--Outputs
		brTaken_o 			: OUT	STD_LOGIC;
		alu_res_o 			: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		mul_res_o 			: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		addr_gen_o 			: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0)
	);
END Execute;


ARCHITECTURE struct OF Execute IS
	-- ALU operands and shared comparison results.
	SIGNAL 	alu_operand_a_w 			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL 	alu_operand_b_w 			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL 	subtract_result_w 		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL 	unsigned_less_than_w 	: STD_LOGIC;
	SIGNAL 	operands_equal_w			: STD_LOGIC;
	SIGNAL	operand_signs_differ_w	: STD_LOGIC;
	SIGNAL	alu_result_w 				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	branch_taken_w 			: STD_LOGIC;

	-- Barrel-shifter intermediate values.
	SIGNAL	shift_left_after_1_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	shift_left_after_2_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	shift_left_after_4_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	shift_left_after_8_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	SIGNAL	shift_right_after_1_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	shift_right_after_2_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	shift_right_after_4_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	shift_right_after_8_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	shift_right_fill_w		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	SIGNAL	multiply_result_w		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);


BEGIN

--------------------------------------------------------------------------------------------------------
-- Multiplier
--------------------------------------------------------------------------------------------------------
MULTIPLIER_U : Multiplier_16bit
PORT MAP (
	Ain       => read_data1_i,
	Bin       => read_data2_i,
	MULOP     => MUL_OP_ctrl_i,
	MUL_res_o => multiply_result_w
);

--------------------------------------------------------------------------------------------------------
-- Branch Address Adder
-- addr_gen_o = pc_i + (sign_extend_i << 2)
--------------------------------------------------------------------------------------------------------
addr_gen_o	<= pc_i(PC_WIDTH-1 DOWNTO 0) + (sign_extend_i(PC_WIDTH-3 DOWNTO 0) & '0');

--------------------------------------------------------------------------------------------------------
--ALU
--------------------------------------------------------------------------------------------------------
WITH UpperIm_ctrl_i SELECT
	alu_operand_a_w <= 	read_data1_i																					WHEN	"00",
						((DATA_BUS_WIDTH-PC_WIDTH-1) DOWNTO 0 => '0') & pc_i	WHEN	"01",
						(others => '0')	WHEN	OTHERS;

alu_operand_b_w <= 	read_data2_i	WHEN not ALUSrc_ctrl_i ELSE	sign_extend_i(DATA_BUS_WIDTH-1 DOWNTO 0);


-- Reused results
subtract_result_w			<= alu_operand_a_w - alu_operand_b_w;
unsigned_less_than_w			<= '1' WHEN alu_operand_a_w < alu_operand_b_w 					ELSE '0';
operands_equal_w			<= '1' WHEN alu_operand_a_w = alu_operand_b_w 					ELSE '0';
operand_signs_differ_w	<= '1' WHEN alu_operand_a_w(31) /= alu_operand_b_w(31) 	ELSE '0';



ALU_COMB_P : PROCESS (all)
BEGIN
	-- default values
	alu_result_w 		<= (others => '0');
	branch_taken_w 		<= '0';
	shift_left_after_1_w	<= (others => '0');
	shift_left_after_2_w	<= (others => '0');
	shift_left_after_4_w	<= (others => '0');
	shift_left_after_8_w	<= (others => '0');
	shift_right_after_1_w	<= (others => '0');
	shift_right_after_2_w	<= (others => '0');
	shift_right_after_4_w	<= (others => '0');
	shift_right_after_8_w	<= (others => '0');
	shift_right_fill_w	<= (others => '0');


 	CASE ALUOp_ctrl_i IS	-- Select ALU operation
		------------------------------------------------------
    -- Arithmetic
    ------------------------------------------------------
		-- add, addi, auipc, jal, jalr
		WHEN ALU_ADD 	=>
			alu_result_w	<= alu_operand_a_w + alu_operand_b_w;
			branch_taken_w	<= '0';

		-- sub
		WHEN ALU_SUB	=>
			alu_result_w	<= subtract_result_w;
			branch_taken_w	<= '0';
		------------------------------------------------------
    -- Logic
    ------------------------------------------------------
		-- and, andi
    WHEN	ALU_AND 	=>
			alu_result_w	<= alu_operand_a_w and alu_operand_b_w;
			branch_taken_w	<= '0';

		-- or, ori
	 	WHEN ALU_OR	=>
			alu_result_w	<= alu_operand_a_w or alu_operand_b_w;
			branch_taken_w	<= '0';

		-- xor, xori
		WHEN ALU_XOR 	=>
			alu_result_w	<= alu_operand_a_w xor alu_operand_b_w;
			branch_taken_w	<= '0';

		------------------------------------------------------
    -- Shift Left
    ------------------------------------------------------
		-- sll, slli
		WHEN ALU_SHIFTL	=>
			-- Barrel-Shifter SHL stage 0
			if (alu_operand_b_w(0) = '1') then
				shift_left_after_1_w <= (alu_operand_a_w(30 DOWNTO 0) & '0');
			else
				shift_left_after_1_w <= alu_operand_a_w;
			end if;

			-- Barrel-Shifter SHL stage 1
			if (alu_operand_b_w(1) = '1') then
				shift_left_after_2_w <= (shift_left_after_1_w(29 DOWNTO 0) & "00");
			else
				shift_left_after_2_w <= shift_left_after_1_w;
			end if;

			-- Barrel-Shifter SHL stage 2
			if (alu_operand_b_w(2) = '1')	then
				shift_left_after_4_w <= (shift_left_after_2_w(27 DOWNTO 0) & "0000");
			else
				shift_left_after_4_w <= shift_left_after_2_w;
			end if;

			-- Barrel-Shifter SHL stage 3
			if (alu_operand_b_w(3) = '1')	then
				shift_left_after_8_w <= (shift_left_after_4_w(23 DOWNTO 0) & "00000000");
			else
				shift_left_after_8_w <= shift_left_after_4_w;
			end if;

			-- Barrel-Shifter SHL stage 4
			if (alu_operand_b_w(4) = '1')	then
				alu_result_w <= (shift_left_after_8_w(15 DOWNTO 0) & "0000000000000000");
			else
				alu_result_w <= shift_left_after_8_w;
			end if;

			branch_taken_w	<= '0';
		------------------------------------------------------
    -- Shift Right
    ------------------------------------------------------
		-- srl, srli, sra, srai
		WHEN ALU_SHIFTR | ALU_SHIFTR_ARITH 	=>
			-- Arithmetic shifts replicate the sign bit.
			if (alu_operand_a_w(31) = '1' and (ALUOp_ctrl_i = ALU_SHIFTR_ARITH)) then
				shift_right_fill_w <= 32x"FFFF";
			else
				shift_right_fill_w <= 32x"0000";
			end if;

			-- Barrel-Shifter SHR stage 0
			if (alu_operand_b_w(0) = '1') then
				shift_right_after_1_w <= (shift_right_fill_w(31) & alu_operand_a_w(31 DOWNTO 1));
			else
				shift_right_after_1_w <= alu_operand_a_w;
			end if;

			-- Barrel-Shifter SHR stage 1
			if (alu_operand_b_w(1) = '1') then
				shift_right_after_2_w <= (shift_right_fill_w(31 DOWNTO 30) & shift_right_after_1_w(31 DOWNTO 2));
			else
				shift_right_after_2_w <= shift_right_after_1_w;
			end if;

			-- Barrel-Shifter SHR stage 2
			if (alu_operand_b_w(2) = '1') then
				shift_right_after_4_w <= (shift_right_fill_w(31 DOWNTO 28) & shift_right_after_2_w(31 DOWNTO 4));
			else
				shift_right_after_4_w <= shift_right_after_2_w;
			end if;

			-- Barrel-Shifter SHR stage 3
			if (alu_operand_b_w(3) = '1') then
				shift_right_after_8_w <= (shift_right_fill_w(31 DOWNTO 24) & shift_right_after_4_w(31 DOWNTO 8));
			else
				shift_right_after_8_w <= shift_right_after_4_w;
			end if;

			-- Barrel-Shifter SHR stage 4
			if (alu_operand_b_w(4) = '1')	then
				alu_result_w <= (shift_right_fill_w(31 DOWNTO 16) & shift_right_after_8_w(31 DOWNTO 16));
			else
				alu_result_w <= shift_right_after_8_w;
			end if;

			branch_taken_w	<= '0';
		------------------------------------------------------
	    -- Comparison
    ------------------------------------------------------
		-- slt, slti
		WHEN ALU_LESS_THAN_SIGNED	=>
			branch_taken_w	<= '0';
			IF operand_signs_differ_w THEN
				IF alu_operand_a_w(31) THEN
					alu_result_w	<= (0 => '1', others => '0');	--32'h1
				ELSE
						alu_result_w	<= (others => '0');						--32'h0
				END IF;
			ELSE
				IF subtract_result_w(31) THEN
						alu_result_w	<= (0 => '1', others => '0');	--32'h1
				ELSE
						alu_result_w	<= (others => '0');						--32'h0
				END IF;
			END IF;

		-- sltu, sltiu
		WHEN ALU_LESS_THAN_UNSIGNED	=>
			branch_taken_w	<= '0';
			IF unsigned_less_than_w THEN
					alu_result_w	<= (0 => '1', others => '0');		--32'h1
			ELSE
					alu_result_w	<= (others => '0');							--32'h0
			END IF;

		------------------------------------------------------
	    -- Conditional Branch
    ------------------------------------------------------
		-- beq
		WHEN ALU_BEQ	=>
			alu_result_w	<= (others => '0');
			branch_taken_w	<= operands_equal_w;

		-- bne
		WHEN ALU_BNE	=>
			alu_result_w	<= (others => '0');
			branch_taken_w	<= not operands_equal_w;

		-- blt
		WHEN ALU_BLT	=>
			alu_result_w	<= (others => '0');
			IF operand_signs_differ_w THEN
				branch_taken_w	<= alu_operand_a_w(31);
			ELSE
				branch_taken_w	<= subtract_result_w(31);
			END IF;

		-- bge
		WHEN ALU_BGE	=>
			alu_result_w	<= (others => '0');
			IF operand_signs_differ_w THEN
				branch_taken_w	<= alu_operand_b_w(31);
			ELSE
				branch_taken_w	<= not subtract_result_w(31);
			END IF;

		-- bltu
		WHEN ALU_BLTU	=>
			alu_result_w	<= (others => '0');
			branch_taken_w	<= unsigned_less_than_w;

		-- bgeu
		WHEN ALU_BGEU	=>
			alu_result_w	<= (others => '0');
			branch_taken_w	<= not unsigned_less_than_w;

 	 	WHEN OTHERS	=>
			alu_result_w	<= (others => '0');
			branch_taken_w	<= '0';

  END CASE;

END PROCESS;

--------------------------------------------------------------------------------------------------------
-- Keep the raw ALU and multiplier outputs separate. RV32IM_CORE implements
-- the two cascaded WBSrc muxes from the datapath diagram.
alu_res_o	<= alu_result_w;
mul_res_o	<= multiply_result_w;
brTaken_o	<= branch_taken_w;

END struct;
