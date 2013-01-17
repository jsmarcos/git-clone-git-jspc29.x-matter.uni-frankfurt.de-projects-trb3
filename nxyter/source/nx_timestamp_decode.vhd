library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.nxyter_components.all;

entity nx_timestamp_decode is
  port (
    CLK_IN               : in  std_logic;  
    RESET_IN             : in  std_logic;

    -- Inputs
    NX_NEW_TIMESTAMP_IN  : in  std_logic;
    NX_TIMESTAMP_IN      : in  std_logic_vector(31 downto 0);
    TIMESTAMP_REF_IN     : in  unsigned(11 downto 0);

    -- Outputs
    TIMESTAMP_DATA_OUT   : out std_logic_vector(31 downto 0);
    TIMESTAMP_VALID_OUT  : out std_logic;
    NX_TOKEN_RETURN      : out std_logic;
    NX_NOMORE_DATA       : out std_logic;

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

architecture Behavioral of nx_timestamp_decode is
  
  -- Sync Ref
  signal timestamp_ref_x      : unsigned(11 downto 0);
  signal timestamp_ref        : unsigned(11 downto 0);

  -- Gray Decoder
  signal nx_timestamp         : std_logic_vector(13 downto 0);
  signal nx_channel_id        : std_logic_vector( 6 downto 0);

  -- TIMESTAMP_BITS
  signal new_timestamp        : std_logic;
  signal valid_frame_bits     : std_logic_vector(3 downto 0);
  signal status_bits          : std_logic_vector(1 downto 0);
  signal parity_bit           : std_logic;
  signal parity               : std_logic;
  signal timstamp_raw         : std_logic_vector(31 downto 0);
  
  -- Validate Timestamp
  signal timestamp_data_o     : std_logic_vector(31 downto 0);
  signal timestamp_valid_o    : std_logic;
  signal nx_token_return_o    : std_logic;
  signal nx_nomore_data_o     : std_logic;
  signal nx_data_notvalid_ctr : unsigned(1 downto 0);
  signal invalid_frame_ctr    : unsigned(15 downto 0);
  signal overflow_ctr         : unsigned(15 downto 0);
  signal pileup_ctr           : unsigned(15 downto 0);
  signal parity_error_ctr     : unsigned(15 downto 0);
  
  -- Config
  signal readout_type         : std_logic_vector(1 downto 0);

  -- Slave Bus                    
  signal slv_data_out_o       : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o   : std_logic;
  signal slv_unknown_addr_o   : std_logic;
  signal slv_ack_o            : std_logic;
  signal clear_counters       : std_logic;
  signal trigger_window_width : unsigned(13 downto 0);
  signal trigger_window_delay : unsigned(13 downto 0);
  signal readout_mode         : std_logic_vector(1 downto 0);

begin

  -- Debug Line
  DEBUG_OUT(0)                    <= CLK_IN;
  DEBUG_OUT(1)                    <= NX_NEW_TIMESTAMP_IN;
  DEBUG_OUT(2)                    <= TIMESTAMP_VALID_OUT;
  DEBUG_OUT(3)                    <= new_timestamp;
  DEBUG_OUT(5 downto 4)           <= status_bits;

  DEBUG_OUT(6)                    <= parity;
  DEBUG_OUT(7)                    <= '0';
  
  DEBUG_OUT(14 downto 8)          <= nx_channel_id;
  DEBUG_OUT(15)                   <= '0';
  
  -----------------------------------------------------------------------------
  -- Gray Decoder for Timestamp and Chgannel Id
  -----------------------------------------------------------------------------

  Gray_Decoder_1: Gray_Decoder          -- Decode nx_timestamp
    generic map (
      WIDTH => 14
      )
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,
      GRAY_IN(13 downto 7) => not NX_TIMESTAMP_IN(30 downto 24),
      GRAY_IN( 6 downto 0) => not NX_TIMESTAMP_IN(22 downto 16),
      BINARY_OUT           => nx_timestamp
      );

  Gray_Decoder_2: Gray_Decoder          -- Decode Channel_ID
    generic map (
      WIDTH => 7
      )
    port map (
      CLK_IN     => CLK_IN,
      RESET_IN   => RESET_IN,
      GRAY_IN    => NX_TIMESTAMP_IN(14 downto 8),
      BINARY_OUT => nx_channel_id
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
  
  -- Separate Status-, Parity- and Frame-bits, calculate parity
  PROC_TIMESTAMP_BITS: process (CLK_IN)
    variable parity_bits : std_logic_vector(22 downto 0);
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        valid_frame_bits    <= (others => '0');
        status_bits         <= (others => '0');
        parity_bit          <= '0';
        parity              <= '0';
        new_timestamp       <= '0';
        timstamp_raw        <= (others => '0');
      else
        -- Timestamp Bit #6 is excluded (funny nxyter-bug)
        parity_bits         := NX_TIMESTAMP_IN(31 downto 24) &
                               NX_TIMESTAMP_IN(21 downto 16) &
                               NX_TIMESTAMP_IN(14 downto  8) &
                               NX_TIMESTAMP_IN( 2 downto  1);
        valid_frame_bits    <= (others => '0');
        status_bits         <= (others => '0');
        parity_bit          <= '0';
        parity              <= '0';
        new_timestamp       <= '0';
        timstamp_raw        <= (others => '0');
        
        if (NX_NEW_TIMESTAMP_IN = '1') then
          valid_frame_bits(3) <= NX_TIMESTAMP_IN(31);
          valid_frame_bits(2) <= NX_TIMESTAMP_IN(23);
          valid_frame_bits(1) <= NX_TIMESTAMP_IN(15);
          valid_frame_bits(0) <= NX_TIMESTAMP_IN(7);
          status_bits         <= NX_TIMESTAMP_IN(2 downto 1);
          parity_bit          <= NX_TIMESTAMP_IN(0);
          parity              <= xor_all(parity_bits);
          timstamp_raw        <= NX_TIMESTAMP_IN;
          new_timestamp       <= '1';
        end if;
      end if;
    end if;
  end process PROC_TIMESTAMP_BITS;    

  -----------------------------------------------------------------------------
  -- Filter only valid events
  -----------------------------------------------------------------------------

  PROC_VALIDATE_TIMESTAMP: process (CLK_IN)
    variable ref    : unsigned(13 downto 0);
    variable deltaT : unsigned(13 downto 0);
  begin 
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        timestamp_data_o     <= (others => '0');
        timestamp_valid_o    <= '0';
        nx_token_return_o    <= '0';
        nx_nomore_data_o     <= '1';
        nx_data_notvalid_ctr <= (others => '0');
        invalid_frame_ctr    <= (others => '0');
        overflow_ctr         <= (others => '0');
        pileup_ctr           <= (others => '0');
        parity_error_ctr     <= (others => '0');
      else
        timestamp_data_o(31 downto 0)  <= (others => '0');
        timestamp_valid_o              <= '0';
        nx_token_return_o              <= '0';
        nx_nomore_data_o               <= '0';
    
        if (new_timestamp = '1') then
          case valid_frame_bits is
            when "1000" =>
              ---- Check Overflow
              if (status_bits(0) = '1') then
                if (clear_counters = '0') then
                  overflow_ctr <= overflow_ctr + 1;
                end if;
              end if;

              ---- Check Parity
              if ((parity_bit /= parity) and (clear_counters = '0')) then
                parity_error_ctr <= parity_error_ctr + 1;
              end if;

              -- Check PileUp
              if ((status_bits(1) = '1') and (clear_counters = '0')) then
                pileup_ctr <= pileup_ctr + 1;
              end if;
              
              -- Take Timestamp
              ref                 := timestamp_ref & "00";
              deltaT              := ref - unsigned(nx_timestamp);
              
              case readout_mode is
                
                when "00" => 
                  -- Raw
                  timestamp_data_o(13 downto  0)   <= nx_timestamp;  
                  timestamp_valid_o                <= '1';
                
                when "01" =>
                  -- Ref
                  timestamp_data_o(13 downto  0)   <= std_logic_vector(deltaT);
                  timestamp_valid_o                <= '1';

                when "10" =>
                  -- Trigger Window
                  if ((deltaT < trigger_window_delay) and
                      (deltaT > (trigger_window_delay - trigger_window_width)))
                  then
                    timestamp_data_o(13 downto  0) <= std_logic_vector(deltaT);
                    timestamp_valid_o              <= '1';
                  end if;

                when others => null;
              end case;
              
              timestamp_data_o(15 downto 14) <= (others => '0');
              timestamp_data_o(22 downto 16) <= nx_channel_id;
              timestamp_data_o(23)           <= '0';
              timestamp_data_o(24)           <= parity_bit;
              timestamp_data_o(25)           <= parity;
              timestamp_data_o(29 downto 26) <= (others => '0');
              timestamp_data_o(31 downto 30) <= status_bits;

              nx_data_notvalid_ctr           <= (others => '0');
                
            when "0000" =>
              case nx_data_notvalid_ctr is
                when "00"   =>
                  nx_token_return_o    <= '1';
                  nx_data_notvalid_ctr <= nx_data_notvalid_ctr + 1;
                when "01"   =>
                  nx_nomore_data_o     <= '1';
                  nx_data_notvalid_ctr <= nx_data_notvalid_ctr + 1;
                when others => null;
              end case;
              
            when others =>
              -- Invalid frame, not empty, discard timestamp
              if (clear_counters = '0') then
                invalid_frame_ctr <= invalid_frame_ctr + 1;
              end if;
          end case;
        end if;

        -- Reset Counters
        if (clear_counters = '1') then
          invalid_frame_ctr   <= (others => '0');
          overflow_ctr        <= (others => '0');
          pileup_ctr          <= (others => '0');
          parity_error_ctr    <= (others => '0');
        end if;
      end if;
    end if;
  end process PROC_VALIDATE_TIMESTAMP;

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
        readout_mode           <= "00";
        clear_counters         <= '0';
        trigger_window_width   <= (others => '0');
        trigger_window_delay   <= (others => '0');
      else
        slv_data_out_o         <= (others => '0');
        slv_unknown_addr_o     <= '0';
        slv_no_more_data_o     <= '0';
        clear_counters         <= '0';
        
        if (SLV_READ_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              slv_data_out_o(1 downto 0)   <= readout_mode;
              slv_data_out_o(31 downto 2)  <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0001" =>
              slv_data_out_o(13 downto 0)            <=
                std_logic_vector(trigger_window_width);
              slv_data_out_o(31 downto 14) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0002" =>
              slv_data_out_o(13 downto 0)            <=
                std_logic_vector(trigger_window_delay);
              slv_data_out_o(31 downto 14) <= (others => '0');
              slv_ack_o                    <= '1'; 
              
            when x"000a" =>
              slv_data_out_o(15 downto 0)  <=
                std_logic_vector(invalid_frame_ctr);
              slv_data_out_o(31 downto 16) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"000b" =>
              slv_data_out_o(15 downto 0)  <=
                std_logic_vector(overflow_ctr);
              slv_data_out_o(31 downto 16) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"000c" =>
              slv_data_out_o(15 downto 0)  <=
                std_logic_vector(pileup_ctr);
              slv_data_out_o(31 downto 16) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"000d" =>
              slv_data_out_o(15 downto 0)  <=
                std_logic_vector(parity_error_ctr);
              slv_data_out_o(31 downto 16) <= (others => '0');
              slv_ack_o                    <= '1';
              
            when others  =>
              slv_unknown_addr_o           <= '1';
              slv_ack_o                    <= '0';
          end case;
          
        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              readout_mode                 <= SLV_DATA_IN(1 downto 0);
              slv_ack_o                    <= '1';

            when x"0001" =>
              trigger_window_width         <=
                unsigned(SLV_DATA_IN(13 downto 0));
              slv_ack_o                    <= '1';

            when x"0002" =>
              trigger_window_delay         <=
                unsigned(SLV_DATA_IN(13 downto 0));
              slv_ack_o                    <= '1'; 

            when x"000f" =>
              clear_counters               <= '1';
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

  TIMESTAMP_DATA_OUT    <= timestamp_data_o;
  TIMESTAMP_VALID_OUT   <= timestamp_valid_o;
  NX_TOKEN_RETURN       <= nx_token_return_o;
  NX_NOMORE_DATA        <= nx_nomore_data_o;
  
  -- Slave 
  SLV_DATA_OUT          <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT  <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT  <= slv_unknown_addr_o;
  SLV_ACK_OUT           <= slv_ack_o;
end Behavioral;
