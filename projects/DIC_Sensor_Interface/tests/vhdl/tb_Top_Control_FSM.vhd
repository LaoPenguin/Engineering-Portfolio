library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.finish;

entity tb_Top_Control_FSM is
end entity tb_Top_Control_FSM;

architecture sim of tb_Top_Control_FSM is
  constant CLK_PERIOD : time := 10 ns;

  signal clk        : std_logic := '0';
  signal rst_n      : std_logic := '0';
  signal tick_10s   : std_logic := '0';
  signal adc_done   : std_logic := '0';
  signal cal_done   : std_logic := '0';
  signal tx_done    : std_logic := '0';
  signal adc_start  : std_logic;
  signal capture_en : std_logic;
  signal cal_en     : std_logic;
  signal tx_en      : std_logic;
begin
  -- Free-running simulation clock.
  clk <= not clk after CLK_PERIOD / 2;

  -- Device under test: top-level control sequencer.
  dut : entity work.Top_Control_FSM
    port map (
      clk        => clk,
      rst_n      => rst_n,
      tick_10s   => tick_10s,
      adc_done   => adc_done,
      cal_done   => cal_done,
      tx_done    => tx_done,
      adc_start  => adc_start,
      capture_en => capture_en,
      cal_en     => cal_en,
      tx_en      => tx_en
    );

  stim : process
    -- Advance one clock and sample outputs after delta-cycle settling.
    procedure tick is
    begin
      wait until rising_edge(clk);
      wait for 1 ns;
    end procedure tick;

    procedure expect_outputs(
      constant expected_adc_start  : in std_logic;
      constant expected_capture_en : in std_logic;
      constant expected_cal_en     : in std_logic;
      constant expected_tx_en      : in std_logic;
      constant label_text          : in string
    ) is
    begin
      assert adc_start = expected_adc_start
        report "FAIL: adc_start mismatch during " & label_text
        severity failure;
      assert capture_en = expected_capture_en
        report "FAIL: capture_en mismatch during " & label_text
        severity failure;
      assert cal_en = expected_cal_en
        report "FAIL: cal_en mismatch during " & label_text
        severity failure;
      assert tx_en = expected_tx_en
        report "FAIL: tx_en mismatch during " & label_text
        severity failure;
    end procedure expect_outputs;

    procedure expect_idle_outputs(constant label_text : in string) is
    begin
      expect_outputs('0', '0', '0', '0', label_text);
    end procedure expect_idle_outputs;

    -- Run one measurement transaction with configurable done latencies.
    procedure run_measurement(
      constant adc_delay_cycles      : in positive;
      constant cal_delay_cycles      : in positive;
      constant tx_delay_cycles       : in positive;
      constant inject_tick_when_busy : in boolean
    ) is
    begin
      expect_idle_outputs("measurement start");

      tick_10s <= '1';
      tick;
      expect_outputs('1', '0', '0', '0', "adc_start pulse");

      tick_10s <= '0';
      tick;
      expect_idle_outputs("waiting for adc_done after adc_start");

      for wait_idx in 1 to adc_delay_cycles loop
        if inject_tick_when_busy and wait_idx = 1 then
          tick_10s <= '1';
        else
          tick_10s <= '0';
        end if;

        if wait_idx = adc_delay_cycles then
          adc_done <= '1';
        else
          adc_done <= '0';
        end if;

        tick;

        if wait_idx = adc_delay_cycles then
          expect_outputs('0', '1', '0', '0', "capture_en pulse after adc_done");
        else
          expect_idle_outputs("waiting for delayed adc_done");
        end if;
      end loop;

      tick_10s <= '0';
      adc_done <= '0';
      tick;
      expect_outputs('0', '0', '1', '0', "cal_en pulse after capture");

      tick;
      expect_idle_outputs("waiting for cal_done after cal_en");

      for wait_idx in 1 to cal_delay_cycles loop
        if wait_idx = cal_delay_cycles then
          cal_done <= '1';
        else
          cal_done <= '0';
        end if;

        tick;

        if wait_idx = cal_delay_cycles then
          expect_outputs('0', '0', '0', '1', "tx_en pulse after cal_done");
        else
          expect_idle_outputs("waiting for delayed cal_done");
        end if;
      end loop;

      cal_done <= '0';
      tick;
      expect_idle_outputs("waiting for tx_done after tx_en");

      for wait_idx in 1 to tx_delay_cycles loop
        if wait_idx = tx_delay_cycles then
          tx_done <= '1';
        else
          tx_done <= '0';
        end if;

        tick;
        expect_idle_outputs("waiting for delayed tx_done or returned idle");
      end loop;

      tx_done  <= '0';
      tick_10s <= '0';
      adc_done <= '0';
      cal_done <= '0';
      tick;
      expect_idle_outputs("idle after measurement complete");
    end procedure run_measurement;
  begin
    -- Reset and idle-state checks.
    tick;
    expect_idle_outputs("reset asserted");

    rst_n <= '1';
    tick;
    expect_idle_outputs("reset released with no tick");

    run_measurement(1, 1, 1, false);
    -- Also verify that tick_10s is ignored while the FSM is busy.
    run_measurement(3, 2, 2, true);
    run_measurement(10, 3, 3, false);

    report "PASS: Top_Control_FSM reset, one-cycle pulses, variable adc_done wait, and busy tick ignore behavior verified"
      severity note;
    finish;
  end process;
end architecture sim;
