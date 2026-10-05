module Clock_Divider
#(
  parameter integer CLK_FREQ_HZ = 1000000
)
(
  input  wire clk,
  input  wire rst_n,
  output reg  clk_1Hz,
  output reg  tick_10s
);

  function integer clog2;
    input integer value;
    integer work_value;
    begin
      work_value = value - 1;
      for (clog2 = 0; work_value > 0; clog2 = clog2 + 1)
        work_value = work_value >> 1;
    end
  endfunction

  localparam integer CLK_1HZ_HALF_PERIOD_CYCLES = CLK_FREQ_HZ / 2;
  localparam integer TICK_10S_PERIOD_CYCLES     = CLK_FREQ_HZ * 10;
  localparam integer CLK_1HZ_COUNT_WIDTH        = clog2(CLK_1HZ_HALF_PERIOD_CYCLES);
  localparam integer TICK_10S_COUNT_WIDTH       = clog2(TICK_10S_PERIOD_CYCLES);

  reg [CLK_1HZ_COUNT_WIDTH-1:0]  clk_1hz_count;
  reg [TICK_10S_COUNT_WIDTH-1:0] tick_10s_count;

  always @(posedge clk) begin
    if (!rst_n) begin
      clk_1hz_count  <= {CLK_1HZ_COUNT_WIDTH{1'b0}};
      tick_10s_count <= {TICK_10S_COUNT_WIDTH{1'b0}};
      clk_1Hz        <= 1'b0;
      tick_10s       <= 1'b0;
    end else begin
      tick_10s <= 1'b0;

      if (clk_1hz_count == CLK_1HZ_HALF_PERIOD_CYCLES - 1) begin
        clk_1hz_count <= {CLK_1HZ_COUNT_WIDTH{1'b0}};
        clk_1Hz       <= ~clk_1Hz;
      end else begin
        clk_1hz_count <= clk_1hz_count + 1'b1;
      end

      if (tick_10s_count == TICK_10S_PERIOD_CYCLES - 1) begin
        tick_10s_count <= {TICK_10S_COUNT_WIDTH{1'b0}};
        tick_10s       <= 1'b1;
      end else begin
        tick_10s_count <= tick_10s_count + 1'b1;
      end
    end
  end

endmodule
