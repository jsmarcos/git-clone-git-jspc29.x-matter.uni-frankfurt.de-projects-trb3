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

    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_timestamp_fifo_read is

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

  -- FIFO Output Handler
  signal fifo_out                 : std_logic_vector(35 downto 0);
  signal fifo_empty               : std_logic;
  signal fifo_read_enable_x       : std_logic;
  signal fifo_read_enable         : std_logic;
  signal register_fifo_data_x     : std_logic_vector(31 downto 0);
  signal register_fifo_data       : std_logic_vector(31 downto 0);
  signal fifo_new_data_x          : std_logic;
  signal fifo_new_data            : std_logic;

  signal frame_clock_ctr_inc_r    : std_logic;
  signal frame_clock_ctr_inc_s    : std_logic;
  signal frame_clock_ctr_inc_o    : std_logic;
  
  -- Sync NX Frame Process

  -- RS Sync FlipFlop
  signal nx_frame_synced_o     : std_logic;
  signal rs_sync_set           : std_logic;
  signal rs_sync_reset         : std_logic;
  
  -- Sync Process
  signal nx_frame_resync_ctr   : unsigned(7 downto 0);
  signal frame_sync_wait_ctr   : unsigned (7 downto 0);
  
  -- Slave Bus
  signal slv_data_out_o        : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o    : std_logic;
  signal slv_unknown_addr_o    : std_logic;
  signal slv_ack_o             : std_logic;
  signal register_fifo_status  : std_logic_vector(31 downto 0);

  type STATES is (S_IDLE,
                  S_READ_FIFO
                  );
  signal STATE, NEXT_STATE : STATES;

  type STATES_SYNC is (S_SYNC_CHECK,
                       S_SYNC_RESYNC,
                       S_SYNC_WAIT
                       );
  signal STATE_SYNC : STATES_SYNC;


begin
  
  DEBUG_OUT(0)           <= CLK_IN;
  
  DEBUG_OUT(1)           <= NX_TIMESTAMP_CLK_IN; -- fifo_write_enable;
--    DEBUG_OUT(2)           <= fifo_full;
--    DEBUG_OUT(3)           <= fifo_write_enable;
--    DEBUG_OUT(4)           <= fifo_empty;
--    DEBUG_OUT(5)           <= fifo_read_enable;
  
 -- DEBUG_OUT(2)           <= NX_FRAME_CLOCK_OUT;
 -- DEBUG_OUT(3)           <= ;
 -- DEBUG_OUT(5)           <= ;
 -- DEBUG_OUT(6)           <= ;
 -- DEBUG_OUT(7)           <= '0';
  DEBUG_OUT(6)             <= NX_FRAME_CLOCK_OUT;
  DEBUG_OUT(7)             <= frame_clock_ctr_inc;
