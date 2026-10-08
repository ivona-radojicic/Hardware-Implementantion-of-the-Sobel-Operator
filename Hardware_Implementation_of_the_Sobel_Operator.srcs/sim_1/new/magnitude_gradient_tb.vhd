library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use STD.TEXTIO.all;
use IEEE.NUMERIC_STD.ALL;
library work;

entity magnitude_gradient_tb is
end magnitude_gradient_tb;

architecture Behavioral of magnitude_gradient_tb is
    component magnitude_gradient is
        port(
            clk : in std_logic;
            reset : in std_logic;
            butt : in std_logic;
            tx : out std_logic  
        );
    end component magnitude_gradient;

    signal clk: std_logic := '0';
    signal reset: std_logic := '0';
    signal butt : std_logic := '0';
    signal tx   : std_logic;     
    
    constant Tclk : time := 10 ns;

    --file my_output : TEXT open WRITE_MODE is "C:\Users\radoj\OneDrive\Desktop\signal_output1.txt.txt"; 
    
    signal output_ready : std_logic; 
    signal counter, upis_counter : integer := 0;

begin

    reset <= '1', '0' after 21 ns; 
    clk_gen: clk <= not clk after Tclk/2;

    dut : magnitude_gradient 
        port map(
            clk => clk, 
            reset => reset,  
            butt => butt,        
            tx => tx           
        );

    process(clk, reset) is
    begin
        if reset = '1' then
            counter <= 0;
            upis_counter <= 0;
            butt <= '0';
        elsif rising_edge(clk) then
            counter <= counter + 1;
            if (counter > 539 and counter < 65562 and counter mod 256 /= 27 and counter mod 256 /= 26) then  
                output_ready <= '1';
                upis_counter <= upis_counter + 1;
            else
                output_ready <= '0';
            end if;
            if counter = 66000 then
                butt <= '1';
            elsif counter = 66010 then
                butt <= '0';
            end if;
        end if;
    end process;
    
   
    --process(clk)  
        --variable my_output_line : LINE;  
    --begin  
        --if falling_edge(clk) then
            --if output_ready = '1' then   
                --write(my_output_line, to_integer(unsigned(Dout)));  
                --writeline(my_output, my_output_line);
            --end if;  
        --end if;  
    --end process

end Behavioral;