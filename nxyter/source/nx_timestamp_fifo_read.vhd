library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.nxyter_components.all;

entity nx_timestamp_fifo_read is
  port(
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    
    -- nXyter Timestamp Ports
    NX_TIMESTAMP_CLK_IN  : in std_logic;
    NX_TIMESTAMP_IN      : in std_logic_vector (7 downto 0);
    NX_FRAME_CLOCK_OUT   : out std_logic;
    NX_FRAME_SYNC_OUT    : out std_logic;
    NX_TIMESTAMP_OUT     : out std_logic_vector(31 downto 0);
    
    -- Slave bus         
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;

    DEBUG_OUT            : out std_logic_vector(7 downto 0)
    );
end entity;

architecture Behavioral of nx_timestamp_fifo_read is


  -- FIFO Input Handler
  signal nx_timestamp_n      : std_logic_vector(7 downto 0);
  signal fifo_skip_write_x   : std_logic;
  signal fifo_skip_write_l   : std_logic;
  signal fifo_skip_write     : std_logic;
  signal fifo_full_i         : std_logic;
  signal fifo_write_enable_o : std_logic;
  signal fifo_write_skip_ctr : unsigned(7 downto 0);
  signal nx_frame_clock_o    : std_logic;
  signal frame_clock_ctr     : unsigned(1 downto 0);

  -- FIFO Output Handler
  signal fifo_empty_i        : std_logic;       
  signal fifo_empty_x        : std_logic;       
  signal fifo_empty          : std_logic;       
  signal fifo_full_x         : std_logic;
  signal fifo_full           : std_logic;
  signal fifo_out            : std_logic_vector(31 downto 0);
  signal fifo_read_enable_o  : std_logic;
  signal fifo_skip_write_o   : std_logic;
  signal fifo_skip_write_r   : std_logic;
  signal fifo_skip_write_s   : std_logic;

  -- SYNC NX Frame Process
  
  -- RS Sync FlipFlop
  signal nx_frame_synced_o     : std_logic;
  signal rs_sync_set           : std_logic;
  signal rs_sync_reset         : std_logic;
  
  -- Sync Process
  signal nx_frame_resync_ctr   : unsigned(7 downto 0);
  signal frame_sync_wait_ctr   : unsigned (7 downto 0);
  
  -- Slave Bus
  signal register_fifo_data    : std_logic_vector(31 downto 0);
  signal register_fifo_status  : std_logic_vector(31 downto 0);
  signal slv_data_out_o        : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o    : std_logic;
  signal slv_unknown_addr_o    : std_logic;
  signal slv_ack_o             : std_logic;
  signal fifo_write_enable_x   : std_logic;
  signal fifo_write_enable     : std_logic;
  signal fifo_read_enable_x    : std_logic;
  signal fifo_read_enable      : std_logic;
  signal fifo_write_skip_ctr_x : std_logic_vector(7 downto 0);
  signal fifo_write_skip_ctr_o : std_logic_vector(7 downto 0);
  
  type STATES is (IDLE,
                  READ_FIFO
                  );
  signal STATE : STATES;

  type STATES_SYNC is (SYNC_CHECK,
                       SYNC_RESYNC,
                       SYNC_WAIT
                       );
  signal STATE_SYNC : STATES_SYNC;
  
