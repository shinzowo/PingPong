----------------------------------------------
------ GERAÇÃO DE PULSOS DE SINCRONISMO ------
---------------- E CONTADORES ----------------
----------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;

entity pongSync is
   port(
        clock_placa : in std_logic;
        clock_25 : out std_logic;
        refresh : out std_logic; 
        hsync, vsync : out std_logic;
        video_on : out std_logic;
	     vga_blank : out std_logic;
		  vga_sync : out std_logic;
        pixel_x, linha : out integer range 1023 downto 0
        );
end pongSync;

architecture vgasignals of pongSync is

-- Frame total horizontal: 800 pixels --
    constant H_display : integer := 640;
    constant H_FP : integer := 16;
    constant H_BP : integer := 48;
    constant H_R : integer := 96;
    constant H_total : integer := 799;
    
-- Frame total vertical: 525 pixels --
    constant V_display : integer := 480;
    constant V_FP : integer := 10;
    constant V_BP : integer := 33;
    constant V_R : integer := 2;
    constant V_total : integer := 524;
    constant V_total_div2 : integer := 262;
----------------------------------------

    signal hsync_sig, vsync_sig : std_logic;
	 signal video_on_sig : std_logic := '1';
	 signal refresh_sig : std_logic := '1';
	 signal clock_25_sig : std_logic := '0';
	 signal count_x : integer range 1023 downto 0 := 0;
	 signal count_y : integer range 1023 downto 0 := 23;

begin

-- Modulação de clock de 25 MHz (clock_placa --> 50 MHz)--
process(clock_placa)
begin 
    if (clock_placa'event and clock_placa='1') then
        clock_25_sig <= not clock_25_sig;
    end if;    
end process;

clock_25 <= clock_25_sig;

-- Contagem de pixels em x e linhas em y --
process(clock_25_sig, count_x, count_y)
begin
    if(clock_25_sig'event and clock_25_sig = '1') then
		count_x <= count_x + 1;
		if(count_x = H_total) then
			count_x <= 0;
			count_y <= count_y + 1;
            case count_y is 
                when V_total_div2 => 
						refresh_sig <= not refresh_sig;
                when V_total => 
						count_y <= 0;
						refresh_sig <= not refresh_sig;
				    when others => 
						refresh_sig <= refresh_sig;
            end case;
		end if;
    end if;
end process;
	 
-- Saída de sincronismo horizontal --	 
	hsync_sig <= '0' when (count_x > (H_display + H_FP - 1)) 
					 and (count_x <= (H_display + H_FP + H_R - 1))
					 else '1';

-- Saída de sincronismo vertical --
   vsync_sig <= '0' when (count_y > (V_display + V_FP - 1)) 
					 and (count_y <= (V_display + V_FP + V_R - 1))
					 else '1';

-- Sinal de display --
   video_on_sig <= '1' when (count_x <= H_display - 1) 
						 and (count_y <= V_display - 1)
					  	 else '0';
	 
	pixel_x <= count_x;
	linha <= count_y;
	hsync <= hsync_sig;
	vsync <= vsync_sig;
	refresh <= refresh_sig;
	video_on <= video_on_sig;
	vga_blank <= video_on_sig;
	vga_sync <= '1';

end vgasignals;