library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
library work;
use work.RAM_definitions_PK.all;

entity magnitude_gradient is
    port(
        clk : in std_logic;
        reset : in std_logic;
        butt : in std_logic;
        --final_pixel : out std_logic_vector(7 downto 0);
        tx: out std_logic
    );
end magnitude_gradient;

architecture Behavioral of magnitude_gradient is
    component line_buffer is
        port (
        clk      : in std_logic;
        reset : in std_logic;
        input_pixel : in std_logic_vector(7 downto 0);
        output_pixel : out std_logic_vector(7 downto 0)
    );
    end component;
    
    component im_ram is
    generic (
        G_RAM_WIDTH : integer := 8;            		    -- Specify RAM data width
        G_RAM_DEPTH : integer := 256*256; 				        -- Specify RAM depth (number of entries)
        G_RAM_PERFORMANCE : string := "LOW_LATENCY"   -- Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        );
    port (
        addra : in std_logic_vector((clogb2(G_RAM_DEPTH)-1) downto 0);     -- Write address bus, width determined from RAM_DEPTH
        addrb : in std_logic_vector((clogb2(G_RAM_DEPTH)-1) downto 0);     -- Read address bus, width determined from RAM_DEPTH
        dina  : in std_logic_vector(G_RAM_WIDTH-1 downto 0);		  -- RAM input data
        clka  : in std_logic;                       			  -- Clock
        wea   : in std_logic;                       			  -- Write enable
        enb   : in std_logic;                       			  -- RAM Enable, for additional power savings, disable port when not in use
        rstb  : in std_logic;                       			  -- Output reset (does not affect memory contents)
        regceb: in std_logic;                       			  -- Output register enable
        doutb : out std_logic_vector(G_RAM_WIDTH-1 downto 0) 		  -- RAM output data
        );
     end component im_ram;
     
     component sqrt is
        generic(
            G_IN_BW    : natural := 16; --  irina ulaza
            G_OUT_BW   : natural := 16; --  irina izlaza
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
    end component sqrt;
    
    component edge_detector is
    port(
        clk: in std_logic;
        reset: in std_logic;
        button: in std_logic;
        edge : out std_logic
    );
    end component edge_detector;
    
    component uart_tx is
    generic (
        CLK_FREQ : integer := 125;   -- Main frequency (MHz)
        SER_FREQ : integer := 500000 -- Baud rate (bps)
    );
    port (
        -- Control
        clk        : in	std_logic; -- Main clock
        rst        : in	std_logic; -- Main reset
        -- External Interface
        tx         : out	std_logic; -- RS232 transmitted serial data
        -- RS232/UART Configuration
        par_en     : in	std_logic; -- Parity bit enable
        -- uPC Interface
        tx_dvalid  : in	std_logic;					  -- Indicates that tx_data is valid and should be sent
        tx_data    : in	std_logic_vector(7 downto 0); -- Data to transmit
        tx_busy    : out std_logic                    -- Active while UART is busy and cannot receive data
    );
    end component uart_tx;
        
    signal counter : integer := 0;
    type ram_type is array (0 to 256*256-1) of std_logic_vector (7 downto 0);
    signal data_input : std_logic_vector(7 downto 0);
    signal sqrt_input : std_logic_vector(15 downto 0);
    signal addra : std_logic_vector(15 downto 0);
    signal addrb : std_logic_vector(15 downto 0);
    signal wea : std_logic := '0';
    signal doutb : std_logic_vector(7 downto 0);
    signal reg0, reg1, reg2: std_logic_vector(7 downto 0);
    signal reg3, reg4, reg5: std_logic_vector(7 downto 0);
    signal reg6, reg7, reg8: std_logic_vector(7 downto 0);
    signal sqrt_valid : std_logic;
    signal output_ready : std_logic;
    signal sqrt_out : std_logic_vector(15 downto 0);
    signal v1, v2, v3: std_logic;
    signal grad_H, grad_V : std_logic_vector(10 downto 0);
    signal qdr_grad_H, qdr_grad_V : std_logic_vector(19 downto 0);
    signal sum : std_logic_vector(21 downto 0);
    signal tx_valid : std_logic;
    signal busy : std_logic;
    signal button_edge : std_logic;
    signal uart_data : std_logic_vector(7 downto 0);
    signal sending: std_logic := '0';
    signal tx_counter    : unsigned(15 downto 0) := (others => '0');
    signal process_done : std_logic := '0';
    -- Signali za UART pipeline
    signal addrb_uart  : std_logic_vector(15 downto 0);
    signal doutb_d1, doutb_d2 : std_logic_vector(7 downto 0);
    
begin

    IM_MEM : entity work.im_ram(Behavioral)
    generic map(
        G_RAM_WIDTH => 8,
        G_RAM_DEPTH => 256*256,
        G_RAM_PERFORMANCE => "HIGH_PERFORMANCE" --2 takta kasni 
    )
    port map (
        addra => addra, 
        addrb => addrb, 
        dina  => data_input, 
        clka  => clk,
        wea   => wea,
        enb   => '1',   
        rstb  => '0',
        regceb=> '1', 
        doutb => doutb
    );
    LINE_BUFFER_IMPL1 : line_buffer port map (clk => clk, reset => reset, input_pixel => reg2, output_pixel => reg3);
    LINE_BUFFER_IMPL2 : line_buffer port map (clk => clk, reset => reset, input_pixel => reg5 , output_pixel => reg6);
    
    SQRT_MAP : entity work.sqrt_pipelined(Behavioral_sqrt_pipelined)
    generic map(
        G_IN_BW    => 16, --  irina ulaza
        G_OUT_BW   => 16, --  irina izlaza
        G_OUT_FRAC => 8   -- broj bita za razlomak
    )
    port map(
        clk => clk,
        reset => reset,     
        d_in  => sqrt_input,    
        valid_in => sqrt_valid,
        d_out => sqrt_out,   
        valid_out => output_ready
    );
    
    EDGE_MAP : entity work.edge_detector(Behavioral)
    port map (
        clk => clk,
        reset => reset,
        button => butt,
        edge => button_edge
    );
    
    
    UART_MAP : entity work.uart_tx(Behavioral)
    generic map(
       CLK_FREQ => 125,  -- Main frequency (MHz)
	   SER_FREQ => 115200 -- Baud rate (bps)
    )
    
    port map(
        clk => clk,
        rst => reset,
        par_en => '0',
        tx_dvalid => tx_valid,
        tx_data => uart_data, 
        tx_busy => busy,
        tx => tx
    );

    SHIFT_PROC: process(clk) is
    begin
        if rising_edge(clk) then
            if reset = '1' then
                counter <= 0;
                process_done <= '0';
            elsif process_done = '0' then
                counter <= counter + 1;
                reg0 <= doutb;
                reg1 <= reg0;
                reg2 <= reg1;
                reg4 <= reg3;
                reg5 <= reg4;
                reg7 <= reg6;
                reg8 <= reg7;
        
                if counter = 65562 then
                    process_done <= '1';
                end if;
            end if;
        end if;
    end process SHIFT_PROC;
    
    
    SOBEL_PIPELINE : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                grad_H      <= (others => '0');
                grad_V      <= (others => '0');
                qdr_grad_H  <= (others => '0');
                qdr_grad_V  <= (others => '0');
                sum         <= (others => '0');
                sqrt_input  <= (others => '0');
                v1 <= '0'; v2 <= '0'; v3 <= '0'; sqrt_valid <= '0';
            else
                -- STAGE 1: Gradijenti 
                if counter > 514  and process_done = '0' then
                    grad_H <= std_logic_vector(
                                to_signed(
                                    (to_integer(unsigned(reg2)) - to_integer(unsigned(reg0))) +
                                    2 * (to_integer(unsigned(reg5)) - to_integer(unsigned(reg3))) +
                                    (to_integer(unsigned(reg8)) - to_integer(unsigned(reg6))),
                                    11));
                    grad_V <= std_logic_vector(
                                to_signed(
                                    (to_integer(unsigned(reg6)) - to_integer(unsigned(reg0))) +
                                    2 * (to_integer(unsigned(reg7)) - to_integer(unsigned(reg1))) +
                                    (to_integer(unsigned(reg8)) - to_integer(unsigned(reg2))),
                                    11));
                    v1 <= '1';
                else
                    grad_H <= (others => '0');
                    grad_V <= (others => '0');
                    v1 <= '0';
                end if;
    
                -- STAGE 2: Kvadriranje
                qdr_grad_H <= std_logic_vector(resize(unsigned(signed(grad_H) * signed(grad_H)), 20));
                qdr_grad_V <= std_logic_vector(resize(unsigned(signed(grad_V) * signed(grad_V)), 20));
                v2 <= v1;
    
                -- STAGE 3: Sabiranje kvadrata i prosirenje na 22 bita
                sum <= std_logic_vector(resize(unsigned(qdr_grad_H) + unsigned(qdr_grad_V),22));
                v3 <= v2;
    
                -- STAGE 4: Deljenje sa 64 i priprema za sqrt
                sqrt_input <= std_logic_vector(resize(shift_right(unsigned(sum),6),16));
                sqrt_valid <= v3;
            end if;
        end if;
    end process;
    
    WRITE_PROC: process(clk)
    begin
        if rising_edge(clk) then ---mod za izbegavanje zadnje i prve kolona
            if (output_ready = '1' and process_done = '0' and counter > 537 and counter < 65562 and counter mod 256 /= 27 and counter mod 256 /= 26) then
                wea <= '1';
                data_input <= sqrt_out(15 downto 8);
                addra <= std_logic_vector(to_unsigned(counter-283,16)); -- adrese od 1x1 do 254x254
            else
                wea <= '0';
            end if;
        end if;
    end process;
    
    UART_SEND_PROC: process(clk)
    begin
        if rising_edge(clk) then
            if reset='1' then
                tx_counter <= (others=>'0');
                tx_valid   <= '0';
                sending    <= '0';
                addrb_uart <= (others=>'0');
            else
                -- START slanja
                if button_edge='1' and sending='0' and process_done='1' then
                    sending    <= '1';
                    tx_counter <= (others=>'0');
                    addrb_uart <= (others=>'0');
                end if;
    
                if sending='1' then
                    -- Ako UART nije zauzet, po alji podatak
                    if busy='0' and tx_valid='0' then
                        uart_data   <= doutb_d2;   -- deterministi?ki pipeline
                        tx_valid    <= '1';
                    end if;
    
                    -- UART prihvatio podatak
                    if tx_valid='1' and busy='1' then
                        tx_valid <= '0';
                        if tx_counter = 65535 then
                            sending <= '0'; -- zavr eno slanje
                        else
                            tx_counter <= tx_counter + 1;
                            addrb_uart <= std_logic_vector(tx_counter + 1); -- slede?a adresa
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    DOUBT: process(clk)
    begin
        if rising_edge(clk) then
            doutb_d1 <= doutb;   -- 1. takt latencije
            doutb_d2 <= doutb_d1; -- 2. takt latencije
        end if;
    end process;
    
    ADDR: process(clk)
    begin
        if rising_edge(clk) then
            if sending = '0' then
                addrb <= std_logic_vector(to_unsigned(counter,16));
            else
                addrb <= addrb_uart; -- UART ?ita iz registrovane adrese
            end if;
        end if;
    end process;
    
    --final_pixel <= data_input;
    
end Behavioral;