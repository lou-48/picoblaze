library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity uart is
    generic(
    -- Default setting :
    -- 19200 baud, 8 data bits , 1 stop bit, 2^2 FIFO
    DBIT : integer := 8;    -- # data bits
    SB_TICK: integer := 16; -- # ticks for stop bits, 16/24/32
                                -- for 1/1.5/2 stop bits
    DVSR: integer := 163;   -- baud rate divisor
                                -- DVSR = 50M/(16*baud rate)
    DVSR_BIT: integer := 8; -- # bits of DVSR
    FIFO_W: integer := 2);  -- # addr bits of FIFO
                                -- # words in FIFO=2^FIFO-W
    port(
        clk, reset: in std_logic;
        rd_uart , wr_uart : in std_logic;
        rx: in std_logic;
        w_data: in std_logic_vector(7 downto 0);
        tx_full, rx_empty: out std_logic;
        r_data: out std_logic_vector(7 downto 0);
        tx: out std_logic); 
end uart;

architecture Behavioral of uart is
signal rx_done_tick : std_logic;
signal tick : std_logic;
signal tx_fifo_out : std_logic_vector(7 downto 0);
signal rx_data_out : std_logic_vector(7 downto 0);
signal tx_empty, tx_fifo_not_empty : std_logic;
signal tx_done_tick : std_logic;

-- Components
component uart_tx is
    generic(
        DBIT : integer := 8 ;       -- # data bits
        SB_TICK: integer := 16);    -- # ticks for stop bits
    port(
        clk, reset: in std_logic;
        tx_start : in std_logic;
        s_tick: in std_logic ;
        din: in std_logic_vector(7 downto 0);
        tx_done_tick: out std_logic;
        tx: out std_logic); 
end component;

component uart_rx is
    generic(
        DBIT : integer := 8;        -- # data bits
        SB_TICK: integer := 16);    -- # ticks for stop bits
    port(
        clk, reset: in std_logic;
        rx: in std_logic;
        s_tick: in std_logic;
        rx_done_tick: out std_logic;
        dout: out std_logic_vector(7 downto 0)); 
end component;

component fifo is
    generic(
        B: natural := 8;    -- number of bits
        W: natural := 4);   -- number of address bits
    port(
        clk, reset: in std_logic;
        rd, wr: in std_logic;
        w_data: in std_logic_vector(B-1 downto 0);
        empty, full : out std_logic;
        r_data: out std_logic_vector(B-1 downto 0));
end component;

component mod_m_counter is
    generic(
        N: integer := 4;    -- number of bits
        M: integer := 10);  -- mod4
    port(
        clk, reset: in std_logic;
        max_tick: out std_logic;
        q: out std_logic_vector (N-1 downto 0)); 
end component;

begin
baud_gen_unit: mod_m_counter
    generic map(M=>DVSR , N=>DVSR_BIT)
    port map(clk=>clk, reset=>reset, q=>open , max_tick=>tick);

uart_rx_unit: uart_rx
    generic map(DBIT=>DBIT, SB_TICK=>SB_TICK)
    port map(clk=>clk, reset=>reset, rx=>rx, s_tick => tick, rx_done_tick => rx_done_tick, dout=>rx_data_out);
    
fifo_rx_unit: fifo
    generic map(B=>DBIT , W=>FIFO_W)
    port map(clk=>clk, reset=>reset , rd=>rd_uart, wr=>rx_done_tick, w_data=>rx_data_out,
        empty=>rx_empty, full=>open, r_data=>r_data);
fifo_tx_unit: fifo
    generic map(B=>DBIT , W=>FIFO_W)
    port map(clk=>clk, reset=>reset, rd=>tx_done_tick, wr=>wr_uart, w_data=>w_data, empty=>tx_empty,
        full=>tx_full, r_data=>tx_fifo_out);
uart_tx_unit : uart_tx
    generic map(DBIT => DBIT, SB_TICK => SB_TICK)
    port map(clk=>clk, reset=>reset, tx_start=>tx_fifo_not_empty, s_tick=>tick, din=>tx_fifo_out,
        tx_done_tick=> tx_done_tick, tx=>tx);

tx_fifo_not_empty <= not tx_empty; 


end Behavioral;
