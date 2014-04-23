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
                             
    TIMESTAMP_RESET_1_IN     : in  std_logic;
    TIMESTAMP_RESET_2_IN     : in  std_logic;
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

  signal timestamp_reset_1_ff : std_logic;
  signal timestamp_reset_1_f  : std_logic;
  signal timestamp_reset_1    : std_logic;
  signal timestamp_reset_2_ff : std_logic;
  signal timestamp_reset_2_f  : std_logic;
  signal timestamp_reset_2    : std_logic;
  signal timestamp_ctr        : unsigned(11 downto 0);

  signal timestamp_hold_o     : std_logic_vector(11 downto 0);
  signal timestamp_trigger_o  : std_logic;
  signal timestamp_sync_o    : std_logic;

  -- Reset
  signal RESET_NX_MAIN_CLK_IN : std_logic;
  
begin

  DEBUG_OUT(0)             <= NX_MAIN_CLK_IN;
  DEBUG_OUT(1)             <= TIMESTAMP_RESET_1_IN;
  DEBUG_OUT(2)             <= TIMESTAMP_RESET_2_IN;
  DEBUG_OUT(3)             <= TIMESTAMP_RESET_OUT;
  DEBUG_OUT(4)             <= TRIGGER_IN;
  DEBUG_OUT(15 downto 5)   <= timestamp_hold_o(10 downto 0);

  -----------------------------------------------------------------------------
  -- Reset Domain Transfer
  -----------------------------------------------------------------------------
  signal_async_trans_RESET_IN: signal_async_trans
    port map (
      CLK_IN      => NX_MAIN_CLK_IN,
      SIGNAL_A_IN => RESET_IN,
      SIGNAL_OUT  => RESET_NX_MAIN_CLK_IN
    );
  
  -----------------------------------------------------------------------------
  -- NX Clock Domain
  -----------------------------------------------------------------------------

  -- Timestamp Process + Trigger
  PROC_TIMESTAMP_CTR: process (NX_MAIN_CLK_IN)
  begin
    if (rising_edge(NX_MAIN_CLK_IN)) then
      timestamp_reset_1_ff       <= TIMESTAMP_RESET_1_IN;
      timestamp_reset_2_ff       <= TIMESTAMP_RESET_2_IN;

      if (RESET_NX_MAIN_CLK_IN = '1') then
        timestamp_reset_1_f      <= '0';
        timestamp_reset_2_f      <= '0';
        timestamp_reset_1        <= '0';
        timestamp_reset_2        <= '0';
        
        timestamp_ctr            <= (others => '0');
        timestamp_hold_o         <= (others => '0');
        timestamp_sync_o         <= '0';
      else
        timestamp_reset_1_f      <= timestamp_reset_1_ff;
        timestamp_reset_1        <= timestamp_reset_1_f;
        timestamp_reset_2_f      <= timestamp_reset_2_ff;
        timestamp_reset_2        <= timestamp_reset_2_f;
        timestamp_trigger_o      <= '1'; 
        timestamp_sync_o         <= '0';
        
        if ((timestamp_reset_1 = '0' and timestamp_reset_1_f = '1') or
            (timestamp_reset_2 = '0' and timestamp_reset_2_f = '1'))then
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
