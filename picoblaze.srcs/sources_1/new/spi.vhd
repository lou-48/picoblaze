library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity spi is
    generic(
        data_length : INTEGER := 8;
        DVSR: integer := 100; -- baud rate divisor  -- DVSR = 100M/(2*baud rate)
        DVSR_BIT: integer := 8 -- # bits of DVSR
    ); 
    port(
        clk, reset : in std_logic;
        w_strobe, r_strobe : in std_logic;
        out_port, port_id : in std_logic_vector(7 downto 0);
        in_port : out std_logic_vector(7 downto 0);
        miso : in std_logic;                              --master in slave out
        sclk : out std_logic;                             --spi clock
        ss_n : out std_logic;                             --slave select
        mosi : out std_logic                             --master out slave insignal
    );
end spi;

architecture Behavioral of spi is
type spi_state is (idle, data);
signal state_reg, state_next : spi_state;
signal spi_tick : std_logic;
signal busy : std_logic;
signal spi_rw_reg, spi_rw_next, spi_clk_reg, spi_clk_next : std_logic;
signal r_data_reg, r_data_next, w_data_reg, w_data_next : std_logic_vector(data_length-1 downto 0);
signal counter_reg, counter_next : integer range 0 to data_length*2+1;
signal byte_cnt_reg, byte_cnt_next : integer range 0 to 255;

-- Periph registers
signal config_r : std_logic_vector(7 downto 0);
signal len_r : std_logic_vector(7 downto 0);

-- fifo tx
signal tx_wr, tx_rd : std_logic;
signal tx_r_data : std_logic_vector(data_length-1 downto 0);
signal tx_empty, tx_full_sig : std_logic;
    
-- fifo rx
signal rx_wr, rx_rd : std_logic;
signal rx_r_data : std_logic_vector(data_length-1 downto 0);
signal rx_empty_sig, rx_full : std_logic;

signal tx_rd_reg, tx_rd_next, rx_wr_reg, rx_wr_next : std_logic;
-- Capture fin d'octet reçu
signal rx_byte_done : std_logic;

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

component fifo is
    generic(
        B: natural := 8; -- number of bits
        W: natural := 4 -- number of address bits
    );
    port (
    clk, reset: in std_logic;
    rd, wr: in std_logic;
    w_data: in std_logic_vector(B-1 downto 0);
    empty, full : out std_logic;
    r_data: out std_logic_vector(B-1 downto 0)
    );
end component;

begin
baud_gen_unit: mod_m_counter
    generic map(M=>DVSR , N=>DVSR_BIT)
    port map(clk=>clk, reset=>reset, q=>open , max_tick=>spi_tick);
    
fifo_tx: fifo
    generic map(
        B => 8, -- number of bits
        W => 5 -- number of address bits
    )
    port map(
        clk => clk,
        reset => reset,
        rd => tx_rd,
        wr => tx_wr,
        w_data => out_port,
        empty => tx_empty,
        full => tx_full_sig,
        r_data => tx_r_data
    );
tx_wr <= w_strobe when (port_id = x"0C") else '0';

fifo_rx: fifo
    generic map(
        B => 8, -- number of bits
        W => 5 -- number of address bits
    )
    port map(
        clk => clk,
        reset => reset,
        rd => rx_rd,
        wr => rx_wr,
        w_data => r_data_reg,
        empty => rx_empty_sig,
        full => rx_full,
        r_data => rx_r_data
    );
rx_rd <= r_strobe when (port_id = x"09") else '0';

in_port <= rx_r_data when port_id = x"09" else
           "00000" & rx_empty_sig & tx_full_sig & busy;
           

tx_rd <= tx_rd_reg and spi_tick;
rx_wr <= rx_wr_reg and spi_tick;

process(clk, reset)
begin
    if reset = '1' then
        config_r <= (others => '0');
    elsif rising_edge(clk) then    
        if w_strobe = '1' then
            case port_id is
                when x"0A" => config_r <= out_port; -- spi0 config
                when x"0B" => len_r <= out_port; -- spi0 len frame
                when others => null;
            end case;
        end if;
        if state_reg = data then -- Auto clear start after start of SPI transaction
            config_r(0) <= '0';
        end if;
    end if;
end process;

sclk <= spi_clk_reg;
process(spi_tick, reset)
begin
    if reset = '1' then
        state_reg <= idle;
        counter_reg <= 0;
        byte_cnt_reg <= 0;
        spi_rw_reg <= '0';
        spi_clk_reg <= '0';
        r_data_reg <= (others => '0');
        w_data_reg <= (others => '0');
        tx_rd_reg <= '0';
        rx_wr_reg <= '0';        
    elsif rising_edge(spi_tick) then
        state_reg <= state_next;
        counter_reg <= counter_next;
        byte_cnt_reg <= byte_cnt_next;
        spi_rw_reg <= spi_rw_next;
        spi_clk_reg <= spi_clk_next;
        r_data_reg <= r_data_next;
        w_data_reg <= w_data_next;
        tx_rd_reg <= tx_rd_next;
        rx_wr_reg <= rx_wr_next;
    end if;
end process;

process(state_reg, counter_reg, spi_rw_reg, r_data_reg, spi_clk_reg, w_data_reg, miso, config_r, len_r, byte_cnt_reg, tx_r_data)
variable frame_len : integer range 0 to 255;
begin
    state_next <= state_reg;
    counter_next <= counter_reg;
    byte_cnt_next <= byte_cnt_reg;
    spi_rw_next <= spi_rw_reg;
    spi_clk_next <= spi_clk_reg;
    r_data_next <= r_data_reg;
    w_data_next <= w_data_reg;
    tx_rd_next <= '0';
    rx_wr_next <= '0';
    
    ss_n <= '1';
    busy <= '0';
    case state_reg is
        when idle => 
            spi_clk_next <= config_r(1);
            counter_next <= 0;
            byte_cnt_next <= 0;
            mosi <= 'Z';
            if config_r(0) = '1' then -- Start SPI transaction
                frame_len := to_integer(unsigned(len_r));
                if frame_len = 0 then frame_len := 1; end if;
                if frame_len > 32 then frame_len := 32; end if;
                state_next <= data;
                tx_rd_next <= '1';
                w_data_next <= tx_r_data;
                spi_rw_next <= config_r(2);
                busy <= '1';
            end if;
        when data =>
            busy <= '1';
            ss_n <= '0';
            counter_next <= counter_reg + 1;
            spi_rw_next <= not spi_rw_reg;
            
            if counter_reg < data_length*2 then
                spi_clk_next <= not spi_clk_reg;            
            end if;
            
            if spi_rw_reg = '0' and counter_reg < data_length*2 then -- write
                mosi <= w_data_reg(data_length-1);
                w_data_next <= w_data_reg(data_length-2 downto 0) & '0';
            elsif spi_rw_reg = '1' and counter_reg > 0 and counter_reg < data_length*2+1 then -- read
                r_data_next <= r_data_reg(data_length-2 downto 0) & miso;
            end if;
                        
            if counter_reg = data_length*2+1 then
                rx_wr_next  <= '1';
                counter_next <= 0;
                if byte_cnt_reg = frame_len - 1 then
                    state_next <= idle;
                    byte_cnt_next <= 0;
                    ss_n <= '1';
                else
                    byte_cnt_next <= byte_cnt_reg + 1;
                    tx_rd_next <= '1';
                    w_data_next <= tx_r_data;
                    spi_rw_next <= config_r(2);
                end if;
            end if;
    end case;
end process;

end Behavioral;