--   DEBUG_OUT(15 downto 8) <= NX_TIMESTAMP_OUT(7 downto 0);
  --DEBUG_OUT(15 downto 8) <= NX_TIMESTAMP_IN(7 downto 0);
  DEBUG_OUT(9 downto 8) <= frame_clock_ctr;
  
  -----------------------------------------------------------------------------
  -- Dual Clock FIFO 8bit to 32bit
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

  -- Write only in case FIFO is not full
  fifo_write_enable <= '0' when fifo_full = '1' else '1';
  
  -----------------------------------------------------------------------------
  -- FIFO Input Handler
  -----------------------------------------------------------------------------
  
  -- Cross ClockDomain CLK_IN --> NX_TIMESTAMP_CLK_IN for signal
  -- fifo_skip_write
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
        frame_tag_o       <= '1';
      else
        case frame_clock_ctr is

          when "00" =>
            nx_frame_clock_o  <= '1';
            frame_tag_o       <= '1';
          when "01" =>
            nx_frame_clock_o  <= '1';
            frame_tag_o       <= '0';
          when "10" =>
            nx_frame_clock_o  <= '0';
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

  PROC_FIFO_READ_TRANSFER: process (CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        fifo_read_enable    <= '0';
        fifo_new_data       <= '0';
        register_fifo_data  <= (others => '0');
        STATE               <= S_IDLE;
        register_fifo_data  <= (others => '0');
      else
        fifo_read_enable    <= fifo_read_enable_x;
        fifo_new_data       <= fifo_new_data_x;
        register_fifo_data  <= register_fifo_data_x;
        STATE               <= NEXT_STATE;
      end if;
    end if;
  end process PROC_FIFO_READ_TRANSFER;

  -- Read only in case FIFO is not empty
  PROC_FIFO_READ: process(STATE)

    variable frame_tag : std_logic_vector(3 downto 0);

  begin
    fifo_read_enable_x   <= '0';
    fifo_new_data_x      <= '0';
    register_fifo_data_x <= register_fifo_data;

    frame_tag := fifo_out(35) & fifo_out(26) &
                 fifo_out(17) & fifo_out(8);
    
    case STATE is

      when S_IDLE =>
        if (fifo_empty = '1') then
          NEXT_STATE <= S_IDLE;
        else
          fifo_read_enable_x <= '1';
          NEXT_STATE         <= S_READ_FIFO;
        end if;
        
      when S_READ_FIFO =>
        fifo_new_data_x  <= '1';
        case frame_tag is
          when "1000" =>
            register_fifo_data_x(31 downto 24) <= fifo_out(34 downto 27);
            register_fifo_data_x(23 downto 16) <= fifo_out(25 downto 18);
            register_fifo_data_x(15 downto 8)  <= fifo_out(16 downto  9);
            register_fifo_data_x(7 downto 0)   <= fifo_out(7  downto  0);
          when "0100" => 
            register_fifo_data_x(31 downto 24) <= fifo_out( 7 downto  0);
            register_fifo_data_x(23 downto 16) <= fifo_out(34 downto 27);
            register_fifo_data_x(15 downto 8)  <= fifo_out(25 downto 18);
            register_fifo_data_x(7 downto 0)   <= fifo_out(16 downto  9);
          when "0010" => 
            register_fifo_data_x(31 downto 24) <= fifo_out(16 downto  9);
            register_fifo_data_x(23 downto 16) <= fifo_out(7  downto  0);
            register_fifo_data_x(15 downto 8)  <= fifo_out(34 downto 27);
            register_fifo_data_x(7 downto 0)   <= fifo_out(25 downto 18);
          when "0001" => 
            register_fifo_data_x(31 downto 24) <= fifo_out(25  downto 18);
            register_fifo_data_x(23 downto 16) <= fifo_out(16  downto  9);
            register_fifo_data_x(15 downto 8)  <= fifo_out(7   downto  0);
            register_fifo_data_x(7 downto 0)   <= fifo_out(34  downto 27);

          when others =>
            register_fifo_data_x <= (others => '1');
            fifo_new_data_x      <= '0';
        end case;
        NEXT_STATE <= S_IDLE;
        
      when others => null;
    end case;
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

  -- Sync to NX_DATA FRAME 
  PROC_SYNC_TO_NO_DATA: process(CLK_IN)

    variable fifo_tag_given : std_logic_vector(3 downto 0);
  
  begin
    fifo_tag_given := fifo_out(35) & fifo_out(26) &
                      fifo_out(17) & fifo_out(8);

    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        rs_sync_set           <= '0';
        rs_sync_reset         <= '1';
        nx_frame_resync_ctr   <= (others => '0');
        frame_sync_wait_ctr   <= (others => '0');
        frame_clock_ctr_inc_s <= '0';
        STATE_SYNC            <= S_SYNC_CHECK;
      else
        rs_sync_set           <= '0';
        rs_sync_reset         <= '0';
        frame_clock_ctr_inc_s <= '0';

        DEBUG_OUT(5 downto 2) <= fifo_tag_given;
        
        case STATE_SYNC is

          when S_SYNC_CHECK =>
            case register_fifo_data is
              when x"7f7f7f06" =>
                rs_sync_set <= '1';
                STATE_SYNC  <= S_SYNC_CHECK;

              when x"067f7f7f" =>
                STATE_SYNC <= S_SYNC_RESYNC;

              when x"7f067f7f" =>
                STATE_SYNC <= S_SYNC_RESYNC;
                
              when x"7f7f067f" =>
                STATE_SYNC <= S_SYNC_RESYNC;

              when others =>
                STATE_SYNC <= S_SYNC_CHECK;
                
            end case;

          when S_SYNC_RESYNC =>
            rs_sync_reset         <= '1';
            frame_clock_ctr_inc_s <= '1';
            nx_frame_resync_ctr   <= nx_frame_resync_ctr + 1;
            frame_sync_wait_ctr   <= x"ff";
            STATE_SYNC            <= S_SYNC_WAIT;

          when S_SYNC_WAIT =>
            if (frame_sync_wait_ctr > 0) then
              frame_sync_wait_ctr <= frame_sync_wait_ctr -1;
              STATE_SYNC          <= S_SYNC_WAIT;
            else
              STATE_SYNC          <= S_SYNC_CHECK;
            end if;

        end case;

      end if;
    end if;
  end process PROC_SYNC_TO_NO_DATA;

  NX_FRAME_SYNC_OUT <= nx_frame_synced_o;

-- 
-- -------------------------------------------------------------------------------
-- -- TRBNet Slave Bus
-- -------------------------------------------------------------------------------
-- 
--   -- Cross ClockDomain NX_TIMESTAMP_CLK_IN --> CLK_IN, for simplicity just
--   -- cross all signals, even the CLK_IN ones
-- --   PROC_SYNC_FIFO_SIGNALS: process(CLK_IN)
-- --   begin
-- --     if( rising_edge(CLK_IN) ) then
-- --       if( RESET_IN = '1' ) then
-- --         fifo_empty_x          <= '0';
-- --         fifo_empty            <= '0';
-- -- 
-- --         fifo_full_x           <= '0';
-- --         fifo_full             <= '0';
-- -- 
-- --         fifo_write_enable_x   <= '0';
-- --         fifo_write_enable     <= '0';
-- --         
-- --         fifo_read_enable_x    <= '0';
-- --         fifo_read_enable      <= '0';
-- -- 
-- --         fifo_write_skip_ctr_x <= (others => '0');
-- --         fifo_write_skip_ctr_o <= (others => '0');
-- --       else
-- --         fifo_empty_x        <= fifo_empty_i;
-- --         fifo_empty          <= fifo_empty_x;
-- -- 
-- --         fifo_full_x         <= fifo_full_i;
-- --         fifo_full           <= fifo_full_x;
-- -- 
-- --         fifo_write_enable_x <= fifo_write_enable;
-- --         fifo_write_enable   <= fifo_write_enable_x;
-- -- 
-- --         fifo_read_enable_x  <= fifo_read_enable_o;
-- --         fifo_read_enable    <= fifo_read_enable_x;
-- -- 
-- --         fifo_write_skip_ctr_x <= fifo_write_skip_ctr;
-- --         fifo_write_skip_ctr_o <= fifo_write_skip_ctr_x;
-- --       end if;
-- --     end if;
-- --   end process PROC_SYNC_FIFO_SIGNALS;
-- 

  register_fifo_status(0)            <= fifo_write_enable;
  register_fifo_status(1)            <= fifo_full;
  register_fifo_status(3 downto 2)   <= (others => '0');
  register_fifo_status(4)            <= fifo_read_enable;
  register_fifo_status(5)            <= fifo_empty;
  register_fifo_status(7 downto 6)   <= (others => '0');
  register_fifo_status(15 downto 8)  <= (others => '0');-- fifo_write_skip_ctr;
  register_fifo_status(23 downto 16) <= nx_frame_resync_ctr;
  register_fifo_status(30 downto 24) <= (others => '0');
  register_fifo_status(31)           <= nx_frame_synced_o;


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
            when x"0000" => slv_data_out_o     <= register_fifo_data;
            when x"0001" => slv_data_out_o     <= register_fifo_status;
            when others  => slv_unknown_addr_o <= '1';
                            slv_ack_o          <= '0';          
          end case;
          
        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0001" => frame_clock_ctr_inc_r <= '1';
            when others  => slv_unknown_addr_o    <= '1';              
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
  SLV_DATA_OUT         <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT <= slv_unknown_addr_o;
  SLV_ACK_OUT          <= slv_ack_o;

  NX_FRAME_CLOCK_OUT   <= nx_frame_clock_o;
  NX_TIMESTAMP_OUT     <= register_fifo_data;

end Behavioral;
