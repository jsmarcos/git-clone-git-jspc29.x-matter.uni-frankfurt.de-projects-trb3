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
    TRIGGER_IN               : in  std_logic;
    TIMESTAMP_CURRENT_OUT    : out unsigned(11 downto 0);
    TIMESTAMP_HOLD_OUT       : out unsigned(11 downto 0);
    NX_TIMESTAMP_SYNC_OUT    : out std_logic;
    NX_TIMESTAMP_TRIGGER_OUT : out std_logic;

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
  signal timestamp_ctr       : unsigned(11 downto 0);
  signal timestamp_current_o : unsigned(11 downto 0);
  signal timestamp_hold_o    : std_logic_vector(11 downto 0);
  signal trigger             : std_logic;
  signal timestamp_sync      : std_logic;

  signal nx_timestamp_sync_o : std_logic;

  signal fifo_full           : std_logic;
  signal fifo_write_enable   : std_logic;

begin

  DEBUG_OUT(0)             <= CLK_IN;
  DEBUG_OUT(1)             <= TIMESTAMP_SYNC_IN;
  DEBUG_OUT(2)             <= nx_timestamp_sync_o;
  DEBUG_OUT(3)             <= TRIGGER_IN;
  DEBUG_OUT(4)             <= trigger;
  
  DEBUG_OUT(15 downto 5)   <= timestamp_hold_o(10 downto 0);
                             
  -----------------------------------------------------------------------------
  -- NX Clock Domain
  -----------------------------------------------------------------------------
  
  -- Sync in  TRIGGER and Timestamp Sync
  pulse_dtrans_1: pulse_dtrans
    generic map (
      CLK_RATIO => 2
      )
    port map (
      CLK_A_IN    => CLK_IN,
      RESET_A_IN  => RESET_IN,
      PULSE_A_IN  => TRIGGER_IN,
      CLK_B_IN    => NX_MAIN_CLK_IN,
      RESET_B_IN  => RESET_IN,
      PULSE_B_OUT => trigger
      );

  pulse_dtrans_2: pulse_dtrans
    generic map (
      CLK_RATIO => 2
      )
    port map (
      CLK_A_IN    => CLK_IN,
      RESET_A_IN  => RESET_IN,
      PULSE_A_IN  => TIMESTAMP_SYNC_IN,
      CLK_B_IN    => NX_MAIN_CLK_IN,
      RESET_B_IN  => RESET_IN,
      PULSE_B_OUT => timestamp_sync
      );

  -- Timestamp Process + Trigger
  
  PROC_TIMESTAMP_CTR: process (NX_MAIN_CLK_IN)
  begin
    if( rising_edge(NX_MAIN_CLK_IN) ) then
      if( RESET_IN = '1' ) then
        timestamp_ctr          <= (others => '0');
        timestamp_hold_o       <= (others => '0');
        nx_timestamp_sync_o    <= '0';
      else
        nx_timestamp_sync_o    <= '0';
        if (timestamp_sync = '1') then
          timestamp_ctr        <= (others => '0');
          nx_timestamp_sync_o  <= '1';
        else
          if (trigger = '1') then
            timestamp_hold_o   <= std_logic_vector(timestamp_ctr - 3);
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
  
  TIMESTAMP_CURRENT_OUT     <= timestamp_current_o;
  TIMESTAMP_HOLD_OUT        <= timestamp_hold_o;
  NX_TIMESTAMP_SYNC_OUT     <= nx_timestamp_sync_o;
  NX_TIMESTAMP_TRIGGER_OUT  <= trigger;

end Behavioral;
