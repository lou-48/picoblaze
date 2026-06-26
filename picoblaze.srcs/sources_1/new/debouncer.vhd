library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity debouncer is
    generic(
        delay : integer := 1000000);
    port(
        clk : in std_logic;
        button : in std_logic;
        debounce : out std_logic);
end debouncer;

architecture Behavioral of debouncer is
signal count : integer range 0 to delay := delay;

begin
process(clk)
begin
    if rising_edge(clk) then
        if button = '1' then
            if count = 0 then
                debounce <= '1';
            else
                count <= count - 1;
            end if;
        else
            debounce <= '0';
            count <= delay;
        end if;
    end if;
end process;    

end Behavioral;
