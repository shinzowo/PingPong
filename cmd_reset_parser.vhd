-- cmd_reset_parser.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Принимает строку от uart_rx, завершённую \r или \n.
-- "RESET"  -> reset_cmd='1', отправляет "OK\r\n"
-- иначе    -> отправляет "Unknown command\r\n"

entity cmd_reset_parser is
    port (
        clk        : in  std_logic;
        reset_n    : in  std_logic;
        rx_data    : in  std_logic_vector(7 downto 0);
        rx_valid   : in  std_logic;
        tx_data    : out std_logic_vector(7 downto 0);
        tx_start   : out std_logic;
        tx_busy    : in  std_logic;
        reset_cmd  : out std_logic
    );
end cmd_reset_parser;

architecture rtl of cmd_reset_parser is

    -- "OK\r\n" = 4 байта
    type ok_rom_t is array (0 to 3) of std_logic_vector(7 downto 0);
    constant OK_ROM : ok_rom_t := (
        x"4F",  -- 'O'
        x"4B",  -- 'K'
        x"0D",  -- \r
        x"0A"   -- \n
    );

    -- "Unknown command\r\n" = 17 байт
    type unk_rom_t is array (0 to 16) of std_logic_vector(7 downto 0);
    constant UNK_ROM : unk_rom_t := (
        x"55",  -- 'U'
        x"6E",  -- 'n'
        x"6B",  -- 'k'
        x"6E",  -- 'n'
        x"6F",  -- 'o'
        x"77",  -- 'w'
        x"6E",  -- 'n'
        x"20",  -- ' '
        x"63",  -- 'c'
        x"6F",  -- 'o'
        x"6D",  -- 'm'
        x"6D",  -- 'm'
        x"61",  -- 'a'
        x"6E",  -- 'n'
        x"64",  -- 'd'
        x"0D",  -- \r
        x"0A"   -- \n
    );

    type state_t is (
        S_COLLECT,      -- накапливаем символы строки
        S_OK_SEND,      -- отправляем OK\r\n
        S_OK_WAIT,      -- ждём конца передачи байта OK
        S_UNK_SEND,     -- отправляем Unknown command\r\n
        S_UNK_WAIT      -- ждём конца передачи байта Unknown
    );
    signal state    : state_t;

    signal buf        : std_logic_vector(39 downto 0);
    signal cnt        : integer range 0 to 5;
    signal tx_idx     : integer range 0 to 16;
    signal tx_start_i : std_logic;   -- внутренняя копия tx_start для чтения

begin

    tx_start <= tx_start_i;

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state       <= S_COLLECT;
            buf         <= (others => '0');
            cnt         <= 0;
            tx_idx      <= 0;
            tx_data     <= (others => '0');
            tx_start_i  <= '0';
            reset_cmd   <= '0';

        elsif rising_edge(clk) then
            tx_start_i <= '0';
            reset_cmd  <= '0';

            case state is

                -- --------------------------------------------------
                -- Накапливаем символы до \r или \n
                -- --------------------------------------------------
                when S_COLLECT =>
                    if rx_valid = '1' then
                        if rx_data = x"0D" or rx_data = x"0A" then
                            -- Конец строки: buf LSB-first
                            -- 'R'=52 'E'=45 'S'=53 'E'=45 'T'=54
                            -- buf[7:0]='R', buf[15:8]='E', ...
                            -- => эталон 0x5445534552
                            if cnt = 5 and buf = x"5445534552" then
                                reset_cmd  <= '1';
                                tx_idx     <= 0;
                                tx_data    <= OK_ROM(0);
                                tx_start_i <= '1';
                                state      <= S_OK_WAIT;
                            else
                                tx_idx     <= 0;
                                tx_data    <= UNK_ROM(0);
                                tx_start_i <= '1';
                                state      <= S_UNK_WAIT;
                            end if;
                            cnt <= 0;
                            buf <= (others => '0');
                        else
                            -- Накапливаем символ
                            if cnt < 5 then
                                buf(cnt*8+7 downto cnt*8) <= rx_data;
                                cnt <= cnt + 1;
                            end if;
                            -- Если cnt >= 5 — строка длиннее 5 символов,
                            -- просто игнорируем, но сбросим cnt не будем —
                            -- при \r/\n проверка cnt=5 не пройдёт -> Unknown
                        end if;
                    end if;

                -- --------------------------------------------------
                -- Отправка "OK\r\n"
                -- --------------------------------------------------
                when S_OK_WAIT =>
                    if tx_busy = '0' and tx_start_i = '0' then
                        -- Предыдущий байт принят передатчиком
                        if tx_idx = 3 then
                            state <= S_COLLECT;   -- все 4 байта отправлены
                        else
                            tx_idx   <= tx_idx + 1;
                            tx_data  <= OK_ROM(tx_idx + 1);
                            tx_start_i <= '1';
                        end if;
                    end if;

                -- --------------------------------------------------
                -- Отправка "Unknown command\r\n"
                -- --------------------------------------------------
                when S_UNK_WAIT =>
                    if tx_busy = '0' and tx_start_i = '0' then
                        if tx_idx = 16 then
                            state <= S_COLLECT;   -- все 17 байт отправлены
                        else
                            tx_idx   <= tx_idx + 1;
                            tx_data  <= UNK_ROM(tx_idx + 1);
                            tx_start_i <= '1';
                        end if;
                    end if;

                when others =>
                    state <= S_COLLECT;

            end case;
        end if;
    end process;

end rtl;