LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pongImg is
   port(
        img_reset : in std_logic;
        pixel_clk : in std_logic;
        refresh : in std_logic;
        video_on : in std_logic;
        mode : in std_logic_vector(1 downto 0);
        speed_mode : in std_logic_vector(2 downto 0);
        lbutton_p1, rbutton_p1 : in std_logic;
        lbutton_p2, rbutton_p2 : in std_logic;
        pixel_x, linha : in integer range 2047 downto 0;
        red_out : out std_logic_vector(9 downto 0);
        green_out : out std_logic_vector(9 downto 0);
        blue_out : out std_logic_vector(9 downto 0)
        );
end pongImg;

architecture imagegen of pongImg is

    constant bar_width : integer := 15;
    constant bar_length : integer := 72;
    constant bar_vel : integer := 8;

    constant ball_size : integer := 8;
    signal active_width  : integer := 640;
    signal active_height : integer := 480;
    signal center_x      : integer := 320;
    signal bar_home_top  : integer := 204;
    signal ball_start_left : integer := 316;

    constant ball_start_top : integer := 19;

    constant lbar_pos_left : integer := 30;
    constant lbar_pos_right : integer := lbar_pos_left + bar_width - 1;
    signal lbar_top : integer range 0 to 2047 := 204;
    signal lbar_bottom : integer range 0 to 2047 := 275;

    signal rbar_pos_left : integer := 594;
    signal rbar_pos_right : integer := 608;
    signal rbar_top : integer range 0 to 2047 := 204;
    signal rbar_bottom : integer range 0 to 2047 := 275;

    signal ball_pos_left : integer range 0 to 2047 := 316;
    signal ball_pos_right : integer range 0 to 2047 := 323;
    signal ball_top : integer range 0 to 2047 := 19;
    signal ball_bottom : integer range 0 to 2047 := 26;
    signal ball_vel_x : integer range -8 to 8 := 3;
    signal ball_vel_y : integer range -8 to 8 := 3;
    signal ball_speed_mag : integer range 1 to 8 := 3;

    signal midline_right : integer := 320;
    signal midline_left : integer := 318;

    signal lbar_on, rbar_on, ball_on : std_logic;
    signal midline_on, topline_on, bottomline_on, leftline_on, rightline_on : std_logic;
    signal lbar_red, lbar_green, lbar_blue : std_logic_vector(9 downto 0);
    signal rbar_red, rbar_green, rbar_blue : std_logic_vector(9 downto 0);
    signal ball_red, ball_green, ball_blue : std_logic_vector(9 downto 0);
    signal ball_team : integer range 0 to 2 := 0;
    signal background_red, background_green, background_blue : std_logic_vector(9 downto 0);
    signal line_red, line_green, line_blue : std_logic_vector(9 downto 0);
    signal red_sig, green_sig, blue_sig : std_logic_vector(9 downto 0);

    constant time_restart : integer := 120;
    signal img_restart : std_logic := '0';
    signal rsdelay : integer range 0 to time_restart := 0;
    signal score_left : integer range 0 to 7 := 0;
    signal score_right : integer range 0 to 7 := 0;
    signal game_finished : std_logic := '0';

    constant digit_width : integer := 24;
    constant digit_height : integer := 40;
    signal digit_start_x_left : integer := 260;
    signal digit_start_x_right : integer := 360;
    constant digit_start_y : integer := 30;
    signal score_on : std_logic;
    signal score_red, score_green, score_blue : std_logic_vector(9 downto 0);

    signal text_on : std_logic;
    signal text_red, text_green, text_blue : std_logic_vector(9 downto 0);

    type font_rom_type is array(0 to 127, 0 to 6) of std_logic_vector(4 downto 0);
    constant font_rom : font_rom_type := (
        32 => ("00000","00000","00000","00000","00000","00000","00000"),
        48 => ("01110","10001","10001","10001","10001","10001","01110"),
        49 => ("00100","01100","00100","00100","00100","00100","01110"),
        50 => ("01110","10001","00001","00010","00100","01000","11111"),
        51 => ("01110","10001","00001","00110","00001","10001","01110"),
        52 => ("00010","00110","01010","10010","11111","00010","00010"),
        53 => ("11111","10000","11110","00001","00001","10001","01110"),
        54 => ("00110","01000","10000","11110","10001","10001","01110"),
        55 => ("11111","00001","00010","00100","01000","01000","01000"),
        56 => ("01110","10001","10001","01110","10001","10001","01110"),
        57 => ("01110","10001","10001","01111","00001","00010","01100"),
        65 => ("00100","01010","10001","11111","10001","10001","10001"),
        67 => ("01110","10001","10000","10000","10000","10001","01110"),
        69 => ("11111","10000","10000","11110","10000","10000","11111"),
        70 => ("11111","10000","10000","11110","10000","10000","10000"),
        71 => ("01110","10001","10000","10111","10001","10001","01110"),
        72 => ("10001","10001","10001","11111","10001","10001","10001"),
        73 => ("01110","00100","00100","00100","00100","00100","01110"),
        76 => ("10000","10000","10000","10000","10000","10000","11111"),
        77 => ("10001","11011","10101","10001","10001","10001","10001"),
        78 => ("10001","11001","10101","10011","10001","10001","10001"),
        79 => ("01110","10001","10001","10001","10001","10001","01110"),
        80 => ("11110","10001","10001","11110","10000","10000","10000"),
        82 => ("11110","10001","10001","11110","10100","10010","10001"),
        83 => ("01111","10000","10000","01110","00001","00001","11110"),
        84 => ("11111","00100","00100","00100","00100","00100","00100"),
        86 => ("10001","10001","10001","10001","10001","01010","00100"),
        87 => ("10001","10001","10001","10001","10101","11011","10001"),
        others => ("00000","00000","00000","00000","00000","00000","00000")
    );

