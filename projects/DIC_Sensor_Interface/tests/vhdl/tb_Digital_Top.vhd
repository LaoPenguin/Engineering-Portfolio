library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.finish;
use work.digital_constants_pkg.all;

entity tb_Digital_Top is
end entity tb_Digital_Top;

architecture sim of tb_Digital_Top is
  -- Use a tiny clock frequency generic so the 10-second tick is simulated fast.
  constant CLK_PERIOD  : time := 10 ns;
  constant CLK_FREQ_HZ : positive := 10;

  signal clk                       : std_logic := '0';
  signal rst_n                     : std_logic := '0';
  signal adc_done                  : std_logic := '0';
  signal adc_data                  : std_logic_vector(ADC_WIDTH - 1 downto 0) := (others => '0');
  signal dev_id                    : dev_id_t := (others => '0');
  signal adc_start                 : std_logic;
  signal serial_out                : std_logic;
  signal serial_clk                : std_logic;
  signal led_drv                   : std_logic;

  signal adc_model_next_data       : std_logic_vector(ADC_WIDTH - 1 downto 0) := (others => '0');
  signal adc_model_latency_cycles  : positive := 2;

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

  function serial_frame_hex(frame_value : serial_frame_t) return string is
    variable value_u : unsigned(FRAME_WIDTH - 1 downto 0);
    variable result  : string(1 to 4);
  begin
    value_u := unsigned(frame_value);
    result(1) := hex_char(to_integer(value_u(15 downto 12)));
    result(2) := hex_char(to_integer(value_u(11 downto 8)));
    result(3) := hex_char(to_integer(value_u(7 downto 4)));
    result(4) := hex_char(to_integer(value_u(3 downto 0)));
    return result;
  end function serial_frame_hex;
