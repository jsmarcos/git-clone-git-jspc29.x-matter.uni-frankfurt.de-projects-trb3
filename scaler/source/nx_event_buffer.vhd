library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.scaler_components.all;
use work.trb3_components.all;

entity nx_event_buffer is
  generic (
    BOARD_ID : std_logic_vector(1 downto 0) := "11"
    );
  port (
    CLK_IN                     : in  std_logic;  
    RESET_IN                   : in  std_logic;
    RESET_DATA_BUFFER_IN       : in  std_logic;
    NXYTER_OFFLINE_IN          : in  std_logic;

    -- Data Buffer FIFO        
    DATA_IN                    : in  std_logic_vector(31 downto 0);
    DATA_CLK_IN                : in  std_logic;
    EVT_NOMORE_DATA_IN         : in  std_logic;

    -- Trigger
    TRIGGER_IN                 : in  std_logic;
    FAST_CLEAR_IN              : in  std_logic;
    TRIGGER_BUSY_OUT           : out std_logic;
    EVT_BUFFER_FULL_OUT        : out std_logic;
    
    --Response from FEE        
    FEE_DATA_OUT               : out std_logic_vector(31 downto 0);
    FEE_DATA_WRITE_OUT         : out std_logic;
    FEE_DATA_ALMOST_FULL_IN    : in  std_logic;
    
    -- Slave bus         
    SLV_READ_IN                : in  std_logic;
    SLV_WRITE_IN               : in  std_logic;
    SLV_DATA_OUT               : out std_logic_vector(31 downto 0);
    SLV_DATA_IN                : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN                : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT                : out std_logic;
    SLV_NO_MORE_DATA_OUT       : out std_logic;
    SLV_UNKNOWN_ADDR_OUT       : out std_logic;

    ERROR_OUT                  : out std_logic;                        

    DEBUG_OUT                  : out std_logic_vector(15 downto 0)
    );

end entity;

architecture Behavioral of nx_event_buffer is

  --Data channel
  signal fee_data_o           : std_logic_vector(31 downto 0);
  signal fee_data_write_o     : std_logic;
  signal trigger_busy_o       : std_logic;
  signal evt_data_flush       : std_logic;
  
  type STATES is (S_IDLE,
                  S_FLUSH_BUFFER_WAIT
                  );
  signal STATE : STATES; 

  -- FIFO
  signal fifo_reset           : std_logic;
  signal fifo_read_enable     : std_logic;

  -- FIFO Input Handler
  signal fifo_next_word       : std_logic_vector(31 downto 0);
  signal fifo_full            : std_logic;
  signal fifo_write_enable    : std_logic;
  signal fifo_almost_full_thr : std_logic_vector(10 downto 0);

    -- NOMORE_DATA RS FlipFlop
  signal flush_end_enable_set : std_logic;
  signal flush_end_enable     : std_logic;
  
  -- FIFO Read Handler
  signal fifo_o               : std_logic_vector(31 downto 0);
  signal fifo_empty           : std_logic;
  signal fifo_read_start      : std_logic;
  signal fifo_almost_full     : std_logic;
                              
  signal fifo_read_enable_s   : std_logic;
  signal fifo_read_busy       : std_logic;
  signal fifo_no_data         : std_logic;
  signal fifo_read_done       : std_logic;
  signal evt_buffer_full_o    : std_logic;
  signal fifo_data            : std_logic_vector(31 downto 0);

  type R_STATES is (R_IDLE,
                    R_NOP1,
                    R_NOP2,
                    R_READ_WORD
                    );

  signal R_STATE : R_STATES;

  -- Event Buffer Output Handler
  signal evt_data_clk              : std_logic;
  signal evt_data_flushed          : std_logic;
                                   
  signal fifo_read_enable_f        : std_logic;
  signal fifo_read_enable_f2       : std_logic;
  signal fifo_flush_ctr            : unsigned(10 downto 0);
  signal fifo_flush_ctr_last       : unsigned(10 downto 0);

  signal evt_data_flushed_x        : std_logic;
  signal fifo_flush_ctr_x          : unsigned(10 downto 0);
  signal flush_end_enable_reset_x  : std_logic;

  type F_STATES is (F_IDLE,
                    F_FLUSH,
                    F_END
                    );

  signal F_STATE, F_NEXT_STATE : F_STATES;

  -- Error Status
  signal fifo_almost_full_p    : std_logic;
  signal error_status_o        : std_logic;
  signal fifo_full_rate_ctr    : unsigned(19 downto 0);
  signal fifo_full_rate        : unsigned(19 downto 0);
  signal rate_timer_ctr        : unsigned(27 downto 0);

  -- Slave Bus
  signal slv_data_out_o        : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o    : std_logic;
  signal slv_unknown_addr_o    : std_logic;
  signal slv_ack_o             : std_logic;

  signal register_fifo_status  : std_logic_vector(7 downto 0);

  signal data_wait             : std_logic;

