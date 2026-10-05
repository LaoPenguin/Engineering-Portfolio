library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.finish;
use work.digital_constants_pkg.all;

entity tb_Calibration_Unit is
end entity tb_Calibration_Unit;

architecture sim of tb_Calibration_Unit is
  constant CLK_PERIOD : time := 10 ns;

  signal clk               : std_logic := '0';
  signal rst_n             : std_logic := '0';
  signal capture_en        : std_logic := '0';
  signal cal_en            : std_logic := '0';
  signal adc_code          : adc_code_t := (others => '0');
  signal temperature_field : temperature_field_t;
  signal low_out_of_range  : std_logic;
  signal high_out_of_range : std_logic;
  signal cal_done          : std_logic;

  function decode_temperature_x10(field_value : temperature_field_t) return integer is
  begin
    return to_integer(field_value);
  end function decode_temperature_x10;

  function hex_char(nibble_value : natural) return character is
  begin
    case nibble_value is
      when 0  => return '0';
      when 1  => return '1';
      when 2  => return '2';
      when 3  => return '3';
      when 4  => return '4';
      when 5  => return '5';
      when 6  => return '6';
      when 7  => return '7';
      when 8  => return '8';
      when 9  => return '9';
      when 10 => return 'A';
      when 11 => return 'B';
      when 12 => return 'C';
      when 13 => return 'D';
      when 14 => return 'E';
      when others => return 'F';
    end case;
  end function hex_char;

  function temperature_field_hex(field_value : temperature_field_t) return string is
    variable value_u : unsigned(TEMP_WIDTH - 1 downto 0);
    variable result  : string(1 to 3);
  begin
    value_u := unsigned(field_value);
    result(1) := hex_char(to_integer(value_u(11 downto 8)));
    result(2) := hex_char(to_integer(value_u(7 downto 4)));
    result(3) := hex_char(to_integer(value_u(3 downto 0)));
    return result;
  end function temperature_field_hex;
begin
  -- Free-running simulation clock.
  clk <= not clk after CLK_PERIOD / 2;

  -- Device under test: fixed-point ADC-to-temperature calibration unit.
  dut : entity work.Calibration_Unit
    port map (
      clk               => clk,
      rst_n             => rst_n,
      capture_en        => capture_en,
      cal_en            => cal_en,
      adc_code          => adc_code,
      temperature_field => temperature_field,
      low_out_of_range  => low_out_of_range,
      high_out_of_range => high_out_of_range,
      cal_done          => cal_done
    );

  stim : process
    -- Advance one clock and sample outputs after delta-cycle settling.
    procedure tick is
    begin
      wait until rising_edge(clk);
      wait for 1 ns;
    end procedure tick;

    procedure run_case(
      constant adc_code_value      : in natural;
      constant expected_x10        : in integer;
      constant expected_low_range  : in std_logic;
      constant expected_high_range : in std_logic
    ) is
      variable actual_x10 : integer;
      variable poison_code : natural;
    begin
      -- Capture the intended ADC code, then change the input to prove latching.
      adc_code <= to_unsigned(adc_code_value, ADC_WIDTH);
      capture_en <= '1';
      tick;
      capture_en <= '0';

      if adc_code_value = 1023 then
        poison_code := 0;
      else
        poison_code := 1023;
      end if;

      adc_code <= to_unsigned(poison_code, ADC_WIDTH);
      cal_en   <= '1';
      tick;
      cal_en   <= '0';

      -- Compare signed temperature, saturation flags, and cal_done pulse.
      actual_x10 := decode_temperature_x10(temperature_field);

      report "ADC code " & integer'image(adc_code_value) &
             ": expected_x10=" & integer'image(expected_x10) &
             " expected_hex=0x" & temperature_field_hex(temperature_field_t'(to_signed(expected_x10, TEMP_WIDTH))) &
             " actual_x10=" & integer'image(actual_x10) &
             " actual_hex=0x" & temperature_field_hex(temperature_field) &
             " poison_adc_code=" & integer'image(poison_code) &
             " low=" & std_logic'image(low_out_of_range) &
             " high=" & std_logic'image(high_out_of_range)
        severity note;

      assert cal_done = '1'
        report "FAIL: cal_done was not asserted with valid result"
        severity failure;
      assert actual_x10 = expected_x10
        report "FAIL: temperature_field mismatch for ADC code " & integer'image(adc_code_value)
        severity failure;
      assert low_out_of_range = expected_low_range
        report "FAIL: low_out_of_range mismatch for ADC code " & integer'image(adc_code_value)
        severity failure;
      assert high_out_of_range = expected_high_range
        report "FAIL: high_out_of_range mismatch for ADC code " & integer'image(adc_code_value)
        severity failure;

      tick;
      assert cal_done = '0'
        report "FAIL: cal_done stayed high after cal_en deasserted"
        severity failure;
    end procedure run_case;
  begin
    -- Check reset defaults before running calibration vectors.
    tick;
    assert temperature_field = to_signed(0, TEMP_WIDTH)
      report "FAIL: temperature_field did not reset to zero"
      severity failure;
    assert low_out_of_range = '0'
      report "FAIL: low_out_of_range did not reset low"
      severity failure;
    assert high_out_of_range = '0'
      report "FAIL: high_out_of_range did not reset low"
      severity failure;
    assert cal_done = '0'
      report "FAIL: cal_done did not reset low"
      severity failure;
    assert capture_en = '0'
      report "FAIL: capture_en did not start low"
      severity failure;

    rst_n <= '1';
    tick;

    run_case(0,    -200, '1', '0');
    run_case(77,   -200, '1', '0');
    run_case(78,   -200, '0', '0');
    run_case(253,     2, '0', '0');
    run_case(515,   303, '0', '0');
    run_case(946,   800, '0', '0');
    run_case(947,   800, '0', '1');
    run_case(1023,  800, '0', '1');

    report "PASS: Calibration_Unit fixed-point conversion, saturation, flags, and cal_done verified"
      severity note;
    finish;
  end process;
end architecture sim;
