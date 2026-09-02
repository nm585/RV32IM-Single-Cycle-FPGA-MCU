LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Unsigned 32-bit divider, one quotient bit per clock.
-- A request completes after 32 DIVCLK cycles and remains valid until restart.
-- Division by zero returns all ones and preserves the dividend as remainder.
ENTITY Divider_32bit IS
    PORT (
        DIVCLK   : IN  STD_LOGIC;
        DIVRST   : IN  STD_LOGIC;
        DIVENA   : IN  STD_LOGIC;
        Dividend : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
        Divisor  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
        DIVBUSY  : OUT STD_LOGIC;
        Residue  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        Quotient : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END Divider_32bit;

ARCHITECTURE rtl OF Divider_32bit IS
    -- Combined remainder and dividend shift register.
    SIGNAL dividend_shift_q : STD_LOGIC_VECTOR(63 DOWNTO 0);
    SIGNAL divisor_q        : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL quotient_shift_q : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL original_dividend_q : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL iteration_count_q    : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL divide_by_zero_q : STD_LOGIC;
    SIGNAL divbusy_q        : STD_LOGIC;
    SIGNAL quotient_q       : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL residue_q        : STD_LOGIC_VECTOR(31 DOWNTO 0);
BEGIN
    -- Each DIVCLK edge shifts in one dividend bit.
    -- The partial remainder is compared with the divisor and conditionally
    -- reduced, producing one quotient bit per iteration.
    DIVIDE_ITERATION_P : PROCESS(DIVCLK, DIVRST)
		VARIABLE shifted_dividend_v : STD_LOGIC_VECTOR(63 DOWNTO 0);
		VARIABLE partial_remainder_v: STD_LOGIC_VECTOR(31 DOWNTO 0);
		VARIABLE quotient_v         : STD_LOGIC_VECTOR(31 DOWNTO 0);
    BEGIN
        IF DIVRST = '1' THEN
            dividend_shift_q <= (OTHERS => '0');
            divisor_q        <= (OTHERS => '0');
            quotient_shift_q <= (OTHERS => '0');
			original_dividend_q <= (OTHERS => '0');
			iteration_count_q    <= (OTHERS => '0');
            divide_by_zero_q <= '0';
            divbusy_q        <= '0';
            quotient_q       <= (OTHERS => '0');
            residue_q        <= (OTHERS => '0');
        ELSIF rising_edge(DIVCLK) THEN
            IF divbusy_q = '0' THEN
                IF DIVENA = '1' THEN
                    -- Latch both operands at the start of the operation.
                    dividend_shift_q <= x"00000000" & Dividend;
                    divisor_q        <= Divisor;
                    quotient_shift_q <= (OTHERS => '0');
					original_dividend_q <= Dividend;
					iteration_count_q    <= (OTHERS => '0');
                    IF Divisor = x"00000000" THEN
                        divide_by_zero_q <= '1';
                    ELSE
                        divide_by_zero_q <= '0';
                    END IF;
                    divbusy_q        <= '1';
                END IF;
            ELSE
                -- Shift, compare and append the next quotient bit.
				shifted_dividend_v  := dividend_shift_q(62 DOWNTO 0) & '0';
				partial_remainder_v := shifted_dividend_v(63 DOWNTO 32);
				quotient_v          := quotient_shift_q(30 DOWNTO 0) & '0';

				IF divide_by_zero_q = '0' AND partial_remainder_v >= divisor_q THEN
					partial_remainder_v := partial_remainder_v - divisor_q;
					quotient_v(0) := '1';
                ELSE
                    quotient_v(0) := '0';
                END IF;

				shifted_dividend_v(63 DOWNTO 32) := partial_remainder_v;
				dividend_shift_q <= shifted_dividend_v;
                quotient_shift_q <= quotient_v;

				IF iteration_count_q = 31 THEN
                    -- Publish both results with the final iteration.
                    divbusy_q <= '0';

                    IF divide_by_zero_q = '1' THEN
                        quotient_q  <= (OTHERS => '1');
						residue_q  <= original_dividend_q;
                    ELSE
                        quotient_q  <= quotient_v;
						residue_q  <= partial_remainder_v;
                    END IF;
                ELSE
					iteration_count_q <= iteration_count_q + 1;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- Drive the registered results.
    DIVBUSY  <= divbusy_q;
    Residue  <= residue_q;
    Quotient <= quotient_q;
END rtl;
