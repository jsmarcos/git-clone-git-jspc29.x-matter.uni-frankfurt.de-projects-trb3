library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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
    NX_TIMESTAMP_OUT     : out std_logic_vector(31 downto 0);
    NX_NEW_TIMESTAMP_OUT : out std_logic;
    
    -- Slave bus         
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;

    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_timestamp_fifo_read is

  -----------------------------------------------------------------------------
  -- NX_TIMESTAMP_CLK Domain
  -----------------------------------------------------------------------------

  -- FIFO Input Handler
  signal fifo_full                : std_logic;
  signal fifo_write_enable        : std_logic;
  signal frame_tag_o              : std_logic;

  -- FRAME_CLOCK_GENERATOR  
  signal frame_clock_ctr          : unsigned(1 downto 0);
  signal nx_frame_clock_o         : std_logic;

  signal frame_clock_ctr_inc_x    : std_logic;
  signal frame_clock_ctr_inc_l    : std_logic;
  signal frame_clock_ctr_inc      : std_logic;

  -----------------------------------------------------------------------------
  -- CLK_IN Domain
  -----------------------------------------------------------------------------

  -- FIFO Output Handler
  signal fifo_out                 : std_logic_vector(35 downto 0);
  signal fifo_empty               : std_logic;
  signal fifo_empty_prev          : std_logic;
  signal fifo_read_enable         : std_logic;
  signal fifo_data_valid_x        : std_logic;
  signal fifo_data_valid          : std_logic;
  
  signal register_fifo_data       : std_logic_vector(31 downto 0);
  signal fifo_new_frame           : std_logic;

  signal frame_clock_ctr_inc_o    : std_logic;
  
  -- RS Sync FlipFlop
  signal nx_frame_synced          : std_logic;

  -- Frame Sync Process                 
  type STATES_SYNC is (S_SYNC_CHECK,
                       S_SYNC_RESYNC,
                       S_SYNC_WAIT
                       );

  signal STATE_SYNC, NEXT_STATE_SYNC: STATES_SYNC;

  signal rs_sync_set              : std_logic;
  signal rs_sync_reset            : std_logic;
  signal frame_clock_ctr_inc_s    : std_logic;
  signal frame_sync_wait_ctr      : unsigned(7 downto 0);
  signal nx_frame_resync_ctr      : unsigned(7 downto 0);
  signal frame_sync_wait_done     : std_logic;
  
  signal rs_sync_set_x            : std_logic;
  signal rs_sync_reset_x          : std_logic;
  signal frame_clock_ctr_inc_s_x  : std_logic;
  signal frame_sync_wait_ctr_x    : unsigned(7 downto 0);
  signal nx_frame_resync_ctr_x    : unsigned(7 downto 0);

  -- Slave Bus                    
  signal slv_data_out_o           : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o       : std_logic;
  signal slv_unknown_addr_o       : std_logic;
  signal slv_ack_o                : std_logic;
  signal register_fifo_status     : std_logic_vector(31 downto 0);
  signal frame_clock_ctr_inc_r    : std_logic;

begin

  DEBUG_OUT(0)           <= CLK_IN;
  DEBUG_OUT(1)           <= NX_TIMESTAMP_CLK_IN;
  DEBUG_OUT(2)           <= fifo_empty;
  DEBUG_OUT(3)           <= fifo_read_enable;
  DEBUG_OUT(4)           <= fifo_data_valid;
  DEBUG_OUT(5)           <= fifo_new_frame;
  DEBUG_OUT(6)           <= NX_NEW_TIMESTAMP_OUT;
  DEBUG_OUT(7)           <= frame_tag_o;
  -- DEBUG_OUT(15 downto 8) <= NX_TIMESTAMP_IN;
  DEBUG_OUT(15 downto 8) <= fifo_out(7 downto 0);
  
