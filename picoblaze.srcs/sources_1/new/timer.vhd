library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity timer is
    port(
        clk, reset : in std_logic;
        w_strobe : in std_logic;
        port_id, out_port : in std_logic_vector(7 downto 0);
        counter_r : out std_logic_vector(31 downto 0);
        interrupt_flag : out std_logic
    );
end timer;

architecture Behavioral of timer is
type state_type is (idle, counting);
signal counter_reg, counter_next : unsigned(31 downto 0);
signal config_reg, config_next : std_logic_vector(7 downto 0);
signal preload_reg : unsigned(31 downto 0);
signal prescaler_reg, prescaler_next : unsigned(3 downto 0);
signal state_reg, state_next : state_type;

signal preload_r : std_logic_vector(23 downto 0);

begin
-- register
process (clk, reset, out_port)
begin
    if (reset = '1') then
        counter_reg <= (others => '0');
        preload_reg <= (others => '0');
        config_reg <= (others => '0');
        prescaler_reg <= (others => '0');
        state_reg <= idle;
    elsif (rising_edge(clk)) then
        counter_reg <= counter_next;
        state_reg <= state_next;
        prescaler_reg <= prescaler_next;
        config_reg <= config_next;
        if w_strobe = '1' then
            case port_id is
                when x"05" => config_reg <= out_port; -- tim0 config
                when x"06" => preload_r(7 downto 0) <= out_port; -- tim0 preload B0 (LSB)
                when x"07" => preload_r(15 downto 8) <= out_port; -- tim0 preload B1
                when x"08" => preload_r(23 downto 16) <= out_port; -- tim0 preload B2
                when x"09" => preload_reg <= unsigned(out_port & preload_r);-- tim0 preload B3 (MSB)
                when others => null;
            end case;
        end if;
    end if;
end process;

-- next-state logic
process(config_reg, state_reg, prescaler_reg, preload_reg, counter_reg)
begin
    state_next <= state_reg;
    counter_next <= counter_reg;
    prescaler_next <= prescaler_reg;
    config_next <= config_reg;
    case state_reg is
        when idle =>
            counter_next <= (others => '0');
            prescaler_next <= (others => '0');
            if config_reg(0) = '1' then -- enable
                state_next <= counting;
            end if;
        when counting =>
            if config_reg(0) = '1' then -- still enable
                if prescaler_reg = unsigned(config_reg(7 downto 4)) then
                    prescaler_next <= (others => '0');
                    if counter_reg = preload_reg then -- reach the preload value
                        counter_next <= (others => '0');
                        if config_reg(2) = '0' then
                            config_next(0) <= '0';
                            state_next <= idle;
                        end if;
                    else
                        counter_next <= counter_reg + 1;
                    end if;
                else
                    prescaler_next <= prescaler_reg + 1;
                end if;
            else
                state_next <= idle;
            end if;
    end case;
end process;

-- output logic
counter_r <= std_logic_vector(counter_reg);
interrupt_flag <= '1' when counter_reg = preload_reg and config_reg(1) = '1' and prescaler_reg = unsigned(config_reg(7 downto 4)) else '0'; -- Reach the preload value and interrupt was enable

end Behavioral;
