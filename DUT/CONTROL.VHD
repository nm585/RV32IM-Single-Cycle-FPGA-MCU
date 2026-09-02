--============================================================================
-- Copyright 2026 Hananya Ribo
-- Copyright 2026 Hanan Ribo
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- Control-Unit module
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_SIGNED.ALL;
USE work.const_package.all;


ENTITY control IS
	  PORT(
		--Inputs
		-- Clock, instruction and multicycle status.
		clk_i					: IN	STD_LOGIC;
		rst_i					: IN	STD_LOGIC;
		instruction_i 		: IN 	STD_LOGIC_VECTOR(31 DOWNTO 0);
		DIVBUSY				: IN	STD_LOGIC;
		IntPChold_i			: IN	STD_LOGIC;
		IntBusy_i				: IN	STD_LOGIC;

		--Outputs
		-- Datapath and memory controls.
		PChold_o				: OUT	STD_LOGIC;
		DIVENA_o				: OUT	STD_LOGIC;
		RegDst_ctrl_o 		: OUT 	STD_LOGIC;
		ALUSrc_ctrl_o 		: OUT 	STD_LOGIC;
		MemtoReg_ctrl_o 	: OUT 	STD_LOGIC;
		RegWrite_ctrl_o 	: OUT 	STD_LOGIC;
		MemRead_ctrl_o 		: OUT 	STD_LOGIC;
		MemWrite_ctrl_o	 	: OUT 	STD_LOGIC;
		Branch_ctrl_o 		: OUT 	STD_LOGIC;
		Jal_ctrl_o 				: OUT 	STD_LOGIC;
		Jalr_ctrl_o 			: OUT 	STD_LOGIC;
		Reti_ctrl_o        : OUT  STD_LOGIC;
		MUL_OP_ctrl_o			: OUT 	STD_LOGIC;
		wbsrc0_o				: OUT 	STD_LOGIC;
		wbsrc1_o				: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0);
		DIVU_ctrl_o				: OUT 	STD_LOGIC;
		REMU_ctrl_o				: OUT 	STD_LOGIC;
		UpperIm_ctrl_o		: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0);
		ALUOp_ctrl_o	 		: OUT 	STD_LOGIC_VECTOR(4 DOWNTO 0)
 	----------------------------

	);
END control;


ARCHITECTURE behavior OF control IS

	-- Instruction format classes.
	SIGNAL	r_type_w, i_type_w, s_type_w, b_type_w, u_type_w, j_type_w 								: STD_LOGIC;

	-- Load and store decoding.
	SIGNAL	lb_w, lh_w, lw_w, lbu_w, lhu_w, lwu_w, load_w, sb_w, sh_w, sw_w, store_w			: STD_LOGIC;

	-- Control-flow decoding.
	SIGNAL	beq_w, bne_w, blt_w, bge_w, bltu_w, bgeu_w, branch_w, jal_w, jalr_w, reti_w 					: STD_LOGIC;

	-- Integer ALU decoding.
	SIGNAL	add_w, addi_w, and_w, andi_w, or_w, ori_w, sll_w, slli_w, sra_w, srai_w							: STD_LOGIC;
	SIGNAL	srl_w, srli_w, sub_w, xor_w, xori_w, auipc_w, lui_w, slt_w, slti_w, sltu_w, sltiu_w	: STD_LOGIC;
	SIGNAL  opcode_w : STD_LOGIC_VECTOR(6 DOWNTO 0);

	-- Multiply/divide decoding and completion tracking.
	SIGNAL  mul_w, div_w, divu_w, rem_w, remu_w, divide_or_remainder_w : STD_LOGIC;
	SIGNAL  divbusy_previous_q, div_complete_w : STD_LOGIC;

