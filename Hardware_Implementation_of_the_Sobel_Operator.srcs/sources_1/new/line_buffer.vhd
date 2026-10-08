library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;

entity line_buffer is
    port(
        clk: in std_logic;
        input_pixel: in std_logic_vector(7 downto 0);
        reset: in std_logic;
        output_pixel: out std_logic_vector(7 downto 0)
    );
end line_buffer;

architecture Behavioral of line_buffer is
    type fifo_array is array (0 to 252) of std_logic_vector(7 downto 0);
    signal data : fifo_array := (others => (others => '0'));

begin
    process(clk)
    begin
        if rising_edge(clk) then
            data(0) <= input_pixel;
            data(1 to 252) <= data(0 to 251);
            output_pixel <= data(252);
        end if;
    end process;

end Behavioral;
