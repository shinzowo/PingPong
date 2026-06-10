LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pongImg is
   port(
        img_reset : in std_logic;
		  refresh : in std_logic;
        clock_25 : in std_logic;
        video_on : in std_logic;
		  lbutton_p1, rbutton_p1 : in std_logic;
	     lbutton_p2, rbutton_p2 : in std_logic;
        pixel_x, linha : in integer range 1023 downto 0;
        red_out : out std_logic_vector(9 downto 0);
		  green_out : out std_logic_vector(9 downto 0);
        blue_out : out std_logic_vector(9 downto 0)
        );
end pongImg;

architecture imagegen of pongImg is

	constant bar_width : integer := 15;
	constant bar_length : integer := 72;
	constant bar_top : integer := 204;
	constant bar_bottom : integer := 275;

	constant bar_vel : integer := 8;
	signal ball_vel_x : integer := 3;
	signal ball_vel_y : integer := 3;
	constant ball_vel_y_n : integer := -3;
	constant ball_vel_y_p : integer := 3;
	constant ball_vel_x_n : integer := -3;
	constant ball_vel_x_p : integer := 3;
  
	constant lbar_pos_left : integer := 30;
	constant lbar_pos_right : integer := 44;
	signal lbar_top : integer range 1023 downto 0 := 204;
	signal lbar_bottom : integer range 1023 downto 0 := 275;
 
	constant rbar_pos_left : integer :=  594;
	constant rbar_pos_right : integer := 609;
	signal rbar_top : integer range 1023 downto 0 := 204;
	signal rbar_bottom : integer range 1023 downto 0 := 275;

	constant init_ball_pos_left : integer := 316;
	constant init_ball_pos_right : integer := 323;
	constant init_ball_top : integer := 19;
	constant init_ball_bottom : integer := 26;
	signal ball_pos_left : integer range 1023 downto 0 := 316;
	signal ball_pos_right : integer range 1023 downto 0 := 323;
	signal ball_pos_left_next : integer range 1023 downto 0;
	signal ball_top_next : integer range 1023 downto 0;
	signal ball_top : integer range 1023 downto 0 := 19;
	signal ball_bottom : integer range 1023 downto 0 := 26;
	
	constant midline_right : integer := 320;
	constant midline_left : integer := 318;
	
	signal lbar_on, rbar_on, ball_on : std_logic;
	signal midline_on, topline_on, bottomline_on, leftline_on, rightline_on : std_logic;
	signal lbar_red, lbar_green, lbar_blue : std_logic_vector(9 downto 0);
	signal rbar_red, rbar_green, rbar_blue : std_logic_vector(9 downto 0);
	signal ball_red, ball_green, ball_blue : std_logic_vector(9 downto 0);
	signal ball_team : integer range 2 downto 0 := 0;
	signal background_red, background_green, background_blue : std_logic_vector(9 downto 0);
	signal line_red, line_green, line_blue : std_logic_vector(9 downto 0);
	
	signal red_sig, green_sig, blue_sig : std_logic_vector(9 downto 0);
	
	signal framerate : std_logic;
	
	constant time_restart : integer := 120;
	signal img_restart : std_logic := '0';
	signal rsdelay : integer range 1023 downto 0 := 0;	

	signal score_left : integer range 0 to 7 := 0;
	signal score_right : integer range 0 to 7 := 0;
	signal game_finished : std_logic := '0';
	
	constant digit_width : integer := 24;
	constant digit_height : integer := 40;
	constant digit_start_x_left : integer := 260;
	constant digit_start_x_right : integer := 360;
	constant digit_start_y : integer := 30;
	
	signal score_on : std_logic;
	signal score_red, score_green, score_blue : std_logic_vector(9 downto 0);
	
	signal text_on : std_logic;
	signal text_red, text_green, text_blue : std_logic_vector(9 downto 0);
	
