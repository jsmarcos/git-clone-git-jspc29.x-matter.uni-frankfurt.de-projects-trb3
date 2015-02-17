library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.config.all;

entity adc_serializer is
  port (
    ADC_DCO : out std_logic;
    ADC_DATA : out std_logic_vector(4 downto 0)
  );
end entity adc_serializer;

architecture arch of adc_serializer is
  signal ddr_clock : std_logic := '1';
  
begin
  gen_40MHz : if ADC_SAMPLING_RATE = 40 generate
    ddr_clock <= not ddr_clock after 2.5 ns; -- 200 MHz => 40x10=400Mbit DDR
  end generate;

  gen_80MHz : if ADC_SAMPLING_RATE = 80 generate
    ddr_clock <= not ddr_clock after 1.25 ns;   
  end generate;
  
  ADC_DCO <= ddr_clock;
  
  output : process is
    variable cnt : unsigned(4 downto 0);
  begin
    wait until rising_edge(ddr_clock);
    ADC_DATA <= std_logic_vector(cnt);
    cnt := cnt+1;
    
    wait until falling_edge(ddr_clock);
    ADC_DATA <= std_logic_vector(cnt);
    cnt := cnt+1;
  end process output;  
  
end architecture arch;
