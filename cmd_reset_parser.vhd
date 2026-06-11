library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cmd_reset_parser is
    port (
        clk            : in  std_logic;
        reset_n        : in  std_logic;
        rx_data        : in  std_logic_vector(7 downto 0);
        rx_valid       : in  std_logic;
        tx_data        : out std_logic_vector(7 downto 0);
        tx_start       : out std_logic;
        tx_busy        : in  std_logic;
        reset_cmd      : out std_logic;
        resolution_mode: out std_logic_vector(1 downto 0);
        speed_mode     : out std_logic_vector(2 downto 0)
    );
end cmd_reset_parser;

architecture rtl of cmd_reset_parser is

    type response_rom_t is array (0 to 16) of std_logic_vector(7 downto 0);
    type command_rom_t is array (0 to 8) of std_logic_vector(47 downto 0);
    type command_len_rom_t is array (0 to 8) of integer range 0 to 6;
    
    constant ROM_OK   : response_rom_t := (x"4F",x"4B",x"0D",x"0A", others => x"00"); -- "OK\r\n"
    constant ROM_RES0 : response_rom_t := (x"4F",x"4B",x"20",x"36",x"34",x"30",x"78",x"34",x"38",x"30",x"0D",x"0A", others => x"00"); -- "OK 640x480\r\n"
    constant ROM_RES1 : response_rom_t := (x"4F",x"4B",x"20",x"38",x"30",x"30",x"78",x"36",x"30",x"30",x"0D",x"0A", others => x"00"); -- "OK 800x600\r\n"
    constant ROM_RES2 : response_rom_t := (x"4F",x"4B",x"20",x"31",x"30",x"32",x"34",x"78",x"37",x"36",x"38",x"0D",x"0A", others => x"00"); -- "OK 1024x768\r\n"
    constant ROM_UNK  : response_rom_t := (x"55",x"6E",x"6B",x"6E",x"6F",x"77",x"6E",x"20",x"63",x"6F",x"6D",x"6D",x"61",x"6E",x"64",x"0D",x"0A"); -- "Unknown command\r\n"

    type state_t is (S_COLLECT, S_SEND_RESP, S_WAIT_TX);
    signal state        : state_t;

    signal buf          : std_logic_vector(47 downto 0);
    signal cnt          : integer range 0 to 6;
    
    signal current_rom  : response_rom_t;
    signal tx_idx       : integer range 0 to 16;
    signal max_tx_idx   : integer range 0 to 16;
    signal tx_start_i   : std_logic;
    
    signal mode_reg     : std_logic_vector(1 downto 0) := "00";
    signal speed_reg    : std_logic_vector(2 downto 0) := "011";

    constant ROM_SPD1 : response_rom_t := (x"4F",x"4B",x"20",x"53",x"50",x"45",x"45",x"44",x"31",x"0D",x"0A", others => x"00"); -- "OK SPEED1\r\n"
    constant ROM_SPD2 : response_rom_t := (x"4F",x"4B",x"20",x"53",x"50",x"45",x"45",x"44",x"32",x"0D",x"0A", others => x"00"); -- "OK SPEED2\r\n"
    constant ROM_SPD3 : response_rom_t := (x"4F",x"4B",x"20",x"53",x"50",x"45",x"45",x"44",x"33",x"0D",x"0A", others => x"00"); -- "OK SPEED3\r\n"
    constant ROM_SPD4 : response_rom_t := (x"4F",x"4B",x"20",x"53",x"50",x"45",x"45",x"44",x"34",x"0D",x"0A", others => x"00"); -- "OK SPEED4\r\n"
    constant ROM_SPD5 : response_rom_t := (x"4F",x"4B",x"20",x"53",x"50",x"45",x"45",x"44",x"35",x"0D",x"0A", others => x"00"); -- "OK SPEED5\r\n"

    constant CMD_ROM : command_rom_t := (
        0 => x"005445534552", -- RESET
        1 => x"000030534552", -- RES0
        2 => x"000031534552", -- RES1
        3 => x"000032534552", -- RES2
        4 => x"314445455053", -- SPEED1
        5 => x"324445455053", -- SPEED2
        6 => x"334445455053", -- SPEED3
        7 => x"344445455053", -- SPEED4
        8 => x"354445455053"  -- SPEED5
    );

    constant CMD_LEN_ROM : command_len_rom_t := (
        0 => 5,
        1 => 4,
        2 => 4,
        3 => 4,
        4 => 6,
        5 => 6,
        6 => 6,
        7 => 6,
        8 => 6
    );