-- Font ROM (5x7 pixels for each character)
	type font_rom_type is array(0 to 127, 0 to 6) of std_logic_vector(4 downto 0);
	constant font_rom : font_rom_type := (
		-- Space (32)
		32 => ("00000","00000","00000","00000","00000","00000","00000"),
		-- '0' - '9' (48-57)
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
		-- 'A' - 'Z' (65-90)
		65 => ("00100","01010","10001","11111","10001","10001","10001"),
		66 => ("11110","10001","10001","11110","10001","10001","11110"),
		67 => ("01110","10001","10000","10000","10000","10001","01110"),
		68 => ("11110","10001","10001","10001","10001","10001","11110"),
		69 => ("11111","10000","10000","11110","10000","10000","11111"),
		70 => ("11111","10000","10000","11110","10000","10000","10000"),
		71 => ("01110","10001","10000","10111","10001","10001","01110"),
		72 => ("10001","10001","10001","11111","10001","10001","10001"),
		73 => ("01110","00100","00100","00100","00100","00100","01110"),
		74 => ("00001","00001","00001","00001","10001","10001","01110"),
		75 => ("10001","10010","10100","11000","10100","10010","10001"),
		76 => ("10000","10000","10000","10000","10000","10000","11111"),
		77 => ("10001","11011","10101","10001","10001","10001","10001"),
		78 => ("10001","11001","10101","10011","10001","10001","10001"),
		79 => ("01110","10001","10001","10001","10001","10001","01110"),
		80 => ("11110","10001","10001","11110","10000","10000","10000"),
		81 => ("01110","10001","10001","10001","10101","10010","01101"),
		82 => ("11110","10001","10001","11110","10100","10010","10001"),
		83 => ("01111","10000","10000","01110","00001","00001","11110"),
		84 => ("11111","00100","00100","00100","00100","00100","00100"),
		85 => ("10001","10001","10001","10001","10001","10001","01110"),
		86 => ("10001","10001","10001","10001","10001","01010","00100"),
		87 => ("10001","10001","10001","10001","10101","11011","10001"),
		88 => ("10001","10001","01010","00100","01010","10001","10001"),
		89 => ("10001","10001","01010","00100","00100","00100","00100"),
		90 => ("11111","00001","00010","00100","01000","10000","11111"),
		others => ("00000","00000","00000","00000","00000","00000","00000")
	);

begin

	framerate <= refresh;
	 

	midline_on <= '1' when (midline_right >= pixel_x) and (midline_left <= pixel_x) else '0';
	topline_on <= '1' when (2 >= linha) else '0';
	leftline_on <= '1' when (2 >= pixel_x) else '0';
	rightline_on <= '1' when (pixel_x >= 637) else '0';
	bottomline_on <= '1' when (linha >= 477) else '0';

	line_red <= "0110011111";
	line_green <= "0110011111";
	line_blue <= "0110011111";
	
-- Score display generation --
process(pixel_x, linha, score_left, score_right)
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
			if font_rom(48 + digit_l, rel_y_l)(4-rel_x_l) = '1' then
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
			if font_rom(48 + digit_r, rel_y_r)(4-rel_x_r) = '1' then
				score_on <= '1';
			end if;
		end if;
	end if;
end process;

