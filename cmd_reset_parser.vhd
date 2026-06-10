-- cmd_reset_parser.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cmd_reset_parser is
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        rx_data     : in  std_logic_vector(7 downto 0);
        rx_valid    : in  std_logic;
        reset_cmd   : out std_logic    -- импульс при получении команды RESET
    );
end cmd_reset_parser;

architecture rtl of cmd_reset_parser is
    type state_t is (WAIT_CMD, COLLECT);
    signal state      : state_t;
    signal buf        : std_logic_vector(39 downto 0);  -- максимум 5 символов ("RESET")
    signal cnt        : integer range 0 to 5;
begin
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= WAIT_CMD;
            cnt <= 0;
            reset_cmd <= '0';
            buf <= (others => '0');
        elsif rising_edge(clk) then
            reset_cmd <= '0';
            
            if rx_valid = '1' then
                -- Завершающий символ: \n (0x0A) или \r (0x0D)
                -- PuTTY по умолчанию посылает \r при нажатии Enter
                if rx_data = x"0A" or rx_data = x"0D" then
                    -- ИСПРАВЛЕНО: порядок байт LSB-first:
                    --   buf[7:0]  = 'R' (0x52) — первый принятый символ
                    --   buf[15:8] = 'E' (0x45)
                    --   buf[23:16]= 'S' (0x53)
                    --   buf[31:24]= 'E' (0x45)
                    --   buf[39:32]= 'T' (0x54) — пятый принятый символ
                    -- Итого: 0x5445534552  (не 0x5245534554!)
                    if cnt = 5 and buf = x"5445534552" then
                        reset_cmd <= '1';
                    end if;
                    state <= WAIT_CMD;
                    cnt <= 0;
                else
                    if state = WAIT_CMD then
                        state <= COLLECT;
                        cnt <= 1;
                        buf(7 downto 0) <= rx_data;
                    elsif state = COLLECT and cnt < 5 then
                        buf(cnt*8+7 downto cnt*8) <= rx_data;
                        cnt <= cnt + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;
end rtl;
