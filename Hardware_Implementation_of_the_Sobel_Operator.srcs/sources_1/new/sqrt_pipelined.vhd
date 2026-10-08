library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
library work;

entity sqrt_pipelined is
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
end sqrt_pipelined;



architecture Behavioral_sqrt_pipelined of sqrt_pipelined is

    constant NUM_ITER    : integer := (G_IN_BW / 2) + G_OUT_FRAC;
    constant INTERNAL_BW : integer := G_IN_BW + 2*G_OUT_FRAC;

    -- pipeline registri
    type slv_array is array (0 to NUM_ITER) of std_logic_vector(INTERNAL_BW+1 downto 0);
    type root_array is array (0 to NUM_ITER) of std_logic_vector(G_OUT_BW-1 downto 0);
    type idx_array  is array (0 to NUM_ITER) of integer range 0 to INTERNAL_BW;
    type val_array  is array (0 to NUM_ITER) of std_logic;
    type pair_array is array (0 to NUM_ITER) of std_logic_vector(INTERNAL_BW-1 downto 0);

    signal rem_pipe   : slv_array;
    signal root_pipe  : root_array;
    signal idx_pipe   : idx_array;
    signal valid_pipe : val_array;
    signal ukupni_parovi_pipe : pair_array;  -- svaki stepen ima svoj registar

begin

    INPUT:process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                valid_pipe(0)           <= '0';
                rem_pipe(0)             <= (others => '0');
                root_pipe(0)            <= (others => '0');
                idx_pipe(0)             <= 0;
                ukupni_parovi_pipe(0)   <= (others => '0');
            else
                valid_pipe(0) <= valid_in;
                if valid_in = '1' then
                    ukupni_parovi_pipe(0) <= d_in & std_logic_vector(to_unsigned(0, 2*G_OUT_FRAC));
                    rem_pipe(0)   <= (others => '0');
                    root_pipe(0)  <= (others => '0');
                    idx_pipe(0)   <= INTERNAL_BW - 1;
                end if;
            end if;
        end if;
    end process;

    gen_pipeline : for i in 0 to NUM_ITER-1 generate
        process(clk)
            variable v_pair         : std_logic_vector(1 downto 0);
            variable v_next_rem     : std_logic_vector(INTERNAL_BW+1 downto 0);
            variable v_test_val     : std_logic_vector(INTERNAL_BW+1 downto 0);
        begin
            if rising_edge(clk) then
                if reset = '1' then
                    valid_pipe(i+1)           <= '0';
                    rem_pipe(i+1)             <= (others => '0');
                    root_pipe(i+1)            <= (others => '0');
                    idx_pipe(i+1)             <= 0;
                    ukupni_parovi_pipe(i+1)   <= (others => '0');
                else
                    valid_pipe(i+1) <= valid_pipe(i);
                    ukupni_parovi_pipe(i+1) <= ukupni_parovi_pipe(i);  -- propagate parove

                    if valid_pipe(i) = '1' then
                        -- uzmi dva bita za iteraciju
                        v_pair := ukupni_parovi_pipe(i)(idx_pipe(i) downto idx_pipe(i)-1);

                        -- ostatak = (ostatak << 2) | par
                        v_next_rem := std_logic_vector(shift_left(unsigned(rem_pipe(i)), 2)or resize(unsigned(v_pair), INTERNAL_BW+2));

                        -- test = (koren << 2) | 1
                        v_test_val := std_logic_vector(resize((shift_left(unsigned(root_pipe(i)), 2) + 1),INTERNAL_BW + 2));


                        if unsigned(v_test_val) <= unsigned(v_next_rem) then
                            rem_pipe(i+1) <= std_logic_vector(unsigned(v_next_rem) - unsigned(v_test_val));
                            root_pipe(i+1) <= std_logic_vector(shift_left(unsigned(root_pipe(i)), 1) + 1);
                        else
                            rem_pipe(i+1) <= std_logic_vector(v_next_rem);
                            root_pipe(i+1) <= std_logic_vector(shift_left(unsigned(root_pipe(i)), 1));
                        end if;

                        if idx_pipe(i) > 1 then
                            idx_pipe(i+1) <= idx_pipe(i) - 2;
                        else
                            idx_pipe(i+1) <= 0;
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end generate;

    OUTPUT:process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                valid_out <= '0';
                d_out     <= (others => '0');
            else
                valid_out <= valid_pipe(NUM_ITER);
                d_out     <= root_pipe(NUM_ITER);
            end if;
        end if;
    end process;

end Behavioral_sqrt_pipelined;