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
    clk_divcounter : in std_logic_vector(7 downto 0); -- clockdivider for
                                                      -- graycounter clock
    counter : out std_logic_vector(COUNTWIDTH-1 downto 0)  -- counter
    );
end Graycounter;

architecture rtl of Graycounter is
  
  signal msb           : std_logic := '0';
  signal counter_reg   : std_logic_vector(COUNTWIDTH downto 0) := (others => '0');
  signal no_ones_below : std_logic_vector(COUNTWIDTH downto 0) := "000000001";
  signal clk_enable : std_logic := '0';
  signal divcounter : unsigned(7 downto 0) := (others => '0');
  
begin
  
  counter <= counter_reg(COUNTWIDTH downto 1);

  msb <= counter_reg(COUNTWIDTH) or counter_reg(COUNTWIDTH-1);

  clock_divider_proc: process (clk) is
  begin  -- process clock_divider_proc
    if rising_edge(clk) then
      if reset = '1' then
        divcounter <= (others => '0');
        clk_enable <= '0';
      else
        divcounter <= divcounter + 1;
        clk_enable <= '0';
        if std_logic_vector(divcounter) = clk_divcounter then
          clk_enable <= '1';
          divcounter <= (others => '0');
        end if;
      end if;
    end if;
  end process clock_divider_proc;

  process(clk, reset)
  begin
    if(reset = '1') then
      counter_reg    <= (others => '0');
      counter_reg(0) <= '1';
      no_ones_below(0) <= '1';
    elsif (clk'event and clk = '1') then
      if (sync_reset = '1') then
        no_ones_below(0) <= '1';
        counter_reg    <= (others => '0');
        counter_reg(0) <= '1';
      else
        if clk_enable = '1' then
          counter_reg(0) <= not counter_reg(0);
        for i in 1 to COUNTWIDTH-1 loop
          counter_reg(i) <= counter_reg(i) xor (counter_reg(i-1) and no_ones_below(i-1));
        end loop;
        counter_reg(COUNTWIDTH) <= counter_reg(COUNTWIDTH) xor (msb and no_ones_below(COUNTWIDTH-1));
        else
          counter_reg <=  counter_reg;
        end if;
      end if;
    end if;
  end process;

  process(counter_reg, no_ones_below)
  begin
    for j in 1 to COUNTWIDTH loop
      no_ones_below(j) <= no_ones_below(j-1) and not counter_reg(j-1);
    end loop;
  end process;
  
end rtl;
