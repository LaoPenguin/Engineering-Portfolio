module Serialize_Output
#(
  parameter integer TEMP_WIDTH   = 12,
  parameter integer DEV_ID_WIDTH = 4,
  parameter integer FRAME_WIDTH  = 16
)
(
  input  wire                         clk,
  input  wire                         rst_n,
  input  wire                         tx_en,
  input  wire [DEV_ID_WIDTH-1:0]      dev_id,
  input  wire signed [TEMP_WIDTH-1:0] temperature_field,
  output reg                          serial_out,
  output reg                          serial_clk,
  output reg                          tx_done
);

  localparam [1:0] S_IDLE       = 2'd0;
  localparam [1:0] S_CLOCK_HIGH = 2'd1;
  localparam [1:0] S_CLOCK_LOW  = 2'd2;
  localparam [1:0] S_DONE       = 2'd3;

  reg [1:0] state_reg;
  reg [FRAME_WIDTH-1:0] shift_reg;
  reg [3:0] bit_count;

  always @(posedge clk) begin
    if (!rst_n) begin
      state_reg  <= S_IDLE;
      shift_reg  <= {FRAME_WIDTH{1'b0}};
      bit_count  <= 4'd0;
      serial_out <= 1'b0;
      serial_clk <= 1'b0;
      tx_done    <= 1'b0;
    end else begin
      tx_done <= 1'b0;

      case (state_reg)
        S_IDLE: begin
          serial_clk <= 1'b0;
          serial_out <= 1'b0;
          bit_count <= 4'd0;

          if (tx_en) begin
            shift_reg <= {dev_id, temperature_field};
            serial_out <= temperature_field[0];
            state_reg <= S_CLOCK_HIGH;
          end
        end

        S_CLOCK_HIGH: begin
          serial_clk <= 1'b1;

          if (bit_count == FRAME_WIDTH - 1)
            state_reg <= S_DONE;
          else
            state_reg <= S_CLOCK_LOW;
        end

        S_CLOCK_LOW: begin
          serial_clk <= 1'b0;
          shift_reg <= {1'b0, shift_reg[FRAME_WIDTH-1:1]};
          serial_out <= shift_reg[1];
          bit_count <= bit_count + 1'b1;
          state_reg <= S_CLOCK_HIGH;
        end

        S_DONE: begin
          serial_clk <= 1'b0;
          serial_out <= 1'b0;
          tx_done <= 1'b1;
          bit_count <= 4'd0;
          state_reg <= S_IDLE;
        end

        default: begin
          state_reg <= S_IDLE;
          serial_clk <= 1'b0;
          serial_out <= 1'b0;
          tx_done <= 1'b0;
          bit_count <= 4'd0;
        end
      endcase
    end
  end

endmodule
