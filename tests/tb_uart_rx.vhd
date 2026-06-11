library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart_rx is
end tb_uart_rx;

architecture tb of tb_uart_rx is

    -- Testbench scenarios:
    -- 1. Verification of the idle state after reset.
    -- 2. Verification of receiving one byte over UART.
    -- 3. Verification that rx_valid is a short pulse after reception completes.
    -- 4. Verification of receiving multiple bytes in sequence with pauses.
    -- 5. Verification of stability during idle gaps between packets.

    constant CLK_FREQ   : integer := 100;
    constant BAUD_RATE  : integer := 10;
    constant BIT_TICKS  : integer := CLK_FREQ / BAUD_RATE;
    constant CLK_PERIOD : time := 10 ns;

    signal clk      : std_logic := '0';
    signal reset_n  : std_logic := '0';
    signal rx_line  : std_logic := '1';
    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;

begin

    clk <= not clk after CLK_PERIOD / 2;

    dut: entity work.uart_rx
        generic map(
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => BAUD_RATE
        )
        port map(
            clk      => clk,
            reset_n  => reset_n,
            rx_line  => rx_line,
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

        procedure send_serial_byte(value : std_logic_vector(7 downto 0)) is
        begin
            rx_line <= '0';
            wait_ticks(BIT_TICKS);
            for i in 0 to 7 loop
                rx_line <= value(i);
                wait_ticks(BIT_TICKS);
            end loop;
            rx_line <= '1';
            wait_ticks(BIT_TICKS);
        end procedure;
    begin
        wait for 3 * CLK_PERIOD;
        reset_n <= '1';
        wait_ticks(2);
        assert rx_valid = '0'
            report "In the idle state, rx_valid must be low" severity error;

        send_serial_byte(x"A5");
        wait_ticks(2);
        assert rx_valid = '1'
            report "After a full byte is received, rx_valid must assert" severity error;
        assert rx_data = x"A5"
            report "The received byte does not match transmitted value 0xA5" severity error;
        wait_ticks(1);
        assert rx_valid = '0'
            report "rx_valid must be a short pulse" severity error;

        wait_ticks(BIT_TICKS);
        send_serial_byte(x"55");
        wait_ticks(2);
        assert rx_valid = '1' and rx_data = x"55"
            report "Reception error for byte 0x55" severity error;

        wait_ticks(BIT_TICKS * 2);
        send_serial_byte(x"3C");
        wait_ticks(2);
        assert rx_valid = '1' and rx_data = x"3C"
            report "Reception error for byte 0x3C" severity error;

        wait_ticks(BIT_TICKS * 3);
        assert rx_valid = '0'
            report "During the idle pause, rx_valid must not assert" severity error;

        assert false
            report "tb_uart_rx completed."
            severity note;
        wait;
    end process;

end tb;
