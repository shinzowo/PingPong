-- pongGame.vhd
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

entity pongGame is
port(
    FPGA_CLK_50    : in std_logic;
    KEY            : in std_logic_vector(1 downto 0);
    
    lbutton_p1, rbutton_p1 : in std_logic;
    lbutton_p2, rbutton_p2 : in std_logic;
    
    UART_RX        : in std_logic;
    UART_TX        : out std_logic;
    
    HDMI_TX_CLK    : out std_logic;
    HDMI_TX_HSYNC  : out std_logic;
    HDMI_TX_VSYNC  : out std_logic;
    HDMI_TX_DE     : out std_logic;
    HDMI_TX_D      : out std_logic_vector(23 downto 0);
    
    -- Сигнал обнаружения Hot-Plug (Прерывание от ADV7513)
    HDMI_TX_INT    : in std_logic; 
    
    I2C_SCL        : out std_logic;
    I2C_SDA        : inout std_logic;
    
    LEDR           : out std_logic_vector(9 downto 0)
);
end pongGame;

architecture toplevel of pongGame is

    signal refresh      : std_logic;
    
    signal clk_25       : std_logic;
    signal clk_40       : std_logic;
    signal clk_65       : std_logic;
    signal selected_pixel_clk : std_logic;
    
    signal pll_locked   : std_logic;
    signal hsync_raw    : std_logic;
    signal vsync_raw    : std_logic;
    signal de_raw       : std_logic;
    signal hdmi_hsync_reg : std_logic := '1';
    signal hdmi_vsync_reg : std_logic := '1';
    signal hdmi_de_reg    : std_logic := '0';
    signal hdmi_data_reg  : std_logic_vector(23 downto 0) := (others => '0');

    signal pixel_x_unsigned : unsigned(10 downto 0);
    signal pixel_y_unsigned : unsigned(10 downto 0);
    signal pixel_x_int : integer range 2047 downto 0;
    signal pixel_y_int : integer range 2047 downto 0;
    
    signal red_10bit, green_10bit, blue_10bit : std_logic_vector(9 downto 0);
    signal red_8bit, green_8bit, blue_8bit : std_logic_vector(7 downto 0);
    
    signal init_done : std_logic;
    
    signal rx_data      : std_logic_vector(7 downto 0);
    signal rx_valid     : std_logic;
    signal reset_cmd    : std_logic;
    signal reset_cmd_stretched : std_logic := '0';
    signal img_reset_int: std_logic;
    
    signal tx_data      : std_logic_vector(7 downto 0);
    signal tx_start     : std_logic;
    signal tx_busy      : std_logic;
    
    signal res_mode_sig : std_logic_vector(1 downto 0);
    signal speed_mode_sig : std_logic_vector(2 downto 0);
    
    -- Сигналы для логики Hot-Plug
    signal hpd_sync       : std_logic_vector(2 downto 0) := "000";
    signal i2c_reinit     : std_logic := '0';
    signal reinit_counter : integer range 0 to 1_000_000 := 0; -- Таймер на 20 мс
    signal adv_reset_n    : std_logic;
    signal init_done_prev : std_logic := '0';
    signal startup_reinit_done : std_logic := '0';
    signal sys_reset_n    : std_logic;
    signal reset_stretch_cnt : integer range 0 to 31 := 0;
    
    component pll_3way is
        port (
            refclk   : in  std_logic;
            rst      : in  std_logic;
            outclk_0 : out std_logic; 
            outclk_1 : out std_logic; 
            outclk_2 : out std_logic; 
            locked   : out std_logic
        );
    end component;
    
    component adv7513_wrapper is
        port(
            clk       : in  std_logic;
            reset_n   : in  std_logic;
            i2c_scl   : out std_logic;
            i2c_sda   : inout std_logic;
            init_done : out std_logic
        );
    end component;

