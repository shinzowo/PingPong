library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart_tx is
end tb_uart_tx;

architecture tb of tb_uart_tx is

    -- Testbench scenarios:
    -- 1. Verification of the idle state after reset.
    -- 2. Verification of transmitting one byte: start, 8 data bits, stop.
    -- 3. Verification that tx_busy stays asserted during transmission.
    -- 4. Verification that a repeated tx_start during busy does not break the current transfer.
    -- 5. Verification of sequential transmission of multiple bytes.

    constant CLK_FREQ   : integer := 100;
    constant BAUD_RATE  : integer := 10;
    constant BIT_TICKS  : integer := CLK_FREQ / BAUD_RATE;
    constant CLK_PERIOD : time := 10 ns;

    signal clk      : std_logic := '0';
    signal reset_n  : std_logic := '0';
    signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_start : std_logic := '0';
    signal tx_busy  : std_logic;
    signal tx_line  : std_logic;

begin

    clk <= not clk after CLK_PERIOD / 2;

    dut: entity work.uart_tx
        generic map(
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => BAUD_RATE
        )
        port map(
            clk      => clk,
            reset_n  => reset_n,
            tx_data  => tx_data,
            tx_start => tx_start,
            tx_busy  => tx_busy,
            tx_line  => tx_line
        );

    stim_proc: process
        procedure wait_ticks(count : integer) is
        begin
            for i in 1 to count loop
                wait until rising_edge(clk);
            end loop;
            wait for 1 ns;
        end procedure;

        procedure start_transfer(value : std_logic_vector(7 downto 0)) is
        begin
            tx_data  <= value;
            tx_start <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
            tx_start <= '0';
        end procedure;

        procedure sample_uart_bit(expected : std_logic; bit_name : string) is
        begin
            wait_ticks(BIT_TICKS / 2);
            assert tx_line = expected
                report "Incorrect UART TX line value for " & bit_name severity error;
            wait_ticks(BIT_TICKS - (BIT_TICKS / 2));
        end procedure;
    begin
        wait for 3 * CLK_PERIOD;
        reset_n <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;

        assert tx_line = '1'
            report "In idle mode, the TX line must be logic high" severity error;
        assert tx_busy = '0'
            report "After reset, the TX module must not be busy" severity error;

        start_transfer(x"A5");
        assert tx_busy = '1'
            report "After tx_start, tx_busy must assert" severity error;
        sample_uart_bit('0', "start bit");
        sample_uart_bit('1', "bit 0");
        sample_uart_bit('0', "bit 1");
        sample_uart_bit('1', "bit 2");
        sample_uart_bit('0', "bit 3");
        sample_uart_bit('0', "bit 4");
        sample_uart_bit('1', "bit 5");
        sample_uart_bit('0', "bit 6");
        sample_uart_bit('1', "bit 7");
        sample_uart_bit('1', "stop bit");
        assert tx_busy = '0'
            report "After transmission completes, tx_busy must deassert" severity error;

        start_transfer(x"55");
        wait_ticks(BIT_TICKS);
        tx_data  <= x"FF";
        tx_start <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        tx_start <= '0';
        sample_uart_bit('1', "bit 0 of the first byte during repeated start");
        sample_uart_bit('0', "bit 1 of the first byte during repeated start");
        wait_ticks(BIT_TICKS * 8);

        wait until tx_busy = '0';
        start_transfer(x"3C");
        sample_uart_bit('0', "start bit of the second byte");
        sample_uart_bit('0', "bit 0 of the second byte");
        sample_uart_bit('0', "bit 1 of the second byte");
        sample_uart_bit('1', "bit 2 of the second byte");
        sample_uart_bit('1', "bit 3 of the second byte");
        sample_uart_bit('1', "bit 4 of the second byte");
        sample_uart_bit('1', "bit 5 of the second byte");
        sample_uart_bit('0', "bit 6 of the second byte");
        sample_uart_bit('0', "bit 7 of the second byte");
        sample_uart_bit('1', "stop bit of the second byte");

        assert false
            report "tb_uart_tx completed."
            severity note;
        wait;
    end process;

end tb;
