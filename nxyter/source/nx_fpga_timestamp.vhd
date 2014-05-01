library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_fpga_timestamp is
  port (
    CLK_IN                   : in  std_logic;
    RESET_IN                 : in  std_logic;
    NX_MAIN_CLK_IN           : in  std_logic;      
                             
    TIMESTAMP_RESET_IN       : in  std_logic;
    TIMESTAMP_RESET_OUT      : out std_logic;
    TRIGGER_IN               : in  std_logic; -- must be in NX_MAIN_CLK_DOMAIN
    TIMESTAMP_HOLD_OUT       : out unsigned(11 downto 0);
    TIMESTAMP_TRIGGER_OUT    : out std_logic;

    -- Slave bus         
    SLV_READ_IN              : in  std_logic;
    SLV_WRITE_IN             : in  std_logic;
    SLV_DATA_OUT             : out std_logic_vector(31 downto 0);
    SLV_DATA_IN              : in  std_logic_vector(31 downto 0);
    SLV_ACK_OUT              : out std_logic;
    SLV_NO_MORE_DATA_OUT     : out std_logic;
    SLV_UNKNOWN_ADDR_OUT     : out std_logic;
                             
    -- Debug Line            
    DEBUG_OUT                : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_fpga_timestamp is

  signal timestamp_reset_ff   : std_logic;
  signal timestamp_reset_f    : std_logic;
  signal timestamp_reset      : std_logic;
  signal timestamp_ctr        : unsigned(11 downto 0);

  signal timestamp_hold_o     : std_logic_vector(11 downto 0);
  signal timestamp_trigger_o  : std_logic;
  signal timestamp_sync_o     : std_logic;

  -- Reset
  signal reset_nx_main_clk_in_ff  : std_logic;
  signal reset_nx_main_clk_in_f   : std_logic;
  signal RESET_NX_MAIN_CLK_IN     : std_logic;

  attribute syn_keep : boolean;
  attribute syn_keep of reset_nx_main_clk_in_ff     : signal is true;
  attribute syn_keep of reset_nx_main_clk_in_f      : signal is true;

  attribute syn_preserve : boolean;
  attribute syn_preserve of reset_nx_main_clk_in_ff : signal is true;
  attribute syn_preserve of reset_nx_main_clk_in_f  : signal is true;
  
begin
  DEBUG_OUT(0)             <= NX_MAIN_CLK_IN;
  DEBUG_OUT(1)             <= TIMESTAMP_RESET_IN;
  DEBUG_OUT(2)             <= timestamp_reset;
  DEBUG_OUT(3)             <= TIMESTAMP_RESET_OUT;
  DEBUG_OUT(4)             <= TRIGGER_IN;
  DEBUG_OUT(15 downto 5)   <= timestamp_hold_o(10 downto 0);

  -----------------------------------------------------------------------------
  -- Reset Domain Transfer
  -----------------------------------------------------------------------------
  reset_nx_main_clk_in_ff   <= RESET_IN when rising_edge(NX_MAIN_CLK_IN);
  reset_nx_main_clk_in_f    <= reset_nx_main_clk_in_ff
                               when rising_edge(NX_MAIN_CLK_IN); 
  RESET_NX_MAIN_CLK_IN      <= reset_nx_main_clk_in_f
                               when rising_edge(NX_MAIN_CLK_IN);

  -----------------------------------------------------------------------------
  -- NX Clock Domain
  -----------------------------------------------------------------------------

  -- Timestamp Process + Trigger
  timestamp_reset_ff         <= TIMESTAMP_RESET_IN
                                when rising_edge(NX_MAIN_CLK_IN);
  timestamp_reset_f          <= timestamp_reset_ff
                                when rising_edge(NX_MAIN_CLK_IN);
  timestamp_reset            <= timestamp_reset_f
                                when rising_edge(NX_MAIN_CLK_IN);

  PROC_TIMESTAMP_CTR: process (NX_MAIN_CLK_IN)
  begin
    if (rising_edge(NX_MAIN_CLK_IN)) then
      if (RESET_NX_MAIN_CLK_IN = '1') then
        timestamp_ctr            <= (others => '0');
        timestamp_hold_o         <= (others => '0');
        timestamp_sync_o         <= '0';
      else
        timestamp_trigger_o      <= '1'; 
        timestamp_sync_o         <= '0';
        
        if ((timestamp_reset = '0' and timestamp_reset_f = '1')) then
          timestamp_ctr          <= (others => '0');
          timestamp_sync_o       <= '1';
        else
          if (TRIGGER_IN = '1') then
            timestamp_hold_o      <= std_logic_vector(timestamp_ctr);
            timestamp_trigger_o   <= '1'; 
          end if;
          -- Increase TS Counter
          timestamp_ctr          <= timestamp_ctr + 1;
        end if;
      end if;
    end if;
  end process PROC_TIMESTAMP_CTR;

  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  TIMESTAMP_RESET_OUT       <= timestamp_sync_o;
  TIMESTAMP_HOLD_OUT        <= timestamp_hold_o;
  TIMESTAMP_TRIGGER_OUT     <= timestamp_trigger_o;

end Behavioral;
