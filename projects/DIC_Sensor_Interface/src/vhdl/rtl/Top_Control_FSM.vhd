library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Top_Control_FSM is
  port (
    clk         : in  std_logic;
    rst_n       : in  std_logic;
    tick_10s    : in  std_logic;
    adc_done    : in  std_logic;
    cal_done    : in  std_logic;
    tx_done     : in  std_logic;
    adc_start   : out std_logic;
    capture_en  : out std_logic;
    cal_en      : out std_logic;
    tx_en       : out std_logic
  );
end entity Top_Control_FSM;

architecture rtl of Top_Control_FSM is
  -- Main sequencing states for one complete measure-calculate-transmit cycle.
  type fsm_state_t is (
    S_IDLE,
    S_START_ADC,
    S_WAIT_ADC,
    S_CAPTURE_ADC,
    S_CALC,
    S_WAIT_CALC,
    S_TX,
    S_WAIT_TX
  );

  signal state_reg  : fsm_state_t := S_IDLE;
  signal state_next : fsm_state_t := S_IDLE;
begin
  -- State register with synchronous active-low reset.
  process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        state_reg <= S_IDLE;
      else
        state_reg <= state_next;
      end if;
    end if;
  end process;

  -- Next-state logic. tick_10s is treated as an enable, not as a clock.
  process (state_reg, tick_10s, adc_done, cal_done, tx_done)
  begin
    state_next <= state_reg;

    case state_reg is
      when S_IDLE =>
        if tick_10s = '1' then
          state_next <= S_START_ADC;
        end if;

      when S_START_ADC =>
        state_next <= S_WAIT_ADC;

      when S_WAIT_ADC =>
        if adc_done = '1' then
          state_next <= S_CAPTURE_ADC;
        end if;

      when S_CAPTURE_ADC =>
        state_next <= S_CALC;

      when S_CALC =>
        state_next <= S_WAIT_CALC;

      when S_WAIT_CALC =>
        if cal_done = '1' then
          state_next <= S_TX;
        end if;

      when S_TX =>
        state_next <= S_WAIT_TX;

      when S_WAIT_TX =>
        if tx_done = '1' then
          state_next <= S_IDLE;
        end if;
    end case;
  end process;

  -- One-clock command pulses generated from dedicated FSM states.
  adc_start  <= '1' when state_reg = S_START_ADC else '0';
  capture_en <= '1' when state_reg = S_CAPTURE_ADC else '0';
  cal_en     <= '1' when state_reg = S_CALC else '0';
  tx_en      <= '1' when state_reg = S_TX else '0';
end architecture rtl;