process(pixel_x, linha, game_finished, score_left, score_right)
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
			char_index := (pixel_x - 210) / 6;
			if char_index >= 0 and char_index <= 8 then
				case char_index is
					when 0 => char_code := 71;  -- G
					when 1 => char_code := 65;  -- A
					when 2 => char_code := 77;  -- M
					when 3 => char_code := 69;  -- E
					when 4 => char_code := 32;  -- space
					when 5 => char_code := 79;  -- O
					when 6 => char_code := 86;  -- V
					when 7 => char_code := 69;  -- E
					when 8 => char_code := 82;  -- R
					when others => char_code := 32;
				end case;
				char_x := (pixel_x - 210) - (char_index * 6);
				char_y := linha - 210;
				if char_x >= 0 and char_x < 5 and char_y >= 0 and char_y < 7 then
					font_data := font_rom(char_code, char_y);
					if font_data(4-char_x) = '1' then
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
				char_index := (pixel_x - 230) / 6;
				if char_index >= 0 and char_index <= 8 then
					case char_index is
						when 0 => char_code := 76;  -- L
						when 1 => char_code := 69;  -- E
						when 2 => char_code := 70;  -- F
						when 3 => char_code := 84;  -- T
						when 4 => char_code := 32;  -- space
						when 5 => char_code := 87;  -- W
						when 6 => char_code := 73;  -- I
						when 7 => char_code := 78;  -- N
						when 8 => char_code := 83;  -- S
						when others => char_code := 32;
					end case;
					char_x := (pixel_x - 230) - (char_index * 6);
					char_y := linha - 230;
					if char_x >= 0 and char_x < 5 and char_y >= 0 and char_y < 7 then
						font_data := font_rom(char_code, char_y);
						if font_data(4-char_x) = '1' then
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
				char_index := (pixel_x - 210) / 6;
				if char_index >= 0 and char_index <= 9 then
					case char_index is
						when 0 => char_code := 82;  -- R
						when 1 => char_code := 73;  -- I
						when 2 => char_code := 71;  -- G
						when 3 => char_code := 72;  -- H
						when 4 => char_code := 84;  -- T
						when 5 => char_code := 32;  -- space
						when 6 => char_code := 87;  -- W
						when 7 => char_code := 73;  -- I
						when 8 => char_code := 78;  -- N
						when 9 => char_code := 83;  -- S
						when others => char_code := 32;
					end case;
					char_x := (pixel_x - 210) - (char_index * 6);
					char_y := linha - 230;
					if char_x >= 0 and char_x < 5 and char_y >= 0 and char_y < 7 then
						font_data := font_rom(char_code, char_y);
						if font_data(4-char_x) = '1' then
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
			char_index := (pixel_x - 200) / 6;
			if char_index >= 0 and char_index <= 10 then
				case char_index is
					when 0 => char_code := 80;  -- P
					when 1 => char_code := 82;  -- R
					when 2 => char_code := 69;  -- E
					when 3 => char_code := 83;  -- S
					when 4 => char_code := 83;  -- S
					when 5 => char_code := 32;  -- space
					when 6 => char_code := 82;  -- R
					when 7 => char_code := 69;  -- E
					when 8 => char_code := 83;  -- S
					when 9 => char_code := 69;  -- E
					when 10 => char_code := 84; -- T
					when others => char_code := 32;
				end case;
				char_x := (pixel_x - 200) - (char_index * 6);
				char_y := linha - 260;
				if char_x >= 0 and char_x < 5 and char_y >= 0 and char_y < 7 then
					font_data := font_rom(char_code, char_y);
					if font_data(4-char_x) = '1' then
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

process(framerate, img_reset, img_restart, game_finished,
                   lbar_top, lbar_bottom, lbutton_p1, rbutton_p1)
