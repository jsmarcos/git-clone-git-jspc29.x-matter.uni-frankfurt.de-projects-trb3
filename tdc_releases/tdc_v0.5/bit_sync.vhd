--synchronizes a single bit to a different clock domain

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity bit_sync is
  generic(
    DEPTH : integer := 3
    );
  port(
    RESET : in  std_logic;  --Reset is neceessary to avoid optimization to shift register
    CLK0  : in  std_logic;              --clock for first FF
    CLK1  : in  std_logic;              --Clock for other FF
    D_IN  : in  std_logic;              --Data input
    D_OUT : out std_logic               --Data output
    );
end entity;

architecture behavioral of bit_sync is

  signal sync_q : std_logic_vector(DEPTH downto 0);

  attribute syn_preserve           : boolean;
  attribute syn_keep               : boolean;
  attribute syn_keep of sync_q     : signal is true;
  attribute syn_preserve of sync_q : signal is true;


begin
  sync_q(0) <= D_IN;
  D_OUT     <= sync_q(DEPTH);

  process(CLK0)
  begin
    if rising_edge(CLK0) then
      if RESET = '1' then
        sync_q(1) <= '0';
      else
        sync_q(1) <= sync_q(0);
      end if;
    end if;
  end process;

  gen_others : if DEPTH > 1 generate
    gen_flipflops : for i in 2 to DEPTH generate
      process(CLK1)
      begin
        if rising_edge(CLK1) then
          if RESET = '1' then
            sync_q(i) <= '0';
          else
            sync_q(i) <= sync_q(i-1);
          end if;
        end if;
      end process;
    end generate;
  end generate;

end architecture;
