module Top_Control_FSM
(
  input  wire clk,
  input  wire rst_n,
  input  wire tick_10s,
  input  wire adc_done,
  input  wire cal_done,
  input  wire tx_done,
  output wire adc_start,
  output wire capture_en,
  output wire cal_en,
  output wire tx_en
);

  localparam [2:0] S_IDLE        = 3'd0;
  localparam [2:0] S_START_ADC   = 3'd1;
  localparam [2:0] S_WAIT_ADC    = 3'd2;
  localparam [2:0] S_CAPTURE_ADC = 3'd3;
  localparam [2:0] S_CALC        = 3'd4;
  localparam [2:0] S_WAIT_CALC   = 3'd5;
  localparam [2:0] S_TX          = 3'd6;
  localparam [2:0] S_WAIT_TX     = 3'd7;

  reg [2:0] state_reg;
  reg [2:0] state_next;

  always @(posedge clk) begin
    if (!rst_n)
      state_reg <= S_IDLE;
    else
      state_reg <= state_next;
  end

  always @(*) begin
    state_next = state_reg;

    case (state_reg)
      S_IDLE: begin
        if (tick_10s)
          state_next = S_START_ADC;
      end

      S_START_ADC: begin
        state_next = S_WAIT_ADC;
      end

      S_WAIT_ADC: begin
        if (adc_done)
          state_next = S_CAPTURE_ADC;
      end

      S_CAPTURE_ADC: begin
        state_next = S_CALC;
      end

      S_CALC: begin
        state_next = S_WAIT_CALC;
      end

      S_WAIT_CALC: begin
        if (cal_done)
          state_next = S_TX;
      end

      S_TX: begin
        state_next = S_WAIT_TX;
      end

      S_WAIT_TX: begin
        if (tx_done)
          state_next = S_IDLE;
      end

      default: begin
        state_next = S_IDLE;
      end
    endcase
  end

  assign adc_start = (state_reg == S_START_ADC);
  assign capture_en = (state_reg == S_CAPTURE_ADC);
  assign cal_en = (state_reg == S_CALC);
  assign tx_en = (state_reg == S_TX);

endmodule
