library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package digital_constants_pkg is
  -- Shared width definitions for the digital temperature subsystem.
  constant ADC_WIDTH    : positive := 10;
  constant TEMP_WIDTH   : positive := 12;
  constant DEV_ID_WIDTH : positive := 4;
  constant FRAME_WIDTH  : positive := 16;

  -- ADC calibration endpoints and span in raw 10-bit ADC codes.
  constant ADC_LOW_CODE  : natural := 78;
  constant ADC_HIGH_CODE : natural := 946;
  constant ADC_SPAN      : natural := 868;

  -- Temperature limits are stored in 0.1 deg C signed integer units.
  constant TEMP_MIN_X10 : integer := -200;
  constant TEMP_MAX_X10 : integer := 800;

  -- Fixed-point constants for the Q12 calibration multiply.
  constant TEMP_SLOPE_Q12 : natural := 4719;
  constant ROUND_Q12      : natural := 2048;
  constant Q12_SHIFT      : natural := 12;

  -- Common typed aliases used by RTL and testbenches.
  subtype adc_code_t is unsigned(ADC_WIDTH - 1 downto 0);
  subtype temperature_field_t is signed(TEMP_WIDTH - 1 downto 0);
  subtype dev_id_t is std_logic_vector(DEV_ID_WIDTH - 1 downto 0);
  subtype serial_frame_t is std_logic_vector(FRAME_WIDTH - 1 downto 0);

  -- temperature_field is a 12-bit signed two's-complement value in
  -- 0.1 deg C units. It is not an unsigned offset-scaled code.
  --
  -- -20.0 deg C -> -200 -> 0xF38
  --   0.0 deg C ->    0 -> 0x000
  -- +80.0 deg C -> +800 -> 0x320
  constant TEMP_FIELD_MINUS_20C : temperature_field_t := to_signed(-200, TEMP_WIDTH);
  constant TEMP_FIELD_ZERO_C    : temperature_field_t := to_signed(0, TEMP_WIDTH);
  constant TEMP_FIELD_PLUS_80C  : temperature_field_t := to_signed(800, TEMP_WIDTH);
end package digital_constants_pkg;