begin

    sys_reset_n <= pll_locked;

    pixel_x_int <= to_integer(pixel_x_unsigned);
    pixel_y_int <= to_integer(pixel_y_unsigned);

    pll_inst : component pll_3way
        port map (
            refclk   => FPGA_CLK_50,
            rst      => '0',
            outclk_0 => clk_25,
            outclk_1 => clk_40,
            outclk_2 => clk_65,
            locked   => pll_locked
        );

    process(res_mode_sig, clk_25, clk_40, clk_65)
    begin
        case res_mode_sig is
            when "01"   => selected_pixel_clk <= clk_40;
            when "10"   => selected_pixel_clk <= clk_65;
            when others => selected_pixel_clk <= clk_25;
        end case;
    end process;

    -----------------------------------------------------------------
    -- Детектор Hot-Plug кабеля HDMI
    -----------------------------------------------------------------
    process(FPGA_CLK_50)
    begin
        if rising_edge(FPGA_CLK_50) then
            if sys_reset_n = '0' then
                hpd_sync <= (others => '0');
                i2c_reinit <= '0';
                reinit_counter <= 0;
                init_done_prev <= '0';
                startup_reinit_done <= '0';
            else
                -- 1. Сдвиговый регистр для защиты от метастабильности
                hpd_sync <= hpd_sync(1 downto 0) & HDMI_TX_INT;
                init_done_prev <= init_done;

                -- 2. После первого полного старта даём ADV7513 ещё одну мягкую
                -- переинициализацию, чтобы холодный старт совпадал с hot-plug сценарием.
                if startup_reinit_done = '0' and init_done_prev = '0' and init_done = '1' then
                    reinit_counter <= 1_000_000;
                    i2c_reinit <= '1';
                    startup_reinit_done <= '1';
                elsif (hpd_sync(2) = '0' and hpd_sync(1) = '1') or
                      (hpd_sync(2) = '1' and hpd_sync(1) = '0') then
                    reinit_counter <= 1_000_000;
                    i2c_reinit <= '1';
                elsif reinit_counter > 0 then
                    reinit_counter <= reinit_counter - 1;
                    i2c_reinit <= '1';
                else
                    i2c_reinit <= '0';
                end if;
            end if;
        end if;
    end process;

    process(FPGA_CLK_50)
    begin
        if rising_edge(FPGA_CLK_50) then
            if sys_reset_n = '0' then
                reset_stretch_cnt <= 0;
                reset_cmd_stretched <= '0';
            elsif reset_cmd = '1' then
                reset_stretch_cnt <= 31;
                reset_cmd_stretched <= '1';
            elsif reset_stretch_cnt > 0 then
                reset_stretch_cnt <= reset_stretch_cnt - 1;
                reset_cmd_stretched <= '1';
            else
                reset_cmd_stretched <= '0';
            end if;
        end if;
    end process;

    -- KEY0 сбрасывает только игру. Видеотракт и ADV7513 живут отдельно,
    -- чтобы экран не гас при игровом рестарте.
    adv_reset_n <= sys_reset_n and (not i2c_reinit);

    i2c_init: component adv7513_wrapper
        port map(
            clk       => FPGA_CLK_50,
            reset_n   => adv_reset_n,
            i2c_scl   => I2C_SCL,
            i2c_sda   => I2C_SDA,
            init_done => init_done
        );
    
    vgasync : entity work.pongSync
        port map(
            pixel_clk  => selected_pixel_clk,
            reset_n    => pll_locked,
            mode       => res_mode_sig,
            hsync      => hsync_raw,
            vsync      => vsync_raw,
            de         => de_raw,
            pixel_x    => pixel_x_unsigned,
            pixel_y    => pixel_y_unsigned,
            frame_tick => refresh
        );

    imagegen : entity work.pongImg
        port map(
            img_reset   => img_reset_int,
            pixel_clk   => selected_pixel_clk,
            refresh     => refresh,
            video_on    => de_raw,
            mode        => res_mode_sig,
            speed_mode  => speed_mode_sig,
            lbutton_p1  => lbutton_p1,
            rbutton_p1  => rbutton_p1,
            lbutton_p2  => lbutton_p2,
            rbutton_p2  => rbutton_p2,
            pixel_x     => pixel_x_int,
            linha       => pixel_y_int,
            red_out     => red_10bit,
            green_out   => green_10bit,
            blue_out    => blue_10bit
        );

    red_8bit   <= red_10bit(9 downto 2);
    green_8bit <= green_10bit(9 downto 2);
    blue_8bit  <= blue_10bit(9 downto 2);

    process(selected_pixel_clk, pll_locked)
    begin
        if pll_locked = '0' then
            hdmi_hsync_reg <= '1';
            hdmi_vsync_reg <= '1';
            hdmi_de_reg <= '0';
            hdmi_data_reg <= (others => '0');
        elsif rising_edge(selected_pixel_clk) then
            hdmi_hsync_reg <= hsync_raw;
            hdmi_vsync_reg <= vsync_raw;

            if init_done = '1' then
                hdmi_de_reg <= de_raw;
                hdmi_data_reg <= red_8bit & green_8bit & blue_8bit;
            else
                hdmi_de_reg <= '0';
                hdmi_data_reg <= (others => '0');
            end if;
        end if;
    end process;

    HDMI_TX_D   <= hdmi_data_reg;
    HDMI_TX_CLK <= selected_pixel_clk;
    HDMI_TX_HSYNC <= hdmi_hsync_reg;
    HDMI_TX_VSYNC <= hdmi_vsync_reg;
    HDMI_TX_DE  <= hdmi_de_reg;
    
    uart_rx_inst: entity work.uart_rx
        generic map(CLK_FREQ => 50_000_000, BAUD_RATE => 115_200)
        port map(
            clk      => FPGA_CLK_50,
            reset_n  => sys_reset_n,
            rx_line  => UART_RX,
            rx_data  => rx_data,
            rx_valid => rx_valid
        );

    uart_tx_inst: entity work.uart_tx
        generic map(CLK_FREQ => 50_000_000, BAUD_RATE => 115_200)
        port map(
            clk      => FPGA_CLK_50,
            reset_n  => sys_reset_n,
            tx_data  => tx_data,
            tx_start => tx_start,
            tx_busy  => tx_busy,
            tx_line  => UART_TX
        );

    parser_inst: entity work.cmd_reset_parser
        port map(
            clk             => FPGA_CLK_50,
            reset_n         => sys_reset_n,
            rx_data         => rx_data,
            rx_valid        => rx_valid,
            tx_data         => tx_data,
            tx_start        => tx_start,
            tx_busy         => tx_busy,
            reset_cmd       => reset_cmd,
            resolution_mode => res_mode_sig,
            speed_mode      => speed_mode_sig
        );

    img_reset_int <= (not KEY(0)) or reset_cmd_stretched;

    LEDR(0) <= pll_locked;
    LEDR(1) <= init_done;
    LEDR(2) <= reset_cmd_stretched;
    LEDR(9 downto 3) <= (others => '0');

end toplevel;
