library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity picoblaze_top is
    port(
        clk : in std_logic;
        btnC, btnU, btnL, btnR, btnD : in std_logic;
        sw : in std_logic_vector(15 downto 0);
        led : out std_logic_vector(15 downto 0)
    );
end picoblaze_top;

architecture Behavioral of picoblaze_top is
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

begin
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
            reset => btnC,
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

end Behavioral;
