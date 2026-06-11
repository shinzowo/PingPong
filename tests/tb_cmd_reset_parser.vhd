library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_cmd_reset_parser is
end tb_cmd_reset_parser;

architecture tb of tb_cmd_reset_parser is

    -- Testbench scenarios:
    -- 1. Module reset and verification of default values.
    -- 2. Verification of the RESET command and the "OK" response.
    -- 3. Verification of RES0, RES1, RES2 commands and resolution mode switching.
    -- 4. Verification of SPEED1..SPEED5 commands and speed mode switching.
    -- 5. Verification of behavior for an unknown command.
    -- 6. Verification of a command sequence without restarting the module.

    constant CLK_PERIOD : time := 20 ns;

    signal clk             : std_logic := '0';
    signal reset_n         : std_logic := '0';
    signal rx_data         : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_valid        : std_logic := '0';
    signal tx_data         : std_logic_vector(7 downto 0);
    signal tx_start        : std_logic;
    signal tx_busy         : std_logic := '0';
    signal reset_cmd       : std_logic;
    signal resolution_mode : std_logic_vector(1 downto 0);
    signal speed_mode      : std_logic_vector(2 downto 0);

    type byte_mem_t is array (0 to 63) of std_logic_vector(7 downto 0);
    signal captured : byte_mem_t := (others => (others => '0'));
    signal cap_idx  : integer range 0 to 63 := 0;

begin

    clk <= not clk after CLK_PERIOD / 2;

    dut: entity work.cmd_reset_parser
        port map(
            clk             => clk,
            reset_n         => reset_n,
            rx_data         => rx_data,
            rx_valid        => rx_valid,
            tx_data         => tx_data,
            tx_start        => tx_start,
            tx_busy         => tx_busy,
            reset_cmd       => reset_cmd,
            resolution_mode => resolution_mode,
            speed_mode      => speed_mode
        );

    capture_proc: process(clk)
    begin
        if rising_edge(clk) then
            if tx_start = '1' then
                captured(cap_idx) <= tx_data;
                if cap_idx < 63 then
                    cap_idx <= cap_idx + 1;
                end if;
            end if;
        end if;
    end process;

    stim_proc: process
        procedure clear_capture is
        begin
            cap_idx <= 0;
            for i in 0 to 63 loop
                captured(i) <= (others => '0');
            end loop;
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;

        procedure push_byte(value : std_logic_vector(7 downto 0)) is
        begin
            rx_data  <= value;
            rx_valid <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
            rx_valid <= '0';
        end procedure;

        procedure send_text(text : string) is
        begin
            for i in text'range loop
                push_byte(std_logic_vector(to_unsigned(character'pos(text(i)), 8)));
            end loop;
            push_byte(x"0D");
            wait for 1 ns;
        end procedure;
    begin
        repeat_reset:
        for dummy in 0 to 0 loop
            reset_n <= '0';
            wait for 4 * CLK_PERIOD;
            reset_n <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
        end loop;

        assert resolution_mode = "00"
            report "After reset, resolution_mode must be RES0" severity error;
        assert speed_mode = "011"
            report "After reset, speed_mode must be SPEED3" severity error;

        clear_capture;
        send_text("RESET");
        assert reset_cmd = '1'
            report "The RESET command must generate a reset_cmd pulse" severity error;
        wait for 10 * CLK_PERIOD;
        assert captured(0) = x"4F" and captured(1) = x"4B"
            report "The response to RESET must start with OK" severity error;

        clear_capture;
        send_text("RES0");
        assert reset_cmd = '1'
            report "The RES0 command must restart the game" severity error;
        assert resolution_mode = "00"
            report "The RES0 command must select 640x480 mode" severity error;

        clear_capture;
        send_text("RES1");
        assert reset_cmd = '1'
            report "The RES1 command must restart the game" severity error;
        assert resolution_mode = "01"
            report "The RES1 command must select 800x600 mode" severity error;

        clear_capture;
        send_text("RES2");
        assert reset_cmd = '1'
            report "The RES2 command must restart the game" severity error;
        assert resolution_mode = "10"
            report "The RES2 command must select 1024x768 mode" severity error;

        clear_capture;
        send_text("SPEED1");
        assert reset_cmd = '1'
            report "The SPEED1 command must restart the game" severity error;
        assert speed_mode = "001"
            report "The SPEED1 command must select level 1" severity error;

        clear_capture;
        send_text("SPEED2");
        assert speed_mode = "010"
            report "The SPEED2 command must select level 2" severity error;

        clear_capture;
        send_text("SPEED3");
        assert speed_mode = "011"
            report "The SPEED3 command must select level 3" severity error;

        clear_capture;
        send_text("SPEED4");
        assert speed_mode = "100"
            report "The SPEED4 command must select level 4" severity error;

        clear_capture;
        send_text("SPEED5");
        assert speed_mode = "101"
            report "The SPEED5 command must select level 5" severity error;

        clear_capture;
        send_text("BAD");
        assert reset_cmd = '0'
            report "An unknown command must not trigger reset_cmd" severity error;
        wait for 10 * CLK_PERIOD;
        assert captured(0) = x"55"
            report "The response to an unknown command must start with the letter U" severity error;

        clear_capture;
        send_text("RES1");
        assert resolution_mode = "01"
            report "After a command sequence, resolution mode must update correctly" severity error;
        send_text("RESET");
        assert reset_cmd = '1'
            report "RESET must work after previous commands" severity error;
        send_text("SPEED5");
        assert speed_mode = "101"
            report "SPEED5 must work after previous commands" severity error;

        assert false
            report "tb_cmd_reset_parser completed."
            severity note;
        wait;
    end process;

end tb;
