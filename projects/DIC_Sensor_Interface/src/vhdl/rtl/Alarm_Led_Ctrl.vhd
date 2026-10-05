library ieee;
use ieee.std_logic_1164.all;

entity Alarm_Led_Ctrl is
  port (
    clk_1Hz           : in  std_logic;
    low_out_of_range  : in  std_logic;
    high_out_of_range : in  std_logic;
    led_drv           : out std_logic
  );
end entity Alarm_Led_Ctrl;

architecture rtl of Alarm_Led_Ctrl is
begin
  -- Blink only when the calibration unit reports an out-of-range condition.
  led_drv <= clk_1Hz when (low_out_of_range = '1' or high_out_of_range = '1') else '0';
end architecture rtl;
