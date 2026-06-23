library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity picoblaze_top is
    port(
        clk : in std_logic;
        btnC, btnU, btnL, btnR, btnD : in std_logic;
        sw : in std_logic_vector(15 downto 0);
        led : out std_logic_vector(15 downto 0);
        --7seg
        dp : out std_logic;
        an : out std_logic_vector(3 downto 0);
        seg : out std_logic_vector(6 downto 0);
        -- UART
        rsRx : in std_logic;
        rsTx : out std_logic;
        -- SPI
        miso: in std_logic;
        mosi, sclk, ss_n : out std_logic
    );
end picoblaze_top;

architecture Behavioral of picoblaze_top is
-- Core
signal address : std_logic_vector(11 downto 0);
signal instruction : std_logic_vector(17 downto 0);
signal bram_enable : std_logic;
signal in_port : std_logic_vector(7 downto 0);
signal out_port : std_logic_vector(7 downto 0);
Signal port_id : std_logic_vector(7 downto 0);
Signal write_strobe : std_logic;
Signal k_write_strobe : std_logic;
Signal read_strobe : std_logic;
Signal interrupt : std_logic;
Signal interrupt_ack : std_logic;
Signal kcpsm6_sleep : std_logic;
Signal kcpsm6_reset : std_logic;
Signal rdl : std_logic;

Signal decode_port_id : std_logic_vector(7 downto 0);
Signal w_strobe : std_logic;

-- Debounce
signal btnC_db, btnU_db, btnL_db, btnR_db, btnD_db : std_logic;

-- Registers
signal en_o : std_logic_vector(6 downto 0);

-- Leds
signal led_reg : std_logic_vector(15 downto 0);

-- Uart
signal r_data : std_logic_vector(7 downto 0);
signal rd_uart, rx_not_empty, rx_empty : std_logic;
signal wr_uart, tx_full : std_logic;

-- 7seg
signal bin_7seg_reg : std_logic_vector(13 downto 0);

-- Interrupts
signal timer_int : std_logic;

-- Timer
signal tim0_counter : std_logic_vector(31 downto 0);

-- SPI
signal spi_tx, spi_rx : std_logic_vector(7 downto 0);
signal spi_config : std_logic_vector(2 downto 0);
signal spi_busy : std_logic;

-- Components
component kcpsm6 is
    generic(               hwbuild : std_logic_vector(7 downto 0) := X"00";
                  interrupt_vector : std_logic_vector(11 downto 0) := X"3FF";
           scratch_pad_memory_size : integer := 64);
    port (                 address : out std_logic_vector(11 downto 0);
                       instruction : in std_logic_vector(17 downto 0);
                       bram_enable : out std_logic;
                           in_port : in std_logic_vector(7 downto 0);
                          out_port : out std_logic_vector(7 downto 0);
                           port_id : out std_logic_vector(7 downto 0);
                      write_strobe : out std_logic;
                    k_write_strobe : out std_logic;
                       read_strobe : out std_logic;
                         interrupt : in std_logic;
                     interrupt_ack : out std_logic;
                             sleep : in std_logic;
                             reset : in std_logic;
                               clk : in std_logic);
end component;

component picoblaze_rom is
    generic(C_FAMILY : string := "S6";
        C_RAM_SIZE_KWORDS : integer := 1;
        C_JTAG_LOADER_ENABLE : integer := 0);
    Port (address : in std_logic_vector(11 downto 0);
        instruction : out std_logic_vector(17 downto 0);
        enable : in std_logic;
        rdl : out std_logic;                    
        clk : in std_logic);
end component;

component debouncer is
    generic(
        delay : integer := 1000000
    );
    port(
        clk : in std_logic;
        button : in std_logic;
        debounce : out std_logic
    );
end component;

