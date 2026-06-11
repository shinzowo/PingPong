
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pongSync is
    port(
        pixel_clk  : in  std_logic;
        reset_n    : in  std_logic;
        mode       : in  std_logic_vector(1 downto 0);

        hsync      : out std_logic;
        vsync      : out std_logic;
        de         : out std_logic;

        pixel_x    : out unsigned(10 downto 0);
        pixel_y    : out unsigned(10 downto 0);

        frame_tick : out std_logic
    );
end pongSync;

architecture rtl of pongSync is

    signal H_VISIBLE, H_FRONT_PORCH, H_SYNC_PULSE, H_BACK_PORCH, H_TOTAL : integer;
    signal V_VISIBLE, V_FRONT_PORCH, V_SYNC_PULSE, V_BACK_PORCH, V_TOTAL : integer;

    signal h_count : unsigned(10 downto 0) := (others => '0');
    signal v_count : unsigned(10 downto 0) := (others => '0');

    signal h_pulse : std_logic;
    signal v_pulse : std_logic;
    signal sync_pol: std_logic;

begin

    process(mode)
    begin
        case mode is
            when "01" => -- 800x600 @ 60Hz (VESA Standard: Positive Sync)
                H_VISIBLE <= 800; H_FRONT_PORCH <= 40; H_SYNC_PULSE <= 128; H_BACK_PORCH <= 88;  H_TOTAL <= 1056;
                V_VISIBLE <= 600; V_FRONT_PORCH <= 1;  V_SYNC_PULSE <= 4;   V_BACK_PORCH <= 23;  V_TOTAL <= 628;
                sync_pol <= '1';
            when "10" => -- 1024x768 @ 60Hz (VESA Standard: Negative Sync)
                H_VISIBLE <= 1024; H_FRONT_PORCH <= 24; H_SYNC_PULSE <= 136; H_BACK_PORCH <= 160; H_TOTAL <= 1344;
                V_VISIBLE <= 768;  V_FRONT_PORCH <= 3;  V_SYNC_PULSE <= 6;   V_BACK_PORCH <= 29;  V_TOTAL <= 806;
                sync_pol <= '0';
            when others => -- 640x480 @ 60Hz (VESA Standard: Negative Sync)
                H_VISIBLE <= 640; H_FRONT_PORCH <= 16; H_SYNC_PULSE <= 96;  H_BACK_PORCH <= 48;  H_TOTAL <= 800;
                V_VISIBLE <= 480; V_FRONT_PORCH <= 10; V_SYNC_PULSE <= 2;   V_BACK_PORCH <= 33;  V_TOTAL <= 525;
                sync_pol <= '0';
        end case;
    end process;

    process(pixel_clk, reset_n)
    begin
        if reset_n = '0' then
            h_count <= (others => '0');
            v_count <= (others => '0');
        elsif rising_edge(pixel_clk) then
            if h_count = H_TOTAL - 1 then
                h_count <= (others => '0');
                if v_count = V_TOTAL - 1 then
                    v_count <= (others => '0');
                else
                    v_count <= v_count + 1;
                end if;
            else
                h_count <= h_count + 1;
            end if;
        end if;
    end process;

    -- Генерация активного импульса (всегда High внутри процесса)
    h_pulse <= '1' when (to_integer(h_count) >= (H_VISIBLE + H_FRONT_PORCH) and
                         to_integer(h_count) <  (H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE)) else '0';

    v_pulse <= '1' when (to_integer(v_count) >= (V_VISIBLE + V_FRONT_PORCH) and
                         to_integer(v_count) <  (V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE)) else '0';

    -- Применение правильной полярности для ADV7513
    hsync <= h_pulse when sync_pol = '1' else not h_pulse;
    vsync <= v_pulse when sync_pol = '1' else not v_pulse;

    de <= '1' when (to_integer(h_count) < H_VISIBLE and to_integer(v_count) < V_VISIBLE) else '0';

    pixel_x <= h_count;
    pixel_y <= v_count;

    frame_tick <= '1' when (h_count = 0 and v_count = 0) else '0';

end rtl;