--   DEBUG_OUT(0)           <= CLK_IN;
--   
--   DEBUG_OUT(1)           <= NX_TIMESTAMP_CLK_IN;
--   DEBUG_OUT(2)           <= NX_FRAME_CLOCK_OUT;
--   DEBUG_OUT(3)           <= NX_FRAME_SYNC_OUT;
--   -- DEBUG_OUT(4)           <= NX_NEW_FRAME_OUT;
--   -- DEBUG_OUT(5)           <= frame_clock_ctr_inc_o;
--   -- DEBUG_OUT(6)           <= frame_tag_o;
--   -- DEBUG_OUT(7)           <= '0';
--    DEBUG_OUT(7 downto 4) <= fifo_out(3 downto 0);
--   DEBUG_OUT(15 downto 8) <= fifo_out(34 downto 27);
  
  -----------------------------------------------------------------------------
  -- Dual Clock FIFO 9bit to 36bit
  -----------------------------------------------------------------------------

  -- Send data to FIFO
  fifo_dc_9to36_1: fifo_dc_9to36
    port map (
      Data(7 downto 0) => NX_TIMESTAMP_IN,
      Data(8)          => frame_tag_o,
      WrClock          => NX_TIMESTAMP_CLK_IN,
      RdClock          => CLK_IN,
      WrEn             => fifo_write_enable,
      RdEn             => fifo_read_enable,
      Reset            => RESET_IN,
      RPReset          => RESET_IN,
      Q                => fifo_out,
      Empty            => fifo_empty,
      Full             => fifo_full
      );

  fifo_write_enable <= not RESET_IN;
  
  -----------------------------------------------------------------------------
  -- FIFO Input Handler
  -----------------------------------------------------------------------------
  
  -- Cross ClockDomain CLK_IN --> NX_TIMESTAMP_CLK_IN for signal
  -- frame_clock_ctr_inc
  PROC_FIFO_IN_HANDLER_SYNC: process(NX_TIMESTAMP_CLK_IN)
  begin
    if( rising_edge(NX_TIMESTAMP_CLK_IN) ) then
      if( RESET_IN = '1' ) then
        frame_clock_ctr_inc_x  <= '0';
        frame_clock_ctr_inc_l  <= '0';
      else
        frame_clock_ctr_inc_x <= frame_clock_ctr_inc_o;
        frame_clock_ctr_inc_l <= frame_clock_ctr_inc_x;   
      end if;
    end if;
  end process PROC_FIFO_IN_HANDLER_SYNC;

  -- Signal frame_tag_ctr_inc_l might be 2 clocks long --> I need 1
  level_to_pulse_1: level_to_pulse
    port map (
      CLK_IN    => NX_TIMESTAMP_CLK_IN,
      RESET_IN  => RESET_IN,
      LEVEL_IN  => frame_clock_ctr_inc_l,
      PULSE_OUT => frame_clock_ctr_inc
      );
      
  PROC_FRAME_CLOCK_GENERATOR: process(NX_TIMESTAMP_CLK_IN)
  begin
    if( rising_edge(NX_TIMESTAMP_CLK_IN) ) then
      if( RESET_IN = '1' ) then
        frame_clock_ctr   <= (others => '0');
        nx_frame_clock_o  <= '0';
        frame_tag_o       <= '0';
      else
        case frame_clock_ctr is

          when "00" =>
            nx_frame_clock_o  <= '0';
            frame_tag_o       <= '1';
          when "01" =>
            nx_frame_clock_o  <= '1';
            frame_tag_o       <= '0';
          when "10" =>
            nx_frame_clock_o  <= '1';
            frame_tag_o       <= '0';
          when "11" =>
            nx_frame_clock_o  <= '0';
            frame_tag_o       <= '0';
          when others => null;

        end case;

        if (frame_clock_ctr_inc = '1') then
          frame_clock_ctr <= frame_clock_ctr + 2;
        else
          frame_clock_ctr <= frame_clock_ctr + 1;
        end if;
        
      end if;
    end if;
  end process PROC_FRAME_CLOCK_GENERATOR;

  
  -----------------------------------------------------------------------------
  -- FIFO Output Handler and Sync FIFO
  -----------------------------------------------------------------------------

  PROC_FIFO_READ_ENABLE: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        fifo_empty_prev    <= '0';
        fifo_read_enable   <= '0';
        fifo_data_valid_x  <= '0';
        fifo_data_valid    <= '0';
      else
        if (fifo_empty = '0' and fifo_empty_prev = '1') then
          fifo_read_enable <= '1';
        else
          fifo_read_enable <= '0';
        end if;
        fifo_empty_prev   <= fifo_empty; 
        fifo_data_valid_x <= fifo_read_enable;
        fifo_data_valid   <= fifo_data_valid_x;
      end if;
    end if;
  end process PROC_FIFO_READ_ENABLE;
  

  -- Read only in case FIFO is not empty, i.e. data_valid is set

  PROC_FIFO_READ: process(CLK_IN)

    variable frame_tag  : std_logic_vector(3 downto 0);

  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        fifo_new_frame     <= '0';
        register_fifo_data <= (others => '0');
      else
        frame_tag  := fifo_out( 8) & fifo_out(17) &
                      fifo_out(26) & fifo_out(35);
        fifo_new_frame     <= '0';
        register_fifo_data <= x"deadbeef";

        if (fifo_data_valid = '1') then

          case frame_tag is

            when "1000" =>
              register_fifo_data(31 downto 24) <= fifo_out( 7 downto  0);
              register_fifo_data(23 downto 16) <= fifo_out(16 downto  9);
              register_fifo_data(15 downto  8) <= fifo_out(25 downto 18);
              register_fifo_data( 7 downto  0) <= fifo_out(34 downto 27);
              fifo_new_frame                   <= '1';          

            when "0100" => 
              register_fifo_data(31 downto 24) <= fifo_out(16 downto  9);
              register_fifo_data(23 downto 16) <= fifo_out(25 downto 18);
              register_fifo_data(15 downto  8) <= fifo_out(34 downto 27);
              register_fifo_data( 7 downto  0) <= fifo_out( 7 downto  0);
              fifo_new_frame                   <= '1';          

            when "0010" => 
              register_fifo_data(31 downto 24) <= fifo_out(25 downto 18);
              register_fifo_data(23 downto 16) <= fifo_out(34 downto 27);
              register_fifo_data(15 downto  8) <= fifo_out( 7 downto  0);
              register_fifo_data( 7 downto  0) <= fifo_out(16 downto  9);
              fifo_new_frame                   <= '1';          

            when "0001" => 
              register_fifo_data(31 downto 24) <= fifo_out(34 downto 27);
              register_fifo_data(23 downto 16) <= fifo_out( 7 downto  0);
              register_fifo_data(15 downto  8) <= fifo_out(16 downto  9);
              register_fifo_data( 7 downto  0) <= fifo_out(25 downto 18);
              fifo_new_frame                   <= '1';          

            when others => null;
                           
          end case;

        end if;
      end if;
    end if;
  end process PROC_FIFO_READ;
  

  -----------------------------------------------------------------------------
  -- Sync to NX_DATA FRAME
  -----------------------------------------------------------------------------
  
  -- RS FlipFlop to hold Sync Status
  PROC_RS_FRAME_SYNCED: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1' or rs_sync_reset = '1') then
        nx_frame_synced <= '0';
      elsif (rs_sync_set = '1') then
        nx_frame_synced <= '1';
      end if;
    end if;
  end process PROC_RS_FRAME_SYNCED;

  -- Frame Resync Timer_done Timer
  nx_timer_1: nx_timer
    generic map (
      CTR_WIDTH => 8
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => RESET_IN,
      TIMER_START_IN => frame_sync_wait_ctr,
      TIMER_DONE_OUT => frame_sync_wait_done
      );

  -- Frame Sync process
  PROC_SYNC_TO_NX_FRAME_TRANSFER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        rs_sync_set           <= '0';
        rs_sync_reset         <= '1';
        frame_clock_ctr_inc_s <= '0';
        nx_frame_resync_ctr   <= (others => '0');
        frame_sync_wait_ctr   <= (others => '0');
        STATE_SYNC            <= S_SYNC_CHECK;
      else
        rs_sync_set           <= rs_sync_set_x;
        rs_sync_reset         <= rs_sync_reset_x;
        frame_clock_ctr_inc_s <= frame_clock_ctr_inc_s_x;
        nx_frame_resync_ctr   <= nx_frame_resync_ctr_x;
        frame_sync_wait_ctr   <= frame_sync_wait_ctr_x;
        STATE_SYNC            <= NEXT_STATE_SYNC;
      end if;
    end if;
  end process PROC_SYNC_TO_NX_FRAME_TRANSFER;

  PROC_SYNC_TO_NX_FRAME: process(STATE_SYNC,
                                 fifo_out(35),
                                 fifo_out(26),
                                 fifo_out(17),
                                 fifo_out(8),
                                 fifo_new_frame,
                                 register_fifo_data,
                                 frame_sync_wait_done
                                 )

    variable fifo_tag_given : std_logic_vector(3 downto 0);

  begin
    rs_sync_set_x           <= '0';
    rs_sync_reset_x         <= '0';
    frame_clock_ctr_inc_s_x <= '0';
    nx_frame_resync_ctr_x   <= nx_frame_resync_ctr;
    frame_sync_wait_ctr_x   <= (others => '0');

    fifo_tag_given := fifo_out(35) & fifo_out(26) &
                      fifo_out(17) & fifo_out(8);

    case STATE_SYNC is
      when S_SYNC_CHECK =>
        if (fifo_new_frame = '1') then      
          case register_fifo_data is
            when x"7f7f7f06" =>
              rs_sync_set_x <= '1';
              NEXT_STATE_SYNC  <= S_SYNC_CHECK;

            when x"067f7f7f" =>
              NEXT_STATE_SYNC <= S_SYNC_RESYNC;
            
            when x"7f067f7f" =>
              NEXT_STATE_SYNC <= S_SYNC_RESYNC;
            
            when x"7f7f067f" =>
              NEXT_STATE_SYNC <= S_SYNC_RESYNC;
            
            when others =>
              NEXT_STATE_SYNC <= S_SYNC_CHECK;
            
          end case;
        else
          NEXT_STATE_SYNC <= S_SYNC_CHECK;
        end if;

      when S_SYNC_RESYNC =>
        rs_sync_reset_x         <= '1';
        frame_clock_ctr_inc_s_x <= '1';
        nx_frame_resync_ctr_x   <= nx_frame_resync_ctr + 1;
        frame_sync_wait_ctr_x   <= x"14";
        NEXT_STATE_SYNC         <= S_SYNC_WAIT;

      when S_SYNC_WAIT =>
        if (frame_sync_wait_done = '0') then
          NEXT_STATE_SYNC       <= S_SYNC_WAIT;
        else
          NEXT_STATE_SYNC       <= S_SYNC_CHECK;
        end if;
        
    end case;
  end process PROC_SYNC_TO_NX_FRAME;

  -----------------------------------------------------------------------------
  -- TRBNet Slave Bus
  -----------------------------------------------------------------------------

  register_fifo_status(0)            <= fifo_full;
  register_fifo_status(1)            <= fifo_empty;
  register_fifo_status(2)            <= fifo_data_valid;
  register_fifo_status(3)            <= fifo_new_frame;
  register_fifo_status(15 downto 4)  <= (others => '0');
  register_fifo_status(23 downto 16) <= nx_frame_resync_ctr;
  register_fifo_status(30 downto 24) <= (others => '0');
  register_fifo_status(31)           <= nx_frame_synced;

  -- Give status info to the TRB Slow Control Channel
  PROC_FIFO_REGISTERS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o         <= (others => '0');
        slv_ack_o              <= '0';
        slv_unknown_addr_o     <= '0';
        slv_no_more_data_o     <= '0';
        frame_clock_ctr_inc_r  <= '0';
      else
        slv_data_out_o         <= (others => '0');
        slv_ack_o              <= '1';
        slv_unknown_addr_o     <= '0';
        slv_no_more_data_o     <= '0';
        frame_clock_ctr_inc_r  <= '0';

        if (SLV_READ_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              slv_data_out_o     <= register_fifo_data;

            when x"0001" =>
              slv_data_out_o     <= register_fifo_status;

            when others  =>
              slv_unknown_addr_o <= '1';
              slv_ack_o          <= '0';          
          end case;
          
        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0001" =>
              frame_clock_ctr_inc_r <= '1';

            when others  =>
              slv_unknown_addr_o    <= '1';              
              slv_ack_o             <= '0';
          end case;                
        else
          slv_ack_o <= '0';
        end if;
      end if;
    end if;
  end process PROC_FIFO_REGISTERS;

  frame_clock_ctr_inc_o <= frame_clock_ctr_inc_r or frame_clock_ctr_inc_s;
  
  -- Output Signals
  SLV_DATA_OUT          <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT  <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT  <= slv_unknown_addr_o;
  SLV_ACK_OUT           <= slv_ack_o;

  NX_FRAME_CLOCK_OUT    <= nx_frame_clock_o;
  NX_TIMESTAMP_OUT      <= register_fifo_data;
  NX_NEW_TIMESTAMP_OUT  <= fifo_new_frame and nx_frame_synced;
    
end Behavioral;
