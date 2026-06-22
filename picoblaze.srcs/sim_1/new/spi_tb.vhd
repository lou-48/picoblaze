library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity spi_tb is
end spi_tb;

architecture Behavioral of spi_tb is
signal clk, reset : std_logic := '0';
signal enable : std_logic;                           --initiate communication
signal cpol : std_logic;  							 --clock polarity mode
signal cpha : std_logic;  							 --clock phase mode
signal miso : std_logic;                             --master in slave out
signal sclk : std_logic;                             --spi clock
signal ss_n : std_logic;                             --slave select
signal mosi : std_logic;                             --master out slave in
signal busy : std_logic;                             --master busy signal
signal tx : std_logic_vector(7 downto 0);  --data to transmit
signal rx : std_logic_vector(7 downto 0); --data received
        
component spi is
    generic(
        data_length : INTEGER := 8;
        DVSR: integer := 100; -- baud rate divisor  -- DVSR = 100M/baud rate
        DVSR_BIT: integer := 8 -- # bits of DVSR
    ); 
    port(
        clk, reset : in std_logic;
        enable : in std_logic;                             --initiate communication
        cpol : in std_logic;  									--clock polarity mode
        cpha : in std_logic;  									--clock phase mode
        miso : in std_logic;                             --master in slave out
        sclk : out std_logic;                             --spi clock
        ss_n : out std_logic;                             --slave select
        mosi : out std_logic;                             --master out slave in
        busy : out std_logic;                             --master busy signal
        tx : in std_logic_vector(data_length-1 downto 0);  --data to transmit
        rx : out std_logic_vector(data_length-1 downto 0) --data received
    );
end component;
begin
uut : spi 
    generic map(
        data_length => 8,
        DVSR => 100, -- baud rate divisor  -- DVSR = 100M/baud rate
        DVSR_BIT => 8 -- # bits of DVSR
    )
    port map(
        clk => clk,
        reset => reset,
        enable => enable,                             --initiate communication
        cpol => cpol, 									--clock polarity mode
        cpha => cpha, 									--clock phase mode
        miso => miso,                             --master in slave out
        sclk => sclk,                            --spi clock
        ss_n => ss_n,                             --slave select
        mosi => mosi,                            --master out slave in
        busy => busy,                             --master busy signal
        tx => tx,  --data to transmit
        rx => rx --data received
    );

process
begin
    clk <= not clk;
    wait for 5ns;
end process;

miso <= mosi;
process
begin
    reset <= '1';
    wait for 50ns;
    reset <= '0';
    tx <= x"A2";
    cpol <= '0';
    cpha <= '1';
    wait for 30ns;
    enable <= '1';
    wait;
end process;

end Behavioral;
