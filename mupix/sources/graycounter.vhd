-- Gray counter
-- Niklaus Berger
-- 15.5.2012


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity Graycounter is
  generic (
    COUNTWIDTH : integer := 8
    );
  port (
    clk        : in std_logic;          -- clock
    reset      : in std_logic;          -- asynchronous reset
    sync_reset : in std_logic;          -- synchronous reset

    counter : out std_logic_vector(COUNTWIDTH-1 downto 0)  -- counter
    );
end Graycounter;

architecture rtl of Graycounter is
  
  signal msb           : std_logic;
  signal counter_reg   : std_logic_vector(COUNTWIDTH downto 0);
  signal no_ones_below : std_logic_vector(COUNTWIDTH downto 0);
  
begin
  
  counter <= counter_reg(COUNTWIDTH downto 1);

  msb <= counter_reg(COUNTWIDTH) or counter_reg(COUNTWIDTH-1);

  process(clk, reset)
  begin
    if(reset = '1') then
      counter_reg    <= (others => '0');
      counter_reg(0) <= '1';
    elsif (clk'event and clk = '1') then
      if (sync_reset = '1') then
        counter_reg    <= (others => '0');
        counter_reg(0) <= '1';
      else
        counter_reg(0) <= not counter_reg(0);
        for i in 1 to COUNTWIDTH-1 loop
          counter_reg(i) <= counter_reg(i) xor (counter_reg(i-1) and no_ones_below(i-1));
        end loop;
        counter_reg(COUNTWIDTH) <= counter_reg(COUNTWIDTH) xor (msb and no_ones_below(COUNTWIDTH-1));
      end if;
    end if;
  end process;

  no_ones_below(0) <= '1';

  process(counter_reg, no_ones_below)
  begin
    for j in 1 to COUNTWIDTH loop
      no_ones_below(j) <= no_ones_below(j-1) and not counter_reg(j-1);
    end loop;
  end process;
  
end rtl;
