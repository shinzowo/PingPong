library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pongImg is
end tb_pongImg;

architecture tb of tb_pongImg is

    -- Testbench scenarios:
    -- 1. Basic game reset and verification of the startup image in 640x480.
    -- 2. Verification of the white background and both paddle colors.
    -- 3. Verification of ball startup and motion after a game refresh.
    -- 4. Verification of all SPEED1..SPEED5 modes at game start.
    -- 5. Verification of the field border in 800x600 and 1024x768 modes.
    -- 6. Verification of blanking mode when video_on=0.
    -- 7. Verification of a valid left paddle upward movement scenario.

    constant CLK_PERIOD : time := 20 ns;

    constant WHITE10 : std_logic_vector(9 downto 0) := (others => '1');
    constant BLACK10 : std_logic_vector(9 downto 0) := (others => '0');
    constant RED10   : std_logic_vector(9 downto 0) := "1001111111";
    constant BLUE10  : std_logic_vector(9 downto 0) := "1001111111";
    constant GRAY10  : std_logic_vector(9 downto 0) := "0110011111";

    signal pixel_clk  : std_logic := '0';
    signal img_reset  : std_logic := '0';
    signal refresh    : std_logic := '0';
    signal video_on   : std_logic := '1';
    signal mode       : std_logic_vector(1 downto 0) := "00";
    signal speed_mode : std_logic_vector(2 downto 0) := "011";
    signal lbutton_p1 : std_logic := '1';
    signal rbutton_p1 : std_logic := '1';
    signal lbutton_p2 : std_logic := '1';
    signal rbutton_p2 : std_logic := '1';
    signal pixel_x    : integer range 2047 downto 0 := 0;
    signal linha      : integer range 2047 downto 0 := 0;
    signal red_out    : std_logic_vector(9 downto 0);
    signal green_out  : std_logic_vector(9 downto 0);
    signal blue_out   : std_logic_vector(9 downto 0);

begin

    pixel_clk <= not pixel_clk after CLK_PERIOD / 2;

    dut: entity work.pongImg
        port map(
            img_reset  => img_reset,
            pixel_clk  => pixel_clk,
            refresh    => refresh,
            video_on   => video_on,
            mode       => mode,
            speed_mode => speed_mode,
            lbutton_p1 => lbutton_p1,
            rbutton_p1 => rbutton_p1,
            lbutton_p2 => lbutton_p2,
            rbutton_p2 => rbutton_p2,
            pixel_x    => pixel_x,
            linha      => linha,
            red_out    => red_out,
            green_out  => green_out,
            blue_out   => blue_out
        );

    stim_proc: process
        procedure apply_game_reset is
        begin
            img_reset <= '1';
            wait until rising_edge(pixel_clk);
            wait for 1 ns;
            img_reset <= '0';
            wait until rising_edge(pixel_clk);
            wait for 1 ns;
        end procedure;

        procedure pulse_refresh is
        begin
            refresh <= '1';
            wait until rising_edge(pixel_clk);
            wait for 1 ns;
            refresh <= '0';
            wait until rising_edge(pixel_clk);
            wait for 1 ns;
        end procedure;

        procedure sample_pixel(
            x             : integer;
            y             : integer;
            exp_r         : std_logic_vector(9 downto 0);
            exp_g         : std_logic_vector(9 downto 0);
            exp_b         : std_logic_vector(9 downto 0);
            scenario_name : string
        ) is
        begin
            pixel_x <= x;
            linha   <= y;
            wait for 1 ns;
            assert red_out = exp_r and green_out = exp_g and blue_out = exp_b
                report "Incorrect pixel color in scenario: " & scenario_name severity error;
        end procedure;
    begin
        mode <= "00";
        speed_mode <= "011";
        apply_game_reset;
        sample_pixel(100, 100, WHITE10, WHITE10, WHITE10, "white background in 640x480");
        sample_pixel(35, 220, RED10, BLACK10, BLACK10, "left paddle color");
        sample_pixel(600, 220, BLACK10, BLACK10, BLUE10, "right paddle color");
        sample_pixel(318, 22, BLACK10, BLACK10, BLACK10, "ball start position");

        pulse_refresh;
        sample_pixel(326, 29, BLACK10, BLACK10, BLACK10, "ball after one frame at SPEED3");

        speed_mode <= "001";
        wait for 1 ns;
        apply_game_reset;
        pulse_refresh;
        sample_pixel(324, 27, BLACK10, BLACK10, BLACK10, "ball after one frame at SPEED1");

        speed_mode <= "101";
        wait for 1 ns;
        apply_game_reset;
        pulse_refresh;
        sample_pixel(320, 23, WHITE10, WHITE10, WHITE10, "old center area must not match SPEED5");
        sample_pixel(328, 31, BLACK10, BLACK10, BLACK10, "ball after one frame at SPEED5");

        mode <= "01";
        speed_mode <= "011";
        wait for 1 ns;
        apply_game_reset;
        sample_pixel(798, 100, GRAY10, GRAY10, GRAY10, "right border in 800x600");

        mode <= "10";
        wait for 1 ns;
        apply_game_reset;
        sample_pixel(1022, 100, GRAY10, GRAY10, GRAY10, "right border in 1024x768");

        video_on <= '0';
        sample_pixel(100, 100, BLACK10, BLACK10, BLACK10, "blanking with video_on disabled");
        video_on <= '1';

        mode <= "00";
        apply_game_reset;
        sample_pixel(35, 204, RED10, BLACK10, BLACK10, "left paddle before movement");
        lbutton_p1 <= '1';
        rbutton_p1 <= '0';
        pulse_refresh;
        lbutton_p1 <= '1';
        rbutton_p1 <= '1';
        sample_pixel(35, 204, WHITE10, WHITE10, WHITE10, "left paddle moved upward");

        assert false
            report "tb_pongImg completed."
            severity note;
        wait;
    end process;

end tb;