begin

    tx_start <= tx_start_i;
    resolution_mode <= mode_reg;
    speed_mode <= speed_reg;

    process(clk, reset_n)
        variable matched_cmd : integer range -1 to 8;
    begin
        if reset_n = '0' then
            state       <= S_COLLECT;
            buf         <= (others => '0');
            cnt         <= 0;
            tx_idx      <= 0;
            max_tx_idx  <= 0;
            tx_data     <= (others => '0');
            tx_start_i  <= '0';
            reset_cmd   <= '0';
            mode_reg    <= "00";
            speed_reg   <= "011";
        elsif rising_edge(clk) then
            tx_start_i <= '0';
            reset_cmd  <= '0';

            case state is
                when S_COLLECT =>
                    if rx_valid = '1' then
                        if rx_data = x"0D" or rx_data = x"0A" then
                            matched_cmd := -1;
                            for i in CMD_ROM'range loop
                                if cnt = CMD_LEN_ROM(i) and buf = CMD_ROM(i) then
                                    matched_cmd := i;
                                end if;
                            end loop;

                            case matched_cmd is
                                when 0 =>
                                    reset_cmd <= '1';
                                    current_rom <= ROM_OK;
                                    max_tx_idx <= 3;
                                    state <= S_SEND_RESP;

                                when 1 =>
                                    mode_reg <= "00";
                                    reset_cmd <= '1';
                                    current_rom <= ROM_RES0;
                                    max_tx_idx <= 11;
                                    state <= S_SEND_RESP;

                                when 2 =>
                                    mode_reg <= "01";
                                    reset_cmd <= '1';
                                    current_rom <= ROM_RES1;
                                    max_tx_idx <= 11;
                                    state <= S_SEND_RESP;

                                when 3 =>
                                    mode_reg <= "10";
                                    reset_cmd <= '1';
                                    current_rom <= ROM_RES2;
                                    max_tx_idx <= 12;
                                    state <= S_SEND_RESP;

                                when 4 =>
                                    speed_reg <= "001";
                                    reset_cmd <= '1';
                                    current_rom <= ROM_SPD1;
                                    max_tx_idx <= 10;
                                    state <= S_SEND_RESP;

                                when 5 =>
                                    speed_reg <= "010";
                                    reset_cmd <= '1';
                                    current_rom <= ROM_SPD2;
                                    max_tx_idx <= 10;
                                    state <= S_SEND_RESP;

                                when 6 =>
                                    speed_reg <= "011";
                                    reset_cmd <= '1';
                                    current_rom <= ROM_SPD3;
                                    max_tx_idx <= 10;
                                    state <= S_SEND_RESP;

                                when 7 =>
                                    speed_reg <= "100";
                                    reset_cmd <= '1';
                                    current_rom <= ROM_SPD4;
                                    max_tx_idx <= 10;
                                    state <= S_SEND_RESP;

                                when 8 =>
                                    speed_reg <= "101";
                                    reset_cmd <= '1';
                                    current_rom <= ROM_SPD5;
                                    max_tx_idx <= 10;
                                    state <= S_SEND_RESP;

                                when others =>
                                    current_rom <= ROM_UNK;
                                    max_tx_idx <= 16;
                                    state <= S_SEND_RESP;
                            end if;
                            
                            cnt <= 0;
                            buf <= (others => '0');
                        else
                            if cnt < 6 then
                                buf(cnt*8+7 downto cnt*8) <= rx_data;
                                cnt <= cnt + 1;
                            end if;
                        end if;
                    end if;

                when S_SEND_RESP =>
                    tx_idx <= 0;
                    tx_data <= current_rom(0);
                    tx_start_i <= '1';
                    state <= S_WAIT_TX;

                when S_WAIT_TX =>
                    if tx_busy = '0' and tx_start_i = '0' then
                        if tx_idx = max_tx_idx then
                            state <= S_COLLECT;
                        else
                            tx_idx   <= tx_idx + 1;
                            tx_data  <= current_rom(tx_idx + 1);
                            tx_start_i <= '1';
                        end if;
                    end if;
                    
                when others =>
                    state <= S_COLLECT;
            end case;
        end if;
    end process;

end rtl;
