library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_adv7513_setup is
end tb_adv7513_setup;

architecture tb of tb_adv7513_setup is

    -- Testbench scenarios:
    -- 1. Reset and waiting for the internal delay before I2C configuration starts.
    -- 2. Verification of the full ROM command set and its order.
    -- 3. Verification of a valid busy handshake with the I2C controller.
    -- 4. Verification that done is asserted after the sequence completes.
    -- 5. Repeated reset and repeated configuration start.

    constant CLK_PERIOD : time := 10 ns;

    signal clk              : std_logic := '0';
    signal rst              : std_logic := '1';
    signal i2c_activate     : std_logic;
    signal i2c_busy         : std_logic := '0';
    signal i2c_address      : std_logic_vector(6 downto 0);
    signal i2c_readnotwrite : std_logic;
    signal i2c_byte1        : std_logic_vector(7 downto 0);
    signal i2c_byte2        : std_logic_vector(7 downto 0);
    signal active           : std_logic;
    signal done             : std_logic;
    signal is_busywait      : std_logic;
    signal is_busyseen      : std_logic;

    type rom_t is array (0 to 20) of std_logic_vector(23 downto 0);
    constant expected_rom : rom_t := (
        0  => x"724110",
        1  => x"729803",
        2  => x"729AE0",
        3  => x"729C30",
        4  => x"729D61",
        5  => x"72A2A4",
        6  => x"72A3A4",
        7  => x"72E0D0",
        8  => x"72E460",
        9  => x"72F900",
        10 => x"721500",
        11 => x"721630",
        12 => x"721700",
        13 => x"721846",
        14 => x"72BA60",
        15 => x"725500",
        16 => x"725608",
        17 => x"724100",
        18 => x"72AF06",
        19 => x"7296C0",
        20 => x"7294C0"
    );

    component adv7513_setup is
        generic (
            CNT_200MS : integer := 10_000_000
        );
        port (
            clk              : in  std_logic;
            rst              : in  std_logic;
            i2c_activate     : out std_logic;
            i2c_busy         : in  std_logic;
            i2c_address      : out std_logic_vector(6 downto 0);
            i2c_readnotwrite : out std_logic;
            i2c_byte1        : out std_logic_vector(7 downto 0);
            i2c_byte2        : out std_logic_vector(7 downto 0);
            active           : out std_logic;
            done             : out std_logic;
            is_busywait      : out std_logic;
            is_busyseen      : out std_logic
        );
    end component;

begin

    clk <= not clk after CLK_PERIOD / 2;

    dut: adv7513_setup
        generic map(
            CNT_200MS => 8
        )
        port map(
            clk              => clk,
            rst              => rst,
            i2c_activate     => i2c_activate,
            i2c_busy         => i2c_busy,
            i2c_address      => i2c_address,
            i2c_readnotwrite => i2c_readnotwrite,
            i2c_byte1        => i2c_byte1,
            i2c_byte2        => i2c_byte2,
            active           => active,
            done             => done,
            is_busywait      => is_busywait,
            is_busyseen      => is_busyseen
        );

    stim_proc: process
        variable observed : std_logic_vector(23 downto 0);

        procedure accept_transaction(idx : integer) is
        begin
            wait until i2c_activate = '1';
            observed := i2c_address & i2c_readnotwrite & i2c_byte1 & i2c_byte2;
            assert observed = expected_rom(idx)
                report "ROM transaction has an incorrect value" severity error;

            wait until rising_edge(clk);
            i2c_busy <= '1';
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            i2c_busy <= '0';

            wait until i2c_activate = '0';
            wait until rising_edge(clk);
        end procedure;
    begin
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst <= '0';

        assert active = '0' and done = '0'
            report "Before configuration starts, active and done must both be low" severity error;

        for i in 0 to 20 loop
            accept_transaction(i);
        end loop;

        wait until done = '1';
        assert active = '0'
            report "After configuration completes, active must deassert" severity error;

        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst <= '0';

        for i in 0 to 2 loop
            accept_transaction(i);
        end loop;

        assert false
            report "tb_adv7513_setup completed."
            severity note;
        wait;
    end process;

end tb;
