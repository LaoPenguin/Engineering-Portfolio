module Alarm_Led_Ctrl
(
  input  wire clk_1Hz,
  input  wire low_out_of_range,
  input  wire high_out_of_range,
  output wire led_drv
);

  assign led_drv = (low_out_of_range || high_out_of_range) ? clk_1Hz : 1'b0;

endmodule