component uart is
    generic(
    -- Default setting :
    -- 9600 baud, 8 data bits , 1 stop bit, 2^2 FIFO
    DBIT : integer := 8; -- # data bits
    SB_TICK: integer := 16; -- # ticks for stop bits, 16/24/32
                            -- for 1/1.5/2 stop bits
    DVSR: integer := 651; -- baud rate divisor
                          -- DVSR = 100M/(16*baud rate)
    DVSR_BIT: integer := 8; -- # bits of DVSR
    FIFO_W: integer := 2 -- # addr bits of FIFO
                         -- # words in FIFO=2^FIFO-W
    );
    port (
        clk, reset: in std_logic;
        rd_uart , wr_uart : in std_logic;
        rx: in std_logic;
        w_data: in std_logic_vector(7 downto 0);
        tx_full, rx_empty: out std_logic;
        r_data: out std_logic_vector(7 downto 0);
        tx: out std_logic
    ); 
end component;

component seg7 is
    port (
        clk, reset : in std_logic;
        value : in std_logic_vector(13 downto 0);
        dp : out std_logic;
        an : out std_logic_vector(3 downto 0);
        seg : out std_logic_vector(6 downto 0)
    );
end component;

component timer is
    port(
        clk, reset : in std_logic;
        w_strobe : in std_logic;
        port_id, out_port : in std_logic_vector(7 downto 0);
        counter_r : out std_logic_vector(31 downto 0);
        interrupt_flag : out std_logic
    );
end component;

component flag_buf is
    port(
        clk, reset: in std_logic;
        clr_flag : in std_logic;
        D : in std_logic;
        Q : out std_logic
    );
end component;

component spi is
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
end component;

begin
kcpsm6_reset <= rdl or btnC_db;

kcpsm6_core: kcpsm6
    generic map(hwbuild => X"00", 
            interrupt_vector => X"3FF", 
            scratch_pad_memory_size => 64)
    port map(address => address, 
            instruction => instruction,
            bram_enable => bram_enable,
            in_port => in_port,
            out_port => out_port,
            port_id => port_id,
            write_strobe => write_strobe,
            k_write_strobe => k_write_strobe,
            read_strobe => read_strobe,
            interrupt => interrupt,
            interrupt_ack => interrupt_ack,
            sleep => '0',
            reset => kcpsm6_reset,
            clk => clk);
            
rom: picoblaze_rom
    generic map(C_FAMILY => "7S",
            C_RAM_SIZE_KWORDS => 1,
            C_JTAG_LOADER_ENABLE => 0)
    port map(address => address,
        instruction => instruction,
        enable => bram_enable,
        rdl => rdl,                    
        clk => clk);
        
db_btnC: debouncer
    generic map(
        delay => 1000000
    )
    port map(
        clk => clk,
        button => btnC,
        debounce => btnC_db
    );

db_btnU: debouncer
    generic map(
        delay => 1000000
    )
    port map(
        clk => clk,
        button => btnU,
        debounce => btnU_db
    );

db_btnL: debouncer
    generic map(
        delay => 1000000
    )
    port map(
        clk => clk,
        button => btnL,
        debounce => btnL_db
    );

db_btnR: debouncer
    generic map(
        delay => 1000000
    )
    port map(
        clk => clk,
        button => btnR,
        debounce => btnR_db
    );

db_btnD: debouncer
    generic map(
        delay => 1000000
    )
    port map(
        clk => clk,
        button => btnD,
        debounce => btnD_db
    );

uart_interface: uart
    generic map(
    -- Default setting :
    -- 115200 baud, 8 data bits , 1 stop bit, 2^2 FIFO
    DBIT => 8, -- # data bits
    SB_TICK => 16, -- # ticks for stop bits, 16/24/32
                            -- for 1/1.5/2 stop bits
    DVSR => 54, -- baud rate divisor
                          -- DVSR = 100M/(16*baud rate)
    DVSR_BIT => 8, -- # bits of DVSR
    FIFO_W => 2 -- # addr bits of FIFO
                         -- # words in FIFO=2^FIFO-W
    )
    port map(
        clk => clk, 
        reset => kcpsm6_reset, 
        rd_uart => rd_uart, 
        wr_uart => wr_uart,
        rx => rsRx, 
        w_data => out_port,
        tx_full => tx_full, 
        rx_empty => rx_empty,
        r_data => r_data,
        tx => rsTX
    );
