library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity seg7 is
    port (
        clk, reset : in std_logic;
        value : in std_logic_vector(13 downto 0);
        dp : out std_logic;
        an : out std_logic_vector(3 downto 0);
        seg : out std_logic_vector(6 downto 0)
    );
end seg7;

architecture Behavioral of seg7 is
signal counter : std_logic_vector(18 downto 0) := (others => '0');
signal sel : std_logic_vector(1 downto 0) := (others => '0');
signal num : std_logic_vector(3 downto 0) := (others => '0');
signal bcd0, bcd1, bcd2, bcd3: std_logic_vector(3 downto 0);

component binary_to_bcd is
    generic(
        N: positive := 16;
        MAX_VAL : natural := 9999
    );
    port(
        clk, reset: in std_logic;
        binary_in: in std_logic_vector(N-1 downto 0);
        bcd0, bcd1, bcd2, bcd3: out std_logic_vector(3 downto 0)
    );
end component;

begin
bin2bcd : binary_to_bcd
    generic map(N => 14, MAX_VAL => 9999)
    port map(clk => clk, reset => reset, binary_in => value, bcd0 => bcd0, bcd1 => bcd1, bcd2 => bcd2, bcd3 => bcd3);

process(clk)
begin
    if clk'event and clk = '1' then
        counter <= counter + 1;
    end if;
end process;

process(counter(18))
begin
    if counter(18)'event and counter(18) = '1' then
        sel <= sel + 1;
    end if;
end process;

process(sel, bcd0, bcd1, bcd2, bcd3)
begin
    case sel is
        when "00" => an <= "1110";
                     num <= bcd0;
        when "01" => an <= "1101";
                     num <= bcd1;
        when "10" => an <= "1011";
                     num <= bcd2;
        when "11" => an <= "0111";
                     num <= bcd3;
        when others => null;
    end case;
end process;

process(num)
begin
    case num is
        when "0000" => seg <= "1000000"; -- 0
        when "0001" => seg <= "1111001"; -- 1
        when "0010" => seg <= "0100100"; -- 2
        when "0011" => seg <= "0110000"; -- 3
        when "0100" => seg <= "0011001"; -- 4
        when "0101" => seg <= "0010010"; -- 5
        when "0110" => seg <= "0000010"; -- 6
        when "0111" => seg <= "1111000"; -- 7
        when "1000" => seg <= "0000000"; -- 8
        when others => seg <= "0010000"; -- 9
    end case;
end process;
dp <= '1'; -- OFF

end Behavioral;
