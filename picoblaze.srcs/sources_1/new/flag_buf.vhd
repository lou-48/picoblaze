library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity flag_buf is
    port(
        clk, reset: in std_logic;
        clr_flag : in std_logic;
        D : in std_logic;
        Q : out std_logic
    );
end flag_buf;

architecture Behavioral of flag_buf is
signal flag_reg, flag_next : std_logic; 
begin
-- FF & register
process(clk, reset)
begin
    if reset = '1' then
        flag_reg <= '0';
    elsif (rising_edge(clk)) then
        flag_reg <= flag_next;
    end if;
end process;

-- state 1ogic
process(flag_reg, clr_flag, D)
begin
    if (clr_flag = '1') then
        flag_next <= '0';
    else
        flag_next <= flag_reg or D;
    end if;
end process;

-- output logic
Q <= flag_reg;
end Behavioral;
