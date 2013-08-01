library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_fpga_timestamp is
  port (
    CLK_IN                : in  std_logic;
    RESET_IN              : in  std_logic;

    TIMESTAMP_SYNC_IN     : in  std_logic;
    TRIGGER_IN            : in  std_logic;

    TIMESTAMP_OUT         : out unsigned(11 downto 0);
    NX_TIMESTAMP_SYNC_OUT : out std_logic;

    -- Slave bus         
    SLV_READ_IN           : in  std_logic;
    SLV_WRITE_IN          : in  std_logic;
    SLV_DATA_OUT          : out std_logic_vector(31 downto 0);
    SLV_DATA_IN           : in  std_logic_vector(31 downto 0);
    SLV_ACK_OUT           : out std_logic;
    SLV_NO_MORE_DATA_OUT  : out std_logic;
    SLV_UNKNOWN_ADDR_OUT  : out std_logic;
    
    -- Debug Line
    DEBUG_OUT             : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_fpga_timestamp is

  signal timestamp_ctr       : unsigned(11 downto 0);
  signal timestamp_o         : unsigned(11 downto 0);
  signal trigger_x           : std_logic;
  signal trigger_l           : std_logic;
  signal trigger             : std_logic;
  signal timestamp_sync_x    : std_logic;
  signal timestamp_sync_l    : std_logic;
  signal timestamp_sync      : std_logic;

  signal nx_timestamp_sync_o : std_logic;
  
begin

  DEBUG_OUT(0)           <= CLK_IN;
  DEBUG_OUT(1)           <= trigger;
  DEBUG_OUT(2)           <= timestamp_sync;
  DEBUG_OUT(3)           <= '0';
  DEBUG_OUT(15 downto 4) <= TIMESTAMP_OUT;
  
  -- Cross the abyss for trigger and sync signal

  PROC_SYNC: process (CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        trigger_x        <= '0';
        trigger_l        <= '0';
        timestamp_sync_x <= '0';
        timestamp_sync_l <= '0';
      else
        trigger_x        <= TRIGGER_IN;
        trigger_l        <= trigger_x;
        timestamp_sync_x <= TIMESTAMP_SYNC_IN;
        timestamp_sync_l <= timestamp_sync_x;
      end if;
    end if;
  end process PROC_SYNC;

  -- Convert TRIGGER_IN to Pulse

  level_to_pulse_1: level_to_pulse
    port map (
      CLK_IN    => CLK_IN,
      RESET_IN  => RESET_IN,
      LEVEL_IN  => trigger_l,
      PULSE_OUT => trigger
      );

  -- Convert TIMESTAMP_SYNC_IN to Pulse

  level_to_pulse_2: level_to_pulse
    port map (
      CLK_IN    => CLK_IN,
      RESET_IN  => RESET_IN,
      LEVEL_IN  => timestamp_sync_l,
      PULSE_OUT => timestamp_sync
      );

  -- Timestamp Process + Trigger
  
  PROC_TIMESTAMP_CTR: process (CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        timestamp_ctr       <= (others => '0');
        timestamp_o         <= (others => '0');
        nx_timestamp_sync_o <= '0';
      else
        nx_timestamp_sync_o <= '0';
        
        if (timestamp_sync = '1') then
          timestamp_ctr       <= (others => '0');
          timestamp_o         <= (others => '0');
          nx_timestamp_sync_o <= '1';
        else
          if (trigger = '1') then
            timestamp_o       <= timestamp_ctr - 3;
          end if;
          timestamp_ctr       <= timestamp_ctr + 1;
        end if;
      end if;
    end if;
  end process;

  
  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  TIMESTAMP_OUT         <= timestamp_o;
  NX_TIMESTAMP_SYNC_OUT <= nx_timestamp_sync_o;

end Behavioral;
