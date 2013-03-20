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

    -- Outputs
    TIMESTAMP_OUT        : out unsigned(13 downto 0);
    CHANNEL_OUT          : out unsigned(6 downto 0);
    TIMESTAMP_STATUS_OUT : out std_logic_vector(1 downto 0);
    TIMESTAMP_VALID_OUT  : out std_logic;
    NX_TOKEN_RETURN_OUT  : out std_logic;
    NX_NOMORE_DATA_OUT   : out std_logic;

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
  signal timestamp_o          : unsigned(13 downto 0);
  signal channel_o            : unsigned(6 downto 0);
  signal timestamp_status_o   : std_logic_vector(1 downto 0);
  signal timestamp_valid_o    : std_logic;

  signal nx_notempty_ctr      : unsigned (1 downto 0);  
  signal nx_token_return_o    : std_logic;
  signal nx_nomore_data_o     : std_logic;
  
  signal invalid_frame_ctr    : unsigned(15 downto 0);
  signal overflow_ctr         : unsigned(15 downto 0);
  signal pileup_ctr           : unsigned(15 downto 0);
  signal parity_error_ctr     : unsigned(15 downto 0);
  signal nx_valid_ctr         : unsigned(19 downto 0);
  signal nx_rate_timer        : unsigned(19 downto 0);

  -- Config
  signal readout_type         : std_logic_vector(1 downto 0);

  -- Slave Bus                    
  signal slv_data_out_o       : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o   : std_logic;
  signal slv_unknown_addr_o   : std_logic;
  signal slv_ack_o            : std_logic;
  signal clear_counters       : std_logic;
  signal nx_trigger_rate      : unsigned(19 downto 0);

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
  begin 
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        timestamp_o          <= (others => '0');
        channel_o            <= (others => '0');
        timestamp_status_o   <= (others => '0');
        timestamp_valid_o    <= '0';
        nx_notempty_ctr      <= (others => '0');
        nx_token_return_o    <= '0';
        nx_nomore_data_o     <= '1';

        invalid_frame_ctr    <= (others => '0');
        overflow_ctr         <= (others => '0');
        pileup_ctr           <= (others => '0');
        parity_error_ctr     <= (others => '0');
        nx_valid_ctr         <= (others => '0');
        nx_trigger_rate      <= (others => '0');
        nx_rate_timer        <= (others => '0');
      else
        timestamp_o          <= (others => '0');
        channel_o            <= (others => '0');
        timestamp_status_o   <= (others => '0');
        timestamp_valid_o    <= '0';
        nx_token_return_o    <= '0';
        nx_nomore_data_o     <= '0';
    
        if (new_timestamp = '1') then
          case valid_frame_bits is
            when "1000" =>
              ---- Check Overflow
              if ((status_bits(0) = '1') and (clear_counters = '0')) then
                overflow_ctr <= overflow_ctr + 1;
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
              timestamp_o          <= unsigned(nx_timestamp);
              channel_o            <= unsigned(nx_channel_id);
              timestamp_status_o   <= status_bits;
              timestamp_valid_o    <= '1';
              
              nx_notempty_ctr      <= (others => '0');

              -- Rate Counter
              if (nx_rate_timer < x"186a0") then
                nx_valid_ctr  <= nx_valid_ctr + 1;
              end if;
                
            when "0000" =>
              case nx_notempty_ctr is
                when "00"   =>
                  nx_token_return_o <= '1';
                  nx_notempty_ctr   <= nx_notempty_ctr + 1;

                when "01"   =>
                  nx_nomore_data_o  <= '1';
                  nx_notempty_ctr   <= nx_notempty_ctr + 1;
                  
                when others => null;
              end case;
              
            when others =>
              -- Invalid frame, not empty, discard timestamp
              if (clear_counters = '0') then
                invalid_frame_ctr <= invalid_frame_ctr + 1;
              end if;
              nx_notempty_ctr      <= (others => '0');
          end case;
        end if;

        -- Trigger Rate
        if (nx_rate_timer < x"186a0") then
          nx_rate_timer   <= nx_rate_timer + 1;
        else
          nx_rate_timer   <= (others => '0');
          nx_trigger_rate <= nx_valid_ctr;
          nx_valid_ctr    <= (others => '0');
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
        clear_counters         <= '0';
      else
        slv_data_out_o         <= (others => '0');
        slv_unknown_addr_o     <= '0';
        slv_no_more_data_o     <= '0';
        clear_counters         <= '0';
        
        if (SLV_READ_IN  = '1') then
          case SLV_ADDR_IN is

            when x"0000" =>
              slv_data_out_o(15 downto 0)  <=
                std_logic_vector(invalid_frame_ctr);
              slv_data_out_o(31 downto 16) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0001" =>
              slv_data_out_o(15 downto 0)  <=
                std_logic_vector(overflow_ctr);
              slv_data_out_o(31 downto 16) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0002" =>
              slv_data_out_o(15 downto 0)  <=
                std_logic_vector(pileup_ctr);
              slv_data_out_o(31 downto 16) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0003" =>
              slv_data_out_o(15 downto 0)  <=
                std_logic_vector(parity_error_ctr);
              slv_data_out_o(31 downto 16) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0004" =>
              slv_data_out_o(19 downto 0)  <=
                std_logic_vector(nx_trigger_rate);
              slv_data_out_o(31 downto 20) <= (others => '0');
              slv_ack_o                    <= '1';
              
            when others  =>
              slv_unknown_addr_o           <= '1';
              slv_ack_o                    <= '0';
          end case;
          
        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
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

  TIMESTAMP_OUT         <= timestamp_o;
  CHANNEL_OUT           <= channel_o;
  TIMESTAMP_STATUS_OUT  <= timestamp_status_o;
  TIMESTAMP_VALID_OUT   <= timestamp_valid_o;
  NX_TOKEN_RETURN_OUT   <= nx_token_return_o;
  NX_NOMORE_DATA_OUT    <= nx_nomore_data_o;
  
  -- Slave 
  SLV_DATA_OUT          <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT  <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT  <= slv_unknown_addr_o;
  SLV_ACK_OUT           <= slv_ack_o;
end Behavioral;
