----------------------------------------------
-------------------- PONG --------------------
----------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;

entity pongGame is
	port(
		  img_reset : in std_logic;
		  clock_placa : in std_logic;
	     lbutton_p1, rbutton_p1 : in std_logic;
	     lbutton_p2, rbutton_p2 : in std_logic;
		  hsync : out std_logic;
		  vsync : out std_logic;
		  vga_blank : out std_logic;
		  vga_clock : out std_logic;
		  vga_sync : out std_logic;
		  red_out : out std_logic_vector(9 downto 0);
		  green_out : out std_logic_vector(9 downto 0);
		  blue_out : out std_logic_vector(9 downto 0)
		  );
end pongGame;

architecture toplevel of pongGame is

	signal refresh : std_logic;
	signal clock_25 : std_logic;
	signal video_on : std_logic;
	signal vga_blank_sig : std_logic;
	signal vga_sync_sig : std_logic;
	signal pixel_x, linha : integer range 1023 downto 0;
	signal red_sig : std_logic_vector(9 downto 0);
	signal green_sig : std_logic_vector(9 downto 0);
	signal blue_sig : std_logic_vector(9 downto 0);

begin

	imagegen : entity work.pongImg port map(img_reset, refresh, clock_25,
											video_on, lbutton_p1, rbutton_p1,
											lbutton_p2, rbutton_p2, pixel_x,
											linha, red_sig, green_sig, blue_sig);

	vgasync : entity work.pongSync port map(clock_placa, clock_25, refresh,
											hsync, vsync, video_on, vga_blank_sig,
											vga_sync_sig, pixel_x, linha);
														
	red_out <= red_sig;
	green_out <= green_sig;
	blue_out <= blue_sig;
	vga_blank <= vga_blank_sig;
	vga_sync <= vga_sync_sig;
   vga_clock <= clock_25;
	
end toplevel;
	