library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.nxyter_components.all;

entity nx_timestamp_process is
  port (
    CLK_IN               : in  std_logic;  
    RESET_IN             : in  std_logic;

    -- Inputs
    TIMESTAMP_CLK_IN     : in  std_logic;
    NX_TOKEN_RETURN_IN   : in  std_logic;
    NX_NOMORE_DATA_IN    : in  std_logic;
    TIMESTAMP_IN         : in  unsigned(13 downto 0);
    CHANNEL_IN           : in  unsigned(6 downto 0);
    TIMESTAMP_STATUS_IN  : in  std_logic_vector(1 downto 0);
    TIMESTAMP_REF_IN     : in  unsigned(11 downto 0);
    TRIGGER_IN           : in std_logic;
    
    -- Outputs
    PROCESS_BUSY_OUT     : out std_logic;
    DATA_OUT             : out std_logic_vector(31 downto 0);
    DATA_CLK_OUT         : out std_logic;
    DATA_FIFO_RESET_OUT  : out std_logic;
    
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

architecture Behavioral of nx_timestamp_process is

  -- Sync Ref
  signal timestamp_ref_x      : unsigned(11 downto 0);
  signal timestamp_ref        : unsigned(11 downto 0);

  -- Process Channel_Status
  signal channel_index        : unsigned(6 downto 0);
  signal channel_wait         : unsigned(127 downto 0);
  signal channel_done         : unsigned(127 downto 0);
  signal channel_all_done     : std_logic;
  
  type CS_CMDS is (CS_RESET,
                   CS_TOKEN_UPDATE,
                   CS_SET_WAIT,
                   CS_SET_DONE,
                   CS_NONE
                  );
  signal channel_status_cmd   : CS_CMDS; 
  
  -- Process Timestamp
  signal data_o               : std_logic_vector(31 downto 0);
  signal data_clk_o           : std_logic;
  signal out_of_window_l      : std_logic;
  signal out_of_window_h      : std_logic;
  signal ch_status_cmd_pr     : CS_CMDS;
   
  -- Process Trigger Handler
  signal store_to_fifo        : std_logic;
  signal data_fifo_reset_o    : std_logic;
  signal process_busy_o       : std_logic;
  signal wait_timer_init      : unsigned(11 downto 0);
  signal token_return_ctr     : unsigned(3 downto 0);
  signal ch_status_cmd_tr     : CS_CMDS;
  
  type STATES is (S_IDLE,
                  S_TRIGGER,
                  S_WAIT_DATA,
                  S_PROCESS_START,
                  S_WAIT_PROCESS_END,
                  S_WRITE_TRAILER
                  );
  signal STATE : STATES;

  signal t_data_o             : std_logic_vector(31 downto 0);
  signal t_data_clk_o         : std_logic;
  signal busy_time_ctr        : unsigned(11 downto 0);
  
  -- Timer
  signal wait_timer_done      : std_logic;
  
  -- Slave Bus                    
  signal slv_data_out_o       : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o   : std_logic;
  signal slv_unknown_addr_o   : std_logic;
  signal slv_ack_o            : std_logic;

  signal readout_mode         : std_logic_vector(3 downto 0);
  signal trigger_window_width : unsigned(11 downto 0);
  signal trigger_window_delay : unsigned(11 downto 0);
  signal readout_time_max     : unsigned(11 downto 0);
  
begin

  -- Debug Line
  DEBUG_OUT(0)           <= store_to_fifo;
  DEBUG_OUT(1)           <= data_fifo_reset_o;
  DEBUG_OUT(2)           <= process_busy_o;
  DEBUG_OUT(3)           <= channel_all_done;
  DEBUG_OUT(4)           <= data_clk_o;
  DEBUG_OUT(5)           <= t_data_clk_o;
  DEBUG_OUT(6)           <= out_of_window_l;
  DEBUG_OUT(7)           <= out_of_window_h;
  DEBUG_OUT(14 downto 8) <= (others => '0');
  
  -- Timer
  nx_timer_1: nx_timer
    generic map(
      CTR_WIDTH => 12
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => RESET_IN,
      TIMER_START_IN => wait_timer_init,
      TIMER_DONE_OUT => wait_timer_done
      );

  -- Sync Timestamp Ref
  PROC_SYNC_TIMESTAMP_REF: process (CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        timestamp_ref_x <= (others => '0');
        timestamp_ref   <= (others => '0');
      else
        timestamp_ref_x <= TIMESTAMP_REF_IN;
        timestamp_ref   <= timestamp_ref_x;
      end if;
    end if;
  end process PROC_SYNC_TIMESTAMP_REF;
  
  -----------------------------------------------------------------------------
  -- Filter only valid events
  -----------------------------------------------------------------------------

  PROC_PROCESS_TIMESTAMP: process (CLK_IN)
    variable ts_ref             : unsigned(11 downto 0);
    variable window_lower_thr   : unsigned(11 downto 0);
    variable window_upper_thr   : unsigned(11 downto 0);
    variable deltaT             : unsigned(11 downto 0);

  begin 
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        data_o               <= (others => '0');
        data_clk_o           <= '0';
        out_of_window_l      <= '0';
        out_of_window_h      <= '0';
      else
        data_o               <= (others => '0');
        data_clk_o           <= '0';
        out_of_window_l      <= '0';
        out_of_window_h      <= '0';
        ch_status_cmd_pr     <= CS_NONE;
        
        if (store_to_fifo = '1' and TIMESTAMP_CLK_IN = '1') then
          ts_ref             := timestamp_ref - x"010";
          window_lower_thr   := trigger_window_delay;
          window_upper_thr   := window_lower_thr + trigger_window_width;
          deltaT             := TIMESTAMP_IN(13 downto 2) - ts_ref;

          case readout_mode is
            
            when x"0" =>            -- RefValue + valid and window filter 
              if (TIMESTAMP_STATUS_IN(0) = '0') then
                if (deltaT < window_lower_thr) then
                  out_of_window_l <= '1';
                  data_clk_o      <= '0';
                  -- IN LUT-Data bit setzten.
                  channel_index      <= CHANNEL_IN;
                  ch_status_cmd_pr   <= CS_SET_WAIT;
                elsif (deltaT > window_upper_thr) then
                  out_of_window_h <= '1';
                  data_clk_o      <= '0';
                  -- In LUT-Done Bit setzten
                  channel_index    <= CHANNEL_IN;
                  ch_status_cmd_pr <= CS_SET_DONE;
                else
                  --data_o( 1 downto  0) <= TIMESTAMP_IN(1 downto 0);
                  data_o(11 downto  0) <= deltaT;
                  data_o(15 downto 12) <= (others => '0');
                  data_o(22 downto 16) <= CHANNEL_IN;
                  data_o(27 downto 23) <= (others => '0');
                  data_o(29 downto 28) <= TIMESTAMP_STATUS_IN;
                  data_o(31 downto 30) <= (others => '0');
                  data_clk_o <= '1';
                  -- IN LUT-Data bit setzten.
                  channel_index      <= CHANNEL_IN;
                  ch_status_cmd_pr   <= CS_SET_WAIT;
                end if;
              end if;
          
            when x"1" =>            -- RefValue + valid filter
              if (TIMESTAMP_STATUS_IN(0) = '0') then
                --data_o( 1 downto  0) <= TIMESTAMP_IN(1 downto 0);
                data_o(11 downto  0) <= deltaT;
                data_o(15 downto 12) <= (others => '0');
                data_o(22 downto 16) <= CHANNEL_IN;
                data_o(27 downto 23) <= (others => '0');
                data_o(29 downto 28) <= TIMESTAMP_STATUS_IN;
                data_o(31 downto 30) <= (others => '0');
                data_clk_o <= '1';
              end if;

            when x"3" =>            -- RefValue + valid filter
              if (TIMESTAMP_STATUS_IN(0) = '0') then
                data_o(11 downto  0) <= TIMESTAMP_IN(13 downto 2);
                data_o(13 downto 12) <= (others => '0'); 
                data_o(15 downto 14) <= (others => '0');
                data_o(27 downto 16) <= ts_ref;
                data_o(31 downto 28) <= (others => '0');
                data_clk_o <= '1';
              end if;
                  
            when x"4" =>            -- RawValue
              data_o(13 downto  0) <= TIMESTAMP_IN;
              data_o(15 downto 14) <= (others => '0');
              data_o(22 downto 16) <= CHANNEL_IN;
              data_o(27 downto 23) <= (others => '0');
              data_o(29 downto 28) <= TIMESTAMP_STATUS_IN;
              data_o(31 downto 30) <= (others => '0');
              data_clk_o <= '1';

            when x"5" =>            -- RawValue + valid filter
              if (TIMESTAMP_STATUS_IN(0) = '0') then
                data_o(13 downto  0) <= TIMESTAMP_IN;
                data_o(15 downto 14) <= (others => '0');
                data_o(22 downto 16) <= CHANNEL_IN;
                data_o(27 downto 23) <= (others => '0');
                data_o(29 downto 28) <= TIMESTAMP_STATUS_IN;
                data_o(31 downto 30) <= (others => '0');
                data_clk_o <= '1';
              end if;

            when others => null;

          end case;
            
        end if;
      end if;
    end if;
  end process PROC_PROCESS_TIMESTAMP;

  -----------------------------------------------------------------------------
  -- Trigger Handler
  -----------------------------------------------------------------------------

  PROC_TRIGGER_HANDLER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        store_to_fifo         <= '0';
        data_fifo_reset_o     <= '0';
        process_busy_o        <= '0';
        wait_timer_init       <= (others => '0');
        t_data_o              <= (others => '0');
        t_data_clk_o          <= '0';
        busy_time_ctr         <= (others => '0');
        token_return_ctr      <= (others => '0');
        ch_status_cmd_tr      <= CS_RESET;
        STATE                 <= S_IDLE;
      else
        store_to_fifo         <= '0';
        data_fifo_reset_o     <= '0';
        wait_timer_init       <= (others => '0');
        process_busy_o        <= '1';
        t_data_o              <= (others => '0');
        t_data_clk_o          <= '0';
        token_return_ctr      <= token_return_ctr;
        ch_status_cmd_tr      <= CS_NONE;

        case STATE is
          
          when S_IDLE =>
            if (TRIGGER_IN = '1') then
              busy_time_ctr   <= (others => '0');
              STATE           <= S_TRIGGER;
            else
              process_busy_o  <= '0';
              STATE           <= S_IDLE;
            end if;
            
          when S_TRIGGER =>
            ch_status_cmd_tr  <= CS_RESET;
            data_fifo_reset_o <= '1';
            wait_timer_init   <= x"020";    -- wait 320ns for first event
            STATE             <= S_WAIT_DATA;
            
          when S_WAIT_DATA =>
            if (wait_timer_done = '0') then
              STATE           <= S_WAIT_DATA;
            else
              STATE           <= S_PROCESS_START;
            end if;
            
          when S_PROCESS_START =>
            token_return_ctr  <= (others => '0');
            wait_timer_init   <= readout_time_max; 
            store_to_fifo     <= '1';
            STATE             <= S_WAIT_PROCESS_END;
            
          when S_WAIT_PROCESS_END =>
            if (wait_timer_done   = '1' or
                channel_all_done  = '1' or
                NX_NOMORE_DATA_IN = '1') then
              STATE           <= S_WRITE_TRAILER;
            else
              store_to_fifo   <= '1';
              STATE           <= S_WAIT_PROCESS_END;
              
              -- Check Token_Return
              if (readout_mode = x"0" and NX_TOKEN_RETURN_IN = '1') then
                if (token_return_ctr > 0) then
                  ch_status_cmd_tr <= CS_TOKEN_UPDATE;
                end if;
                token_return_ctr   <= token_return_ctr + 1;
              end if;
            end if;

          when S_WRITE_TRAILER =>
            t_data_o          <= x"deadaffe";
            t_data_clk_o      <= '1';
            ch_status_cmd_tr  <= CS_RESET;
            STATE             <= S_IDLE;
            
        end case;

        if (STATE /= S_IDLE) then
          busy_time_ctr   <= busy_time_ctr + 1;
        end if;      

      end if;
    end if;
  end process PROC_TRIGGER_HANDLER;
  
  -----------------------------------------------------------------------------
  -- TRBNet Slave Bus
  -----------------------------------------------------------------------------

  -- Give status info to the TRB Slow Control Channel
  PROC_FIFO_REGISTERS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o         <= (others => '0');
        slv_ack_o              <= '0';
        slv_unknown_addr_o     <= '0';
        slv_no_more_data_o     <= '0';
        readout_mode           <= "0000";
        trigger_window_delay   <= (others => '0');
        trigger_window_width   <= x"020";
        readout_time_max       <= x"640";
      else
        slv_data_out_o         <= (others => '0');
        slv_unknown_addr_o     <= '0';
        slv_no_more_data_o     <= '0';
        
        if (SLV_READ_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              slv_data_out_o(3 downto 0)   <= readout_mode;
              slv_data_out_o(31 downto 4)  <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0001" =>
              slv_data_out_o(11 downto 0)  <=
                std_logic_vector(trigger_window_delay);
              slv_data_out_o(31 downto 12) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0002" =>
              slv_data_out_o(11 downto 0)  <=
                std_logic_vector(trigger_window_width);
              slv_data_out_o(31 downto 12) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0003" =>
              slv_data_out_o(11 downto 0)  <=
                std_logic_vector(readout_time_max);
              slv_data_out_o(31 downto 12) <= (others => '0');
              slv_ack_o                    <= '1'; 

            when x"0004" =>
              slv_data_out_o(11 downto 0)  <=
                std_logic_vector(busy_time_ctr);
              slv_data_out_o(31 downto 12) <= (others => '0');
              slv_ack_o                    <= '1'; 

            when x"0005" =>
              slv_data_out_o               <=
                std_logic_vector(channel_done(31 downto 0));
              slv_ack_o                    <= '1'; 
            when x"0006" =>
              slv_data_out_o               <=
                std_logic_vector(channel_done(63 downto 32));
              slv_ack_o                    <= '1'; 
            when x"0007" =>
              slv_data_out_o               <=
                std_logic_vector(channel_done(95 downto 64));
              slv_ack_o                    <= '1'; 
            when x"0008" =>
              slv_data_out_o               <=
                std_logic_vector(channel_done(127 downto 96));
              slv_ack_o                    <= '1'; 

            when others  =>
              slv_unknown_addr_o           <= '1';
              slv_ack_o                    <= '0';

          end case;
          
        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              readout_mode                 <= SLV_DATA_IN(3 downto 0);
              slv_ack_o                    <= '1';

            when x"0001" =>
              trigger_window_delay         <= SLV_DATA_IN(11 downto 0);
              slv_ack_o                    <= '1';

            when x"0002" =>
              trigger_window_width         <=
                unsigned(SLV_DATA_IN(11 downto 0));
              slv_ack_o                    <= '1';

            when x"0003" =>
              readout_time_max             <=
                unsigned(SLV_DATA_IN(11 downto 0));
              slv_ack_o                    <= '1';
              
            when others  =>
              slv_unknown_addr_o           <= '1';
              slv_ack_o                    <= '0';
          end case;                
        else
          slv_ack_o <= '0';
        end if;
      end if;
    end if;
  end process PROC_FIFO_REGISTERS;
  
  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  PROCESS_BUSY_OUT      <= process_busy_o;
  DATA_OUT              <= data_o or t_data_o;
  DATA_CLK_OUT          <= data_clk_o or t_data_clk_o;
  DATA_FIFO_RESET_OUT   <= data_fifo_reset_o;
  
  -- Slave 
  SLV_DATA_OUT          <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT  <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT  <= slv_unknown_addr_o;
  SLV_ACK_OUT           <= slv_ack_o;


-------------------------------------------------------------------------------
-- Channel Sttaus Handler
-------------------------------------------------------------------------------
  PROC_CHANNEL_STATUS_CMD: process(ch_status_cmd_tr,
                                   ch_status_cmd_pr)
  begin
    if (ch_status_cmd_tr /= CS_NONE) then
      channel_status_cmd <= ch_status_cmd_tr;
    elsif (ch_status_cmd_pr /= CS_NONE) then
      channel_status_cmd <= ch_status_cmd_pr;
    else
      channel_status_cmd <= CS_NONE;
    end if;
  end process PROC_CHANNEL_STATUS_CMD;
  
  PROC_CHANNEL_STATUS: process(CLK_IN)
    constant all_one : unsigned(127 downto 0) := (others => '1');

  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1') then
        channel_wait     <= (others => '0');
        channel_done     <= (others => '0');
        channel_all_done <= '0';

      else
        -- Check done status
        if (channel_done = all_one) then
          channel_all_done <= '1';
        end if;

        -- Process Command
        case channel_status_cmd is

          when CS_RESET =>
            channel_wait      <= (others => '0');
            channel_done      <= (others => '0');
            channel_all_done  <= '0';

          when CS_TOKEN_UPDATE =>
            channel_done      <= channel_done or (not channel_wait);
            channel_wait      <= (others => '0');
            
          when CS_SET_WAIT =>
            case channel_index is

              when "0000000" => channel_wait(0)   <= '1';
              when "0000001" => channel_wait(1)   <= '1';
              when "0000010" => channel_wait(2)   <= '1';
              when "0000011" => channel_wait(3)   <= '1';
              when "0000100" => channel_wait(4)   <= '1';
              when "0000101" => channel_wait(5)   <= '1';
              when "0000110" => channel_wait(6)   <= '1';
              when "0000111" => channel_wait(7)   <= '1';
              when "0001000" => channel_wait(8)   <= '1';
              when "0001001" => channel_wait(9)   <= '1';
              when "0001010" => channel_wait(10)  <= '1';
              when "0001011" => channel_wait(11)  <= '1';
              when "0001100" => channel_wait(12)  <= '1';
              when "0001101" => channel_wait(13)  <= '1';
              when "0001110" => channel_wait(14)  <= '1';
              when "0001111" => channel_wait(15)  <= '1';
              when "0010000" => channel_wait(16)  <= '1';
              when "0010001" => channel_wait(17)  <= '1';
              when "0010010" => channel_wait(18)  <= '1';
              when "0010011" => channel_wait(19)  <= '1';
              when "0010100" => channel_wait(20)  <= '1';
              when "0010101" => channel_wait(21)  <= '1';
              when "0010110" => channel_wait(22)  <= '1';
              when "0010111" => channel_wait(23)  <= '1';
              when "0011000" => channel_wait(24)  <= '1';
              when "0011001" => channel_wait(25)  <= '1';
              when "0011010" => channel_wait(26)  <= '1';
              when "0011011" => channel_wait(27)  <= '1';
              when "0011100" => channel_wait(28)  <= '1';
              when "0011101" => channel_wait(29)  <= '1';
              when "0011110" => channel_wait(30)  <= '1';
              when "0011111" => channel_wait(31)  <= '1';
              when "0100000" => channel_wait(32)  <= '1';
              when "0100001" => channel_wait(33)  <= '1';
              when "0100010" => channel_wait(34)  <= '1';
              when "0100011" => channel_wait(35)  <= '1';
              when "0100100" => channel_wait(36)  <= '1';
              when "0100101" => channel_wait(37)  <= '1';
              when "0100110" => channel_wait(38)  <= '1';
              when "0100111" => channel_wait(39)  <= '1';
              when "0101000" => channel_wait(40)  <= '1';
              when "0101001" => channel_wait(41)  <= '1';
              when "0101010" => channel_wait(42)  <= '1';
              when "0101011" => channel_wait(43)  <= '1';
              when "0101100" => channel_wait(44)  <= '1';
              when "0101101" => channel_wait(45)  <= '1';
              when "0101110" => channel_wait(46)  <= '1';
              when "0101111" => channel_wait(47)  <= '1';
              when "0110000" => channel_wait(48)  <= '1';
              when "0110001" => channel_wait(49)  <= '1';
              when "0110010" => channel_wait(50)  <= '1';
              when "0110011" => channel_wait(51)  <= '1';
              when "0110100" => channel_wait(52)  <= '1';
              when "0110101" => channel_wait(53)  <= '1';
              when "0110110" => channel_wait(54)  <= '1';
              when "0110111" => channel_wait(55)  <= '1';
              when "0111000" => channel_wait(56)  <= '1';
              when "0111001" => channel_wait(57)  <= '1';
              when "0111010" => channel_wait(58)  <= '1';
              when "0111011" => channel_wait(59)  <= '1';
              when "0111100" => channel_wait(60)  <= '1';
              when "0111101" => channel_wait(61)  <= '1';
              when "0111110" => channel_wait(62)  <= '1';
              when "0111111" => channel_wait(63)  <= '1';
              when "1000000" => channel_wait(64)  <= '1';
              when "1000001" => channel_wait(65)  <= '1';
              when "1000010" => channel_wait(66)  <= '1';
              when "1000011" => channel_wait(67)  <= '1';
              when "1000100" => channel_wait(68)  <= '1';
              when "1000101" => channel_wait(69)  <= '1';
              when "1000110" => channel_wait(70)  <= '1';
              when "1000111" => channel_wait(71)  <= '1';
              when "1001000" => channel_wait(72)  <= '1';
              when "1001001" => channel_wait(73)  <= '1';
              when "1001010" => channel_wait(74)  <= '1';
              when "1001011" => channel_wait(75)  <= '1';
              when "1001100" => channel_wait(76)  <= '1';
              when "1001101" => channel_wait(77)  <= '1';
              when "1001110" => channel_wait(78)  <= '1';
              when "1001111" => channel_wait(79)  <= '1';
              when "1010000" => channel_wait(80)  <= '1';
              when "1010001" => channel_wait(81)  <= '1';
              when "1010010" => channel_wait(82)  <= '1';
              when "1010011" => channel_wait(83)  <= '1';
              when "1010100" => channel_wait(84)  <= '1';
              when "1010101" => channel_wait(85)  <= '1';
              when "1010110" => channel_wait(86)  <= '1';
              when "1010111" => channel_wait(87)  <= '1';
              when "1011000" => channel_wait(88)  <= '1';
              when "1011001" => channel_wait(89)  <= '1';
              when "1011010" => channel_wait(90)  <= '1';
              when "1011011" => channel_wait(91)  <= '1';
              when "1011100" => channel_wait(92)  <= '1';
              when "1011101" => channel_wait(93)  <= '1';
              when "1011110" => channel_wait(94)  <= '1';
              when "1011111" => channel_wait(95)  <= '1';
              when "1100000" => channel_wait(96)  <= '1';
              when "1100001" => channel_wait(97)  <= '1';
              when "1100010" => channel_wait(98)  <= '1';
              when "1100011" => channel_wait(99)  <= '1';
              when "1100100" => channel_wait(100) <= '1';
              when "1100101" => channel_wait(101) <= '1';
              when "1100110" => channel_wait(102) <= '1';
              when "1100111" => channel_wait(103) <= '1';
              when "1101000" => channel_wait(104) <= '1';
              when "1101001" => channel_wait(105) <= '1';
              when "1101010" => channel_wait(106) <= '1';
              when "1101011" => channel_wait(107) <= '1';
              when "1101100" => channel_wait(108) <= '1';
              when "1101101" => channel_wait(109) <= '1';
              when "1101110" => channel_wait(110) <= '1';
              when "1101111" => channel_wait(111) <= '1';
              when "1110000" => channel_wait(112) <= '1';
              when "1110001" => channel_wait(113) <= '1';
              when "1110010" => channel_wait(114) <= '1';
              when "1110011" => channel_wait(115) <= '1';
              when "1110100" => channel_wait(116) <= '1';
              when "1110101" => channel_wait(117) <= '1';
              when "1110110" => channel_wait(118) <= '1';
              when "1110111" => channel_wait(119) <= '1';
              when "1111000" => channel_wait(120) <= '1';
              when "1111001" => channel_wait(121) <= '1';
              when "1111010" => channel_wait(122) <= '1';
              when "1111011" => channel_wait(123) <= '1';
              when "1111100" => channel_wait(124) <= '1';
              when "1111101" => channel_wait(125) <= '1';
              when "1111110" => channel_wait(126) <= '1';
              when "1111111" => channel_wait(127) <= '1';
                                
            end case;
            
          when CS_SET_DONE =>
            case channel_index is

              when "0000000" => channel_done(0)   <= '1';
              when "0000001" => channel_done(1)   <= '1';
              when "0000010" => channel_done(2)   <= '1';
              when "0000011" => channel_done(3)   <= '1';
              when "0000100" => channel_done(4)   <= '1';
              when "0000101" => channel_done(5)   <= '1';
              when "0000110" => channel_done(6)   <= '1';
              when "0000111" => channel_done(7)   <= '1';
              when "0001000" => channel_done(8)   <= '1';
              when "0001001" => channel_done(9)   <= '1';
              when "0001010" => channel_done(10)  <= '1';
              when "0001011" => channel_done(11)  <= '1';
              when "0001100" => channel_done(12)  <= '1';
              when "0001101" => channel_done(13)  <= '1';
              when "0001110" => channel_done(14)  <= '1';
              when "0001111" => channel_done(15)  <= '1';
              when "0010000" => channel_done(16)  <= '1';
              when "0010001" => channel_done(17)  <= '1';
              when "0010010" => channel_done(18)  <= '1';
              when "0010011" => channel_done(19)  <= '1';
              when "0010100" => channel_done(20)  <= '1';
              when "0010101" => channel_done(21)  <= '1';
              when "0010110" => channel_done(22)  <= '1';
              when "0010111" => channel_done(23)  <= '1';
              when "0011000" => channel_done(24)  <= '1';
              when "0011001" => channel_done(25)  <= '1';
              when "0011010" => channel_done(26)  <= '1';
              when "0011011" => channel_done(27)  <= '1';
              when "0011100" => channel_done(28)  <= '1';
              when "0011101" => channel_done(29)  <= '1';
              when "0011110" => channel_done(30)  <= '1';
              when "0011111" => channel_done(31)  <= '1';
              when "0100000" => channel_done(32)  <= '1';
              when "0100001" => channel_done(33)  <= '1';
              when "0100010" => channel_done(34)  <= '1';
              when "0100011" => channel_done(35)  <= '1';
              when "0100100" => channel_done(36)  <= '1';
              when "0100101" => channel_done(37)  <= '1';
              when "0100110" => channel_done(38)  <= '1';
              when "0100111" => channel_done(39)  <= '1';
              when "0101000" => channel_done(40)  <= '1';
              when "0101001" => channel_done(41)  <= '1';
              when "0101010" => channel_done(42)  <= '1';
              when "0101011" => channel_done(43)  <= '1';
              when "0101100" => channel_done(44)  <= '1';
              when "0101101" => channel_done(45)  <= '1';
              when "0101110" => channel_done(46)  <= '1';
              when "0101111" => channel_done(47)  <= '1';
              when "0110000" => channel_done(48)  <= '1';
              when "0110001" => channel_done(49)  <= '1';
              when "0110010" => channel_done(50)  <= '1';
              when "0110011" => channel_done(51)  <= '1';
              when "0110100" => channel_done(52)  <= '1';
              when "0110101" => channel_done(53)  <= '1';
              when "0110110" => channel_done(54)  <= '1';
              when "0110111" => channel_done(55)  <= '1';
              when "0111000" => channel_done(56)  <= '1';
              when "0111001" => channel_done(57)  <= '1';
              when "0111010" => channel_done(58)  <= '1';
              when "0111011" => channel_done(59)  <= '1';
              when "0111100" => channel_done(60)  <= '1';
              when "0111101" => channel_done(61)  <= '1';
              when "0111110" => channel_done(62)  <= '1';
              when "0111111" => channel_done(63)  <= '1';
              when "1000000" => channel_done(64)  <= '1';
              when "1000001" => channel_done(65)  <= '1';
              when "1000010" => channel_done(66)  <= '1';
              when "1000011" => channel_done(67)  <= '1';
              when "1000100" => channel_done(68)  <= '1';
              when "1000101" => channel_done(69)  <= '1';
              when "1000110" => channel_done(70)  <= '1';
              when "1000111" => channel_done(71)  <= '1';
              when "1001000" => channel_done(72)  <= '1';
              when "1001001" => channel_done(73)  <= '1';
              when "1001010" => channel_done(74)  <= '1';
              when "1001011" => channel_done(75)  <= '1';
              when "1001100" => channel_done(76)  <= '1';
              when "1001101" => channel_done(77)  <= '1';
              when "1001110" => channel_done(78)  <= '1';
              when "1001111" => channel_done(79)  <= '1';
              when "1010000" => channel_done(80)  <= '1';
              when "1010001" => channel_done(81)  <= '1';
              when "1010010" => channel_done(82)  <= '1';
              when "1010011" => channel_done(83)  <= '1';
              when "1010100" => channel_done(84)  <= '1';
              when "1010101" => channel_done(85)  <= '1';
              when "1010110" => channel_done(86)  <= '1';
              when "1010111" => channel_done(87)  <= '1';
              when "1011000" => channel_done(88)  <= '1';
              when "1011001" => channel_done(89)  <= '1';
              when "1011010" => channel_done(90)  <= '1';
              when "1011011" => channel_done(91)  <= '1';
              when "1011100" => channel_done(92)  <= '1';
              when "1011101" => channel_done(93)  <= '1';
              when "1011110" => channel_done(94)  <= '1';
              when "1011111" => channel_done(95)  <= '1';
              when "1100000" => channel_done(96)  <= '1';
              when "1100001" => channel_done(97)  <= '1';
              when "1100010" => channel_done(98)  <= '1';
              when "1100011" => channel_done(99)  <= '1';
              when "1100100" => channel_done(100) <= '1';
              when "1100101" => channel_done(101) <= '1';
              when "1100110" => channel_done(102) <= '1';
              when "1100111" => channel_done(103) <= '1';
              when "1101000" => channel_done(104) <= '1';
              when "1101001" => channel_done(105) <= '1';
              when "1101010" => channel_done(106) <= '1';
              when "1101011" => channel_done(107) <= '1';
              when "1101100" => channel_done(108) <= '1';
              when "1101101" => channel_done(109) <= '1';
              when "1101110" => channel_done(110) <= '1';
              when "1101111" => channel_done(111) <= '1';
              when "1110000" => channel_done(112) <= '1';
              when "1110001" => channel_done(113) <= '1';
              when "1110010" => channel_done(114) <= '1';
              when "1110011" => channel_done(115) <= '1';
              when "1110100" => channel_done(116) <= '1';
              when "1110101" => channel_done(117) <= '1';
              when "1110110" => channel_done(118) <= '1';
              when "1110111" => channel_done(119) <= '1';
              when "1111000" => channel_done(120) <= '1';
              when "1111001" => channel_done(121) <= '1';
              when "1111010" => channel_done(122) <= '1';
              when "1111011" => channel_done(123) <= '1';
              when "1111100" => channel_done(124) <= '1';
              when "1111101" => channel_done(125) <= '1';
              when "1111110" => channel_done(126) <= '1';
              when "1111111" => channel_done(127) <= '1';
            end case;

          when others => null;

        end case;
      end if;
    end if;
  end process PROC_CHANNEL_STATUS;


end Behavioral;