rd_uart <= '1' when read_strobe = '1' and port_id = x"02" else '0';

segment : seg7
    port map(
        clk => clk, 
        reset => kcpsm6_reset,
        value => bin_7seg_reg,
        dp => dp,
        an => an,
        seg => seg
    );

tim0 : timer
    port map(
        clk => clk,
        reset => kcpsm6_reset,
        w_strobe => w_strobe,
        port_id => decode_port_id,
        out_port => out_port,
        counter_r => tim0_counter,
        interrupt_flag => timer_int
    );

closed_loop_interrupt : flag_buf
    port map(
        clk => clk,
        reset => kcpsm6_reset,
        clr_flag => interrupt_ack,
        D => timer_int,
        Q => interrupt
    );

spi0: spi
    generic map(
        data_length => 8,
        DVSR => 50, -- baud rate divisor  -- DVSR = 100M/(2*baud rate) -> 1MHz
        DVSR_BIT => 8 -- # bits of DVSR
    )
    port map(
        clk => clk,
        reset => kcpsm6_reset,
        enable => spi_config(0),
        cpol => spi_config(1),
        cpha => spi_config(2),
        miso => miso,
        sclk => sclk,
        ss_n => ss_n,
        mosi => mosi,
        busy => spi_busy,
        tx => spi_tx,
        rx => spi_rx 
    );

decode_port_id <= port_id when write_strobe = '1' else x"0" & port_id(3 downto 0) when k_write_strobe = '1' else x"00";
w_strobe <= k_write_strobe or write_strobe;
output_interface: process(w_strobe, decode_port_id)
begin
    en_o <= (others => '0');
    if (w_strobe = '1') then
        case decode_port_id is
            when x"00" => en_o <= "0000001"; -- led 7-0
            when x"01" => en_o <= "0000010"; -- led 15-8
            when x"02" => en_o <= "0000100"; -- tx uart
            when x"03" => en_o <= "0001000"; -- 7seg LSB
            when x"04" => en_o <= "0010000"; -- 7seg MSB
            when x"0A" => en_o <= "0100000"; -- spi config
            when x"0B" => en_o <= "1000000"; -- spi tx
            when others => en_o <= "0000000";
        end case;
    end if;
end process;
wr_uart <= en_o(2);

input_interface: process(port_id, sw, r_data, tx_full, rx_empty, tim0_counter, spi_rx)
begin
    case port_id is
        when x"00" => in_port <= sw(7 downto 0);
        when x"01" => in_port <= sw(15 downto 8);
        when x"02" => in_port <= r_data;
        when x"03" => in_port <= "000000" & tx_full & rx_empty;
        when x"04" => in_port <= tim0_counter(7 downto 0);
        when x"05" => in_port <= tim0_counter(15 downto 8);
        when x"06" => in_port <= tim0_counter(23 downto 16);
        when x"07" => in_port <= tim0_counter(31 downto 24);
        when x"08" => in_port <= "0000000" & spi_busy;
        when x"09" => in_port <= spi_rx;
        when others => in_port <= x"00";
    end case;
end process;

registers: process(clk)
begin
    if (rising_edge(clk)) then
        if (en_o(0) = '1') then led(7 downto 0) <= out_port; end if;
        if (en_o(1) = '1') then led(15 downto 8) <= out_port; end if;
        if (en_o(3) = '1') then bin_7seg_reg(7 downto 0) <= out_port; end if;
        if (en_o(4) = '1') then bin_7seg_reg(13 downto 8) <= out_port(5 downto 0); end if;
        if (en_o(5) = '1') then spi_config <= out_port(2 downto 0); end if;
        if (en_o(6) = '1') then spi_tx <= out_port; end if;
    end if;
end process;

end Behavioral;