begin

  DEBUG_OUT(0)           <= CLK_IN;
  DEBUG_OUT(1)           <= DATA_CLK_IN;
  DEBUG_OUT(2)           <= fifo_empty;
  DEBUG_OUT(3)           <= fifo_almost_full;
  DEBUG_OUT(4)           <= RESET_DATA_BUFFER_IN;
  DEBUG_OUT(5)           <= trigger_busy_o;
  DEBUG_OUT(6)           <= TRIGGER_IN;
  DEBUG_OUT(7)           <= evt_data_flush;
  DEBUG_OUT(8)           <= flush_end_enable;  
  DEBUG_OUT(9)           <= evt_data_clk;
  DEBUG_OUT(10)          <= fee_data_write_o;
  DEBUG_OUT(11)          <= evt_data_flushed;
  DEBUG_OUT(12)          <= '0';
  DEBUG_OUT(13)          <= EVT_NOMORE_DATA_IN; 
  DEBUG_OUT(14)          <= FAST_CLEAR_IN;
  DEBUG_OUT(15)          <= FEE_DATA_ALMOST_FULL_IN;
  
  -----------------------------------------------------------------------------
  -- 
  -----------------------------------------------------------------------------

  PROC_DATA_HANDLER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        evt_data_flush       <= '0';
        trigger_busy_o       <= '0';
        STATE                <= S_IDLE;
      else
        evt_data_flush       <= '0';
        trigger_busy_o       <= '1';
        
        if (FAST_CLEAR_IN = '1') then
          STATE                      <= S_IDLE;
        else
          case STATE is
            when S_IDLE =>
              if (NXYTER_OFFLINE_IN = '1') then
                trigger_busy_o             <= '0';
                STATE                      <= S_IDLE;
              elsif (TRIGGER_IN = '1') then
                evt_data_flush             <= '1';
                STATE                      <= S_FLUSH_BUFFER_WAIT;
              else
                trigger_busy_o             <= '0';
                STATE                      <= S_IDLE;
              end if;
              
            when S_FLUSH_BUFFER_WAIT =>
              if (evt_data_flushed = '0') then
                STATE                      <= S_FLUSH_BUFFER_WAIT;
              else                         
                STATE                      <= S_IDLE;
              end if;                      
              
          end case;
        end if;
      end if;
    end if;
  end process PROC_DATA_HANDLER;

  -----------------------------------------------------------------------------
  -- FIFO Input Handler
  -----------------------------------------------------------------------------

  -- Send data to FIFO
  fifo_32_data_1: entity work.fifo_32_data
    port map (
      Data         => fifo_next_word,
      Clock        => CLK_IN,
      WrEn         => fifo_write_enable,
      RdEn         => fifo_read_enable,
      Reset        => fifo_reset,
      AmFullThresh => fifo_almost_full_thr,
      Q            => fifo_o,
      Empty        => fifo_empty,
      Full         => fifo_full,
      AlmostFull   => fifo_almost_full
      );
  
  fifo_reset       <= RESET_IN or RESET_DATA_BUFFER_IN;
  fifo_read_enable <= fifo_read_enable_f or fifo_read_enable_s;

  PROC_FIFO_WRITE_HANDLER: process(CLK_IN)
  begin
    if(rising_edge(CLK_IN)) then
      if(RESET_IN = '1' or RESET_DATA_BUFFER_IN = '1') then
        fifo_write_enable   <= '0';
      else
        fifo_write_enable   <= '0';
        fifo_next_word      <= x"deadbeef";
        
        if (DATA_CLK_IN      = '1' and
            fifo_full        = '0' and
            fifo_almost_full = '0') then
          fifo_next_word    <= DATA_IN;
          fifo_write_enable <= '1';
        end if;
        
      end if;
    end if;
  end process PROC_FIFO_WRITE_HANDLER;

  PROC_FLUSH_END_RS_FF: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1') then
        flush_end_enable    <= '0';
      else
        if (flush_end_enable_reset_x = '1') then
          flush_end_enable  <= '0';
        elsif (flush_end_enable_set = '1') then
          flush_end_enable  <= '1';
        end if;
      end if;
    end if;
  end process PROC_FLUSH_END_RS_FF;

  flush_end_enable_set <= EVT_NOMORE_DATA_IN;  
    
  PROC_FLUSH_BUFFER_TRANSFER: process(CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      fifo_read_enable_f2    <= fifo_read_enable_f;
      if( RESET_IN = '1' ) then
        evt_data_clk           <= '0';
        evt_data_flushed       <= '0';
        fifo_flush_ctr         <= (others => '0');
        fifo_flush_ctr_last    <= (others => '0');
        F_STATE                <= F_IDLE;
      else
        evt_data_flushed       <= evt_data_flushed_x;
        fifo_flush_ctr         <= fifo_flush_ctr_x;
        F_STATE                <= F_NEXT_STATE;
        evt_data_clk           <= fifo_read_enable_f2;

        if (F_STATE = F_END) then
          fifo_flush_ctr_last  <= fifo_flush_ctr_x;
        end if;
      end if;
    end if;
  end process PROC_FLUSH_BUFFER_TRANSFER;

  PROC_FLUSH_BUFFER: process(F_STATE,
                             evt_data_flush,
                             fifo_empty,
                             evt_data_clk,
                             flush_end_enable
                             )
  begin
    -- Defaults
    fifo_read_enable_f        <= '0';
    fifo_flush_ctr_x          <= fifo_flush_ctr;
    evt_data_flushed_x        <= '0';
    flush_end_enable_reset_x  <= '0';

    -- Multiplexer fee_data_o
    if (evt_data_clk = '1') then
      fee_data_o                   <= fifo_o;
      fee_data_write_o             <= '1';
    else
      fee_data_o                   <= (others => '1');
      fee_data_write_o             <= '0';
    end if;
    
    -- FIFO Read Handler
    case F_STATE is 
      when F_IDLE =>
        if (evt_data_flush = '1') then
          fifo_flush_ctr_x         <= (others => '0');
          flush_end_enable_reset_x <= '1';
          F_NEXT_STATE             <= F_FLUSH;
        else
          F_NEXT_STATE             <= F_IDLE; 
        end if;
            
      when F_FLUSH =>
        if (fifo_empty = '0') then
          fifo_read_enable_f       <= '1';
          fifo_flush_ctr_x         <= fifo_flush_ctr + 1; 
          F_NEXT_STATE             <= F_FLUSH; 
        else
          if (flush_end_enable = '0') then
            F_NEXT_STATE           <= F_FLUSH;
          else
            F_NEXT_STATE           <= F_END;
          end if;
        end if;

      when F_END =>
        evt_data_flushed_x         <= '1';
        F_NEXT_STATE               <= F_IDLE;
        
    end case;
  end process PROC_FLUSH_BUFFER;

  -----------------------------------------------------------------------------
  -- FIFO Output Handler
  -----------------------------------------------------------------------------
  
  PROC_FIFO_READ_WORD: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        fifo_read_enable_s    <= '0';
        fifo_read_busy        <= '0';
        fifo_data             <= (others => '0');
        fifo_read_done        <= '0';
        fifo_no_data          <= '1';
        R_STATE               <= R_IDLE;
      else                    
        fifo_read_busy        <= '0';
        fifo_no_data          <= '0';
        fifo_read_done        <= '0';
        fifo_data             <= (others => '0');
        fifo_read_enable_s    <= '0';

        case R_STATE is 
          when R_IDLE =>
            if (fifo_read_start = '1') then
              if (fifo_empty = '0') then
                fifo_read_enable_s <= '1';
                fifo_read_busy     <= '1';
                R_STATE            <= R_NOP1;
              else
                fifo_no_data       <= '1';
                fifo_read_done     <= '1';
                R_STATE            <= R_IDLE;
              end if;
            else
              R_STATE              <= R_IDLE;
            end if;

          when R_NOP1 =>
            fifo_read_busy         <= '1';
            R_STATE                <= R_NOP2;
                                   
          when R_NOP2 =>           
            fifo_read_busy         <= '1';
            R_STATE                <= R_READ_WORD;
                                   
          when R_READ_WORD =>      
            fifo_read_busy         <= '0';
            fifo_data              <= fifo_o;
            fifo_read_done         <= '1';
            R_STATE                <= R_IDLE;
            
        end case; 
      end if;
    end if;

  end process PROC_FIFO_READ_WORD;

  -----------------------------------------------------------------------------
  -- Rate Counters + Rate Error Check
  -----------------------------------------------------------------------------
  level_to_pulse_FIFO_FULL: level_to_pulse
    port map (
      CLK_IN    => CLK_IN,
      RESET_IN  => RESET_IN,
      LEVEL_IN  => fifo_almost_full,
      PULSE_OUT => fifo_almost_full_p
      );


  PROC_RATE_COUNTER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        fifo_full_rate_ctr     <= (others => '0');
        fifo_full_rate         <= (others => '0');
        rate_timer_ctr         <= (others => '0');
        error_status_o         <= '0';
      else
        if (rate_timer_ctr < x"5f5e100") then
          rate_timer_ctr                  <= rate_timer_ctr + 1;

          if (fifo_almost_full_p = '1') then
            fifo_full_rate_ctr            <= fifo_full_rate_ctr + 1;
          end if;
        else
          rate_timer_ctr                  <= (others => '0');
          fifo_full_rate                  <= fifo_full_rate_ctr; 
          
          fifo_full_rate_ctr(19 downto 1) <= (others => '0');
          fifo_full_rate_ctr(0)           <= fifo_almost_full_p;

          if (fifo_full_rate > 0) then
            error_status_o                <= '1';
          else
            error_status_o                <= '0';
          end if;
        end if;
      end if;
    end if;
  end process PROC_RATE_COUNTER;
  
  -----------------------------------------------------------------------------
  -- Slave Bus Slow Control
  -----------------------------------------------------------------------------

  register_fifo_status(0)            <= fifo_write_enable;
  register_fifo_status(1)            <= fifo_full;
  register_fifo_status(3 downto 2)   <= (others => '0');
  register_fifo_status(4)            <= fifo_read_enable;
  register_fifo_status(5)            <= fifo_empty;
  register_fifo_status(7 downto 6)   <= (others => '0');

  PROC_SLAVE_BUS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o         <= (others => '0');
        slv_ack_o              <= '0';
        slv_unknown_addr_o     <= '0';
        slv_no_more_data_o     <= '0';
                               
        fifo_read_start        <= '0';
        data_wait              <= '0';
        fifo_almost_full_thr   <= "00101011110"; -- default: 350 = 1.4k
      else                     
        slv_data_out_o         <= (others => '0');
        slv_ack_o              <= '0';
        slv_unknown_addr_o     <= '0';
        slv_no_more_data_o     <= '0';
                               
        fifo_read_start        <= '0';
        data_wait              <= '0';
        
        if (data_wait = '1') then
          if (fifo_read_done = '0') then
            data_wait                      <= '1';
          else
            if (fifo_no_data = '0') then
              slv_data_out_o               <= fifo_data;
              slv_ack_o                    <= '1';
            else                           
              slv_no_more_data_o           <= '1';
              slv_ack_o                    <= '0';
            end if;                        
            data_wait                      <= '0';
          end if;

        elsif (SLV_READ_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              fifo_read_start               <= '1';
              data_wait                     <= '1';

            when x"0001" =>
              slv_data_out_o(10 downto 0)   <= fifo_almost_full_thr;
              slv_data_out_o(31 downto 11)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0002" =>
              slv_data_out_o(10 downto 0)   <=
                std_logic_vector(fifo_flush_ctr_last);
              slv_data_out_o(31 downto 11)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0003" =>
               slv_data_out_o(19 downto 0)  <= fifo_full_rate;
               slv_data_out_o(31 downto 20) <= (others => '0');
               slv_ack_o                    <= '1';

            when x"0004" =>
               slv_data_out_o(0)            <= error_status_o;
               slv_data_out_o(31 downto 1)  <= (others => '0');
               slv_ack_o                    <= '1';

            when x"0005" =>
              slv_data_out_o(7 downto 0)    <= register_fifo_status;
              slv_data_out_o(31 downto 8)   <= (others => '0');
              slv_ack_o                     <= '1';
              
            when others  =>
              slv_unknown_addr_o            <= '1';
          end case;
                
        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0001" =>
              if (unsigned(slv_data_out_o(10 downto 0)) < 2040) then
                fifo_almost_full_thr        <= SLV_DATA_IN(10 downto 0);
              end if;
              slv_ack_o                     <= '1';
            
            when others  =>
              slv_unknown_addr_o            <= '1';              
              slv_ack_o                     <= '0';
          end case;                
          
        else
          slv_ack_o                        <= '0';
        end if;
      end if;
    end if;
  end process PROC_SLAVE_BUS;


  -- Output Signals
  
  evt_buffer_full_o      <= fifo_almost_full;
  
  TRIGGER_BUSY_OUT       <= trigger_busy_o;
  EVT_BUFFER_FULL_OUT    <= evt_buffer_full_o;
  
  FEE_DATA_OUT           <= fee_data_o;
  FEE_DATA_WRITE_OUT     <= fee_data_write_o;
  
  SLV_DATA_OUT           <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT   <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT   <= slv_unknown_addr_o;
  SLV_ACK_OUT            <= slv_ack_o;

  ERROR_OUT              <= error_status_o;          

end Behavioral;
