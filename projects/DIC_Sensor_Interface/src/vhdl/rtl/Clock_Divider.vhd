library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Clock_Divider is
  generic (
    CLK_FREQ_HZ : positive := 1_000_000
  );
  port (
    clk      : in  std_logic;
    rst_n    : in  std_logic;
    clk_1Hz  : out std_logic;
    tick_10s : out std_logic
  );
end entity Clock_Divider;

architecture rtl of Clock_Divider is
  -- Count limits derived from the input clock frequency generic.
  constant CLK_1HZ_HALF_PERIOD_CYCLES : positive := CLK_FREQ_HZ / 2;
  constant TICK_10S_PERIOD_CYCLES     : positive := CLK_FREQ_HZ * 10;

  signal clk_1hz_count  : natural range 0 to CLK_1HZ_HALF_PERIOD_CYCLES - 1 := 0;
  signal tick_10s_count : natural range 0 to TICK_10S_PERIOD_CYCLES - 1 := 0;
  signal clk_1hz_reg    : std_logic := '0';
  signal tick_10s_reg   : std_logic := '0';
begin
  assert CLK_FREQ_HZ >= 2
    report "Clock_Divider CLK_FREQ_HZ must be at least 2"
    severity failure;

  assert (CLK_FREQ_HZ mod 2) = 0
    report "Clock_Divider CLK_FREQ_HZ must be even for exact 1 Hz 50% duty cycle"
    severity failure;

  clk_1Hz  <= clk_1hz_reg;
  tick_10s <= tick_10s_reg;

  -- Generate a 1 Hz square wave and a one-clock pulse every 10 seconds.
  process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        clk_1hz_count  <= 0;
        tick_10s_count <= 0;
        clk_1hz_reg    <= '0';
        tick_10s_reg   <= '0';
      else
        tick_10s_reg <= '0';

        if clk_1hz_count = CLK_1HZ_HALF_PERIOD_CYCLES - 1 then
          clk_1hz_count <= 0;
          clk_1hz_reg   <= not clk_1hz_reg;
        else
          clk_1hz_count <= clk_1hz_count + 1;
        end if;

        if tick_10s_count = TICK_10S_PERIOD_CYCLES - 1 then
          tick_10s_count <= 0;
          tick_10s_reg   <= '1';
        else
          tick_10s_count <= tick_10s_count + 1;
        end if;
      end if;
    end if;
  end process;
end architecture rtl;