begin

    process(mode)
    begin
        case mode is
            when "01" =>
                active_width <= 800;
                active_height <= 600;
            when "10" =>
                active_width <= 1024;
                active_height <= 768;
            when others =>
                active_width <= 640;
                active_height <= 480;
        end case;
    end process;

    process(speed_mode)
    begin
        case speed_mode is
            when "001" =>
                ball_speed_mag <= 1;
            when "010" =>
                ball_speed_mag <= 2;
            when "100" =>
                ball_speed_mag <= 4;
            when "101" =>
                ball_speed_mag <= 5;
            when others =>
                ball_speed_mag <= 3;
        end case;
    end process;

    center_x <= active_width / 2;
    bar_home_top <= (active_height / 2) - (bar_length / 2);
    ball_start_left <= center_x - (ball_size / 2);

    midline_left <= center_x - 2;
    midline_right <= center_x;

    rbar_pos_left <= active_width - 46;
    rbar_pos_right <= rbar_pos_left + bar_width - 1;

    digit_start_x_left <= center_x - 60;
    digit_start_x_right <= center_x + 40;

    process(pixel_clk)
        variable next_lbar_top      : integer;
        variable next_rbar_top      : integer;
        variable next_ball_pos_left : integer;
        variable next_ball_top      : integer;
        variable next_ball_vel_x    : integer;
        variable next_ball_vel_y    : integer;
        variable next_ball_team     : integer range 0 to 2;
        variable next_img_restart   : std_logic;
        variable next_rsdelay       : integer range 0 to time_restart;
        variable next_score_left    : integer range 0 to 7;
        variable next_score_right   : integer range 0 to 7;
        variable next_game_finished : std_logic;
        variable lbar_bottom_v      : integer;
        variable rbar_bottom_v      : integer;
        variable ball_pos_right_v   : integer;
        variable ball_bottom_v      : integer;
    begin
        if rising_edge(pixel_clk) then
            if img_reset = '1' then
                lbar_top <= bar_home_top;
                rbar_top <= bar_home_top;
                ball_pos_left <= ball_start_left;
                ball_top <= ball_start_top;
                ball_vel_x <= ball_speed_mag;
                ball_vel_y <= ball_speed_mag;
                ball_team <= 0;
                img_restart <= '0';
                rsdelay <= 0;
                score_left <= 0;
                score_right <= 0;
                game_finished <= '0';
            elsif refresh = '1' then
                next_lbar_top := lbar_top;
                next_rbar_top := rbar_top;
                next_ball_pos_left := ball_pos_left;
                next_ball_top := ball_top;
                next_ball_vel_x := ball_vel_x;
                next_ball_vel_y := ball_vel_y;
                next_ball_team := ball_team;
                next_img_restart := img_restart;
                next_rsdelay := rsdelay;
                next_score_left := score_left;
                next_score_right := score_right;
                next_game_finished := game_finished;

                if next_game_finished = '0' then
                    if (rbutton_p1 = '0') and (lbutton_p1 = '1') and (next_lbar_top >= 5) then
                        next_lbar_top := next_lbar_top - bar_vel;
                    elsif (lbutton_p1 = '0') and (rbutton_p1 = '1') and
                          ((next_lbar_top + bar_length - 1 + bar_vel) <= active_height - 5) then
                        next_lbar_top := next_lbar_top + bar_vel;
                    end if;

                    if (rbutton_p2 = '0') and (lbutton_p2 = '1') and (next_rbar_top >= 5) then
                        next_rbar_top := next_rbar_top - bar_vel;
                    elsif (lbutton_p2 = '0') and (rbutton_p2 = '1') and
                          ((next_rbar_top + bar_length - 1 + bar_vel) <= active_height - 5) then
                        next_rbar_top := next_rbar_top + bar_vel;
                    end if;
                end if;

                lbar_bottom_v := next_lbar_top + bar_length - 1;
                rbar_bottom_v := next_rbar_top + bar_length - 1;
                ball_pos_right_v := ball_pos_left + ball_size - 1;
                ball_bottom_v := ball_top + ball_size - 1;

                if next_game_finished = '1' then
                    next_img_restart := '0';
                    next_rsdelay := 0;
                elsif next_img_restart = '1' then
                    next_ball_pos_left := ball_start_left;
                    next_ball_top := ball_start_top;

                    if next_rsdelay = time_restart then
                        next_rsdelay := 0;
                        next_img_restart := '0';
                    else
                        next_rsdelay := next_rsdelay + 1;
                    end if;
                else
                    if ball_bottom_v >= active_height - 4 then
                        next_ball_vel_y := -ball_speed_mag;
                    elsif ball_top <= 4 then
                        next_ball_vel_y := ball_speed_mag;
                    end if;

                    if ball_pos_left <= 4 then
                        if next_score_right < 7 then
                            next_score_right := next_score_right + 1;
                            if next_score_right = 7 then
                                next_game_finished := '1';
                            else
                                next_img_restart := '1';
                            end if;
                        end if;
                        next_ball_pos_left := ball_start_left;
                        next_ball_top := ball_start_top;
                        next_ball_vel_x := ball_speed_mag;
                        next_ball_vel_y := ball_speed_mag;
                        next_ball_team := 0;
                        next_rsdelay := 0;
                    elsif ball_pos_right_v >= active_width - 4 then
                        if next_score_left < 7 then
                            next_score_left := next_score_left + 1;
                            if next_score_left = 7 then
                                next_game_finished := '1';
                            else
                                next_img_restart := '1';
                            end if;
                        end if;
                        next_ball_pos_left := ball_start_left;
                        next_ball_top := ball_start_top;
                        next_ball_vel_x := -ball_speed_mag;
                        next_ball_vel_y := -ball_speed_mag;
                        next_ball_team := 0;
                        next_rsdelay := 0;
                    elsif ball_pos_left <= lbar_pos_right + 4 then
                        if (ball_bottom_v >= next_lbar_top - 6) and (ball_top <= lbar_bottom_v + 6) then
                            next_ball_vel_x := ball_speed_mag;
                            next_ball_pos_left := ball_pos_left + ball_speed_mag;
                            next_ball_top := ball_top + next_ball_vel_y;
                            next_ball_team := 1;
                        else
                            next_ball_pos_left := ball_pos_left + next_ball_vel_x;
                            next_ball_top := ball_top + next_ball_vel_y;
                        end if;
                    elsif ball_pos_right_v >= rbar_pos_left - 4 then
                        if (ball_bottom_v >= next_rbar_top - 6) and (ball_top <= rbar_bottom_v + 6) then
                            next_ball_vel_x := -ball_speed_mag;
                            next_ball_pos_left := ball_pos_left - ball_speed_mag;
                            next_ball_top := ball_top + next_ball_vel_y;
                            next_ball_team := 2;
                        else
                            next_ball_pos_left := ball_pos_left + next_ball_vel_x;
                            next_ball_top := ball_top + next_ball_vel_y;
                        end if;
                    else
                        next_ball_pos_left := ball_pos_left + next_ball_vel_x;
                        next_ball_top := ball_top + next_ball_vel_y;
                    end if;
                end if;

                lbar_top <= next_lbar_top;
                rbar_top <= next_rbar_top;
                ball_pos_left <= next_ball_pos_left;
                ball_top <= next_ball_top;
                ball_vel_x <= next_ball_vel_x;
                ball_vel_y <= next_ball_vel_y;
                ball_team <= next_ball_team;
                img_restart <= next_img_restart;
                rsdelay <= next_rsdelay;
                score_left <= next_score_left;
                score_right <= next_score_right;
                game_finished <= next_game_finished;
            end if;
        end if;
    end process;

    lbar_bottom <= lbar_top + bar_length - 1;
    rbar_bottom <= rbar_top + bar_length - 1;
    ball_pos_right <= ball_pos_left + ball_size - 1;
    ball_bottom <= ball_top + ball_size - 1;

    midline_on <= '1' when (midline_right >= pixel_x) and (midline_left <= pixel_x) else '0';
    topline_on <= '1' when (2 >= linha) else '0';
    leftline_on <= '1' when (2 >= pixel_x) else '0';
    rightline_on <= '1' when (pixel_x >= active_width - 3) else '0';
    bottomline_on <= '1' when (linha >= active_height - 3) else '0';

    line_red <= "0110011111";
    line_green <= "0110011111";
    line_blue <= "0110011111";

    process(pixel_x, linha, score_left, score_right, digit_start_x_left, digit_start_x_right)
        variable rel_x_l, rel_y_l : integer;
        variable rel_x_r, rel_y_r : integer;
        variable digit_l, digit_r : integer;
    begin
        score_on <= '0';
        score_red <= "1111110000";
        score_green <= "1111110000";
        score_blue <= "0000000000";

        if pixel_x >= digit_start_x_left and pixel_x < digit_start_x_left + digit_width and
           linha >= digit_start_y and linha < digit_start_y + digit_height then
            rel_x_l := (pixel_x - digit_start_x_left) / (digit_width / 5);
            rel_y_l := (linha - digit_start_y) / (digit_height / 7);
            digit_l := score_left;
            if rel_x_l >= 0 and rel_x_l < 5 and rel_y_l >= 0 and rel_y_l < 7 then
                if font_rom(48 + digit_l, rel_y_l)(4 - rel_x_l) = '1' then
                    score_on <= '1';
                end if;
            end if;
        end if;

        if pixel_x >= digit_start_x_right and pixel_x < digit_start_x_right + digit_width and
           linha >= digit_start_y and linha < digit_start_y + digit_height then
            rel_x_r := (pixel_x - digit_start_x_right) / (digit_width / 5);
            rel_y_r := (linha - digit_start_y) / (digit_height / 7);
            digit_r := score_right;
            if rel_x_r >= 0 and rel_x_r < 5 and rel_y_r >= 0 and rel_y_r < 7 then
                if font_rom(48 + digit_r, rel_y_r)(4 - rel_x_r) = '1' then
                    score_on <= '1';
                end if;
            end if;
        end if;
    end process;

    process(pixel_x, linha, game_finished, score_left, score_right, center_x)
        variable char_index : integer;
        variable char_code : integer;
        variable char_x, char_y : integer;
        variable font_data : std_logic_vector(4 downto 0);
    begin
        text_on <= '0';
        text_red <= "1111110000";
        text_green <= "1111110000";
        text_blue <= "0000000000";

        if game_finished = '1' then
            if linha >= 210 and linha <= 216 then
                char_index := (pixel_x - (center_x - 110)) / 6;
                if char_index >= 0 and char_index <= 8 then
                    case char_index is
                        when 0 => char_code := 71;
                        when 1 => char_code := 65;
                        when 2 => char_code := 77;
                        when 3 => char_code := 69;
                        when 4 => char_code := 32;
                        when 5 => char_code := 79;
                        when 6 => char_code := 86;
                        when 7 => char_code := 69;
                        when 8 => char_code := 82;
                        when others => char_code := 32;
                    end case;
                    char_x := (pixel_x - (center_x - 110)) - (char_index * 6);
                    char_y := linha - 210;
                    if char_x >= 0 and char_x < 5 and char_y >= 0 and char_y < 7 then
                        font_data := font_rom(char_code, char_y);
                        if font_data(4 - char_x) = '1' then
                            text_on <= '1';
                            text_red <= "1111111111";
                            text_green <= "0000000000";
                            text_blue <= "0000000000";
                        end if;
                    end if;
                end if;
            end if;

            if score_left = 7 then
                if linha >= 230 and linha <= 236 then
                    char_index := (pixel_x - (center_x - 90)) / 6;
                    if char_index >= 0 and char_index <= 8 then
                        case char_index is
                            when 0 => char_code := 76;
                            when 1 => char_code := 69;
                            when 2 => char_code := 70;
                            when 3 => char_code := 84;
                            when 4 => char_code := 32;
                            when 5 => char_code := 87;
                            when 6 => char_code := 73;
                            when 7 => char_code := 78;
                            when 8 => char_code := 83;
                            when others => char_code := 32;
                        end case;
                        char_x := (pixel_x - (center_x - 90)) - (char_index * 6);
                        char_y := linha - 230;
                        if char_x >= 0 and char_x < 5 and char_y >= 0 and char_y < 7 then
                            font_data := font_rom(char_code, char_y);
                            if font_data(4 - char_x) = '1' then
                                text_on <= '1';
                                text_red <= "1111111111";
                                text_green <= "1111111111";
                                text_blue <= "0000000000";
                            end if;
                        end if;
                    end if;
                end if;
            elsif score_right = 7 then
                if linha >= 230 and linha <= 236 then
                    char_index := (pixel_x - (center_x - 110)) / 6;
                    if char_index >= 0 and char_index <= 9 then
                        case char_index is
                            when 0 => char_code := 82;
                            when 1 => char_code := 73;
                            when 2 => char_code := 71;
                            when 3 => char_code := 72;
                            when 4 => char_code := 84;
                            when 5 => char_code := 32;
                            when 6 => char_code := 87;
                            when 7 => char_code := 73;
                            when 8 => char_code := 78;
                            when 9 => char_code := 83;
                            when others => char_code := 32;
                        end case;
                        char_x := (pixel_x - (center_x - 110)) - (char_index * 6);
                        char_y := linha - 230;
                        if char_x >= 0 and char_x < 5 and char_y >= 0 and char_y < 7 then
                            font_data := font_rom(char_code, char_y);
                            if font_data(4 - char_x) = '1' then
                                text_on <= '1';
                                text_red <= "1111111111";
                                text_green <= "1111111111";
                                text_blue <= "0000000000";
                            end if;
                        end if;
                    end if;
                end if;
            end if;

            if linha >= 260 and linha <= 266 then
                char_index := (pixel_x - (center_x - 120)) / 6;
                if char_index >= 0 and char_index <= 10 then
                    case char_index is
                        when 0 => char_code := 80;
                        when 1 => char_code := 82;
                        when 2 => char_code := 69;
                        when 3 => char_code := 83;
                        when 4 => char_code := 83;
                        when 5 => char_code := 32;
                        when 6 => char_code := 82;
                        when 7 => char_code := 69;
                        when 8 => char_code := 83;
                        when 9 => char_code := 69;
                        when 10 => char_code := 84;
                        when others => char_code := 32;
                    end case;
                    char_x := (pixel_x - (center_x - 120)) - (char_index * 6);
                    char_y := linha - 260;
                    if char_x >= 0 and char_x < 5 and char_y >= 0 and char_y < 7 then
                        font_data := font_rom(char_code, char_y);
                        if font_data(4 - char_x) = '1' then
                            text_on <= '1';
                            text_red <= "0111111111";
                            text_green <= "0111111111";
                            text_blue <= "0111111111";
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    lbar_on <= '1' when (lbar_pos_right >= pixel_x) and (pixel_x >= lbar_pos_left) and
                        (lbar_bottom >= linha) and (linha >= lbar_top)
               else '0';
    lbar_red <= "1001111111";
    lbar_green <= "0000000000";
    lbar_blue <= "0000000000";

    rbar_on <= '1' when (rbar_pos_right >= pixel_x) and (pixel_x >= rbar_pos_left) and
                        (rbar_bottom >= linha) and (linha >= rbar_top)
               else '0';
    rbar_red <= "0000000000";
    rbar_green <= "0000000000";
    rbar_blue <= "1001111111";

    ball_on <= '1' when (ball_pos_right >= pixel_x) and (pixel_x >= ball_pos_left) and
                        (ball_bottom >= linha) and (linha >= ball_top)
               else '0';

    process(ball_team)
    begin
        case ball_team is
            when 1 =>
                ball_red <= "1111111000";
                ball_green <= "0000000000";
                ball_blue <= "0000000000";
            when 2 =>
                ball_red <= "0000000000";
                ball_green <= "0000000000";
                ball_blue <= "1111111000";
            when others =>
                ball_red <= "0000000000";
                ball_green <= "0000000000";
                ball_blue <= "0000000000";
        end case;
    end process;

    background_red <= (others => '1');
    background_green <= (others => '1');
    background_blue <= (others => '1');

    process(video_on, lbar_on, lbar_red, lbar_green, lbar_blue,
            rbar_on, rbar_red, rbar_green, rbar_blue,
            ball_on, ball_red, ball_green, ball_blue,
            background_red, background_green, background_blue,
            midline_on, topline_on, bottomline_on, leftline_on, rightline_on,
            line_red, line_green, line_blue,
            score_on, score_red, score_green, score_blue,
            text_on, text_red, text_green, text_blue)
    begin
        if video_on = '0' then
            red_sig <= (others => '0');
            green_sig <= (others => '0');
            blue_sig <= (others => '0');
        else
            if text_on = '1' then
                red_sig <= text_red;
                green_sig <= text_green;
                blue_sig <= text_blue;
            elsif score_on = '1' then
                red_sig <= score_red;
                green_sig <= score_green;
                blue_sig <= score_blue;
            elsif lbar_on = '1' and ball_on = '0' then
                red_sig <= lbar_red;
                green_sig <= lbar_green;
                blue_sig <= lbar_blue;
            elsif rbar_on = '1' and ball_on = '0' then
                red_sig <= rbar_red;
                green_sig <= rbar_green;
                blue_sig <= rbar_blue;
            elsif ball_on = '1' then
                red_sig <= ball_red;
                green_sig <= ball_green;
                blue_sig <= ball_blue;
            elsif midline_on = '1' or topline_on = '1' or rightline_on = '1' or
                  leftline_on = '1' or bottomline_on = '1' then
                red_sig <= line_red;
                green_sig <= line_green;
                blue_sig <= line_blue;
            else
                red_sig <= background_red;
                green_sig <= background_green;
                blue_sig <= background_blue;
            end if;
        end if;
    end process;

    red_out <= red_sig;
    green_out <= green_sig;
    blue_out <= blue_sig;

end imagegen;