begin
  -- Free-running simulation clock.
  clk <= not clk after CLK_PERIOD / 2;

  -- Device under test: complete digital subsystem top level.
  dut : entity work.Digital_Top
    generic map (
      CLK_FREQ_HZ => CLK_FREQ_HZ
    )
    port map (
      clk                       => clk,
      rst_n                     => rst_n,
      adc_done                  => adc_done,
      adc_data                  => adc_data,
      dev_id                    => dev_id,
      adc_start                 => adc_start,
      serial_out                => serial_out,
      serial_clk                => serial_clk,
      led_drv                   => led_drv
    );

  -- Simple ADC model: responds to adc_start after a programmable latency.
  adc_model : process (clk)
    variable busy        : boolean := false;
    variable done_hold   : boolean := false;
    variable delay_count : natural := 0;
    variable pending_adc : std_logic_vector(ADC_WIDTH - 1 downto 0) := (others => '0');
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        adc_done   <= '0';
        adc_data   <= (others => '0');
        busy       := false;
        done_hold  := false;
        delay_count := 0;
        pending_adc := (others => '0');
      else
        if done_hold then
          adc_done  <= '0';
          done_hold := false;
        elsif busy then
          if delay_count = 1 then
            adc_data <= pending_adc;
            adc_done <= '1';
            busy      := false;
            done_hold := true;
          else
            adc_done <= '0';
            delay_count := delay_count - 1;
          end if;
        elsif adc_start = '1' then
          adc_done   <= '0';
          pending_adc := adc_model_next_data;
          delay_count := adc_model_latency_cycles;
          busy        := true;
        else
          adc_done <= '0';
        end if;
      end if;
    end if;
  end process adc_model;

  stim : process
    -- Advance one clock and sample outputs after delta-cycle settling.
    procedure tick is
    begin
      wait until rising_edge(clk);
      wait for 1 ns;
    end procedure tick;

    -- Wait until the top-level FSM starts an ADC conversion.
    procedure wait_for_adc_start is
      variable wait_count : natural := 0;
    begin
      loop
        tick;
        exit when adc_start = '1';
        wait_count := wait_count + 1;
        assert wait_count < 200
          report "FAIL: timed out waiting for adc_start"
          severity failure;
      end loop;
    end procedure wait_for_adc_start;

    -- Check LED is either off in-range or blinking out-of-range.
    procedure check_led_behavior(
      constant expect_follow_clk : in boolean;
      constant label_text        : in string
    ) is
      variable seen_led_low  : boolean := false;
      variable seen_led_high : boolean := false;
    begin
      for check_index in 1 to 12 loop
        tick;

        if expect_follow_clk then
          if led_drv = '0' then
            seen_led_low := true;
          elsif led_drv = '1' then
            seen_led_high := true;
          end if;
        else
          assert led_drv = '0'
            report "FAIL: LED was not off during " & label_text
            severity failure;
        end if;
      end loop;

      if expect_follow_clk then
        assert seen_led_low and seen_led_high
          report "FAIL: LED blink did not show both low and high phases during " & label_text
          severity failure;
      end if;
    end procedure check_led_behavior;

    -- Run a complete ADC conversion, calibration, and serial frame check.
    procedure run_scenario(
      constant label_text          : in string;
      constant adc_code_value      : in natural;
      constant latency_cycles      : in positive;
      constant dev_value           : in dev_id_t;
      constant expected_x10        : in integer;
      constant expected_low_range  : in std_logic;
      constant expected_high_range : in std_logic
    ) is
      constant expected_frame : serial_frame_t :=
        dev_value & std_logic_vector(temperature_field_t'(to_signed(expected_x10, TEMP_WIDTH)));
      variable actual_frame   : serial_frame_t := (others => '0');
      variable bit_index      : natural range 0 to FRAME_WIDTH := 0;
      variable wait_count     : natural := 0;
    begin
      dev_id                   <= dev_value;
      adc_model_next_data      <= std_logic_vector(to_unsigned(adc_code_value, ADC_WIDTH));
      adc_model_latency_cycles <= latency_cycles;

      wait_for_adc_start;

      while bit_index < FRAME_WIDTH loop
        tick;
        wait_count := wait_count + 1;

        assert wait_count < 200
          report "FAIL: timed out waiting for 16 serial bits during " & label_text
          severity failure;

        if serial_clk = '1' then
          -- Capture and verify each transmitted bit in LSB-first order.
          actual_frame(bit_index) := serial_out;
          assert serial_out = expected_frame(bit_index)
            report "FAIL: LSB-first serial bit mismatch at bit " &
                   integer'image(bit_index) & " during " & label_text
            severity failure;

          bit_index := bit_index + 1;
        end if;
      end loop;

      assert bit_index = FRAME_WIDTH
        report "FAIL: serial frame did not contain exactly 16 bits during " & label_text
        severity failure;
      assert actual_frame = expected_frame
        report "FAIL: reconstructed serial frame mismatch during " & label_text
        severity failure;

      tick;
      tick;

      report label_text &
             ": adc_code=" & integer'image(adc_code_value) &
             " expected_x10=" & integer'image(expected_x10) &
             " expected_frame=0x" & serial_frame_hex(expected_frame) &
             " actual_frame=0x" & serial_frame_hex(actual_frame) &
             " expected_low=" & std_logic'image(expected_low_range) &
             " expected_high=" & std_logic'image(expected_high_range)
        severity note;

      check_led_behavior(
        expected_low_range = '1' or expected_high_range = '1',
        label_text
      );
    end procedure run_scenario;
  begin
    -- Verify reset defaults before starting scenarios.
    for reset_cycle in 1 to 3 loop
      tick;
    end loop;

    assert adc_start = '0'
      report "FAIL: adc_start was not low during reset"
      severity failure;
    assert serial_clk = '0'
      report "FAIL: serial_clk was not low during reset"
      severity failure;
    assert led_drv = '0'
      report "FAIL: led_drv was not low during reset"
      severity failure;

    rst_n <= '1';
    tick;

    run_scenario("in-range lower boundary", 78, 2, "1010", -200, '0', '0');
    run_scenario("in-range middle",         515, 5, "1010", 303,  '0', '0');
    run_scenario("in-range upper boundary", 946, 2, "1010", 800,  '0', '0');
    run_scenario("low out-of-range",        77,  5, "1010", -200, '1', '0');
    run_scenario("high out-of-range",       947, 2, "1010", 800,  '0', '1');

    report "PASS: Digital_Top complete start/done/data flow, fixed-point calibration, alarm LED, and LSB-first serialization verified"
      severity note;
    finish;
  end process;
end architecture sim;
