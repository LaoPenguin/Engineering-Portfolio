module Digital_Top
#(
  parameter integer CLK_FREQ_HZ     = 1000000,
  parameter integer ADC_WIDTH       = 10,
  parameter integer TEMP_WIDTH      = 12,
  parameter integer DEV_ID_WIDTH    = 4,
  parameter integer FRAME_WIDTH     = 16,
  parameter integer ADC_LOW_CODE    = 78,
  parameter integer ADC_HIGH_CODE   = 946,
  parameter integer ADC_SPAN        = 868,
  parameter integer TEMP_MIN_X10    = -200,
  parameter integer TEMP_MAX_X10    = 800,
  parameter integer TEMP_SLOPE_Q12  = 4719,
  parameter integer ROUND_Q12       = 2048,
  parameter integer Q12_SHIFT       = 12
)
(
  input  wire                     clk,
  input  wire                     rst_n,
  input  wire                     adc_done,
  input  wire [ADC_WIDTH-1:0]     adc_data,
  input  wire [DEV_ID_WIDTH-1:0]  dev_id,
  output wire                     adc_start,
  output wire                     serial_out,
  output wire                     serial_clk,
  output wire                     led_drv
);

  wire clk_1hz_s;
  wire tick_10s_s;
  wire adc_start_s;
  wire capture_en_s;
  wire cal_en_s;
  wire cal_done_s;
  wire tx_en_s;
  wire tx_done_s;
  wire [ADC_WIDTH-1:0] adc_code_s;
  wire signed [TEMP_WIDTH-1:0] temperature_field_s;
  wire low_out_s;
  wire high_out_s;

  assign adc_start = adc_start_s;
  assign adc_code_s = adc_data;

  Clock_Divider #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ)
  ) u_clock_divider (
    .clk(clk),
    .rst_n(rst_n),
    .clk_1Hz(clk_1hz_s),
    .tick_10s(tick_10s_s)
  );

  Top_Control_FSM u_top_control_fsm (
    .clk(clk),
    .rst_n(rst_n),
    .tick_10s(tick_10s_s),
    .adc_done(adc_done),
    .cal_done(cal_done_s),
    .tx_done(tx_done_s),
    .adc_start(adc_start_s),
    .capture_en(capture_en_s),
    .cal_en(cal_en_s),
    .tx_en(tx_en_s)
  );

  Calibration_Unit #(
    .ADC_WIDTH(ADC_WIDTH),
    .TEMP_WIDTH(TEMP_WIDTH),
    .ADC_LOW_CODE(ADC_LOW_CODE),
    .ADC_HIGH_CODE(ADC_HIGH_CODE),
    .ADC_SPAN(ADC_SPAN),
    .TEMP_MIN_X10(TEMP_MIN_X10),
    .TEMP_MAX_X10(TEMP_MAX_X10),
    .TEMP_SLOPE_Q12(TEMP_SLOPE_Q12),
    .ROUND_Q12(ROUND_Q12),
    .Q12_SHIFT(Q12_SHIFT)
  ) u_calibration_unit (
    .clk(clk),
    .rst_n(rst_n),
    .capture_en(capture_en_s),
    .cal_en(cal_en_s),
    .adc_code(adc_code_s),
    .temperature_field(temperature_field_s),
    .low_out_of_range(low_out_s),
    .high_out_of_range(high_out_s),
    .cal_done(cal_done_s)
  );

  Alarm_Led_Ctrl u_alarm_led_ctrl (
    .clk_1Hz(clk_1hz_s),
    .low_out_of_range(low_out_s),
    .high_out_of_range(high_out_s),
    .led_drv(led_drv)
  );

  Serialize_Output #(
    .TEMP_WIDTH(TEMP_WIDTH),
    .DEV_ID_WIDTH(DEV_ID_WIDTH),
    .FRAME_WIDTH(FRAME_WIDTH)
  ) u_serialize_output (
    .clk(clk),
    .rst_n(rst_n),
    .tx_en(tx_en_s),
    .dev_id(dev_id),
    .temperature_field(temperature_field_s),
    .serial_out(serial_out),
    .serial_clk(serial_clk),
    .tx_done(tx_done_s)
  );

endmodule
