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
    TIMESTAMP_CURRENT_OUT    : out unsigned(11 downto 0);
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

  signal timestamp_reset      : std_logic;
  signal timestamp_ctr        : unsigned(11 downto 0);

  signal timestamp_current_o  : unsigned(11 downto 0);
  signal timestamp_hold_o     : std_logic_vector(11 downto 0);
  signal timestamp_trigger_o  : std_logic;
  signal timestamp_reset_o    : std_logic;

  -- Reset
  signal RESET_NX_MAIN_CLK_IN : std_logic;
  
begin

  DEBUG_OUT(0)             <= CLK_IN;
  DEBUG_OUT(1)             <= TIMESTAMP_RESET_IN;
  DEBUG_OUT(2)             <= TIMESTAMP_RESET_OUT;
  DEBUG_OUT(3)             <= TRIGGER_IN;
  
  DEBUG_OUT(15 downto 4)   <= timestamp_hold_o(11 downto 0);

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
  
  signal_async_to_pulse_TIMESTAMP_SYNC_IN: signal_async_to_pulse
    generic map (
      NUM_FF => 3
      )
    port map (
      CLK_IN     => NX_MAIN_CLK_IN,
      RESET_IN   => RESET_NX_MAIN_CLK_IN,
      PULSE_A_IN => TIMESTAMP_RESET_IN,
      PULSE_OUT  => timestamp_reset
      );
  
  -- Timestamp Process + Trigger
  PROC_TIMESTAMP_CTR: process (NX_MAIN_CLK_IN)
  begin
    if (rising_edge(NX_MAIN_CLK_IN)) then
      if (RESET_NX_MAIN_CLK_IN = '1') then
        timestamp_ctr           <= (others => '0');
        timestamp_hold_o        <= (others => '0');
        timestamp_reset_o       <= '0';
      else
        timestamp_trigger_o     <= '1'; 
        timestamp_reset_o       <= '0';
        
        if (timestamp_reset = '1') then
          timestamp_ctr         <= (others => '0');
          timestamp_reset_o     <= '1';
        else
          if (TRIGGER_IN = '1') then
            timestamp_hold_o    <= std_logic_vector(timestamp_ctr);
            timestamp_trigger_o <= '1'; 
          end if;
          timestamp_ctr         <= timestamp_ctr + 1;
        end if;
      end if;
    end if;
  end process PROC_TIMESTAMP_CTR;

  timestamp_current_o         <= timestamp_ctr;

  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  TIMESTAMP_RESET_OUT       <= timestamp_reset_o;
  TIMESTAMP_CURRENT_OUT     <= timestamp_current_o;
  TIMESTAMP_HOLD_OUT        <= timestamp_hold_o;
  TIMESTAMP_TRIGGER_OUT     <= timestamp_trigger_o;

end Behavioral;