begin

  DEBUG_OUT(0) <= fifo_write_enable_o;
  DEBUG_OUT(1) <= fifo_full;
  DEBUG_OUT(2) <= fifo_read_enable_o;
  DEBUG_OUT(3) <= fifo_empty;

  DEBUG_OUT(4) <= nx_frame_synced_o;
  DEBUG_OUT(5) <= fifo_skip_write_o;
  DEBUG_OUT(6) <= nx_frame_clock_o;
  DEBUG_OUT(7) <= CLK_IN;
  
  -----------------------------------------------------------------------------
  -- Dual Clock FIFO 8bit to 32bit
  -----------------------------------------------------------------------------

  -- First Decode
  --  Gray_Decoder_1: Gray_Decoder
  --   generic map (
  --     WIDTH => 8)
  --   port map (
  --     CLK_IN     => NX_TIMESTAMP_CLK_IN,
  --     RESET_IN   => RESET_IN,
  --     GRAY_IN    => NX_TIMESTAMP_IN,
  --     BINARY_OUT => nx_timestamp_n
  --     );
  nx_timestamp_n <= NX_TIMESTAMP_IN;
  
  
  -- Second send data to FIFO
  fifo_dc_8to32_1: fifo_dc_8to32
    port map (
      Data    => nx_timestamp_n,
      WrClock => NX_TIMESTAMP_CLK_IN,
      RdClock => CLK_IN,
      WrEn    => fifo_write_enable_o,
      RdEn    => fifo_read_enable_o,
      Reset   => RESET_IN,
      RPReset => RESET_IN,
      Q       => fifo_out,
      Empty   => fifo_empty_i,
      Full    => fifo_full_i
      );

  
  -----------------------------------------------------------------------------
  -- FIFO Input Handler
  -----------------------------------------------------------------------------
  
  -- Cross ClockDomain CLK_IN --> NX_TIMESTAMP_CLK_IN for signal
  -- fifo_skip_write
  PROC_FIFO_IN_HANDLER_SYNC: process(NX_TIMESTAMP_CLK_IN)
  begin
    if( rising_edge(NX_TIMESTAMP_CLK_IN) ) then
      if( RESET_IN = '1' ) then
        fifo_skip_write_x  <= '0';
        fifo_skip_write_l  <= '0';
      else
        fifo_skip_write_x <= fifo_skip_write_o;
        fifo_skip_write_l <= fifo_skip_write_x;
      end if;
    end if;
  end process PROC_FIFO_IN_HANDLER_SYNC;

  -- Signal fifo_skip_write might 2 clocks long --> I need 1
  level_to_pulse_1: level_to_pulse
    port map (
      CLK_IN    => NX_TIMESTAMP_CLK_IN,
      RESET_IN  => RESET_IN,
      LEVEL_IN  => fifo_skip_write_l,
      PULSE_OUT => fifo_skip_write
      );
  
  -- Write only in case FIFO is not full, skip one write cycle in case
  -- fifo_skip_write is true (needed by the synchronization process
  -- to genrate the NX Frame Clock which I don't have, grrrr) 
  PROC_FIFO_IN_HANDLER: process(NX_TIMESTAMP_CLK_IN)
  begin
    if( rising_edge(NX_TIMESTAMP_CLK_IN) ) then
      if( RESET_IN = '1' ) then
        fifo_write_enable_o <= '0';
        frame_clock_ctr     <= (others => '0');
        fifo_write_skip_ctr <= (others => '0'); 
      else
        fifo_write_enable_o <= '1';

        if (fifo_full_i = '1') then
          fifo_write_enable_o <= '0';
        elsif (fifo_skip_write = '1') then
          fifo_write_skip_ctr <= fifo_write_skip_ctr + 1;
          fifo_write_enable_o <= '0';
        end if;

        if (frame_clock_ctr < 2) then
          nx_frame_clock_o <= '1';
        else
          nx_frame_clock_o <= '0';
        end if;

        if (fifo_skip_write = '1') then
          frame_clock_ctr <= (others => '0');
        else
          frame_clock_ctr <= frame_clock_ctr + 1;
        end if;
        
      end if;
    end if;
  end process PROC_FIFO_IN_HANDLER; 

  NX_FRAME_CLOCK_OUT <= nx_frame_clock_o;
  
  -----------------------------------------------------------------------------
  -- FIFO Output Handler and Sync FIFO
  -----------------------------------------------------------------------------

  -- Read only in case FIFO is not empty
  PROC_FIFO_READ: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        fifo_read_enable_o <= '0';
        STATE <= IDLE;
      else
        fifo_read_enable_o <= '0';
        case STATE is

          when IDLE =>
            if (fifo_empty_i = '1') then
              STATE <= IDLE;
            else
              fifo_read_enable_o <= '1';
              STATE <= READ_FIFO;
            end if;
            
          when READ_FIFO =>
            register_fifo_data <= fifo_out;
            STATE <= IDLE;
            
          when others => null;
        end case;
      end if;
    end if;
  end process PROC_FIFO_READ;
  

  -- RS FlipFlop to hold Sync Status
  PROC_RS_FRAME_SYNCED: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1' or rs_sync_reset = '1') then
        nx_frame_synced_o <= '0';
      elsif (rs_sync_set = '1') then
        nx_frame_synced_o <= '1';
      end if;
    end if;
  end process PROC_RS_FRAME_SYNCED;

  -- Sync to NX NO_DATA FRAME 
  PROC_SYNC_TO_NO_DATA: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        rs_sync_set          <= '0';
        rs_sync_reset        <= '1';
        nx_frame_resync_ctr  <= (others => '0');
        frame_sync_wait_ctr  <= (others => '0');
        fifo_skip_write_s    <= '0';
        STATE_SYNC           <= SYNC_CHECK;
      else
        rs_sync_set       <= '0';
        rs_sync_reset     <= '0';
        fifo_skip_write_s <= '0';
        
        case STATE_SYNC is

          when SYNC_CHECK =>
            case fifo_out is
              when x"7f7f7f06" =>
                rs_sync_set <= '1';
                STATE_SYNC  <= SYNC_CHECK;

              when x"067f7f7f" =>
                STATE_SYNC <= SYNC_RESYNC;

              when x"7f067f7f" =>
                STATE_SYNC <= SYNC_RESYNC;
                
              when x"7f7f067f" =>
                STATE_SYNC <= SYNC_RESYNC;

              when others =>
                STATE_SYNC <= SYNC_CHECK;
                
            end case;

          when SYNC_RESYNC =>
            rs_sync_reset     <= '1';
            fifo_skip_write_s <= '1';
            nx_frame_resync_ctr <= nx_frame_resync_ctr + 1;
            frame_sync_wait_ctr <= x"ff";
            STATE_SYNC <= SYNC_WAIT;

          when SYNC_WAIT =>
            if (frame_sync_wait_ctr > 0) then
              frame_sync_wait_ctr <= frame_sync_wait_ctr -1;
              STATE_SYNC <= SYNC_WAIT;
            else
              STATE_SYNC <= SYNC_CHECK;
            end if;

        end case;

      end if;
    end if;
  end process PROC_SYNC_TO_NO_DATA;

  NX_FRAME_SYNC_OUT <= nx_frame_synced_o;
  NX_TIMESTAMP_OUT  <= register_fifo_data;

-------------------------------------------------------------------------------
-- TRBNet Slave Bus
-------------------------------------------------------------------------------

  -- Cross ClockDomain NX_TIMESTAMP_CLK_IN --> CLK_IN, for simplicity just
  -- cross all signals, even the CLK_IN ones
  PROC_SYNC_FIFO_SIGNALS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        fifo_empty_x          <= '0';
        fifo_empty            <= '0';

        fifo_full_x           <= '0';
        fifo_full             <= '0';

        fifo_write_enable_x   <= '0';
        fifo_write_enable     <= '0';
        
        fifo_read_enable_x    <= '0';
        fifo_read_enable      <= '0';

        fifo_write_skip_ctr_x <= (others => '0');
        fifo_write_skip_ctr_o <= (others => '0');
      else
        fifo_empty_x        <= fifo_empty_i;
        fifo_empty          <= fifo_empty_x;

        fifo_full_x         <= fifo_full_i;
        fifo_full           <= fifo_full_x;

        fifo_write_enable_x <= fifo_write_enable_o;
        fifo_write_enable   <= fifo_write_enable_x;

        fifo_read_enable_x  <= fifo_read_enable_o;
        fifo_read_enable    <= fifo_read_enable_x;

        fifo_write_skip_ctr_x <= fifo_write_skip_ctr;
        fifo_write_skip_ctr_o <= fifo_write_skip_ctr_x;
      end if;
    end if;
  end process PROC_SYNC_FIFO_SIGNALS;

  register_fifo_status(0)            <= fifo_write_enable;
  register_fifo_status(1)            <= fifo_full;
  register_fifo_status(3 downto 2)   <= (others => '0');
  register_fifo_status(4)            <= fifo_read_enable;
  register_fifo_status(5)            <= fifo_empty;
  register_fifo_status(7 downto 6)   <= (others => '0');
  register_fifo_status(15 downto 8)  <= fifo_write_skip_ctr_o;
  register_fifo_status(23 downto 16) <= nx_frame_resync_ctr;
  register_fifo_status(30 downto 24) <= (others => '0');
  register_fifo_status(31)           <= nx_frame_synced_o;


  -- Give status info to the TRB Slow Control Channel
  PROC_FIFO_REGISTERS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o     <= (others => '0');
        slv_ack_o          <= '0';
        slv_unknown_addr_o <= '0';
        slv_no_more_data_o <= '0';
        fifo_skip_write_r  <= '0';
      else
        slv_data_out_o     <= (others => '0');
        slv_ack_o          <= '1';
        slv_unknown_addr_o <= '0';
        slv_no_more_data_o <= '0';
        fifo_skip_write_r  <= '0';

        if (SLV_READ_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" => slv_data_out_o <= register_fifo_data;
            when x"0001" => slv_data_out_o <= register_fifo_status;
            when others  => slv_unknown_addr_o <= '1';
                            slv_ack_o <= '0';          
          end case;
          
        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0001" => fifo_skip_write_r <= '1';
            when others  => slv_unknown_addr_o <= '1';              
                            slv_ack_o <= '0';
          end case;                
        else
          slv_ack_o <= '0';
        end if;
      end if;
    end if;
  end process PROC_FIFO_REGISTERS;

  fifo_skip_write_o <= fifo_skip_write_r or fifo_skip_write_s;
  
-- Output Signals
  SLV_DATA_OUT         <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT <= slv_unknown_addr_o;
  SLV_ACK_OUT          <= slv_ack_o;


end Behavioral;
