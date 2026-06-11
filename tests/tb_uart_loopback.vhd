library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart_loopback is
end tb_uart_loopback;

architecture tb of tb_uart_loopback is

    -- Testbench scenarios:
    -- 1. Reset of both modules and verification of the idle line state.
    -- 2. Transfer of one byte from uart_tx to uart_rx over a shared line.
    -- 3. Verification of rx_valid and the received byte correctness.
    -- 4. Transfer of multiple bytes in sequence through loopback.
    -- 5. Verification that tx_busy asserts during transmission and deasserts afterward.
    -- 6. Verification of a valid pause scenario between packets.

    constant CLK_FREQ   : integer := 100;
    constant BAUD_RATE  : integer := 10;
    constant BIT_TICKS  : integer := CLK_FREQ / BAUD_RATE;
    constant CLK_PERIOD : time := 10 ns;

    signal clk      : std_logic := '0';
    signal reset_n  : std_logic := '0';
    signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_start : std_logic := '0';
    signal tx_busy  : std_logic;
    signal tx_line   : std_logic;
    signal rx_data   : std_logic_vector(7 downto 0);
    signal rx_valid  : std_logic;
    signal uart_line : std_logic;

begin

    clk <= not clk after CLK_PERIOD / 2;
    uart_line <= tx_line;

    tx_dut: entity work.uart_tx
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

    rx_dut: entity work.uart_rx
        generic map(
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => BAUD_RATE
        )
        port map(
            clk      => clk,
            reset_n  => reset_n,
            rx_line  => uart_line,
            rx_data  => rx_data,
            rx_valid => rx_valid
        );

    stim_proc: process
        procedure wait_ticks(count : integer) is
        begin
            for i in 1 to count loop
                wait until rising_edge(clk);
            end loop;
            wait for 1 ns;
        end procedure;

        procedure send_byte(value : std_logic_vector(7 downto 0)) is
        begin
            tx_data  <= value;
            tx_start <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
            tx_start <= '0';
        end procedure;

        procedure send_and_check(expected : std_logic_vector(7 downto 0); scenario_name : string) is
        begin
            send_byte(expected);
            assert tx_busy = '1'
                report "In scenario '" & scenario_name & "', tx_busy must assert after transmission start"
                severity error;

            wait until rx_valid = '1';
            wait for 1 ns;
            assert rx_data = expected
                report "In scenario '" & scenario_name & "', the received byte does not match the transmitted one"
                severity error;

            wait until rising_edge(clk);
            wait for 1 ns;
            assert rx_valid = '0'
                report "In scenario '" & scenario_name & "', rx_valid must be a short pulse"
                severity error;

            wait until tx_busy = '0';
            wait for 1 ns;
        end procedure;
    begin
        wait for 3 * CLK_PERIOD;
        reset_n <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;

        assert uart_line = '1'
            report "After reset, the shared UART line must stay at logic high"
            severity error;
        assert tx_busy = '0'
            report "After reset, the transmitter must not be busy" severity error;
        assert rx_valid = '0'
            report "After reset, the receiver must not assert rx_valid" severity error;

        send_and_check(x"41", "single-byte transfer 0x41");
        send_and_check(x"55", "byte transfer 0x55");
        send_and_check(x"A5", "byte transfer 0xA5");
        send_and_check(x"3C", "byte transfer 0x3C");

        wait_ticks(BIT_TICKS * 4);
        assert rx_valid = '0'
            report "During the pause between packets, the receiver must not assert rx_valid" severity error;
        assert uart_line = '1'
            report "During the pause between packets, the line must remain in the idle state" severity error;

        send_and_check(x"7E", "byte transfer after pause");

        assert false
            report "tb_uart_loopback completed."
            severity note;
        wait;
    end process;

end tb;
