library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.finish;

entity tb_Clock_Divider is
end entity tb_Clock_Divider;

architecture sim of tb_Clock_Divider is
  -- Small simulated clock frequency keeps the divider test short.
  constant CLK_FREQ_HZ       : positive := 20;
  constant CLK_PERIOD        : time := 10 ns;
  constant HALF_1HZ_CYCLES   : positive := CLK_FREQ_HZ / 2;
  constant TICK_10S_CYCLES   : positive := CLK_FREQ_HZ * 10;
  constant MONITOR_CYCLES    : positive := (2 * TICK_10S_CYCLES) + 5;

  signal clk      : std_logic := '0';
  signal rst_n    : std_logic := '0';
  signal clk_1Hz  : std_logic;
  signal tick_10s : std_logic;
begin
  -- Free-running simulation clock.
  clk <= not clk after CLK_PERIOD / 2;

  -- Device under test: clock divider with accelerated generic.
  dut : entity work.Clock_Divider
    generic map (
      CLK_FREQ_HZ => CLK_FREQ_HZ
    )
    port map (
      clk      => clk,
      rst_n    => rst_n,
      clk_1Hz  => clk_1Hz,
      tick_10s => tick_10s
    );

  stim : process
    variable expected_clk_1hz : std_logic;
    variable prev_tick_10s    : std_logic := '0';
  begin
    -- Check reset state before releasing the DUT.
    wait until rising_edge(clk);
    wait for 1 ns;
    assert clk_1Hz = '0'
      report "FAIL: clk_1Hz is not low during reset"
      severity failure;
    assert tick_10s = '0'
      report "FAIL: tick_10s is not low during reset"
      severity failure;

    rst_n <= '1';

    -- Verify 1 Hz toggling and one-cycle tick_10s pulses.
    for cycle_num in 1 to MONITOR_CYCLES loop
      wait until rising_edge(clk);
      wait for 1 ns;

      if ((cycle_num / HALF_1HZ_CYCLES) mod 2) = 0 then
        expected_clk_1hz := '0';
      else
        expected_clk_1hz := '1';
      end if;

      assert clk_1Hz = expected_clk_1hz
        report "FAIL: clk_1Hz did not toggle at the expected 1 Hz half-period"
        severity failure;

      if (cycle_num mod TICK_10S_CYCLES) = 0 then
        assert tick_10s = '1'
          report "FAIL: tick_10s was not high at the expected 10 s boundary"
          severity failure;
      else
        assert tick_10s = '0'
          report "FAIL: tick_10s was high outside the expected one-cycle pulse"
          severity failure;
      end if;

      assert not (prev_tick_10s = '1' and tick_10s = '1')
        report "FAIL: tick_10s stayed high for consecutive clock cycles"
        severity failure;
      prev_tick_10s := tick_10s;
    end loop;

    -- Reapply reset and confirm counters restart from the initial state.
    rst_n <= '0';
    wait until rising_edge(clk);
    wait for 1 ns;
    assert clk_1Hz = '0'
      report "FAIL: clk_1Hz did not reset low"
      severity failure;
    assert tick_10s = '0'
      report "FAIL: tick_10s did not reset low"
      severity failure;

    rst_n <= '1';
    for cycle_num in 1 to TICK_10S_CYCLES - 1 loop
      wait until rising_edge(clk);
      wait for 1 ns;

      if cycle_num < HALF_1HZ_CYCLES then
        assert clk_1Hz = '0'
          report "FAIL: clk_1Hz counter did not restart from the reset state"
          severity failure;
      end if;

      assert tick_10s = '0'
        report "FAIL: tick_10s asserted too early after reset"
        severity failure;
    end loop;

    wait until rising_edge(clk);
    wait for 1 ns;
    assert tick_10s = '1'
      report "FAIL: tick_10s did not assert at the first 10 s boundary after reset"
      severity failure;

    report "PASS: Clock_Divider clk_1Hz, tick_10s one-shot, and reset behavior verified"
      severity note;
    finish;
  end process;
end architecture sim;
