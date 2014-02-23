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
                             
    TIMESTAMP_SYNC_IN        : in  std_logic;
    TRIGGER_IN               : in  std_logic; -- must be in NX_MAIN_CLK_DOMAIN
    TIMESTAMP_CURRENT_OUT    : out unsigned(11 downto 0);
    TIMESTAMP_HOLD_OUT       : out unsigned(11 downto 0);
    TIMESTAMP_SYNCED_OUT     : out std_logic;
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
  attribute HGROUP : string;
  attribute HGROUP of Behavioral : architecture is "NX_FPGA_TIMESTAMP is";

  signal timestamp_ctr       : unsigned(11 downto 0);
  signal timestamp_current_o : unsigned(11 downto 0);
  signal timestamp_hold_o    : std_logic_vector(11 downto 0);
  signal trigger             : std_logic;
  signal timestamp_sync      : std_logic;

  signal timestamp_synced    : std_logic;
  signal timestamp_synced_o  : std_logic;

  signal fifo_full           : std_logic;
  signal fifo_write_enable   : std_logic;

begin

  DEBUG_OUT(0)             <= CLK_IN;
  DEBUG_OUT(1)             <= TIMESTAMP_SYNC_IN;
  DEBUG_OUT(2)             <= timestamp_synced_o;
  DEBUG_OUT(3)             <= TRIGGER_IN;
  DEBUG_OUT(4)             <= trigger;
  
  DEBUG_OUT(15 downto 5)   <= timestamp_hold_o(10 downto 0);
                             
  -----------------------------------------------------------------------------
  -- NX Clock Domain
  -----------------------------------------------------------------------------
  -- signal_async_to_pulse_1: signal_async_to_pulse
  --   port map (
  --     CLK_IN     => NX_MAIN_CLK_IN,
  --     RESET_IN   => RESET_IN,
  --     PULSE_A_IN => TRIGGER_IN,
  --     PULSE_OUT  => trigger
  --     );
  
  trigger   <= TRIGGER_IN;

  signal_async_to_pulse_TIMESTAMP_SYNC_IN: signal_async_to_pulse
    port map (
      CLK_IN     => NX_MAIN_CLK_IN,
      RESET_IN   => RESET_IN,
      PULSE_A_IN => TIMESTAMP_SYNC_IN,
      PULSE_OUT  => timestamp_sync
      );
  
  -- Timestamp Process + Trigger
  PROC_TIMESTAMP_CTR: process (NX_MAIN_CLK_IN)
  begin
    if( rising_edge(NX_MAIN_CLK_IN) ) then
      if( RESET_IN = '1' ) then
        timestamp_ctr          <= (others => '0');
        timestamp_hold_o       <= (others => '0');
        timestamp_synced       <= '0';
      else
        timestamp_synced       <= '0';
        if (timestamp_sync = '1') then
          timestamp_ctr        <= (others => '0');
          timestamp_synced     <= '1';
        else
          if (trigger = '1') then
            timestamp_hold_o   <= std_logic_vector(timestamp_ctr);
          end if;
          timestamp_ctr        <= timestamp_ctr + 1;
        end if;
      end if;
    end if;
  end process PROC_TIMESTAMP_CTR;

  timestamp_current_o         <= timestamp_ctr;

  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  pulse_dtrans_1: pulse_dtrans
    generic map (
      CLK_RATIO => 4
      )
    port map (
      CLK_A_IN    => NX_MAIN_CLK_IN,
      RESET_A_IN  => RESET_IN,
      PULSE_A_IN  => timestamp_synced,
      CLK_B_IN    => CLK_IN,
      RESET_B_IN  => RESET_IN,
      PULSE_B_OUT => timestamp_synced_o
      );
  
  TIMESTAMP_CURRENT_OUT     <= timestamp_current_o;
  TIMESTAMP_HOLD_OUT        <= timestamp_hold_o;
  TIMESTAMP_SYNCED_OUT      <= timestamp_synced_o;
  TIMESTAMP_TRIGGER_OUT     <= trigger;

end Behavioral;
