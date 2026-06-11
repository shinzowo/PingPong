library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    generic (
        CLK_FREQ  : integer := 50_000_000;
        BAUD_RATE : integer := 115_200
    );
    port (
        clk       : in  std_logic;
        reset_n   : in  std_logic;
        tx_data   : in  std_logic_vector(7 downto 0);
        tx_start  : in  std_logic;   
        tx_busy   : out std_logic;   
        tx_line   : out std_logic    -- выход UART TX
    );
end uart_tx;

architecture rtl of uart_tx is
    constant BIT_CNT_MAX : integer := CLK_FREQ / BAUD_RATE;
    type state_t is (IDLE, START, DATA, STOP);
    signal state       : state_t;
    signal bit_counter : integer range 0 to BIT_CNT_MAX - 1;
    signal bit_index   : integer range 0 to 7;
    signal tx_buf      : std_logic_vector(7 downto 0);
    signal tx_line_i   : std_logic;
begin
    tx_line <= tx_line_i;

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state       <= IDLE;
            tx_line_i   <= '1';
            tx_busy     <= '0';
            bit_counter <= 0;
            bit_index   <= 0;
            tx_buf      <= (others => '0');
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    tx_line_i <= '1';
                    tx_busy   <= '0';
                    if tx_start = '1' then
                        tx_buf      <= tx_data;
                        tx_line_i   <= '0';      
                        bit_counter <= BIT_CNT_MAX - 1;
                        bit_index   <= 0;
                        tx_busy     <= '1';
                        state       <= START;
                    end if;

                when START =>
                    if bit_counter = 0 then
                        tx_line_i   <= tx_buf(0);
                        bit_counter <= BIT_CNT_MAX - 1;
                        state       <= DATA;
                    else
                        bit_counter <= bit_counter - 1;
                    end if;

                when DATA =>
                    if bit_counter = 0 then
                        if bit_index = 7 then
                            tx_line_i   <= '1';  
                            bit_counter <= BIT_CNT_MAX - 1;
                            state       <= STOP;
                        else
                            bit_index   <= bit_index + 1;
                            tx_line_i   <= tx_buf(bit_index + 1);
                            bit_counter <= BIT_CNT_MAX - 1;
                        end if;
                    else
                        bit_counter <= bit_counter - 1;
                    end if;

                when STOP =>
                    if bit_counter = 0 then
                        state   <= IDLE;
                        tx_busy <= '0';
                    else
                        bit_counter <= bit_counter - 1;
                    end if;
            end case;
        end if;
    end process;
end rtl;
