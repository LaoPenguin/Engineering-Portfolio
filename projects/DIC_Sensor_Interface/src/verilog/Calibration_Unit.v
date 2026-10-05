module Calibration_Unit
#(
  parameter integer ADC_WIDTH      = 10,
  parameter integer TEMP_WIDTH     = 12,
  parameter integer ADC_LOW_CODE   = 78,
  parameter integer ADC_HIGH_CODE  = 946,
  parameter integer ADC_SPAN       = 868,
  parameter integer TEMP_MIN_X10   = -200,
  parameter integer TEMP_MAX_X10   = 800,
  parameter integer TEMP_SLOPE_Q12 = 4719,
  parameter integer ROUND_Q12      = 2048,
  parameter integer Q12_SHIFT      = 12
)
(
  input  wire                        clk,
  input  wire                        rst_n,
  input  wire                        capture_en,
  input  wire                        cal_en,
  input  wire [ADC_WIDTH-1:0]        adc_code,
  output reg  signed [TEMP_WIDTH-1:0] temperature_field,
  output reg                         low_out_of_range,
  output reg                         high_out_of_range,
  output reg                         cal_done
);

  localparam integer SLOPE_WIDTH     = 13;
  localparam integer PRODUCT_WIDTH   = 24;
  localparam integer TEMP_CALC_WIDTH = 16;

  localparam [ADC_WIDTH-1:0]      ADC_LOW_CODE_U    = ADC_LOW_CODE;
  localparam [ADC_WIDTH-1:0]      ADC_HIGH_CODE_U   = ADC_HIGH_CODE;
  localparam [ADC_WIDTH-1:0]      ADC_SPAN_U        = ADC_SPAN;
  localparam [SLOPE_WIDTH-1:0]    TEMP_SLOPE_Q12_U  = TEMP_SLOPE_Q12;
  localparam [PRODUCT_WIDTH-1:0]  ROUND_Q12_U       = ROUND_Q12;
  localparam signed [TEMP_CALC_WIDTH-1:0] TEMP_MIN_X10_S = TEMP_MIN_X10;

  reg [ADC_WIDTH-1:0] adc_code_reg;

  always @(posedge clk) begin : calibration_proc
    reg [ADC_WIDTH-1:0]        delta_u;
    reg [PRODUCT_WIDTH-1:0]    product_u;
    reg [PRODUCT_WIDTH-1:0]    rounded_u;
    reg [PRODUCT_WIDTH-1:0]    scaled_u;
    reg signed [TEMP_CALC_WIDTH-1:0] temperature_x10_s;
    reg [ADC_WIDTH-1:0]        calc_adc_code;

    if (!rst_n) begin
      adc_code_reg      <= {ADC_WIDTH{1'b0}};
      temperature_field <= {TEMP_WIDTH{1'b0}};
      low_out_of_range  <= 1'b0;
      high_out_of_range <= 1'b0;
      cal_done          <= 1'b0;
    end else begin
      cal_done <= 1'b0;
      calc_adc_code = adc_code_reg;

      if (capture_en) begin
        adc_code_reg <= adc_code;
        calc_adc_code = adc_code;
      end

      if (cal_en) begin
        if (calc_adc_code < ADC_LOW_CODE_U) begin
          delta_u = {ADC_WIDTH{1'b0}};
          low_out_of_range <= 1'b1;
          high_out_of_range <= 1'b0;
        end else if (calc_adc_code > ADC_HIGH_CODE_U) begin
          delta_u = ADC_SPAN_U;
          low_out_of_range <= 1'b0;
          high_out_of_range <= 1'b1;
        end else begin
          delta_u = calc_adc_code - ADC_LOW_CODE_U;
          low_out_of_range <= 1'b0;
          high_out_of_range <= 1'b0;
        end

        product_u = {{(PRODUCT_WIDTH-ADC_WIDTH){1'b0}}, delta_u} *
                    {{(PRODUCT_WIDTH-SLOPE_WIDTH){1'b0}}, TEMP_SLOPE_Q12_U};
        rounded_u = product_u + ROUND_Q12_U;
        scaled_u = rounded_u >> Q12_SHIFT;
        temperature_x10_s = $signed(scaled_u[TEMP_CALC_WIDTH-1:0]) + TEMP_MIN_X10_S;

        temperature_field <= temperature_x10_s[TEMP_WIDTH-1:0];
        cal_done <= 1'b1;
      end
    end
  end

endmodule
