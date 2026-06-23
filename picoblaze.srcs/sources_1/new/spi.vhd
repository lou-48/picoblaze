library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity spi is
    generic(
        data_length : INTEGER := 8;
        DVSR: integer := 100; -- baud rate divisor  -- DVSR = 100M/(2*baud rate)
        DVSR_BIT: integer := 8 -- # bits of DVSR
    ); 
    port(
        clk, reset : in std_logic;
        enable : in std_logic;                            --initiate communication
        cpol : in std_logic;  							  --clock polarity mode
        cpha : in std_logic;  						      --clock phase mode
        miso : in std_logic;                              --master in slave out
        sclk : out std_logic;                             --spi clock
        ss_n : out std_logic;                             --slave select
        mosi : out std_logic;                             --master out slave in
        busy : out std_logic;                             --master busy signal
        tx : in std_logic_vector(data_length-1 downto 0);  --data to transmit
        rx : out std_logic_vector(data_length-1 downto 0) --data received
    );
end spi;

architecture Behavioral of spi is
type spi_state is (idle, data);
signal state_reg, state_next : spi_state;
signal spi_tick : std_logic;
signal spi_rw_reg, spi_rw_next, spi_clk_reg, spi_clk_next : std_logic;
signal r_data_reg, r_data_next, w_data_reg, w_data_next : std_logic_vector(data_length-1 downto 0);
signal counter_reg, counter_next : integer range 0 to data_length*2+1;

component mod_m_counter is
    generic(
        N: integer := 4; -- number of bits
        M: integer := 10 -- mod4
    );
    port (
        clk, reset: in std_logic;
        max_tick: out std_logic;
        q: out std_logic_vector (N-1 downto 0)
    ); 
end component;
begin
baud_gen_unit: mod_m_counter
    generic map(M=>DVSR , N=>DVSR_BIT)
    port map(clk=>clk, reset=>reset, q=>open , max_tick=>spi_tick);
    
sclk <= spi_clk_reg;
rx <= r_data_reg;
process(spi_tick, reset)
begin
    if reset = '1' then
        state_reg <= idle;
        counter_reg <= 0;
        spi_rw_reg <= '0';
        spi_clk_reg <= '0';
        r_data_reg <= (others => '0');
        w_data_reg <= (others => '0');
    elsif rising_edge(spi_tick) then
        state_reg <= state_next;
        counter_reg <= counter_next;
        spi_rw_reg <= spi_rw_next;
        spi_clk_reg <= spi_clk_next;
        r_data_reg <= r_data_next;
        w_data_reg <= w_data_next;
    end if;
end process;

process(state_reg, counter_reg, spi_rw_reg, tx, cpol, cpha, enable, r_data_reg, spi_clk_reg, w_data_reg, miso)
begin
    state_next <= state_reg;
    counter_next <= counter_reg;
    spi_rw_next <= spi_rw_reg;
    spi_clk_next <= spi_clk_reg;
    r_data_next <= r_data_reg;
    w_data_next <= w_data_reg;
    case state_reg is
        when idle => 
            spi_clk_next <= cpol;
            ss_n <= '1';
            counter_next <= 0;
            mosi <= 'Z';
            busy <= '0';
            if enable = '1' then
                state_next <= data;
                w_data_next <= tx;
                spi_rw_next <= cpha;
                busy <= '1';
            end if;
        when data =>
            counter_next <= counter_reg + 1;
            spi_rw_next <= not spi_rw_reg;
            
            if counter_reg = data_length*2+1 then
                ss_n <= '1';
                state_next <= idle;
                mosi <= 'Z';
                busy <= '0';
            else
                ss_n <= '0';
                busy <= '1';
            end if;
            
            if counter_reg < data_length*2 then
                spi_clk_next <= not spi_clk_reg;            
            end if;
            
            if spi_rw_reg = '0' and counter_reg < data_length*2 then -- write
                mosi <= w_data_reg(data_length-1);
                w_data_next <= w_data_reg(data_length-2 downto 0) & '0';
            elsif spi_rw_reg = '1' and counter_reg > 0 and counter_reg < data_length*2+1 then -- read
                r_data_next <= r_data_reg(data_length-2 downto 0) & miso;
            end if;
            
    end case;
end process;

end Behavioral;
