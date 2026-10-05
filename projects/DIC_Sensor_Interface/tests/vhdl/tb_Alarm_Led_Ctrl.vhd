library ieee;
use ieee.std_logic_1164.all;

use std.env.finish;

entity tb_Alarm_Led_Ctrl is
end entity tb_Alarm_Led_Ctrl;

architecture sim of tb_Alarm_Led_Ctrl is
  signal clk_1Hz           : std_logic := '0';
  signal low_out_of_range  : std_logic := '0';
  signal high_out_of_range : std_logic := '0';
  signal led_drv           : std_logic;
begin
  -- Device under test: combinational alarm LED gate.
  dut : entity work.Alarm_Led_Ctrl
    port map (
      clk_1Hz           => clk_1Hz,
      low_out_of_range  => low_out_of_range,
      high_out_of_range => high_out_of_range,
      led_drv           => led_drv
    );

  stim : process
    -- Exercise all combinations of low/high range flags and clk_1Hz.
    procedure check_case(
      constant low_value  : in std_logic;
      constant high_value : in std_logic;
      constant label_text : in string
    ) is
      variable expected_led : std_logic;
    begin
      low_out_of_range  <= low_value;
      high_out_of_range <= high_value;

      for clk_index in 0 to 1 loop
        if clk_index = 0 then
          clk_1Hz <= '0';
        else
          clk_1Hz <= '1';
        end if;
        wait for 1 ns;

        if low_value = '1' or high_value = '1' then
          expected_led := clk_1Hz;
        else
          expected_led := '0';
        end if;

        report label_text &
               ": clk_1Hz=" & std_logic'image(clk_1Hz) &
               " low=" & std_logic'image(low_value) &
               " high=" & std_logic'image(high_value) &
               " expected_led=" & std_logic'image(expected_led) &
               " actual_led=" & std_logic'image(led_drv)
          severity note;

        assert led_drv = expected_led
          report "FAIL: led_drv mismatch during " & label_text
          severity failure;
      end loop;
    end procedure check_case;
  begin
    check_case('0', '0', "normal range");
    check_case('1', '0', "low out of range");
    check_case('0', '1', "high out of range");
    check_case('1', '1', "both out of range flags");

    report "PASS: Alarm_Led_Ctrl LED output follows clk_1Hz only when an out-of-range flag is asserted"
      severity note;
    finish;
  end process;
end architecture sim;
