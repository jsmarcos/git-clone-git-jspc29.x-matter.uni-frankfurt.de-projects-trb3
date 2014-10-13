------------------------------------------------------------
--VHDL description of very basic  FIFO
--T.Weber, Mainz University
------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity fifo is
  generic(addr_wd : integer := 8;
          word_wd : integer := 8);
  port (Din     : in  std_logic_vector (word_wd - 1 downto 0);
        Wr      : in  std_logic;        
        Dout    : out std_logic_vector (word_wd - 1 downto 0);
        Rd      : in  std_logic;         
        Empty   : out std_logic;        
        Full    : out std_logic;        
        WrCnt_o : out std_logic_vector(addr_wd - 1 downto 0);
        Reset   : in  std_logic;
        CLK     : in  std_logic
        );
end fifo;


architecture fifo_arch of fifo is
  -- decl
  signal wrcnt     : unsigned (addr_wd-1 downto 0) := (others => '0');
  signal rdcnt     : unsigned (addr_wd-1 downto 0) := (others => '0');
  type   memory_type is array(0 to (2**addr_wd)-1) of unsigned(word_wd-1 downto 0);
  signal memory    : memory_type;
  signal full_loc  : std_logic;
  signal empty_loc : std_logic;
  
begin
  process
  begin
    wait until rising_edge(CLK);
    if Reset = '1' then
      rdcnt <= (others => '0');
      wrcnt <= (others => '0');
    else
      if (Wr = '1' and full_loc = '0') then
        memory(to_integer(wrcnt)) <= unsigned(Din);
        wrcnt                     <= wrcnt+1;
      end if;

      if (Rd = '1' and empty_loc = '0') then
        Dout  <= std_logic_vector(memory(to_integer(rdcnt)));
        rdcnt <= rdcnt+1;
      end if;
    end if;
  end process;
  
  full_loc  <= '1' when rdcnt = wrcnt+1 else '0';
  empty_loc <= '1' when rdcnt = wrcnt   else '0';
  Full      <= full_loc;
  Empty     <= empty_loc;
  WrCnt_o   <= std_logic_vector(wrcnt-rdcnt);
  
end architecture fifo_arch; 