begin
	if (img_reset = '1') then
		lbar_top <= bar_top;
	elsif (framerate'event and framerate = '1') then
		if game_finished = '0' then
			if (rbutton_p1 = '0' and lbutton_p1 = '1' and lbar_top >= 5) then
				lbar_top <= lbar_top - bar_vel;
			elsif (lbutton_p1 = '0' and rbutton_p1 = '1' and lbar_bottom <= 475) then
				lbar_top <= lbar_top + bar_vel;
			else  
				lbar_top <= lbar_top;
			end if;
		end if;
	end if;
end process;
	 
	lbar_bottom <= lbar_top + bar_length - 1; 
	 	 
   lbar_on <= '1' when (lbar_pos_right >= pixel_x) and (pixel_x >= lbar_pos_left)
                  and (lbar_bottom >= linha) and (linha >= lbar_top)
                  else '0';

	lbar_red <= "1001111111";
	lbar_green <= "0000000000";
	lbar_blue <= "0000000000";

process(framerate, img_reset, img_restart, game_finished,
                   rbar_top, rbar_bottom, lbutton_p2, rbutton_p2)
begin
	if (img_reset = '1') then
		rbar_top <= bar_top;
	elsif (framerate'event and framerate = '1') then
		if game_finished = '0' then
			if (rbutton_p2 = '0' and lbutton_p2 = '1' and rbar_top >= 5) then
				rbar_top <= rbar_top - bar_vel;
			elsif (lbutton_p2 = '0' and rbutton_p2 = '1' and rbar_bottom <= 475) then
				rbar_top <= rbar_top + bar_vel;
		   else 
				rbar_top <= rbar_top;
			end if;
		end if;
	end if;	
end process;

	rbar_bottom <= rbar_top + bar_length - 1;

   rbar_on <= '1' when (rbar_pos_right >= pixel_x) and (pixel_x >= rbar_pos_left)
                  and (rbar_bottom >= linha) and (linha >= rbar_top)
                  else '0';

	rbar_red <= "0000000000";
	rbar_green <= "0000000000";
	rbar_blue <= "1001111111";

process(framerate, img_reset, img_restart, rsdelay, ball_team, game_finished,
                   ball_pos_right, ball_pos_left, ball_top, ball_bottom,
				   ball_pos_left_next, ball_top_next)
begin
	if (img_reset = '1') then
		ball_top_next <= init_ball_top;
		ball_pos_left_next <= init_ball_pos_left;
		ball_team <= 0;
		score_left <= 0;
		score_right <= 0;
		game_finished <= '0';
   elsif(framerate'event and framerate = '1') then
		if game_finished = '1' then
			ball_top_next <= ball_top;
			ball_pos_left_next <= ball_pos_left;
		elsif (img_restart = '1') then
			ball_top_next <= init_ball_top;
			ball_pos_left_next <= init_ball_pos_left;
			rsdelay <= rsdelay + 1;
			if(rsdelay = time_restart) then
				rsdelay <= 0;
				img_restart <= '0';
			end if;
		elsif (ball_bottom >= 476 ) then
			ball_vel_y <= ball_vel_y_n;
			ball_vel_x <= ball_vel_x;
			ball_pos_left_next <= ball_pos_left + ball_vel_x;
			ball_top_next <= ball_top + ball_vel_y;
		elsif (ball_top <= 4) then
			ball_vel_y <= ball_vel_y_p;
			ball_vel_x <= ball_vel_x;
			ball_pos_left_next <= ball_pos_left + ball_vel_x;
			ball_top_next <= ball_top + ball_vel_y;
		elsif (ball_pos_left <= 4) then
			if score_right < 7 and game_finished = '0' then
				if score_right + 1 = 7 then
					game_finished <= '1';
				end if;
				score_right <= score_right + 1;
			end if;
			img_restart <= '1';
			ball_vel_y <= ball_vel_y_p;
			ball_vel_x <= ball_vel_x_p;
		elsif (ball_pos_right >= 636) then
			if score_left < 7 and game_finished = '0' then
				if score_left + 1 = 7 then
					game_finished <= '1';
				end if;
				score_left <= score_left + 1;
			end if;
			img_restart <= '1';
			ball_vel_y <= ball_vel_y_n;
			ball_vel_x <= ball_vel_x_n;
		elsif (ball_pos_left <= lbar_pos_right + 4) then
			if (ball_top >= lbar_top - 6) and (ball_bottom <= lbar_bottom + 6) then
				ball_vel_y <= ball_vel_y;
				ball_vel_x <= ball_vel_x_p;
				ball_pos_left_next <= ball_pos_left + ball_vel_x;
				ball_top_next <= ball_top + ball_vel_y;
				ball_team <= 1;
			else	
				img_restart <= '1';
				ball_team <= 0;
				if score_right < 7 and game_finished = '0' then
					if score_right + 1 = 7 then
						game_finished <= '1';
					end if;
					score_right <= score_right + 1;
				end if;
			end if;
		elsif (ball_pos_right >= rbar_pos_left - 4) then
			if (ball_top >= rbar_top - 6) and (ball_bottom <= rbar_bottom + 6) then
				ball_vel_y <= ball_vel_y;
				ball_vel_x <= ball_vel_x_n;
				ball_pos_left_next <= ball_pos_left + ball_vel_x;
				ball_top_next <= ball_top + ball_vel_y;
				ball_team <= 2;
			else		
				img_restart <= '1';
				ball_team <= 0;
				if score_left < 7 and game_finished = '0' then
					if score_left + 1 = 7 then
						game_finished <= '1';
					end if;
					score_left <= score_left + 1;
				end if;
			end if;
		else		
			ball_pos_left_next <= ball_pos_left + ball_vel_x; 
			ball_top_next <= ball_top + ball_vel_y; 
		end if;
	end if;
end process;
	 
	ball_pos_left <= ball_pos_left_next;
	ball_pos_right <= ball_pos_left_next + 7;
	ball_top <= ball_top_next;
	ball_bottom <= ball_top_next + 7;

   ball_on <= '1' when (ball_pos_right >= pixel_x) and (pixel_x >= ball_pos_left)
				   and (ball_bottom >= linha) and (linha >= ball_top)
				   else '0';

process(ball_team, ball_red, ball_green, ball_blue)
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

-- enable background(light gray) ---
	background_red <= "1010101111";
	background_green <= "1010101111";
	background_blue <= "1010101111";

-- mux output --
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
		red_sig <= "0000000000";
		green_sig <= "0000000000";
		blue_sig <= "0000000000";
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
		elsif midline_on = '1' or topline_on = '1' or rightline_on = '1' or leftline_on = '1' or bottomline_on = '1' then 
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
