library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity picoblaze_top_tb is
end picoblaze_top_tb;

architecture Behavioral of picoblaze_top_tb is
signal clk :  std_logic := '0';
signal btnC, btnU, btnL, btnR, btnD :  std_logic;
signal sw :  std_logic_vector(15 downto 0);
signal led :  std_logic_vector(15 downto 0);
signal dp : std_logic;
signal an : std_logic_vector(3 downto 0);
signal seg : std_logic_vector(6 downto 0);
signal rsRx :  std_logic;
signal rsTx :  std_logic;

component picoblaze_top is
    port(
        clk : in std_logic;
        btnC, btnU, btnL, btnR, btnD : in std_logic;
        sw : in std_logic_vector(15 downto 0);
        led : out std_logic_vector(15 downto 0);
        dp : out std_logic;
        an : out std_logic_vector(3 downto 0);
        seg : out std_logic_vector(6 downto 0);
        rsRx : in std_logic;
        rsTx : out std_logic
    );
end component;
begin
uut : picoblaze_top port map(clk => clk, btnC => btnC, btnU => btnU, btnL => btnL, btnR => btnR, btnD => btnD,
    sw => sw, led => led, dp => dp, an => an, seg => seg, rsRx => rsRx, rsTx => rsTx);
process
begin
    clk <= not clk;
    wait for 5ns;
end process;
process
begin
    btnC <= '1';
    wait for 50ns;
    btnC <= '0';
    wait for 1000ms;
    wait for 50ns;
    btnC <= '1';
    wait for 50ns;
    btnC <= '0';
    wait;
end process;

sw <= x"8000";


end Behavioral;
