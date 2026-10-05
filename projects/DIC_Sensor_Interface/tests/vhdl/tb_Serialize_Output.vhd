library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.finish;
use work.digital_constants_pkg.all;

entity tb_Serialize_Output is
end entity tb_Serialize_Output;

architecture sim of tb_Serialize_Output is
  constant CLK_PERIOD : time := 10 ns;

  signal clk               : std_logic := '0';
  signal rst_n             : std_logic := '0';
  signal tx_en             : std_logic := '0';
  signal dev_id            : dev_id_t := (others => '0');
  signal temperature_field : temperature_field_t := (others => '0');
  signal serial_out        : std_logic;
  signal serial_clk        : std_logic;
  signal tx_done           : std_logic;

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

  -- Device under test: 16-bit LSB-first serializer.
  dut : entity work.Serialize_Output
    port map (
      clk               => clk,
      rst_n             => rst_n,
      tx_en             => tx_en,
      dev_id            => dev_id,
      temperature_field => temperature_field,
      serial_out        => serial_out,
      serial_clk        => serial_clk,
      tx_done           => tx_done
    );

  stim : process
    -- Advance one clock and sample outputs after delta-cycle settling.
    procedure tick is
    begin
      wait until rising_edge(clk);
      wait for 1 ns;
    end procedure tick;

    procedure run_frame(
      constant dev_value           : in dev_id_t;
      constant temp_value          : in temperature_field_t;
      constant expected_frame      : in serial_frame_t;
      constant label_text          : in string;
      constant inject_busy_tx_en   : in boolean
    ) is
      variable actual_frame : serial_frame_t := (others => '0');
      variable bit_index    : natural range 0 to FRAME_WIDTH := 0;
      variable injected     : boolean := false;
      variable inject_now   : boolean := false;
    begin
      -- Start one frame transfer and check the first bit is available.
      dev_id            <= dev_value;
      temperature_field <= temp_value;
      tx_en             <= '1';
      tick;
      tx_en             <= '0';

      assert serial_clk = '0'
        report "FAIL: serial_clk was not low immediately after loading frame during " & label_text
        severity failure;
      assert tx_done = '0'
        report "FAIL: tx_done asserted while loading frame during " & label_text
        severity failure;
      assert serial_out = expected_frame(0)
        report "FAIL: serial_out did not present frame bit 0 after load during " & label_text
        severity failure;

      while bit_index < FRAME_WIDTH loop
        inject_now := false;

        -- Optional busy tx_en pulse verifies the active frame is not disturbed.
        if inject_busy_tx_en and not injected and bit_index = 4 then
          dev_id            <= "0000";
          temperature_field <= temperature_field_t'(to_signed(0, TEMP_WIDTH));
          tx_en             <= '1';
          injected          := true;
          inject_now        := true;
        end if;

        tick;

        if inject_now then
          tx_en <= '0';
        end if;

        if serial_clk = '1' then
          -- Reconstruct the frame in the transmitted LSB-first order.
          actual_frame(bit_index) := serial_out;

          report label_text &
                 ": bit[" & integer'image(bit_index) & "] expected=" &
                 std_logic'image(expected_frame(bit_index)) &
                 " actual=" & std_logic'image(serial_out)
            severity note;

          assert serial_out = expected_frame(bit_index)
            report "FAIL: LSB-first serial_out mismatch at bit " &
                   integer'image(bit_index) & " during " & label_text
            severity failure;
          assert tx_done = '0'
            report "FAIL: tx_done asserted before all 16 bits were clocked during " & label_text
            severity failure;

          bit_index := bit_index + 1;
        end if;
      end loop;

      assert actual_frame = expected_frame
        report "FAIL: reconstructed frame mismatch during " & label_text
        severity failure;

      tick;
      assert serial_clk = '0'
        report "FAIL: serial_clk did not return low after final bit during " & label_text
        severity failure;
      assert tx_done = '1'
        report "FAIL: tx_done did not assert one clk after the final serial clock during " & label_text
        severity failure;

      report label_text &
             ": expected_frame=0x" & serial_frame_hex(expected_frame) &
             " actual_frame=0x" & serial_frame_hex(actual_frame)
        severity note;

      tick;
      assert tx_done = '0'
        report "FAIL: tx_done stayed high for more than one clk during " & label_text
        severity failure;
      assert serial_clk = '0'
        report "FAIL: serial_clk was not idle low after tx_done during " & label_text
        severity failure;
    end procedure run_frame;
  begin
    tick;
    assert serial_out = '0'
      report "FAIL: serial_out did not reset low"
      severity failure;
    assert serial_clk = '0'
      report "FAIL: serial_clk did not reset low"
      severity failure;
    assert tx_done = '0'
      report "FAIL: tx_done did not reset low"
      severity failure;

    rst_n <= '1';
    tick;

    run_frame("1010", temperature_field_t'(to_signed(-200, TEMP_WIDTH)), x"AF38", "test 1 dev_id=0xA temp=0xF38", false);
    run_frame("0011", temperature_field_t'(to_signed(800, TEMP_WIDTH)), x"3320", "test 2 dev_id=0x3 temp=0x320", false);
    run_frame("1010", temperature_field_t'(to_signed(-200, TEMP_WIDTH)), x"AF38", "test 3 busy tx_en ignored", true);

    report "PASS: Serialize_Output LSB-first frames, serial_clk pulses, tx_done, and busy tx_en ignore behavior verified"
      severity note;
    finish;
  end process;
end architecture sim;
