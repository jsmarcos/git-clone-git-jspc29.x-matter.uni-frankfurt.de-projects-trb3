library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.scaler_components.all;

entity trigger_handler is
  port (
    CLK_IN                     : in  std_logic;
    RESET_IN                   : in  std_logic;
    CLK_D1_IN                  : in  std_logic;
    RESET_D1_IN                : in  std_logic;  -- Rest CLK_D1 Domain
    OFFLINE_IN                 : in  std_logic;
    
    --Input Triggers          
    TIMING_TRIGGER_IN          : in std_logic; -- The raw timing Trigger Signal 
    LVL1_TRG_DATA_VALID_IN     : in std_logic; -- Data Trigger is valid
    LVL1_VALID_TIMING_TRG_IN   : in std_logic; -- Timin Trigger is valid
    LVL1_VALID_NOTIMING_TRG_IN : in std_logic; -- calib trigger w/o ref time
    LVL1_INVALID_TRG_IN        : in std_logic; 

    LVL1_TRG_TYPE_IN           : in std_logic_vector(3 downto 0);
    LVL1_TRG_NUMBER_IN         : in std_logic_vector(15 downto 0);
    LVL1_TRG_CODE_IN           : in std_logic_vector(7 downto 0);
    LVL1_TRG_INFORMATION_IN    : in std_logic_vector(23 downto 0);
    LVL1_INT_TRG_NUMBER_IN     : in std_logic_vector(15 downto 0);

    --Response from FEE        
    FEE_DATA_OUT               : out std_logic_vector(31 downto 0);
    FEE_DATA_WRITE_OUT         : out std_logic;
    FEE_DATA_FINISHED_OUT      : out std_logic;
    FEE_TRG_RELEASE_OUT        : out std_logic;
    FEE_TRG_STATUSBITS_OUT     : out std_logic_vector(31 downto 0);

    CHANNEL_DATA_0_IN          : in  std_logic_vector(47 downto 0);
    CHANNEL_DATA_1_IN          : in  std_logic_vector(47 downto 0);
    
    -- Slave bus               
    SLV_READ_IN                : in  std_logic;
    SLV_WRITE_IN               : in  std_logic;
    SLV_DATA_OUT               : out std_logic_vector(31 downto 0);
    SLV_DATA_IN                : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN                : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT                : out std_logic;
    SLV_NO_MORE_DATA_OUT       : out std_logic;
    SLV_UNKNOWN_ADDR_OUT       : out std_logic;

    -- Debug Line              
    DEBUG_OUT                  : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of trigger_handler is

  -- Timing Trigger Handler
  constant NUM_FF                   : integer := 10;
  signal timing_trigger_ff_p        : std_logic_vector(1 downto 0);
  signal timing_trigger_ff          : std_logic_vector(NUM_FF - 1 downto 0);
  signal timing_trigger_l           : std_logic;
  signal timing_trigger             : std_logic;
  signal timing_trigger_set         : std_logic;
  signal timestamp_trigger_o        : std_logic;

  signal invalid_timing_trigger_n   : std_logic;

  signal invalid_timing_trigger_ff  : std_logic;
  signal invalid_timing_trigger_f   : std_logic;
  signal invalid_timing_trigger     : std_logic;
  signal invalid_timing_trigger_ctr : unsigned(15 downto 0);

  signal trigger_busy_ff            : std_logic;
  signal trigger_busy_f             : std_logic;
  signal trigger_busy               : std_logic;

  signal fast_clear_ff              : std_logic;
  signal fast_clear_f               : std_logic;
  signal fast_clear                 : std_logic;
  
  type TS_STATES is (TS_IDLE,
                     TS_WAIT_VALID_TIMING_TRIGGER,
                     TS_INVALID_TRIGGER,
                     TS_WAIT_TRIGGER_END
                     );
  signal TS_STATE : TS_STATES;

  signal ts_wait_timer_reset        : std_logic;
  signal ts_wait_timer_start        : std_logic;
  signal ts_wait_timer_done         : std_logic;
  
  -- Trigger Handler                
  signal valid_trigger_o            : std_logic;
  signal timing_trigger_o           : std_logic;
  signal status_trigger_o           : std_logic;
  signal calibration_trigger_o      : std_logic;
  signal calib_downscale_ctr        : unsigned(15 downto 0);
  signal fast_clear_o               : std_logic;
  signal trigger_busy_o             : std_logic;
  signal fee_data_o                 : std_logic_vector(31 downto 0);
  signal fee_data_write_o           : std_logic;
  signal fee_data_finished_o        : std_logic;
  signal fee_trg_release_o          : std_logic;
  signal fee_trg_statusbits_o       : std_logic_vector(31 downto 0);

  signal timestamp_calib_trigger_c100 : std_logic;
  signal timestamp_calib_trigger_f    : std_logic;
  signal timestamp_calib_trigger_o    : std_logic;
  
  type STATES is (S_IDLE,
                  S_IGNORE_TRIGGER,
                  S_TIMING_TRIGGER,
                  S_WAIT_TRG_DATA_VALID,

                  S_SEND_CHANNEL_0_DATA,
                  S_SEND_CHANNEL_0_DATA_HIGH,

                  S_SEND_CHANNEL_1_DATA,
                  S_SEND_CHANNEL_1_DATA_HIGH,
                  
                  S_SEND_FEE_DATA_DONE,
                  
                  S_FEE_TRIGGER_RELEASE,
                  S_WAIT_FEE_TRIGGER_RELEASE_ACK
                  );
  signal STATE : STATES;

  type TRIGGER_TYPES is (T_UNDEF,
                         T_IGNORE,
                         T_TIMING,
                         T_STATUS,
                         T_CALIBRATION
                         );
  signal TRIGGER_TYPE : TRIGGER_TYPES;
  
  
  -- Testpulse Handler
  type T_STATES is (T_IDLE,
                    T_WAIT_TESTPULE_DELAY,
                    T_SET_TESTPULSE,
                    T_WAIT_TESTPULE_END
                    );
  
  signal T_STATE : T_STATES;
  
  signal internal_trigger_f          : std_logic;
  signal internal_trigger            : std_logic;
  
  -- Rate Calculation
  signal accepted_trigger_rate_t     : unsigned(27 downto 0);
  signal rate_timer                  : unsigned(27 downto 0);
  
  -- TRBNet Slave Bus                
  signal slv_data_out_o              : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o          : std_logic;
  signal slv_unknown_addr_o          : std_logic;
  signal slv_ack_o                   : std_logic;

  signal accepted_trigger_rate       : unsigned(27 downto 0);
  signal invalid_t_trigger_ctr_clear : std_logic;
  signal bypass_all_trigger          : std_logic;
  signal bypass_physics_trigger      : std_logic;
  signal bypass_status_trigger       : std_logic;
  signal bypass_calibration_trigger  : std_logic;
  signal calibration_downscale       : unsigned(15 downto 0);
  signal physics_trigger_type        : std_logic_vector(3 downto 0);
  signal status_trigger_type         : std_logic_vector(3 downto 0);
  signal calibration_trigger_type    : std_logic_vector(3 downto 0);
  
begin

  -- Debug Line
  DEBUG_OUT(0)            <= CLK_IN;
  DEBUG_OUT(1)            <= TIMING_TRIGGER_IN;
  DEBUG_OUT(2)            <= invalid_timing_trigger;
  DEBUG_OUT(3)            <= LVL1_VALID_TIMING_TRG_IN;
  DEBUG_OUT(4)            <= LVL1_TRG_DATA_VALID_IN;
  DEBUG_OUT(5)            <= fee_data_write_o;
  DEBUG_OUT(6)            <= '0';
  DEBUG_OUT(7)            <= '0';
  DEBUG_OUT(8)            <= valid_trigger_o;
  DEBUG_OUT(9)            <= timing_trigger_o;
  DEBUG_OUT(10)           <= fee_data_finished_o;
  DEBUG_OUT(11)           <= fee_trg_release_o;
  DEBUG_OUT(12)           <= trigger_busy_o;
  DEBUG_OUT(13)           <= timestamp_trigger_o;
  DEBUG_OUT(14)           <= '0';
  DEBUG_OUT(15)           <= '0';

  -----------------------------------------------------------------------------
  -- Trigger Handler
  -----------------------------------------------------------------------------
  
  PROC_TRIGGER_HANDLER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        valid_trigger_o              <= '0';
        timing_trigger_o             <= '0';
        status_trigger_o             <= '0';
        calibration_trigger_o        <= '0';
        fee_data_o                   <= (others => '0');
        fee_data_write_o             <= '0';
        fee_data_finished_o          <= '0';
        fee_trg_release_o            <= '0';
        fee_trg_statusbits_o         <= (others => '0');
        fast_clear_o                 <= '0';
        trigger_busy_o               <= '0';
        timestamp_calib_trigger_c100 <= '0';
        calib_downscale_ctr          <= (others => '0');
        TRIGGER_TYPE                 <= T_UNDEF;
        STATE                        <= S_IDLE;
      else                           
        valid_trigger_o              <= '0';
        timing_trigger_o             <= '0';
        status_trigger_o             <= '0';
        calibration_trigger_o        <= '0';
        fee_data_o                   <= (others => '0');
        fee_data_write_o             <= '0';
        fee_data_finished_o          <= '0';
        fee_trg_release_o            <= '0';
        fee_trg_statusbits_o         <= (others => '0');
        fast_clear_o                 <= '0';
        trigger_busy_o               <= '1';
        timestamp_calib_trigger_c100 <= '0';
        
        if (LVL1_INVALID_TRG_IN = '1') then
          -- There was no valid Timing Trigger at CTS, do a fast clear
          fast_clear_o               <= '1';
          fee_trg_release_o          <= '1';
          STATE                      <= S_IDLE;
        else
          
          case STATE is

            when  S_IDLE =>

              if (LVL1_VALID_TIMING_TRG_IN = '1') then
                -- Check Trigger Type
                if (LVL1_TRG_TYPE_IN = physics_trigger_type) then
                  -- Physiks Trigger
                  TRIGGER_TYPE                 <= T_TIMING;
                  STATE                        <= S_TIMING_TRIGGER;
                else
                  -- Unknown Timing Trigger, ignore
                  TRIGGER_TYPE                 <= T_IGNORE;
                  STATE                        <= S_IGNORE_TRIGGER;
                end if;
              
              elsif (LVL1_VALID_NOTIMING_TRG_IN = '1') then
                -- Ignore NOTIMING Triggers  
                TRIGGER_TYPE                     <= T_IGNORE;
                STATE                            <= S_IGNORE_TRIGGER;
                
              else
                -- No Trigger IN, Nothing to do, Sleep Well
                trigger_busy_o        <= '0';
                TRIGGER_TYPE          <= T_UNDEF;
                STATE                 <= S_IDLE;
              end if;
              
            when S_TIMING_TRIGGER =>
              valid_trigger_o         <= '1';
              timing_trigger_o        <= '1';
              STATE                   <= S_WAIT_TRG_DATA_VALID;

            when S_WAIT_TRG_DATA_VALID | S_IGNORE_TRIGGER =>
              if (LVL1_TRG_DATA_VALID_IN = '0') then
                STATE                 <= S_WAIT_TRG_DATA_VALID;
              else
                if (TRIGGER_TYPE = T_IGNORE) then
                  STATE               <=  S_SEND_FEE_DATA_DONE;
                else
                  STATE               <= S_SEND_CHANNEL_0_DATA;
                end if;
              end if;
              
              -- Send Channel Data
            when S_SEND_CHANNEL_0_DATA =>
              fee_data_o(31 downto 28) <= x"0";            
              fee_data_o(27 downto 16) <= x"aaa";
              fee_data_o(15 downto 0)  <= CHANNEL_DATA_0_IN(47 downto 32);
              fee_data_write_o         <= '1';
              STATE                    <= S_SEND_CHANNEL_0_DATA_HIGH;

            when S_SEND_CHANNEL_0_DATA_HIGH =>
              fee_data_o               <= CHANNEL_DATA_0_IN(31 downto 0);
              fee_data_write_o         <= '1';
              STATE                    <= S_SEND_CHANNEL_1_DATA;


            when S_SEND_CHANNEL_1_DATA =>
              fee_data_o(31 downto 28) <= x"1";            
              fee_data_o(27 downto 16) <= x"bbb";
              fee_data_o(15 downto 0)  <= CHANNEL_DATA_1_IN(47 downto 32);
              fee_data_write_o         <= '1';
              STATE                    <= S_SEND_CHANNEL_1_DATA_HIGH;

            when S_SEND_CHANNEL_1_DATA_HIGH =>
              fee_data_o               <= CHANNEL_DATA_1_IN(31 downto 0);
              fee_data_write_o         <= '1';
              STATE                    <= S_SEND_FEE_DATA_DONE;

              
            when S_SEND_FEE_DATA_DONE =>
              fee_data_finished_o   <= '1';
              STATE                 <= S_FEE_TRIGGER_RELEASE;

              -- Hier noch warten auf CTS
            when S_FEE_TRIGGER_RELEASE =>
              fee_trg_release_o       <= '1';
              STATE                   <= S_WAIT_FEE_TRIGGER_RELEASE_ACK;
              
            when S_WAIT_FEE_TRIGGER_RELEASE_ACK =>
              if (LVL1_TRG_DATA_VALID_IN = '1') then
                STATE                 <= S_WAIT_FEE_TRIGGER_RELEASE_ACK;
              else
                STATE                 <= S_IDLE;
              end if;

              end case;
        end if;
      end if;
    end if;
  end process PROC_TRIGGER_HANDLER;

-----------------------------------------------------------------------------
-- TRBNet Slave Bus
-----------------------------------------------------------------------------

  PROC_SLAVE_BUS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o                 <= (others => '0');
        slv_no_more_data_o             <= '0';
        slv_unknown_addr_o             <= '0';
        slv_ack_o                      <= '0';
        invalid_t_trigger_ctr_clear    <= '1';
        bypass_all_trigger             <= '0';
        bypass_physics_trigger         <= '0';
        bypass_status_trigger          <= '1';
        bypass_calibration_trigger     <= '1';
        calibration_downscale          <= x"0001";
        physics_trigger_type           <= x"1";
        calibration_trigger_type       <= x"9";
        status_trigger_type            <= x"e";
      else                             
        slv_unknown_addr_o             <= '0';
        slv_no_more_data_o             <= '0';
        slv_data_out_o                 <= (others => '0');
        slv_ack_o                      <= '0';
        invalid_t_trigger_ctr_clear    <= '0';

        if (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0003" =>
              invalid_t_trigger_ctr_clear  <= '1';
              slv_ack_o                    <= '1'; 

            when x"0006" =>
              bypass_physics_trigger       <= SLV_DATA_IN(0);
              bypass_status_trigger        <= SLV_DATA_IN(1);
              bypass_calibration_trigger   <= SLV_DATA_IN(2);
              bypass_all_trigger           <= SLV_DATA_IN(3);
              slv_ack_o                    <= '1'; 

            when x"0007" =>
              if (unsigned(SLV_DATA_IN(15 downto 0)) > x"0000") then
                calibration_downscale      <=
                  unsigned(SLV_DATA_IN(15 downto 0));
              end if;
              slv_ack_o                    <= '1';

            when x"0008" =>
              physics_trigger_type          <= SLV_DATA_IN(3 downto 0);
              slv_ack_o                    <= '1';  

            when x"0009" =>
              status_trigger_type          <= SLV_DATA_IN(3 downto 0);
              slv_ack_o                    <= '1';  

            when x"000a" =>
              calibration_trigger_type     <= SLV_DATA_IN(3 downto 0);
              slv_ack_o                    <= '1';  
              
            when others =>
              slv_unknown_addr_o           <= '1';

          end case;

        elsif (SLV_READ_IN = '1') then
          case SLV_ADDR_IN is
            when x"0003" =>
              slv_data_out_o(15 downto 0)  <=
                std_logic_vector(invalid_timing_trigger_ctr);
              slv_data_out_o(31 downto 26) <= (others => '0');
              slv_ack_o                    <= '1';  

            when x"0004" =>
              slv_data_out_o(27 downto 0)  <=
                std_logic_vector(accepted_trigger_rate);
              slv_data_out_o(31 downto 28) <= (others => '0');
              slv_ack_o                    <= '1';  
              
            when x"0006" =>
              slv_data_out_o(0)            <= bypass_physics_trigger;
              slv_data_out_o(1)            <= bypass_status_trigger;
              slv_data_out_o(2)            <= bypass_calibration_trigger;
              slv_data_out_o(3)            <= bypass_all_trigger;
              slv_data_out_o(31 downto 4)  <= (others => '0');
              slv_ack_o                    <= '1';  

            when x"0007" =>
              slv_data_out_o(15 downto 0)  <= calibration_downscale;
              slv_data_out_o(31 downto 16) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0008" =>
              slv_data_out_o(3 downto 0)   <= physics_trigger_type;
              slv_data_out_o(31 downto 4)  <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0009" =>
              slv_data_out_o(3 downto 0)   <= status_trigger_type;
              slv_data_out_o(31 downto 4)  <= (others => '0');
              slv_ack_o                    <= '1';

            when x"000a" =>
              slv_data_out_o(3 downto 0)   <= calibration_trigger_type;
              slv_data_out_o(31 downto 4)  <= (others => '0');
              slv_ack_o                    <= '1';
              
            when others =>
              slv_unknown_addr_o           <= '1';

          end case;

        end if;
      end if;
    end if;           
  end process PROC_SLAVE_BUS;

-----------------------------------------------------------------------------
-- Output Signals
-----------------------------------------------------------------------------

  -- Trigger Output
  FEE_DATA_OUT              <= fee_data_o;
  FEE_DATA_WRITE_OUT        <= fee_data_write_o; 
  FEE_DATA_FINISHED_OUT     <= fee_data_finished_o;
  FEE_TRG_RELEASE_OUT       <= fee_trg_release_o;
  FEE_TRG_STATUSBITS_OUT    <= fee_trg_statusbits_o;

  -- Slave Bus              
  SLV_DATA_OUT              <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT      <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT      <= slv_unknown_addr_o;
  SLV_ACK_OUT               <= slv_ack_o;    

end Behavioral;
