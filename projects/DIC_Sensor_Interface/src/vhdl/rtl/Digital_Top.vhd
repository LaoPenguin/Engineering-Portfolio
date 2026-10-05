library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.digital_constants_pkg.all;

entity Digital_Top is
  generic (
    CLK_FREQ_HZ : positive := 1_000_000
  );
  port (
    clk                       : in  std_logic;
    rst_n                     : in  std_logic;
    adc_done                  : in  std_logic;
    adc_data                  : in  std_logic_vector(ADC_WIDTH - 1 downto 0);
    dev_id                    : in  dev_id_t;
    adc_start                 : out std_logic;
    serial_out                : out std_logic;
    serial_clk                : out std_logic;
    led_drv                   : out std_logic
  );
end entity Digital_Top;

architecture rtl of Digital_Top is
  -- Internal handshake and data signals between subsystem blocks.
  signal clk_1hz_s           : std_logic;
  signal tick_10s_s          : std_logic;
  signal adc_start_s         : std_logic;
  signal capture_en_s        : std_logic;
  signal cal_en_s            : std_logic;
  signal cal_done_s          : std_logic;
  signal tx_en_s             : std_logic;
  signal tx_done_s           : std_logic;
  signal adc_code_s          : adc_code_t;
  signal temperature_field_s : temperature_field_t := (others => '0');
  signal low_out_s           : std_logic;
  signal high_out_s          : std_logic;
begin
  adc_start               <= adc_start_s;
  adc_code_s              <= unsigned(adc_data);

  -- Derive LED blink clock and periodic measurement trigger from system clk.
  u_clock_divider : entity work.Clock_Divider
    generic map (
      CLK_FREQ_HZ => CLK_FREQ_HZ
    )
    port map (
      clk      => clk,
      rst_n    => rst_n,
      clk_1Hz  => clk_1hz_s,
      tick_10s => tick_10s_s
    );

  -- Sequence ADC start, ADC capture, calibration, and serial transmission.
  u_top_control_fsm : entity work.Top_Control_FSM
    port map (
      clk         => clk,
      rst_n       => rst_n,
      tick_10s    => tick_10s_s,
      adc_done    => adc_done,
      cal_done    => cal_done_s,
      tx_done     => tx_done_s,
      adc_start   => adc_start_s,
      capture_en  => capture_en_s,
      cal_en      => cal_en_s,
      tx_en       => tx_en_s
    );

  -- Convert captured ADC code into signed 0.1 deg C temperature field.
  u_calibration_unit : entity work.Calibration_Unit
    port map (
      clk               => clk,
      rst_n             => rst_n,
      capture_en        => capture_en_s,
      cal_en            => cal_en_s,
      adc_code          => adc_code_s,
      temperature_field => temperature_field_s,
      low_out_of_range  => low_out_s,
      high_out_of_range => high_out_s,
      cal_done          => cal_done_s
    );

  -- Drive alarm LED from calibration range flags.
  u_alarm_led_ctrl : entity work.Alarm_Led_Ctrl
    port map (
      clk_1Hz           => clk_1hz_s,
      low_out_of_range  => low_out_s,
      high_out_of_range => high_out_s,
      led_drv           => led_drv
    );

  -- Serialize device ID and temperature frame in LSB-first order.
  u_serialize_output : entity work.Serialize_Output
    port map (
      clk               => clk,
      rst_n             => rst_n,
      tx_en             => tx_en_s,
      dev_id            => dev_id,
      temperature_field => temperature_field_s,
      serial_out        => serial_out,
      serial_clk        => serial_clk,
      tx_done           => tx_done_s
    );
end architecture rtl;
