library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    generic (
        CLK_FREQ   : integer := 50_000_000;  
        BAUD_RATE  : integer := 115_200       
    );
    port (
        clk        : in  std_logic;
        reset_n    : in  std_logic;
        rx_line    : in  std_logic;           -- вход от UART (RX)
        rx_data    : out std_logic_vector(7 downto 0);
        rx_valid   : out std_logic            
    );
end uart_rx;

architecture rtl of uart_rx is
    constant BIT_CNT_MAX : integer := CLK_FREQ / BAUD_RATE;   -- ~434
    signal bit_counter   : integer range 0 to BIT_CNT_MAX-1;
    signal bit_index     : integer range 0 to 9;
    signal rx_reg        : std_logic;
    signal rx_buf        : std_logic_vector(7 downto 0);
    signal rx_valid_i    : std_logic;
    type state_t is (IDLE, START, DATA, STOP);
    signal state         : state_t;
begin
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= IDLE;
            bit_counter <= 0;
            bit_index <= 0;
            rx_buf <= (others => '0');
            rx_valid_i <= '0';
            rx_reg <= '1';
        elsif rising_edge(clk) then
            rx_reg <= rx_line;
            rx_valid_i <= '0';
            
            case state is
                when IDLE =>
                    if rx_reg = '0' then         
                        state <= START;
                        bit_counter <= BIT_CNT_MAX/2 - 1;  
                        bit_index <= 0;
                    end if;
                    
                when START =>
                    if bit_counter = 0 then
                        state <= DATA;
                        bit_counter <= BIT_CNT_MAX - 1;
                    else
                        bit_counter <= bit_counter - 1;
                    end if;
                    
                when DATA =>
                    if bit_counter = 0 then
                        rx_buf(bit_index) <= rx_reg;
                        if bit_index = 7 then
                            state <= STOP;
                            bit_counter <= BIT_CNT_MAX - 1;
                        else
                            bit_index <= bit_index + 1;
                            bit_counter <= BIT_CNT_MAX - 1;
                        end if;
                    else
                        bit_counter <= bit_counter - 1;
                    end if;
                    
                when STOP =>
                    if bit_counter = 0 then
                        state <= IDLE;
                        rx_valid_i <= '1';
                    else
                        bit_counter <= bit_counter - 1;
                    end if;
            end case;
        end if;
    end process;
    
    rx_data  <= rx_buf;
    rx_valid <= rx_valid_i;
end rtl;
