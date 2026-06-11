library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pongSync is
end tb_pongSync;

architecture tb of tb_pongSync is

    -- Testbench scenarios:
    -- 1. Counter reset and frame start from coordinates (0, 0).
    -- 2. Verification of 640x480 mode: active area, frame_tick, HSYNC/VSYNC.
    -- 3. Verification of 800x600 mode: active area, frame_tick, HSYNC/VSYNC.
    -- 4. Verification of 1024x768 mode: active area, frame_tick, HSYNC/VSYNC.
    -- 5. Verification that frame length matches the selected mode parameters.

    constant CLK_PERIOD : time := 20 ns;

    signal clk        : std_logic := '0';
    signal reset_n    : std_logic := '0';
    signal mode       : std_logic_vector(1 downto 0) := "00";
    signal hsync      : std_logic;
    signal vsync      : std_logic;
    signal de         : std_logic;
    signal pixel_x    : unsigned(10 downto 0);
    signal pixel_y    : unsigned(10 downto 0);
    signal frame_tick : std_logic;

begin

    clk <= not clk after CLK_PERIOD / 2;

    dut: entity work.pongSync
        port map(
            pixel_clk  => clk,
            reset_n    => reset_n,
            mode       => mode,
            hsync      => hsync,
            vsync      => vsync,
            de         => de,
            pixel_x    => pixel_x,
            pixel_y    => pixel_y,
            frame_tick => frame_tick
        );

    stim_proc: process
        procedure apply_reset is
        begin
            reset_n <= '0';
            wait for 3 * CLK_PERIOD;
            reset_n <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;

        procedure wait_cycles(count : integer) is
        begin
            for i in 1 to count loop
                wait until rising_edge(clk);
            end loop;
            wait for 1 ns;
        end procedure;

        procedure check_mode(
            mode_value        : std_logic_vector(1 downto 0);
            h_visible         : integer;
            h_front_porch     : integer;
            h_total           : integer;
            v_visible         : integer;
            v_front_porch     : integer;
            v_total           : integer;
            sync_active_level : std_logic
        ) is
            variable frame_len : integer := 0;
        begin
            mode <= mode_value;
            apply_reset;

            assert pixel_x = 0 and pixel_y = 0
                report "After reset, pixel_x and pixel_y counters must be zero" severity error;
            assert de = '1'
                report "At the first visible pixel, DE must be active" severity error;

            apply_reset;
            wait_cycles(h_visible);
            assert de = '0'
                report "After the visible horizontal area, DE must go low" severity error;

            apply_reset;
            wait_cycles(h_visible + h_front_porch);
            assert hsync = sync_active_level
                report "HSYNC has an incorrect active level or an incorrect start moment" severity error;

            apply_reset;
            wait_cycles((v_visible + v_front_porch) * h_total);
            assert vsync = sync_active_level
                report "VSYNC has an incorrect active level or an incorrect start moment" severity error;

            apply_reset;
            wait until frame_tick = '1';
            frame_len := 0;
            loop
                wait until rising_edge(clk);
                wait for 1 ns;
                frame_len := frame_len + 1;
                exit when frame_tick = '1';
            end loop;

            assert frame_len = h_total * v_total
                report "Frame length does not match the selected mode parameters" severity error;
        end procedure;
    begin
        check_mode("00", 640, 16, 800, 480, 10, 525, '0');
        check_mode("01", 800, 40, 1056, 600, 1, 628, '1');
        check_mode("10", 1024, 24, 1344, 768, 3, 806, '0');

        assert false
            report "tb_pongSync completed."
            severity note;
        wait;
    end process;

end tb;
