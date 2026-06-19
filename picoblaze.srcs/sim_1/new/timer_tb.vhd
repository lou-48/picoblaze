library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity timer_tb is
end timer_tb;

architecture Behavioral of timer_tb is
signal clk, reset:  std_logic := '0';
signal config_r :  std_logic_vector(7 downto 0);
signal preload_r :  std_logic_vector(31 downto 0);
signal counter_r :  std_logic_vector(31 downto 0);
signal interrupt_flag :  std_logic;

component timer is
    port(
        clk, reset: in std_logic;
        config_r : in std_logic_vector(7 downto 0);
        preload_r : in std_logic_vector(31 downto 0);
        counter_r : out std_logic_vector(31 downto 0);
        interrupt_flag : out std_logic
    );
end component;
begin
uut : timer
    port map(clk => clk, reset => reset, config_r => config_r, preload_r => preload_r, counter_r => counter_r, interrupt_flag => interrupt_flag);

config_r <= x"23";
preload_r <= x"00000001";

process
begin
    clk <= not clk;
    wait for 5ns;
end process;

process
begin
    reset <= '1';
    wait for 50ns;
    reset <= '0';
    wait;
end process;
end Behavioral;