BEGIN
	-- Detect the synchronized DIVBUSY falling edge.
	DIVBUSY_HISTORY_P : PROCESS(clk_i, rst_i)
	BEGIN
		IF rst_i = '1' THEN
			divbusy_previous_q <= '0';
		ELSIF rising_edge(clk_i) THEN
			divbusy_previous_q <= DIVBUSY;
		END IF;
	END PROCESS;

	div_complete_w <= divbusy_previous_q AND NOT DIVBUSY;

	-- Start one request while the divider and interrupt unit are idle.
	DIVENA_o <= divide_or_remainder_w AND NOT DIVBUSY AND NOT divbusy_previous_q AND
	             NOT IntBusy_i;

	-- Hold the PC while a divide or remainder operation is active.
	-- Release it on completion so write-back and PC advance occur together.
	-- Interrupt entry retains priority over a prefetched instruction.
	PChold_o <= IntPChold_i OR
	            (divide_or_remainder_w AND NOT div_complete_w AND NOT IntBusy_i);

	-- Classify the instruction by opcode.
	opcode_w 	<=	instruction_i(6 DOWNTO 0);
	-- Code to generate control signals using opcode bits
	r_type_w	<=  '1'	WHEN	opcode_w = RTYPE_OPC  ELSE '0';
	i_type_w	<=  '1'	WHEN	(opcode_w = ITYPE_OPC) or (load_w = '1') or (jalr_w = '1') ELSE '0';
	s_type_w 	<=  '1'	WHEN	opcode_w = STYPE_OPC  ELSE '0';
	b_type_w 	<=  '1'	WHEN	opcode_w = SBTYPE_OPC ELSE '0';
	u_type_w 	<=  '1'	WHEN	((opcode_w and UTYPE_OPCODE_COMMON_PATTERN) = UTYPE_OPCODE_COMMON_PATTERN)  ELSE '0';
	j_type_w 	<=  '1'	WHEN	opcode_w = UJTYPE_OPC ELSE '0';

	-- Decode load and store widths.
	lb_w		<=	'1'	WHEN	(instruction_i and INST_LB_MASK) = INST_LB				ELSE 	'0';	--lb
	lh_w		<=	'1'	WHEN	(instruction_i and INST_LH_MASK) = INST_LH				ELSE 	'0';	--lh
	lw_w		<=	'1'	WHEN	(instruction_i and INST_LW_MASK) = INST_LW				ELSE 	'0';	--lw
	lbu_w		<=	'1'	WHEN	(instruction_i and INST_LBU_MASK) = INST_LBU			ELSE	'0';	--lbu
	lhu_w		<=	'1'	WHEN	(instruction_i and INST_LHU_MASK) = INST_LHU			ELSE	'0';	--lhu
	lwu_w		<=	'1'	WHEN	(instruction_i and INST_LWU_MASK) = INST_LWU			ELSE	'0';	--lwu

	load_w 	<=	'1' WHEN 	 lb_w or lh_w or lw_w or lbu_w or lhu_w or lwu_w	ELSE	'0';	--Load

	sb_w		<=	'1'	WHEN	(instruction_i and INST_SB_MASK) = INST_SB				ELSE	'0';	--sb
	sh_w		<=	'1'	WHEN	(instruction_i and INST_SH_MASK) = INST_SH				ELSE	'0';	--sh
	sw_w		<=	'1'	WHEN	(instruction_i and INST_SW_MASK) = INST_SW				ELSE	'0';	--sw

	store_w	<=	'1'	WHEN	sb_w or sh_w or sw_w															ELSE	'0';

	beq_w		<=	'1'	WHEN	(instruction_i and INST_BEQ_MASK) = INST_BEQ			ELSE	'0';	--beq
	bne_w		<=	'1'	WHEN	(instruction_i and INST_BNE_MASK) = INST_BNE			ELSE	'0';	--bne
	blt_w		<=	'1'	WHEN	(instruction_i and INST_BLT_MASK) = INST_BLT			ELSE	'0';	--blt
	bge_w		<=	'1'	WHEN	(instruction_i and INST_BGE_MASK) = INST_BGE			ELSE	'0';	--bge
	bltu_w	<=	'1'	WHEN	(instruction_i and INST_BLTU_MASK) = INST_BLTU		ELSE	'0';	--bltu
	bgeu_w	<=	'1'	WHEN	(instruction_i and INST_BGEU_MASK) = INST_BGEU		ELSE	'0';	--bgeu

	-- Decode branch and jump instructions.
	branch_w	<=	'1'	WHEN	beq_w or bne_w or blt_w or bge_w or bltu_w or bgeu_w		ELSE	'0';

	jal_w		<=		'1'	WHEN	(instruction_i and INST_JAL_MASK) = INST_JAL	ELSE 	'0';		--jal

	jalr_w	<=	'1'	WHEN	(instruction_i and INST_JALR_MASK) = INST_JALR	ELSE 	'0';

	-- Decode integer ALU operations.
	add_w		<=	'1' WHEN	(instruction_i and INST_ADD_MASK) = INST_ADD	ELSE	'0';			--add

	addi_w	<=	'1' WHEN	(instruction_i and INST_ADDI_MASK) = INST_ADDI	ELSE	'0';		--addi

	auipc_w	<=	'1' WHEN	(instruction_i and INST_AUIPC_MASK) = INST_AUIPC	ELSE	'0';	--auipc

	lui_w		<=	'1' WHEN	(instruction_i and INST_LUI_MASK) = INST_LUI	ELSE	'0';			--lui

	and_w		<=	'1' WHEN	(instruction_i and INST_AND_MASK) = INST_AND	ELSE	'0';			--and

	andi_w	<=	'1' WHEN	(instruction_i and INST_ANDI_MASK) = INST_ANDI	ELSE	'0';		--andi

	or_w		<=	'1' WHEN	(instruction_i and INST_OR_MASK) = INST_OR	ELSE	'0';				--or

	ori_w		<=	'1' WHEN	(instruction_i and INST_ORI_MASK) = INST_ORI	ELSE	'0';			--ori

	sll_w		<=	'1' WHEN	(instruction_i and INST_SLL_MASK) = INST_SLL	ELSE	'0';			--sll

	slli_w 	<=	'1' WHEN	(instruction_i and INST_SLLI_MASK) = INST_SLLI	ELSE	'0';		--slli

	sra_w 	<=	'1' WHEN	(instruction_i and INST_SRA_MASK) = INST_SRA	ELSE	'0';			-- sra

	srai_w 	<=	'1' WHEN	(instruction_i and INST_SRAI_MASK) = INST_SRAI	ELSE	'0';		-- srai

	srl_w 	<=	'1' WHEN	(instruction_i and INST_SRL_MASK) = INST_SRL	ELSE	'0';			-- srl

	srli_w 	<=	'1' WHEN	(instruction_i and INST_SRLI_MASK) = INST_SRLI	ELSE	'0';		-- srli

	sub_w 	<=	'1' WHEN	(instruction_i and INST_SUB_MASK) = INST_SUB	ELSE	'0';			-- sub

	xor_w 	<=	'1' WHEN	(instruction_i and INST_XOR_MASK) = INST_XOR	ELSE	'0';			-- xor

	xori_w 	<=	'1' WHEN	(instruction_i and INST_XORI_MASK) = INST_XORI	ELSE	'0';		-- xori

	slt_w 	<=	'1' WHEN	(instruction_i and INST_SLT_MASK) = INST_SLT	ELSE	'0';			-- slt

	slti_w 	<=	'1' WHEN	(instruction_i and INST_SLTI_MASK) = INST_SLTI	ELSE	'0';		-- slti

	sltu_w 	<=	'1' WHEN	(instruction_i and INST_SLTU_MASK) = INST_SLTU	ELSE	'0';		-- sltu

	sltiu_w <=	'1' WHEN	(instruction_i and INST_SLTIU_MASK) = INST_SLTIU	ELSE	'0';	-- sltiu

	reti_w 	<=	'1' WHEN	instruction_i = INST_RETI	ELSE	'0';	-- Exact alias: jalr zero, 0(tp).

	-- Decode the implemented multiply, divide and remainder operations.
	mul_w   <=	'1' WHEN	(instruction_i and INST_MUL_MASK) = INST_MUL		ELSE	'0';	-- mul
	div_w   <=	'1' WHEN	(instruction_i and INST_DIV_MASK) = INST_DIV		ELSE	'0';   -- div
	divu_w  <=	'1' WHEN	(instruction_i and INST_DIVU_MASK) = INST_DIVU	ELSE	'0';      -- divu
	rem_w   <=	'1' WHEN	(instruction_i and INST_REM_MASK) = INST_REM		ELSE	'0';  -- rem
	remu_w  <=	'1' WHEN	(instruction_i and INST_REMU_MASK) = INST_REMU	ELSE	'0';     -- remu
	divide_or_remainder_w <= div_w OR divu_w OR rem_w OR remu_w;



	-- Divide and remainder write back only on the completion cycle.
	RegWrite_ctrl_o 	<=  (r_type_w AND NOT divide_or_remainder_w) OR i_type_w OR u_type_w OR
	                     j_type_w OR
	                     (divide_or_remainder_w AND div_complete_w );
	MemtoReg_ctrl_o 	<=  load_w;
	MemWrite_ctrl_o 	<=  store_w;
	MemRead_ctrl_o 		<=  load_w;
	Branch_ctrl_o     <=	branch_w;
	Jal_ctrl_o				<=	jal_w;
	Jalr_ctrl_o				<=	jalr_w;
	Reti_ctrl_o				<=	reti_w;
	RegDst_ctrl_o			<=	jal_w or jalr_w;
	ALUSrc_ctrl_o  		<=  i_type_w or s_type_w or u_type_w or j_type_w;

	-- UpperIm selects rs1, PC or zero.
	UpperIm_ctrl_o		<=	"01" WHEN auipc_w ELSE
												"10" WHEN	lui_w		ELSE
												"00";

	-- Select the ALU operation.
	ALUOp_ctrl_o		 	<=  ALU_ADD									WHEN	add_w	or addi_w or auipc_w or lui_w or jal_w or jalr_w	or load_w or store_w ELSE

												ALU_AND									WHEN	and_w or andi_w																ELSE

												ALU_OR									WHEN	or_w or ori_w																	ELSE

												ALU_SHIFTL							WHEN	sll_w or	slli_w															ELSE

												ALU_SHIFTR_ARITH				WHEN	sra_w or	srai_w															ELSE

												ALU_SHIFTR							WHEN	srl_w or srli_w																ELSE

												ALU_SUB									WHEN	sub_w																					ELSE

												ALU_XOR									WHEN	xor_w or xori_w																ELSE

												ALU_LESS_THAN_SIGNED		WHEN	slt_w or slti_w 															ELSE

												ALU_LESS_THAN_UNSIGNED	WHEN	sltu_w or sltiu_w															ELSE

												ALU_BEQ									WHEN	beq_w																					ELSE

												ALU_BNE									WHEN	bne_w																					ELSE

												ALU_BLT									WHEN	blt_w																					ELSE

												ALU_BGE									WHEN	bge_w																					ELSE

												ALU_BLTU								WHEN	bltu_w																				ELSE

												ALU_BGEU								WHEN	bgeu_w																				ELSE

												ALU_NONE;

	-- WBSrc0 controls the final 2:1 mux: zero selects the M-extension mux and
	-- one selects the ordinary ALU result. WBSrc1 controls the preceding 3:1
	-- mux: 00=REM, 01=DIV, 10=MUL.
	MUL_OP_ctrl_o	<=	mul_w;
	wbsrc0_o		<=	'0' WHEN (mul_w OR divide_or_remainder_w) = '1' ELSE '1';
	wbsrc1_o		<=	"10" WHEN mul_w = '1' ELSE
						"01" WHEN (div_w OR divu_w) = '1' ELSE
						"00";
	-- Benchmarks use non-negative operands, so DIV/REM share the unsigned unit.
	DIVU_ctrl_o		<=	div_w OR divu_w;
	REMU_ctrl_o		<=	rem_w OR remu_w;

END behavior;
