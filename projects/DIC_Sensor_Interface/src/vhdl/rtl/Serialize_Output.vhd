library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.digital_constants_pkg.all;

entity Serialize_Output is
  port (
    clk               : in  std_logic;
    rst_n             : in  std_logic;
    tx_en             : in  std_logic;
    dev_id            : in  dev_id_t;
    temperature_field : in  temperature_field_t;
    serial_out        : out std_logic;
    serial_clk        : out std_logic;
    tx_done           : out std_logic
  );
end entity Serialize_Output;

architecture rtl of Serialize_Output is
  -- Preserve this unit as a readable hierarchy block in Vivado schematics.
  -- This affects schematic/synthesis hierarchy only, not RTL behavior.
  attribute keep_hierarchy : string;
  attribute keep_hierarchy of rtl : architecture is "yes";

  -- Two-phase bit output state machine with idle-low serial clock.
  type tx_state_t is (
    S_IDLE,
    S_CLOCK_HIGH,
    S_CLOCK_LOW,
    S_DONE
  );

  signal state_reg      : tx_state_t := S_IDLE;
  signal shift_reg      : serial_frame_t := (others => '0');
  signal bit_count      : natural range 0 to FRAME_WIDTH - 1 := 0;
  signal serial_out_reg : std_logic := '0';
  signal serial_clk_reg : std_logic := '0';
  signal tx_done_reg    : std_logic := '0';
begin
  serial_out <= serial_out_reg;
  serial_clk <= serial_clk_reg;
  tx_done    <= tx_done_reg;

  -- Load {dev_id, temperature_field} and transmit the 16-bit frame LSB first.
  process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        state_reg      <= S_IDLE;
        shift_reg      <= (others => '0');
        bit_count      <= 0;
        serial_out_reg <= '0';
        serial_clk_reg <= '0';
        tx_done_reg    <= '0';
      else
        tx_done_reg <= '0';

        case state_reg is
          when S_IDLE =>
            serial_clk_reg <= '0';
            serial_out_reg <= '0';
            bit_count      <= 0;

            if tx_en = '1' then
              -- Frame format: bits 15:12 are dev_id, bits 11:0 are temperature.
              shift_reg      <= dev_id & std_logic_vector(temperature_field);
              serial_out_reg <= temperature_field(0);
              state_reg      <= S_CLOCK_HIGH;
            end if;

          when S_CLOCK_HIGH =>
            serial_clk_reg <= '1';

            if bit_count = FRAME_WIDTH - 1 then
              state_reg <= S_DONE;
            else
              state_reg <= S_CLOCK_LOW;
            end if;

          when S_CLOCK_LOW =>
            serial_clk_reg <= '0';
            shift_reg      <= '0' & shift_reg(FRAME_WIDTH - 1 downto 1);
            serial_out_reg <= shift_reg(1);
            bit_count      <= bit_count + 1;
            state_reg      <= S_CLOCK_HIGH;

          when S_DONE =>
            serial_clk_reg <= '0';
            serial_out_reg <= '0';
            tx_done_reg    <= '1';
            bit_count      <= 0;
            state_reg      <= S_IDLE;
        end case;
      end if;
    end if;
  end process;
end architecture rtl;
