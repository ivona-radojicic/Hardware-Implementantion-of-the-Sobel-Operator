
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
library work;

entity sqrt is
    generic(
        G_IN_BW    : natural := 16; -- širina ulaza
        G_OUT_BW   : natural := 16; -- širina izlaza
        G_OUT_FRAC : natural := 8   -- broj bita za razlomak
    );
    port(
        clk       : in  std_logic;
        reset     : in  std_logic;
        d_in      : in  std_logic_vector(G_IN_BW-1 downto 0);
        valid_in  : in  std_logic;
        d_out     : out std_logic_vector(G_OUT_BW-1 downto 0);
        valid_out : out std_logic
    );
end sqrt;

architecture Behavioral_sqrt_seq of sqrt is
    type fsm is (stInit, stIterate, stShow);
    signal state_reg, next_state : fsm;

    constant NUM_ITER : integer := (G_IN_BW / 2) + G_OUT_FRAC;
    constant INTERNAL_BW : integer := G_IN_BW + 2*G_OUT_FRAC;

    signal ukupni_parovi : std_logic_vector(INTERNAL_BW-1 downto 0);
    signal ostatak       : std_logic_vector(INTERNAL_BW+1 downto 0); 
    signal temp_koren    : std_logic_vector(G_OUT_BW-1 downto 0);
    signal counter       : integer range 0 to NUM_ITER;
    signal idx           : integer range 0 to INTERNAL_BW;

begin

    STATE_TRANSITION: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state_reg <= stInit;
            else
                state_reg <= next_state;
            end if;
        end if;
    end process;

    NEXT_STATE_LOGIC: process(state_reg, valid_in, counter)
    begin
        case state_reg is
            when stInit =>
                if valid_in = '1' then 
                    next_state <= stIterate;
                else 
                    next_state <= stInit;
                end if;
            when stIterate =>
                if counter = 0 then 
                    next_state <= stShow;
                else 
                    next_state <= stIterate;
                end if;
            when stShow =>
                next_state <= stInit;
            when others =>
                next_state <= stInit;
        end case;
    end process;
    
    COUNTER_LOGIC: process (clk)
    begin
        if rising_edge(clk) then
            if state_reg = stIterate and counter > 0 then
                counter <= counter - 1;
            else
                counter <= NUM_ITER;
            end if;
        end if;
    end process;

    DIGIT_BY_DIGIT_PROCESS: process(clk)
        variable v_pair          : std_logic_vector(1 downto 0);
        variable v_test_val      : std_logic_vector(INTERNAL_BW+1 downto 0);
        variable v_next_ostatak  : std_logic_vector(INTERNAL_BW+1 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                temp_koren <= (others => '0');
                ostatak    <= (others => '0');
    
            else
                case state_reg is
                    when stInit =>
                        if valid_in = '1' then
                            ukupni_parovi <= d_in & std_logic_vector(to_unsigned(0, 2*G_OUT_FRAC));
                            idx           <= INTERNAL_BW - 1;
                            ostatak       <= (others => '0');
                            temp_koren    <= (others => '0');
                        end if;
                    when stIterate =>
                        if counter > 0 then
    
                            -- Uzimanje para bita
                            v_pair := ukupni_parovi(idx downto idx-1);
    
                            -- ostatak = (ostatak << 2) | par
                            v_next_ostatak := std_logic_vector(shift_left(unsigned(ostatak), 2)or resize(unsigned(v_pair), ostatak'length));    
                            -- test_vrednost = (temp_koren << 2) | 1
                            v_test_val :=
                                std_logic_vector(resize((shift_left(unsigned(temp_koren), 2) + 1),INTERNAL_BW + 2));
    
                            if unsigned(v_test_val) <= unsigned(v_next_ostatak) then
                                ostatak <= std_logic_vector(unsigned(v_next_ostatak) - unsigned(v_test_val));
                                temp_koren <= std_logic_vector(shift_left(unsigned(temp_koren), 1) + 1);
                            else
                                ostatak <= v_next_ostatak;
                                temp_koren <= std_logic_vector(shift_left(unsigned(temp_koren), 1));
                            end if;
    
                            -- indeks
                            if idx > 1 then
                                idx <= idx - 2;
                            else
                                idx <= 0;
                            end if;
    
                        end if;
                        
                    when stShow =>
                        null;
    
                end case;
            end if;
        end if;
    end process;


    OUTPUT_LOGIC: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                valid_out <= '0';
                d_out <= (others => '0');
            elsif state_reg = stShow then
                valid_out <= '1';
                d_out <= std_logic_vector(temp_koren);
            else
                valid_out <= '0';
            end if;
        end if;
    end process;



end Behavioral_sqrt_seq;
