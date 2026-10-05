library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.digital_constants_pkg.all;

entity Calibration_Unit is
  port (
    clk               : in  std_logic;
    rst_n             : in  std_logic;
    capture_en        : in  std_logic;
    cal_en            : in  std_logic;
    adc_code          : in  adc_code_t;
    temperature_field : out temperature_field_t;
    low_out_of_range  : out std_logic;
    high_out_of_range : out std_logic;
    cal_done          : out std_logic
  );
end entity Calibration_Unit;

architecture rtl of Calibration_Unit is
  -- Preserve this unit as a readable hierarchy block in Vivado schematics.
  -- This affects schematic/synthesis hierarchy only, not RTL behavior.
  attribute keep_hierarchy : string;
  attribute keep_hierarchy of rtl : architecture is "yes";

  -- Internal widths preserve the fixed-point multiply without truncation.
  constant SLOPE_WIDTH     : positive := 13;
  constant PRODUCT_WIDTH   : positive := 24;
  constant TEMP_CALC_WIDTH : positive := 16;

  signal adc_code_reg          : adc_code_t := (others => '0');
  signal temperature_field_reg : temperature_field_t := (others => '0');
  signal low_out_of_range_reg  : std_logic := '0';
  signal high_out_of_range_reg : std_logic := '0';
  signal cal_done_reg          : std_logic := '0';
begin
  -- Static range check for the signed 12-bit temperature output.
  assert TEMP_MIN_X10 >= -(2 ** (TEMP_WIDTH - 1)) and
         TEMP_MAX_X10 <= (2 ** (TEMP_WIDTH - 1)) - 1
    report "Calibration_Unit temperature range does not fit temperature_field"
    severity failure;

  temperature_field <= temperature_field_reg;
  low_out_of_range  <= low_out_of_range_reg;
  high_out_of_range <= high_out_of_range_reg;
  cal_done          <= cal_done_reg;

  -- Capture ADC data on capture_en and run fixed-point calibration on cal_en.
  process (clk)
    variable delta_u          : unsigned(ADC_WIDTH - 1 downto 0);
    variable product_u        : unsigned(PRODUCT_WIDTH - 1 downto 0);
    variable rounded_u        : unsigned(PRODUCT_WIDTH - 1 downto 0);
    variable scaled_u         : unsigned(PRODUCT_WIDTH - 1 downto 0);
    variable temperature_x10_s : signed(TEMP_CALC_WIDTH - 1 downto 0);
    variable calc_adc_code     : adc_code_t;
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        adc_code_reg          <= (others => '0');
        temperature_field_reg <= (others => '0');
        low_out_of_range_reg  <= '0';
        high_out_of_range_reg <= '0';
        cal_done_reg          <= '0';
      else
        cal_done_reg <= '0';
        calc_adc_code := adc_code_reg;

        -- Latch the ADC code after adc_done indicates stable data.
        if capture_en = '1' then
          adc_code_reg  <= adc_code;
          calc_adc_code := adc_code;
        end if;

        if cal_en = '1' then
          -- Saturate out-of-range inputs before applying the linear mapping.
          if calc_adc_code < to_unsigned(ADC_LOW_CODE, ADC_WIDTH) then
            delta_u                 := (others => '0');
            low_out_of_range_reg    <= '1';
            high_out_of_range_reg   <= '0';
          elsif calc_adc_code > to_unsigned(ADC_HIGH_CODE, ADC_WIDTH) then
            delta_u                 := to_unsigned(ADC_SPAN, ADC_WIDTH);
            low_out_of_range_reg    <= '0';
            high_out_of_range_reg   <= '1';
          else
            delta_u                 := calc_adc_code - to_unsigned(ADC_LOW_CODE, ADC_WIDTH);
            low_out_of_range_reg    <= '0';
            high_out_of_range_reg   <= '0';
          end if;

          -- Q12 calculation: temp_x10 = -200 + ((delta * slope + round) >> 12).
          product_u := resize(delta_u * to_unsigned(TEMP_SLOPE_Q12, SLOPE_WIDTH), PRODUCT_WIDTH);
          rounded_u := product_u + to_unsigned(ROUND_Q12, PRODUCT_WIDTH);
          scaled_u  := shift_right(rounded_u, Q12_SHIFT);

          temperature_x10_s :=
            signed(resize(scaled_u, TEMP_CALC_WIDTH)) +
            to_signed(TEMP_MIN_X10, TEMP_CALC_WIDTH);

          temperature_field_reg <= resize(temperature_x10_s, TEMP_WIDTH);
          cal_done_reg          <= '1';
        end if;
      end if;
    end if;
  end process;
end architecture rtl;
