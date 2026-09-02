LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Unsigned 16x16 multiplier, built from four 8x8 products.
-- Only the low 16 bits of each operand are multiplied.
ENTITY Multiplier_16bit IS
    GENERIC (
        DATA_BUS_WIDTH : integer := 32
    );
    PORT (
        Ain       : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        Bin       : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        -- MULOP = '1' enables multiplication.
        MULOP     : IN  STD_LOGIC;
        MUL_res_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
    );
END Multiplier_16bit;

ARCHITECTURE combinational OF Multiplier_16bit IS

BEGIN

    -- Four 8x8 products form the complete 16x16 result.
    -- Cross-products are aligned at bit 8 and summed with an extra carry bit
    -- before the final 32-bit addition.
    MULTIPLY_COMBINATIONAL_P : PROCESS(MULOP, Ain, Bin)
        variable A_low_v  : STD_LOGIC_VECTOR(7  downto 0);
        variable A_high_v : STD_LOGIC_VECTOR(7  downto 0);
        variable B_low_v  : STD_LOGIC_VECTOR(7  downto 0);
        variable B_high_v : STD_LOGIC_VECTOR(7  downto 0);
        variable low_low_product_v   : STD_LOGIC_VECTOR(15 downto 0);
        variable low_high_product_v  : STD_LOGIC_VECTOR(15 downto 0);
        variable high_low_product_v  : STD_LOGIC_VECTOR(15 downto 0);
        variable high_high_product_v : STD_LOGIC_VECTOR(15 downto 0);
        variable cross_products_sum_v: STD_LOGIC_VECTOR(16 downto 0);
    BEGIN
        IF MULOP = '1' THEN
            -- Split both operands into 8-bit halves.
            A_low_v  := Ain(7  downto 0);
            A_high_v := Ain(15 downto 8);
            B_low_v  := Bin(7  downto 0);
            B_high_v := Bin(15 downto 8);

            -- Compute the four 8x8 partial products.
            low_low_product_v   := A_low_v  * B_low_v;
            low_high_product_v  := A_low_v  * B_high_v;
            high_low_product_v  := A_high_v * B_low_v;
            high_high_product_v := A_high_v * B_high_v;

            -- Preserve the carry from the cross-product sum.
            cross_products_sum_v :=
                ('0' & low_high_product_v) + ('0' & high_low_product_v);

            -- Align and combine the partial products.
            MUL_res_o <=
                ("0000000000000000" & low_low_product_v) +
                ("0000000" & cross_products_sum_v & "00000000") +
                (high_high_product_v & "0000000000000000");
        ELSE
            -- Clear the output when multiplication is disabled.
            MUL_res_o <= (others => '0');
        END IF;
    END PROCESS;

END combinational;
