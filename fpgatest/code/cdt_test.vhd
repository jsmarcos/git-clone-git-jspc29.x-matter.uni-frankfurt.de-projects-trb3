library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.trb_net_std.all;

entity cdt_test is
    port(
      CLK_200 : in  std_logic;
      
      CLK_100 : in  std_logic;
      BUS_RX  : in  CTRLBUS_RX;
      BUS_TX  : out CTRLBUS_TX;
      
      
      DEBUG   : out std_logic_vector(31 downto 0)
      );
end entity;


architecture cdt_arch of cdt_test is

component pll is
    port (
        CLK: in std_logic; 
        RESET: in std_logic;
        FINEDELB0: in std_logic; 
        FINEDELB1: in std_logic; 
        FINEDELB2: in std_logic; 
        FINEDELB3: in std_logic; 
        DPHASE0: in std_logic; 
        DPHASE1: in std_logic; 
        DPHASE2: in std_logic; 
        DPHASE3: in std_logic; 
        CLKOP: out std_logic; 
        CLKOS: out std_logic; 
        CLKOK: out std_logic; 
        LOCK: out std_logic);
end component;

  signal clk_200_i, clk_100_i : std_logic;
  signal pll_lock : std_logic;
  signal dphase, finedel : std_logic_vector(3 downto 0);
  
  signal reset : std_logic;
  
  signal ct_fifo_write, ct_fifo_read : std_logic;
  signal ct_fifo_empty, ct_fifo_full : std_logic;
  signal ct_fifo_dout,  ct_fifo_din  : std_logic_vector(17 downto 0);
  
  signal last_fifo_read, fifo_valid : std_logic;
  signal last_data : std_logic_vector(17 downto 0);
  signal error_flag : std_logic;
  
  signal timer : unsigned(3 downto 0) := (others => '0');
  signal input_counter : unsigned(17 downto 0);
  
  signal reg : std_logic_vector(31 downto 0) := x"00000400"; 
  
begin


proc_reg : process begin
  wait until rising_edge(CLK_100);
  if BUS_RX.write = '1' then
    BUS_TX.ack <= '1';
    reg <= BUS_RX.data;
  else
    BUS_TX.ack <= '0';
  end if;  
  BUS_TX.unknown <= '0';
  BUS_TX.nack    <= '0';
end process;  



reset <= not pll_lock or reg(0);

----------------------------------------------------------------------
-- The PLL
----------------------------------------------------------------------
--finedel:  x*130ps
--dphase: 1/16 clock cycle of 200, 312 ps

-- output: 200 MHz, can be shifted plus a fixed 100 Mhz

THE_PLL : pll
  port map(
    CLK       => CLK_200,
    RESET     => reg(0),
    FINEDELB0 => finedel(0),
    FINEDELB1 => finedel(1),
    FINEDELB2 => finedel(2),
    FINEDELB3 => finedel(3),
    DPHASE0   => dphase(0), 
    DPHASE1   => dphase(1), 
    DPHASE2   => dphase(2), 
    DPHASE3   => dphase(3), 
    CLKOP     => open,
    CLKOS     => clk_200_i,
    CLKOK     => clk_100_i, 
    LOCK      => pll_lock
    );


dphase  <= reg(11 downto 8);
finedel <= reg( 7 downto 4);
    
----------------------------------------------------------------------
-- Clock Domain Transfer
----------------------------------------------------------------------
THE_CT_FIFO : entity work.lattice_ecp3_fifo_18x16_dualport_oreg
  port map(
    Data              => ct_fifo_din,
    WrClock           => clk_200_i,
    RdClock           => clk_100_i,
    WrEn              => ct_fifo_write,
    RdEn              => ct_fifo_read,
    Reset             => reset,
    RPReset           => reset,
    Q(17 downto 0)    => ct_fifo_dout,
    Empty             => ct_fifo_empty,
    Full              => ct_fifo_full,
    AlmostFull        => open
    );
    
    
    
-- writes increasing numbers into the fifo, every second clock cycle, and a pause after five values
proc_input : process begin
  wait until rising_edge(clk_200_i);
  timer <= timer + 1;
  
  ct_fifo_din   <= std_logic_vector(input_counter);
  ct_fifo_write <= '0';
  
  case timer is
    when 0 => input_counter <= input_counter + 1;
    when 1 => ct_fifo_write <= '1';
    when 2 => input_counter <= input_counter + 1;
    when 3 => ct_fifo_write <= '1';
    when 4 => input_counter <= input_counter + 1;
    when 5 => ct_fifo_write <= '1';
    when 6 => input_counter <= input_counter + 1;
    when 7 => ct_fifo_write <= '1';
    when 8 => input_counter <= input_counter + 1;
    when 9 => ct_fifo_write <= '1';
    when 12 => timer <= x"0";
    when others => null;
  end case;
  
  if reset = '1' then
    timer         <= x"1";
    input_counter <= (others => '0');
  end if;
end process;  
    
    
    
ct_fifo_read   <= not ct_fifo_empty;    

-- read from fifo when not empty, compare read value with last one    
proc_output : process begin
  wait until rising_edge(clk_100_i);

  last_fifo_read <= ct_fifo_read;
  fifo_valid     <= last_fifo_read;

  error_flag <= '0';
  
  if fifo_valid = '1' then
    last_data <= ct_fifo_dout;
    if unsigned(last_data) + 1 /= unsigned(ct_fifo_dout) then
      error_flag <= '1';
    end if;
  end if;  
  
end process;  
    
DEBUG(11 downto  0) <= ct_fifo_din(11 downto 0);
DEBUG(27 downto 16) <= ct_fifo_dout(11 downto 0);
DEBUG(28) <= ct_fifo_write;
DEBUG(29) <= ct_fifo_read;
DEBUG(30) <= ct_fifo_empty;
DEBUG(31) <= error_flag;
    
end architecture;