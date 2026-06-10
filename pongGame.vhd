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
    
    signal video_on     : std_logic;
    signal pll_locked   : std_logic;
    
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
    signal img_reset_int: std_logic;
    
    signal tx_data      : std_logic_vector(7 downto 0);
    signal tx_start     : std_logic;
    signal tx_busy      : std_logic;
    
    signal res_mode_sig : std_logic_vector(1 downto 0);
    
    -- Сигналы для логики Hot-Plug
    signal hpd_sync       : std_logic_vector(2 downto 0) := "000";
    signal i2c_reinit     : std_logic := '0';
    signal reinit_counter : integer range 0 to 500_000 := 0; -- Таймер на 10 мс
    signal adv_reset_n    : std_logic;
    
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
            -- 1. Сдвиговый регистр для защиты от метастабильности
            hpd_sync <= hpd_sync(1 downto 0) & HDMI_TX_INT;

            -- 2. Ловим изменение состояния пина (любое шевеление кабеля)
            if (hpd_sync(2) = '0' and hpd_sync(1) = '1') or 
               (hpd_sync(2) = '1' and hpd_sync(1) = '0') then
                
                -- Запускаем таймер удержания сброса I2C на 10 миллисекунд (500 000 тактов)
                -- Это аппаратно подавит дребезг контактов
                reinit_counter <= 500_000; 
                i2c_reinit <= '1';
                
            elsif reinit_counter > 0 then
                reinit_counter <= reinit_counter - 1;
                i2c_reinit <= '1';
            else
                i2c_reinit <= '0';
            end if;
        end if;
    end process;

    -- ADV7513 сбрасывается либо физической кнопкой KEY(0), либо нашим автоматом Hot-Plug
    adv_reset_n <= KEY(0) and (not i2c_reinit);

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
            hsync      => HDMI_TX_HSYNC,
            vsync      => HDMI_TX_VSYNC,
            de         => video_on,
            pixel_x    => pixel_x_unsigned,
            pixel_y    => pixel_y_unsigned,
            frame_tick => refresh
        );

    imagegen : entity work.pongImg
        port map(
            img_reset   => img_reset_int,
            refresh     => refresh,
            video_on    => video_on,
            mode        => res_mode_sig,
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
    
    HDMI_TX_D   <= red_8bit & green_8bit & blue_8bit;
    HDMI_TX_CLK <= selected_pixel_clk;
    HDMI_TX_DE  <= video_on;
    
    uart_rx_inst: entity work.uart_rx
        generic map(CLK_FREQ => 50_000_000, BAUD_RATE => 115_200)
        port map(
            clk      => FPGA_CLK_50,
            reset_n  => KEY(0),
            rx_line  => UART_RX,
            rx_data  => rx_data,
            rx_valid => rx_valid
        );

    uart_tx_inst: entity work.uart_tx
        generic map(CLK_FREQ => 50_000_000, BAUD_RATE => 115_200)
        port map(
            clk      => FPGA_CLK_50,
            reset_n  => KEY(0),
            tx_data  => tx_data,
            tx_start => tx_start,
            tx_busy  => tx_busy,
            tx_line  => UART_TX
        );

    parser_inst: entity work.cmd_reset_parser
        port map(
            clk             => FPGA_CLK_50,
            reset_n         => KEY(0),
            rx_data         => rx_data,
            rx_valid        => rx_valid,
            tx_data         => tx_data,
            tx_start        => tx_start,
            tx_busy         => tx_busy,
            reset_cmd       => reset_cmd,
            resolution_mode => res_mode_sig
        );

    img_reset_int <= (not KEY(0)) or reset_cmd;

    LEDR(0) <= pll_locked;
    LEDR(1) <= init_done;
    LEDR(2) <= reset_cmd;
    LEDR(9 downto 3) <= (others => '0');

end toplevel;