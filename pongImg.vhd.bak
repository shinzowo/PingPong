----------------------------------------------
------------- GERAÇÃO DE OBJETOS -------------
----------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;

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

-- Largura e comprimento das barras verticais --
	constant bar_width : integer := 15;
	constant bar_length : integer := 72;
	constant bar_top : integer := 204;
	constant bar_bottom : integer := 275;

-- Velocidades --
	constant bar_vel : integer := 8;
	signal ball_vel_x : integer := 3;
	signal ball_vel_y : integer := 3;
	constant ball_vel_y_n : integer := -3;
	constant ball_vel_y_p : integer := 3;
	constant ball_vel_x_n : integer := -3;
	constant ball_vel_x_p : integer := 3;

-- Posicionamento da barra esquerda --  
	constant lbar_pos_left : integer := 30;
	constant lbar_pos_right : integer := 44;
	signal lbar_top : integer range 1023 downto 0 := 204;
	signal lbar_bottom : integer range 1023 downto 0 := 275;

-- Posicionamento da barra direita --  
	constant rbar_pos_left : integer :=  594;
	constant rbar_pos_right : integer := 609;
	signal rbar_top : integer range 1023 downto 0 := 204;
	signal rbar_bottom : integer range 1023 downto 0 := 275;

-- Posicionamento da bola quadrada --
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
	
-- Posicionamento da linha intermediaria --
	constant midline_right : integer := 320;
	constant midline_left : integer := 318;
	
-- Sinais de geração das imagens --
	signal lbar_on, rbar_on, ball_on : std_logic;
	signal midline_on, topline_on, bottomline_on, leftline_on, rightline_on : std_logic;
	signal lbar_red, lbar_green, lbar_blue : std_logic_vector(9 downto 0);
	signal rbar_red, rbar_green, rbar_blue : std_logic_vector(9 downto 0);
	signal ball_red, ball_green, ball_blue : std_logic_vector(9 downto 0);
	signal ball_team : integer range 2 downto 0 := 0;
	signal background_red, background_green, background_blue : std_logic_vector(9 downto 0);
	signal line_red, line_green, line_blue : std_logic_vector(9 downto 0);
	
-- Sinal de saída habilitada RGB --
	signal red_sig, green_sig, blue_sig : std_logic_vector(9 downto 0);
	
-- Sinal de contagem dos frames --
	signal framerate : std_logic;
	
-- Comandos de controle do restart --
	constant time_restart : integer := 120;
	signal img_restart : std_logic := '0';
	signal rsdelay : integer range 1023 downto 0 := 0;	
--------------------------------------

begin

	framerate <= refresh;
	 
-- Linhas limitrofes (cinza escuro) --
	midline_on <= '1' when (midline_right >= pixel_x) and (midline_left <= pixel_x)
					  else '0';
	topline_on <= '1' when (2 >= linha) 
					  else '0';
	leftline_on <= '1' when (2 >= pixel_x) 
					   else '0';
	rightline_on <= '1' when (pixel_x >= 637) 
					    else '0';
	bottomline_on <= '1' when (linha >= 477) 
					     else '0';

	line_red <= "0110011111";
	line_green <= "0110011111";
	line_blue <= "0110011111";
--------------------------------------

-- Ativar barra esquerda (vermelha) --
process(framerate, img_reset, img_restart, 
                   lbar_top, lbar_bottom, lbutton_p1, rbutton_p1)
begin
	if (img_reset = '1' or img_restart = '1') then
		lbar_top <= bar_top;
	elsif (framerate'event and framerate = '1') then
		if (rbutton_p1 = '0' and lbutton_p1 = '1' and lbar_top >= 5) then
			lbar_top <= lbar_top - bar_vel;
		elsif (lbutton_p1 = '0' and rbutton_p1 = '1' and lbar_bottom <= 475) then
			lbar_top <= lbar_top + bar_vel;
		else 
			lbar_top <= lbar_top;
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
--------------------------------------

-- Ativar barra direita (azul) -------
process(framerate, img_reset, img_restart,
                   rbar_top, rbar_bottom, lbutton_p2, rbutton_p2)
begin
	if (img_reset = '1' or img_restart = '1') then
		rbar_top <= bar_top;
	elsif (framerate'event and framerate = '1') then
		if (rbutton_p2 = '0' and lbutton_p2 = '1' and rbar_top >= 5) then
			rbar_top <= rbar_top - bar_vel;
		elsif (lbutton_p2 = '0' and rbutton_p2 = '1' and rbar_bottom <= 475) then
			rbar_top <= rbar_top + bar_vel;
	   else 
			rbar_top <= rbar_top;
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
--------------------------------------

-- Ativar bola quadrada (preta) ------
process(framerate, img_reset, img_restart, rsdelay, ball_team,
                   ball_pos_right, ball_pos_left, ball_top, ball_bottom,
					ball_pos_left_next, ball_top_next)
begin
	if (img_reset = '1') then
		ball_top_next <= init_ball_top;
		ball_pos_left_next <= init_ball_pos_left;
		ball_team <= 0;
   elsif(framerate'event and framerate = '1') then
		if (img_restart = '1') then
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
			ball_vel_y <= ball_vel_y;
			ball_vel_x <= ball_vel_x_p;
			ball_pos_left_next <= ball_pos_left + ball_vel_x;
			ball_top_next <= ball_top + ball_vel_y;	
		elsif (ball_pos_right >= 636) then
			ball_vel_y <= ball_vel_y;
			ball_vel_x <= ball_vel_x_n;
			ball_pos_left_next <= ball_pos_left + ball_vel_x;
			ball_top_next <= ball_top + ball_vel_y;
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
--------------------------------------

-- Ativar background (cinza claro) ---
	background_red <= "1010101111";
	background_green <= "1010101111";
	background_blue <= "1010101111";
--------------------------------------

-- Multiplexação dos objetos ---------
process(video_on, lbar_on, lbar_red, lbar_green, lbar_blue,
				  rbar_on, rbar_red, rbar_green, rbar_blue,
				  ball_on, ball_red, ball_green, ball_blue,
				  background_red, background_green, background_blue,
	       midline_on, topline_on, bottomline_on, leftline_on, rightline_on,
	   	          line_red, line_green, line_blue)
begin
    if video_on = '0' then red_sig <= "0000000000";
								   green_sig <= "0000000000";
									blue_sig <= "0000000000";
    else
        if lbar_on = '1' and ball_on = '0' then red_sig <= lbar_red;
																green_sig <= lbar_green;
																blue_sig <= lbar_blue;
        elsif rbar_on = '1' and ball_on = '0' then red_sig <= rbar_red;
																	green_sig <= rbar_green;
																	blue_sig <= rbar_blue;
        elsif ball_on = '1' then red_sig <= ball_red;
											green_sig <= ball_green;
											blue_sig <= ball_blue;
		  elsif    midline_on = '1'
			     or topline_on = '1'
			     or rightline_on = '1'	
			     or leftline_on = '1'
			     or bottomline_on = '1' then red_sig <= line_red;
														green_sig <= line_green;
														blue_sig <= line_blue;			
        else red_sig <= background_red;
				 green_sig <= background_green;
				 blue_sig <= background_blue;
        end if;
    end if;
end process;

	red_out <= red_sig;
	green_out <= green_sig;
	blue_out <= blue_sig;
	 
end imagegen;