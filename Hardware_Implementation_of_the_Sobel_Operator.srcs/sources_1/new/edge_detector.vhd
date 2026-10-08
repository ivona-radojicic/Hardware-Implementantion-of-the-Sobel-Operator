library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
library work;

entity edge_detector is
    port(
        clk: in std_logic;
        reset: in std_logic;
        button: in std_logic;
        edge : out std_logic
    );
end edge_detector;

architecture Behavioral of edge_detector is

type fsm is (stIdle, stSend, stEdge);
signal reg_state, next_state : fsm;

begin

    STATE_TRANSITION: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                reg_state <= stIdle;
            else
                reg_state <= next_state;
            end if;
        end if;
    end process;   
    
     NEXT_STATE_TRANSITION: process(reg_state, button)
     begin
        case reg_state is
            when stIdle =>
                if button = '1' then
                    next_state <= stSend;
                else
                    next_state <= stIdle;
                end if;
                edge <= '0';
            when stSend =>
                if button = '0' then 
                    next_state <= stEdge;
                else
                    next_state <= stSend;
                end if;
                edge <= '0';
            when stEdge =>
                edge <= '1';
                next_state <= stIdle;
            when others =>
                next_state <= stIdle;
                edge <= '0';
        end case;
     end process; 

end Behavioral;