library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_fpga_timestamp is
  port (
    CLK_IN                : in std_logic;
    RESET_IN              : in  std_logic;
    NX_CLK_IN             : in  std_logic;      
    
    TIMESTAMP_SYNC_IN     : in  std_logic;
    TRIGGER_IN            : in  std_logic;
    TIMESTAMP_CURRENT_OUT : out unsigned(11 downto 0);
    TIMESTAMP_HOLD_OUT    : out unsigned(11 downto 0);
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
  signal timestamp_current_o : unsigned(11 downto 0);
  signal timestamp_hold      : std_logic_vector(11 downto 0);
  signal trigger_x           : std_logic;
  signal trigger_l           : std_logic;
  signal trigger             : std_logic;
  signal timestamp_sync_x    : std_logic;
  signal timestamp_sync_l    : std_logic;
  signal timestamp_sync      : std_logic;

  signal nx_timestamp_sync_o : std_logic;

  signal fifo_full          : std_logic;
  signal fifo_write_enable    : std_logic;

  -- Main Clock Domain
  signal fifo_empty          : std_logic;
  signal fifo_read_enable    : std_logic;
  signal fifo_data_valid_t   : std_logic; 
  signal fifo_data_valid     : std_logic;
  signal fifo_data_out       : std_logic_vector(11 downto 0);
  signal timestamp_hold_o    : unsigned(11 downto 0);
  
begin

  DEBUG_OUT(0)           <= NX_CLK_IN;
  DEBUG_OUT(1)           <= trigger;
  DEBUG_OUT(2)           <= timestamp_sync;
  DEBUG_OUT(3)           <= '0';
  DEBUG_OUT(15 downto 4) <= timestamp_hold_o;

  -- NX Clock Domain
  
  -- Cross Clockdomain for TRIGGER and SYNC 
  PROC_SYNC: process (NX_CLK_IN)
  begin
    if( rising_edge(NX_CLK_IN) ) then
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
      CLK_IN    => NX_CLK_IN,
      RESET_IN  => RESET_IN,
      LEVEL_IN  => trigger_l,
      PULSE_OUT => trigger
      );

  -- Convert TIMESTAMP_SYNC_IN to Pulse
  level_to_pulse_2: level_to_pulse
    port map (
      CLK_IN    => NX_CLK_IN,
      RESET_IN  => RESET_IN,
      LEVEL_IN  => timestamp_sync_l,
      PULSE_OUT => timestamp_sync
      );

  -- Timestamp Process + Trigger
  
  PROC_TIMESTAMP_CTR: process (NX_CLK_IN)
  begin
    if( rising_edge(NX_CLK_IN) ) then
      if( RESET_IN = '1' ) then
        timestamp_ctr         <= (others => '0');
        timestamp_hold_o      <= (others => '0');
        nx_timestamp_sync_o   <= '0';
        fifo_write_enable     <= '0';
      else
        nx_timestamp_sync_o   <= '0';
        fifo_write_enable     <= '0';   

        if (timestamp_sync = '1') then
          timestamp_ctr       <= (others => '0');
          timestamp_hold_o    <= (others => '0');
          nx_timestamp_sync_o <= '1';
        else
          if (trigger = '1' and fifo_full = '0') then
            timestamp_hold    <= std_logic_vector(timestamp_ctr - 3);
            fifo_write_enable <= '1';
          end if;
          timestamp_ctr       <= timestamp_ctr + 1;
        end if;
      end if;
    end if;
  end process PROC_TIMESTAMP_CTR;

  timestamp_current_o         <= timestamp_ctr;

  -----------------------------------------------------------------------------
  -- Main Clock Domain -> Tranfer TimeStamp
  -----------------------------------------------------------------------------
  
  fifo_ts_12to12_dc_1: fifo_ts_12to12_dc
    port map (
      Data    => timestamp_hold,
      WrClock => NX_CLK_IN,
      RdClock => CLK_IN,
      WrEn    => fifo_write_enable,
      RdEn    => fifo_read_enable,
      Reset   => RESET_IN,
      RPReset => RESET_IN,
      Q       => fifo_data_out,
      Empty   => fifo_empty,
      Full    => fifo_full
    );

  fifo_read_enable  <= not fifo_empty;

  PROC_RECEIVE_TS: process (CLK_IN)
  begin
    if( rising_edge(NX_CLK_IN) ) then
      if( RESET_IN = '1' ) then
        fifo_data_valid_t    <= '0';
        fifo_data_valid      <= '0';
        timestamp_hold       <= (others => '0');
      else
        if (fifo_data_valid = '1') then
          timestamp_hold       <= unsigned(fifo_data_out);
        end if;

        fifo_data_valid_t    <= fifo_read_enable;
        fifo_data_valid      <= fifo_data_valid;
      end if;
    end if;
  end process PROC_RECEIVE_TS;
  
  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------
  
  TIMESTAMP_CURRENT_OUT  <= timestamp_current_o;
  TIMESTAMP_HOLD_OUT     <= timestamp_hold_o;
  NX_TIMESTAMP_SYNC_OUT  <= nx_timestamp_sync_o;

end Behavioral;
