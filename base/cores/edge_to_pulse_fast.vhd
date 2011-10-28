library IEEE;
use IEEE.STD_LOGIC_UNSIGNED.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;

entity edge_to_pulse_fast is
  port (
    RESET     : in  std_logic;
    CLK       : in  std_logic;
    SIGNAL_IN : in  std_logic;
    PULSE_OUT : out std_logic
    );
end edge_to_pulse_fast;

architecture edge_to_pulse_fast of edge_to_pulse_fast is

  signal clk_i    : std_logic;
  signal rst_i    : std_logic;
  signal signal_i : std_logic;
  signal pulse_i  : std_logic;

  signal signal_reg : std_logic;

begin

  clk_i    <= CLK;
  rst_i    <= RESET;
  signal_i <= SIGNAL_IN;

  -- purpose: The SIGNAL_IN is delay by 1 clock cycle
  Register_Signal_in : process (clk_i, rst_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        signal_reg <= '0';
      else
        signal_reg <= signal_i;
      end if;
    end if;
  end process Register_Signal_in;

  -- purpose: Detection of the rising edge of the SIGNAL_IN
  Detect_Rising_Edge : process (signal_i, signal_reg)
  begin
    pulse_i <= signal_i and not(signal_reg);
  end process Detect_Rising_Edge;

  -- purpose: The pulse is registered after the AND gate
  Clock_Pulse_Out : process (clk_i, rst_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        PULSE_OUT <= '0';
      else
        PULSE_OUT <= pulse_i;
      end if;
    end if;
  end process Clock_Pulse_Out;

end edge_to_pulse_fast;
