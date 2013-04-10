library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.nxyter_components.all;

entity nx_timestamp_fifo_read is
  port(
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
     
    -- nXyter Timestamp Ports
    NX_TIMESTAMP_CLK_IN  : in std_logic;
    NX_TIMESTAMP_IN      : in std_logic_vector (7 downto 0);
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
  signal nx_timestamp_reg_t       : std_logic_vector(7 downto 0);
  signal nx_timestamp_reg         : std_logic_vector(7 downto 0);
  signal fifo_full                : std_logic;
  signal fifo_reset               : std_logic;
  
  -- NX_TIMESTAMP_IN Process
  signal frame_byte_ctr           : unsigned(1 downto 0);
  signal fifo_32bit_word          : std_logic_vector(31 downto 0);
  signal nx_new_frame             : std_logic;

  -- Frame Sync Process                 
  signal frame_byte_pos           : unsigned(1 downto 0);

  -- RS Sync FlipFlop
  signal nx_frame_synced          : std_logic;
  signal rs_sync_set              : std_logic;
  signal rs_sync_reset            : std_logic;

  -- Parity Check
  signal parity_error             : std_logic;

  -- Write to FIFO Handler
  signal fifo_data_input          : std_logic_vector(31 downto 0);
  signal fifo_write_enable        : std_logic;

  -----------------------------------------------------------------------------
  -- CLK_IN Domain
  -----------------------------------------------------------------------------

  -- PROC FIFO_READ
  signal nx_new_timestamp_o       : std_logic;
  signal register_fifo_data       : std_logic_vector(31 downto 0);

  signal fifo_almost_empty_tt     : std_logic;
  signal fifo_almost_empty_t      : std_logic;

  
  -- FIFO Output Handler
  signal fifo_out                 : std_logic_vector(31 downto 0);
  signal fifo_empty               : std_logic;
  signal fifo_almost_empty        : std_logic;
  signal fifo_read_enable         : std_logic;
  signal fifo_data_valid_t        : std_logic;
  signal fifo_data_valid          : std_logic;
  signal read_enable_pause        : std_logic;

  -- Resync Counter Process                 
  signal resync_counter           : unsigned(11 downto 0);
  signal resync_ctr_inc           : std_logic;
  signal nx_clk_active            : std_logic;
  
  -- Parity Error Counter Process                 
  signal parity_error_counter     : unsigned(11 downto 0);
  signal parity_error_ctr_inc     : std_logic;

  signal reg_nx_frame_synced_t    : std_logic;
  signal reg_nx_frame_synced      : std_logic;
  
  -- Slave Bus                    
  signal slv_data_out_o           : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o       : std_logic;
  signal slv_unknown_addr_o       : std_logic;
  signal slv_ack_o                : std_logic;

  signal reset_resync_ctr         : std_logic;
  signal reset_parity_error_ctr   : std_logic;
  signal fifo_delay_r             : std_logic_vector(5 downto 0);
  signal fifo_reset_r             : std_logic;

begin

  DEBUG_OUT(0)            <= NX_TIMESTAMP_CLK_IN;
  DEBUG_OUT(1)            <= parity_error;
  DEBUG_OUT(2)            <= nx_new_frame;
  DEBUG_OUT(3)            <= rs_sync_set;
  DEBUG_OUT(4)            <= rs_sync_reset;
  DEBUG_OUT(5)            <= nx_frame_synced;
  DEBUG_OUT(7 downto 6)   <= frame_byte_pos;

  DEBUG_OUT(8)            <= fifo_write_enable;
  DEBUG_OUT(9)            <= fifo_read_enable;
  DEBUG_OUT(10)           <= nx_new_timestamp_o;
  DEBUG_OUT(11)           <= fifo_data_valid;
  DEBUG_OUT(12)           <= nx_clk_active;
  DEBUG_OUT(13)           <= resync_ctr_inc;
  DEBUG_OUT(14)           <= parity_error_ctr_inc;
  DEBUG_OUT(15)           <= reg_nx_frame_synced;
  


--DEBUG_OUT(15 downto 8)  <= fifo_32bit_word(15 downto 8);


--  DEBUG_OUT(6)            <= nx_new_timestamp_o;
--  DEBUG_OUT(7)            <= fifo_almost_empty;
--  DEBUG_OUT(8)            <= nx_frame_synced;
--  DEBUG_OUT(9)            <= rs_sync_reset;
--  DEBUG_OUT(11 downto 10) <= frame_tag_pos;
--  DEBUG_OUT(12)           <= fifo_full;
--  DEBUG_OUT(15 downto 13) <= (others => '0');


  --DEBUG_OUT(8 downto 1)   <= fifo_out(7 downto 0); --nx_timestamp_reg_t when rising_edge(NX_TIMESTAMP_CLK_IN) ;  
  
  -----------------------------------------------------------------------------
  -- NX_TIMESTAMP_CLK_IN Domain
  -----------------------------------------------------------------------------

  nx_timestamp_reg   <= NX_TIMESTAMP_IN when rising_edge(NX_TIMESTAMP_CLK_IN);

  -- Transfer 8 to 32Bit 
  PROC_8_TO_32_BIT: process(NX_TIMESTAMP_CLK_IN)
  begin
    if( rising_edge(NX_TIMESTAMP_CLK_IN) ) then
      if( RESET_IN = '1' ) then
        frame_byte_ctr   <= (others => '0');
        fifo_32bit_word  <= (others => '0');
        nx_new_frame     <= '0';
      else
        nx_new_frame     <= '0';
        
        case frame_byte_pos is
          when "11" => fifo_32bit_word(31 downto 24) <= nx_timestamp_reg;
                       frame_byte_ctr                <= frame_byte_ctr + 1;
                       
          when "10" => fifo_32bit_word(23 downto 16) <= nx_timestamp_reg;
                       frame_byte_ctr                <= frame_byte_ctr + 1;
                                                
          when "01" => fifo_32bit_word(15 downto  8) <= nx_timestamp_reg;
                       frame_byte_ctr                <= frame_byte_ctr + 1;
                         
          when "00" => fifo_32bit_word( 7 downto  0) <= nx_timestamp_reg;
                       if (frame_byte_ctr = "11") then
                         nx_new_frame   <= '1';
                       end if;
                       frame_byte_ctr   <= (others => '0'); 
        end case;
      end if;
    end if;
  end process PROC_8_TO_32_BIT;
  
  -- Frame Sync process
  PROC_SYNC_TO_NX_FRAME: process(NX_TIMESTAMP_CLK_IN)
  begin
    if( rising_edge(NX_TIMESTAMP_CLK_IN) ) then
      if( RESET_IN = '1' ) then
        frame_byte_pos   <= "11";
        rs_sync_set      <= '0';
        rs_sync_reset    <= '0';
      else
        rs_sync_set       <= '0';
        rs_sync_reset     <= '0';
        if (nx_new_frame = '1') then
          case fifo_32bit_word is
            when x"7f7f7f06" =>
              rs_sync_set         <= '1';      
              frame_byte_pos      <= frame_byte_pos - 1;
              
            when x"7f7f067f" =>
              rs_sync_reset       <= '1';
              frame_byte_pos      <= frame_byte_pos - 2;
              
            when x"7f067f7f" =>
              rs_sync_reset       <= '1';
              frame_byte_pos      <= frame_byte_pos - 3;
              
            when x"067f7f7f" =>
              rs_sync_reset       <= '1';        
              frame_byte_pos      <= frame_byte_pos - 4;
              
            when others =>
              frame_byte_pos      <= frame_byte_pos - 1;
          end case;
        else
          frame_byte_pos          <= frame_byte_pos - 1;
        end if;
      end if;
    end if;
  end process PROC_SYNC_TO_NX_FRAME;

  -- RS FlipFlop to hold Sync Status
  PROC_RS_FRAME_SYNCED: process(NX_TIMESTAMP_CLK_IN)
  begin
    if( rising_edge(NX_TIMESTAMP_CLK_IN) ) then
      if (RESET_IN = '1' or rs_sync_reset = '1') then
        nx_frame_synced <= '0';
      elsif (rs_sync_set = '1') then
        nx_frame_synced <= '1';
      end if;
    end if;
  end process PROC_RS_FRAME_SYNCED;

  -- Check Parity
  PROC_PARITY_CHECK: process(NX_TIMESTAMP_CLK_IN)
    variable parity_bits : std_logic_vector(22 downto 0);
    variable parity      : std_logic;
  begin
    if( rising_edge(NX_TIMESTAMP_CLK_IN) ) then
      if (RESET_IN = '1') then
        parity_error   <= '0';
      else
        parity_error   <= '0';
        if (nx_new_frame = '1' and nx_frame_synced = '1') then
          -- Timestamp Bit #6 is excluded (funny nxyter-bug)
          parity_bits         := fifo_32bit_word(31 downto 24) &
                                 fifo_32bit_word(21 downto 16) &
                                 fifo_32bit_word(14 downto  8) &
                                 fifo_32bit_word( 2 downto  1);
          parity              := xor_all(parity_bits);

          if (parity /= fifo_32bit_word(0)) then
            parity_error   <= '1';
          end if;
        end if;
      end if;
    end if;
  end process PROC_PARITY_CHECK;

  -- Write to FIFO
  PROC_WRITE_TO_FIFO: process(NX_TIMESTAMP_CLK_IN)
  begin
    if( rising_edge(NX_TIMESTAMP_CLK_IN) ) then
      if (RESET_IN = '1') then
        fifo_data_input      <= (others => '0');
        fifo_write_enable    <= '0';
      else
        fifo_data_input      <= x"deadbeef";
        fifo_write_enable    <= '0';
        if (nx_new_frame = '1' and nx_frame_synced = '1') then
          fifo_data_input    <= fifo_32bit_word; 
          fifo_write_enable  <= '1';
        end if;
      end if;
    end if;
  end process PROC_WRITE_TO_FIFO;

  fifo_32to32_dc_1: fifo_32to32_dc
    port map (
      Data          => fifo_data_input,
      WrClock       => NX_TIMESTAMP_CLK_IN,
      RdClock       => CLK_IN,
      WrEn          => fifo_write_enable,
      RdEn          => fifo_read_enable,
      Reset         => fifo_reset,
      RPReset       => fifo_reset,
      AmEmptyThresh => fifo_delay_r,
      Q             => fifo_out,
      Empty         => fifo_empty,
      Full          => fifo_full,
      AlmostEmpty   => fifo_almost_empty
      );

  fifo_reset         <= (RESET_IN or fifo_reset_r);

--   -- Reset NX_TIMESTAMP_CLK Domain
--   PROC_NX_CLK_DOMAIN_RESET: process(CLK_IN)
--   begin
--     if( rising_edge(CLK_IN) ) then
--       if( RESET_IN = '1' ) then
--         reset_nx_domain_ctr <= (others => '0');
--         reset_nx_domain <= '1';
--       else
--         if (nx_clk_pulse = '1') then
--           nx_clk_pulse_ctr <= nx_clk_pulse_ctr + 1;
--         end if;
--         
--       end if;
-- 
--     end if;
--   end process PROC_NX_CLK_DOMAIN_RESET;

  PROC_NX_CLK_ACT: process(NX_TIMESTAMP_CLK_IN)
  begin
    if(rising_edge(NX_TIMESTAMP_CLK_IN)) then
      if(RESET_IN = '1' ) then
        nx_clk_active <= '0';
      else
        nx_clk_active <= not nx_clk_active;
      end if;
    end if;
  end process PROC_NX_CLK_ACT;
    
  -----------------------------------------------------------------------------
  -- CLK_IN Domain
  -----------------------------------------------------------------------------

  -- FIFO Read Handler
  PROC_FIFO_READ_ENABLE: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        fifo_read_enable       <= '0';
        read_enable_pause      <= '0';
        fifo_data_valid_t      <= '0';
        fifo_data_valid        <= '0';
      else
        if (fifo_almost_empty = '0' and read_enable_pause = '0') then
          fifo_read_enable     <= '1';
          read_enable_pause    <= '1';
        else
          fifo_read_enable     <= '0';
          read_enable_pause    <= '0';
        end if;

        -- Delay read signal by one CLK
        fifo_data_valid_t      <= fifo_read_enable;
        fifo_data_valid        <= fifo_data_valid_t;

      end if;
    end if;
  end process PROC_FIFO_READ_ENABLE;

  PROC_FIFO_READ: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        nx_new_timestamp_o <= '0';
        register_fifo_data <= (others => '0');
      else
        nx_new_timestamp_o    <= '0';
        register_fifo_data    <= x"affebabe";
 
        if (fifo_data_valid = '1') then
          register_fifo_data  <= fifo_out;
          nx_new_timestamp_o  <= '1';
        end if;
      end if;
    end if;
  end process PROC_FIFO_READ;

  -----------------------------------------------------------------------------
  -- Status Counters
  -----------------------------------------------------------------------------

  -- Domain Transfers
  pulse_sync_1: pulse_sync
    port map (
      CLK_A_IN    => NX_TIMESTAMP_CLK_IN,
      RESET_A_IN  => RESET_IN,
      PULSE_A_IN  => rs_sync_reset,
      CLK_B_IN    => CLK_IN,
      RESET_B_IN  => RESET_IN,
      PULSE_B_OUT => resync_ctr_inc 
      );

  pulse_sync_2: pulse_sync
    port map (
      CLK_A_IN    => NX_TIMESTAMP_CLK_IN,
      RESET_A_IN  => RESET_IN,
      PULSE_A_IN  => parity_error,
      CLK_B_IN    => CLK_IN,
      RESET_B_IN  => RESET_IN,
      PULSE_B_OUT => parity_error_ctr_inc
      );

  PROC_SYNC_FRAME_SYNC: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if(RESET_IN = '1' ) then
        reg_nx_frame_synced_t <= '0';
        reg_nx_frame_synced   <= '0';
      else
        reg_nx_frame_synced_t <= nx_frame_synced;
        reg_nx_frame_synced   <= reg_nx_frame_synced_t; 
      end if;
    end if;
  end process PROC_SYNC_FRAME_SYNC;

  -- Counters
  PROC_RESYNC_COUNTER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1' or reset_resync_ctr = '1') then
        resync_counter <= (others => '0');
      else
        if (resync_ctr_inc = '1') then
          resync_counter <= resync_counter + 1;
        end if;
      end if;
    end if;
  end process PROC_RESYNC_COUNTER; 

  PROC_PARITY_ERROR_COUNTER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1' or reset_parity_error_ctr = '1') then
        parity_error_counter <= (others => '0');
      else
        if (parity_error_ctr_inc = '1') then
          parity_error_counter <= parity_error_counter + 1;
        end if;
      end if;
    end if;
  end process PROC_PARITY_ERROR_COUNTER;
  
  -----------------------------------------------------------------------------
  -- TRBNet Slave Bus
  -----------------------------------------------------------------------------

  -- Give status info to the TRB Slow Control Channel
  PROC_FIFO_REGISTERS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o          <= (others => '0');
        slv_ack_o               <= '0';
        slv_unknown_addr_o      <= '0';
        slv_no_more_data_o      <= '0';
        reset_resync_ctr        <= '0';
        reset_parity_error_ctr  <= '0';
        fifo_delay_r            <= "000010";
        fifo_reset_r            <= '0';
      else                      
        slv_data_out_o          <= (others => '0');
        slv_ack_o               <= '0';
        slv_unknown_addr_o      <= '0';
        slv_no_more_data_o      <= '0';
        reset_resync_ctr        <= '0';
        reset_parity_error_ctr  <= '0';
        fifo_reset_r            <= '0';
        
        if (SLV_READ_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              slv_data_out_o               <= register_fifo_data;
              slv_ack_o                    <= '1';

            when x"0001" =>
              slv_data_out_o(0)            <= fifo_full;
              slv_data_out_o(1)            <= fifo_empty;
              slv_data_out_o(2)            <= fifo_almost_empty;
              slv_data_out_o(3)            <= '0';
              slv_data_out_o(4)            <= fifo_data_valid;
              slv_data_out_o(29 downto 5)  <= (others => '0');
              slv_data_out_o(30)           <= '0';
              slv_data_out_o(31)           <= reg_nx_frame_synced;
              slv_ack_o                    <= '1'; 

            when x"0002" =>
              slv_data_out_o(11 downto  0) <= resync_counter;
              slv_data_out_o(31 downto 12) <= (others => '0');
              slv_ack_o                    <= '1'; 

            when x"0003" =>
              slv_data_out_o(11 downto  0) <= parity_error_counter;
              slv_data_out_o(31 downto 12) <= (others => '0');
              slv_ack_o                    <= '1'; 

            when x"0004" =>
              slv_data_out_o( 5 downto 0)  <= fifo_delay_r;
              slv_data_out_o(31 downto 6)  <= (others => '0');
              slv_ack_o                    <= '1'; 

            when others  =>
              slv_unknown_addr_o           <= '1';
          end case;
          
        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0002" => 
              reset_resync_ctr             <= '1';
              slv_ack_o                    <= '1'; 

            when x"0003" => 
              reset_parity_error_ctr       <= '1';
              slv_ack_o                    <= '1'; 

            when x"0004" => 
              if (SLV_DATA_IN  < x"0000003c" and
                  SLV_DATA_IN  > x"00000001") then
                fifo_delay_r               <= SLV_DATA_IN(5 downto 0);
                fifo_reset_r               <= '1';
              end if;
              slv_ack_o                    <= '1';
                
            when others  =>
              slv_unknown_addr_o           <= '1';              
          end case;                
        end if;
      end if;
    end if;
  end process PROC_FIFO_REGISTERS;

  -- Output Signals
  NX_TIMESTAMP_OUT      <= register_fifo_data;
  NX_NEW_TIMESTAMP_OUT  <= nx_new_timestamp_o;

  SLV_DATA_OUT          <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT  <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT  <= slv_unknown_addr_o;
  SLV_ACK_OUT           <= slv_ack_o;
  
end Behavioral;
