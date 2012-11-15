library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.version.all;

entity TDC is
  generic (
    CHANNEL_NUMBER : integer range 2 to 65;
    STATUS_REG_NR  : integer range 0 to 6;
    CONTROL_REG_NR : integer range 0 to 6);
  port (
    RESET                 : in  std_logic;
    CLK_TDC               : in  std_logic;
    CLK_READOUT           : in  std_logic;
    REFERENCE_TIME        : in  std_logic;
    HIT_IN                : in  std_logic_vector(CHANNEL_NUMBER-1 downto 1);
    TRG_WIN_PRE           : in  std_logic_vector(10 downto 0);
    TRG_WIN_POST          : in  std_logic_vector(10 downto 0);
--
    -- Trigger signals from handler
    TRG_DATA_VALID_IN     : in  std_logic;
    VALID_TIMING_TRG_IN   : in  std_logic;
    VALID_NOTIMING_TRG_IN : in  std_logic;
    INVALID_TRG_IN        : in  std_logic;
    TMGTRG_TIMEOUT_IN     : in  std_logic;
    SPIKE_DETECTED_IN     : in  std_logic;
    MULTI_TMG_TRG_IN      : in  std_logic;
    SPURIOUS_TRG_IN       : in  std_logic;
--
    TRG_NUMBER_IN         : in  std_logic_vector(15 downto 0);
    TRG_CODE_IN           : in  std_logic_vector(7 downto 0);
    TRG_INFORMATION_IN    : in  std_logic_vector(23 downto 0);
    TRG_TYPE_IN           : in  std_logic_vector(3 downto 0);
--
    --Response to handler
    TRG_RELEASE_OUT       : out std_logic;
    TRG_STATUSBIT_OUT     : out std_logic_vector(31 downto 0);
    DATA_OUT              : out std_logic_vector(31 downto 0);
    DATA_WRITE_OUT        : out std_logic;
    DATA_FINISHED_OUT     : out std_logic;
--
    --ToBusHandler
    HCB_READ_EN_IN        : in  std_logic;
    HCB_WRITE_EN_IN       : in  std_logic;
    HCB_ADDR_IN           : in  std_logic_vector(6 downto 0);
    HCB_DATA_OUT          : out std_logic_vector(31 downto 0);
    HCB_DATAREADY_OUT     : out std_logic;
    HCB_UNKNOWN_ADDR_OUT  : out std_logic;
--
    SLOW_CONTROL_REG_OUT  : out std_logic_vector(32*2**STATUS_REG_NR-1 downto 0);
    LOGIC_ANALYSER_OUT    : out std_logic_vector(15 downto 0);
    CONTROL_REG_IN        : in  std_logic_vector(32*2**CONTROL_REG_NR-1 downto 0)
    );
end TDC;

architecture TDC of TDC is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
  -- Coarse Counters
  type   coarse_cntr_array is array (1 to 4) of std_logic_vector(10 downto 0);
  signal coarse_cntr         : coarse_cntr_array;
  signal coarse_cntr_reset   : std_logic;
  signal coarse_cntr_reset_r : std_logic_vector(4 downto 1);

  -- Epoch Counter
  signal epoch_cntr         : std_logic_vector(27 downto 0);
  signal epoch_cntr_up_i    : std_logic;
  signal epoch_cntr_up_reg  : std_logic_vector(0 downto 0);
  signal epoch_cntr_reset_i : std_logic;

  -- Output registers
  signal trg_release_reg     : std_logic;
  signal trg_statusbit_reg   : std_logic_vector(31 downto 0);
  signal data_out_reg        : std_logic_vector(31 downto 0);
  signal data_wr_reg         : std_logic;
  signal data_finished_reg   : std_logic;
  signal fsm_debug_reg       : std_logic_vector(7 downto 0);
  signal logic_analyser_reg  : std_logic_vector(15 downto 0);
  signal logic_analyser_2reg : std_logic_vector(15 downto 0);

  -- Clock - Reset Signals
  signal reset_tdc : std_logic_vector(2 downto 0) := "111";

  -- ReadOut Signals
  signal trigger_time_i     : std_logic_vector(38 downto 0);
  signal ref_time_coarse    : std_logic_vector(22 downto 0);
  signal header_error_bits  : std_logic_vector(15 downto 0);
  signal trailer_error_bits : std_logic_vector(15 downto 0);

  -- FSM Signals
  type FSM is (IDLE, WAIT_FOR_TRG_WIND_END,
               WAIT_FOR_LVL1_TRG_A, WAIT_FOR_LVL1_TRG_B, WAIT_FOR_LVL1_TRG_C,
               SEND_STATUS, SEND_TRG_RELEASE_A, SEND_TRG_RELEASE_B,
               WAIT_FOR_FIFO_NR_A, WAIT_FOR_FIFO_NR_B, WAIT_FOR_FIFO_NR_C,
               WR_HEADER, APPLY_MASK,
               RD_CHANNEL_A, RD_CHANNEL_B, RD_CHANNEL_C);
  signal FSM_CURRENT, FSM_NEXT       : FSM;
  signal start_trg_win_cnt_fsm       : std_logic;
  signal start_trg_win_cnt_i         : std_logic;
  signal start_trg_win_cnt_200       : std_logic;
  signal start_trg_win_cnt_200_pulse : std_logic;
  signal fsm_debug_fsm               : std_logic_vector(7 downto 0);
  signal updt_index_fsm              : std_logic;
  signal updt_index_i                : std_logic;
  signal updt_index_reg              : std_logic;
  signal updt_mask_fsm               : std_logic;
  signal updt_mask_i                 : std_logic;
  signal rd_en_fsm                   : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal rd_en_i                     : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal data_finished_fsm           : std_logic;
  signal data_finished_i             : std_logic;
  signal trg_release_fsm             : std_logic;
  signal wr_header_fsm               : std_logic;
  signal wr_header_i                 : std_logic;
  signal wr_ch_data_fsm              : std_logic;
  signal wr_ch_data_i                : std_logic;
  signal wr_ch_data_reg              : std_logic;
  signal wr_ch_data_2reg             : std_logic;
  signal wr_status_fsm               : std_logic;
  signal wr_status_i                 : std_logic;
  signal wrong_readout_fsm           : std_logic;
  signal wrong_readout_i             : std_logic;
  signal wr_trailer_fsm              : std_logic;
  signal wr_trailer_i                : std_logic;

  -- Readout Busy signals
  type   FSM_RDO_BUSY is (NOT_BUSY, BUSY, WAIT_FOR_SILINCE);
  signal FSM_RDO_BUSY_STATE : FSM_RDO_BUSY := NOT_BUSY;

  -- Other Signals
  signal fifo_full_i           : std_logic;
  signal fifo_almost_full_i    : std_logic;
  signal mask_i                : std_logic_vector(71 downto 0);
  signal fifo_nr_reg           : integer range 0 to CHANNEL_NUMBER := CHANNEL_NUMBER;
  signal fifo_nr               : integer range 0 to CHANNEL_NUMBER := CHANNEL_NUMBER;
  signal fifo_nr_next          : integer range 0 to CHANNEL_NUMBER := CHANNEL_NUMBER;
  signal TW_pre                : std_logic_vector(38 downto 0);
  signal TW_post               : std_logic_vector(38 downto 0);
  signal trg_win_end_100       : std_logic;
  signal trg_win_end_100_pulse : std_logic;
  signal trg_win_end_200       : std_logic;
  signal trg_win_end_200_pulse : std_logic;
  signal trg_win_cnt           : std_logic_vector(11 downto 0);
  signal trg_win_post_200      : std_logic_vector(10 downto 0);
  signal channel_hit_time      : std_logic_vector(38 downto 0);
  signal channel_epoch_cntr_i  : std_logic_vector(27 downto 0);
  signal trg_win_l             : std_logic;
  signal trg_win_r             : std_logic;
  type   Std_Logic_8_array is array (0 to 8) of std_logic_vector(3 downto 0);
  signal fifo_nr_hex           : Std_Logic_8_array;
  signal channel_full_i        : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal channel_full_reg      : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal channel_almost_full_i : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal channel_empty_i       : std_logic_vector(CHANNEL_NUMBER downto 0);
  signal channel_empty_reg     : std_logic_vector(CHANNEL_NUMBER downto 0);
  signal channel_empty_2reg    : std_logic_vector(CHANNEL_NUMBER downto 0);
  signal channel_empty_3reg    : std_logic_vector(CHANNEL_NUMBER downto 0);
  signal channel_empty_4reg    : std_logic_vector(CHANNEL_NUMBER downto 0);
  type   channel_data_array is array (0 to CHANNEL_NUMBER) of std_logic_vector(31 downto 0);
  signal channel_data_i        : channel_data_array;
  signal channel_data_reg      : channel_data_array;
  signal channel_data_2reg     : channel_data_array;
  signal channel_data_3reg     : channel_data_array;
  signal hit_in_i              : std_logic_vector(CHANNEL_NUMBER-1 downto 1);
  signal scaler_in_i           : std_logic_vector(CHANNEL_NUMBER-1 downto 1);

  -- Slow Control Signals
  signal ch_en_i                  : std_logic_vector(64 downto 1);
  signal trigger_win_en           : std_logic;
  signal readout_trigger_mode     : std_logic;  -- readout trigger
                                                -- 1: with trigger
                                                -- 0: triggerless
  signal readout_trigger_mode_200 : std_logic;  -- trigger mode signal synchronised to the coarse counter clk
  signal logic_anal_control       : std_logic_vector(3 downto 0);
  signal debug_mode_en_i          : std_logic;
  signal scaler_number_i          : std_logic_vector(7 downto 0);
  signal counters_reset_i         : std_logic;

  -- Statistics Signals
  type   statistics_array_12 is array (1 to CHANNEL_NUMBER-1) of std_logic_vector(11 downto 0);
  signal trig_number                  : unsigned(23 downto 0);
  signal release_number               : unsigned(23 downto 0);
  signal valid_tmg_trig_number        : unsigned(23 downto 0);
  signal valid_timing_trg_pulse       : std_logic;
  signal valid_NOtmg_trig_number      : unsigned(23 downto 0);
  signal valid_notiming_trg_pulse     : std_logic;
  signal invalid_trig_number          : unsigned(23 downto 0);
  signal invalid_trg_pulse            : std_logic;
  signal multi_tmg_trig_number        : unsigned(23 downto 0);
  signal multi_tmg_trg_pulse          : std_logic;
  signal spurious_trig_number         : unsigned(23 downto 0);
  signal spurious_trg_pulse           : std_logic;
  signal wrong_readout_number         : unsigned(23 downto 0);
  signal spike_number                 : unsigned(23 downto 0);
  signal spike_detected_pulse         : std_logic;
  signal timeout_number               : unsigned(23 downto 0);
  signal timeout_detected_pulse       : std_logic;
  signal idle_i                       : std_logic;
  signal idle_fsm                     : std_logic;
  signal idle_time                    : unsigned(23 downto 0);
  signal readout_i                    : std_logic;
  signal readout_fsm                  : std_logic;
  signal readout_time                 : unsigned(23 downto 0);
  signal wait_i                       : std_logic;
  signal wait_fsm                     : std_logic;
  signal wait_time                    : unsigned(23 downto 0);
  signal empty_channels               : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal total_empty_channel          : unsigned(23 downto 0);
  signal channel_lost_hit_number      : std_logic_vector_array_24(0 to CHANNEL_NUMBER-1);
  signal channel_hit_detect_number    : std_logic_vector_array_24(0 to CHANNEL_NUMBER-1);
  signal channel_encoder_start_number : std_logic_vector_array_24(0 to CHANNEL_NUMBER-1);
  signal channel_fifo_wr_number       : std_logic_vector_array_24(0 to CHANNEL_NUMBER-1);
  signal channel_level_hit_number_i   : std_logic_vector_array_32(0 to CHANNEL_NUMBER-1);
  signal stop_status_i                : std_logic;
  signal readout_busy                 : std_logic;

  -- Test signals
  signal ref_debug_i     : std_logic_vector(31 downto 0);
  type   channel_debug_array is array (1 to CHANNEL_NUMBER-1) of std_logic_vector(31 downto 0);
  signal channel_debug_i : channel_debug_array;

  attribute syn_keep                            : boolean;
  attribute syn_keep of reset_tdc               : signal is true;
  attribute syn_keep of coarse_cntr             : signal is true;
  attribute syn_preserve                        : boolean;
  attribute syn_preserve of coarse_cntr         : signal is true;
  attribute syn_preserve of coarse_cntr_reset_r : signal is true;

-------------------------------------------------------------------------------
  
begin
-------------------------------------------------------------------------------
-- Slow control signals
-------------------------------------------------------------------------------
  logic_anal_control   <= CONTROL_REG_IN(3 downto 0) when rising_edge(CLK_READOUT);
  debug_mode_en_i      <= CONTROL_REG_IN(4);
  counters_reset_i     <= CONTROL_REG_IN(8);
  readout_trigger_mode <= CONTROL_REG_IN(12);
  trigger_win_en       <= CONTROL_REG_IN(1*32+31);
  ch_en_i              <= CONTROL_REG_IN(3*32+31 downto 2*32+0);

-------------------------------------------------------------------------------
-- The Reset Signal Genaration (Synchronous with the fine time clock)
-------------------------------------------------------------------------------
  reset_tdc(0) <= RESET;

-------------------------------------------------------------------------------
-- COMPONENT INSTANTINIATIONS
-------------------------------------------------------------------------------
  --Reference time measurement
  The_Reference_Time : Reference_Channel
    generic map (
      CHANNEL_ID => 0)
    port map (
      RESET_200              => reset_tdc(0),
      RESET_100              => RESET,
      CLK_200                => CLK_TDC,
      CLK_100                => CLK_READOUT,
      HIT_IN                 => REFERENCE_TIME,
      READ_EN_IN             => rd_en_i(0),
      VALID_TMG_TRG_IN       => VALID_TIMING_TRG_IN,
      SPIKE_DETECTED_IN      => SPIKE_DETECTED_IN,
      MULTI_TMG_TRG_IN       => MULTI_TMG_TRG_IN,
      FIFO_DATA_OUT          => channel_data_i(0),
      FIFO_EMPTY_OUT         => channel_empty_i(0),
      FIFO_FULL_OUT          => channel_full_i(0),
      FIFO_ALMOST_FULL_OUT   => channel_almost_full_i(0),
      COARSE_COUNTER_IN      => coarse_cntr(1),
      EPOCH_COUNTER_IN       => epoch_cntr,
      TRIGGER_WINDOW_END_IN  => trg_win_end_200_pulse,
      DATA_FINISHED_IN       => data_finished_i,
      RUN_MODE               => readout_trigger_mode,
      TRIGGER_TIME_STAMP_OUT => trigger_time_i,
      REF_DEBUG_OUT          => ref_debug_i);

  -- Channel enable signals
  GEN_Channel_Enable : for i in 1 to CHANNEL_NUMBER-1 generate
    scaler_in_i(i) <= HIT_IN(i) and ch_en_i(i);
    hit_in_i(i)    <= scaler_in_i(i) and not(readout_busy);
  end generate GEN_Channel_Enable;

  -- Channels UR
  GEN_Channels : for i in 1 to CHANNEL_NUMBER - 1 generate
    Channels : Channel
      generic map (
        CHANNEL_ID => i)
      port map (
        RESET_200             => reset_tdc(0),
        RESET_100             => RESET,
        RESET_COUNTERS        => counters_reset_i,
        CLK_200               => CLK_TDC,
        CLK_100               => CLK_READOUT,
        HIT_IN                => hit_in_i(i),
        SCALER_IN             => scaler_in_i(i),
        READ_EN_IN            => rd_en_i(i),
        FIFO_DATA_OUT         => channel_data_i(i),
        FIFO_EMPTY_OUT        => channel_empty_i(i),
        FIFO_FULL_OUT         => channel_full_i(i),
        FIFO_ALMOST_FULL_OUT  => channel_almost_full_i(i),
        COARSE_COUNTER_IN     => coarse_cntr(integer(ceil(real(i)/real(16)))),
        EPOCH_COUNTER_IN      => epoch_cntr,
        TRIGGER_WINDOW_END_IN => trg_win_end_200_pulse,
        DATA_FINISHED_IN      => data_finished_i,
        RUN_MODE              => readout_trigger_mode,
        LOST_HIT_NUMBER       => channel_lost_hit_number(i),
        HIT_DETECT_NUMBER     => channel_hit_detect_number(i),
        ENCODER_START_NUMBER  => channel_encoder_start_number(i),
        FIFO_WR_NUMBER        => channel_fifo_wr_number(i),
        Channel_DEBUG         => channel_debug_i(i));
  end generate GEN_Channels;
  channel_data_i(CHANNEL_NUMBER) <= x"FFFFFFFF";

  GenCoarseCounter : for i in 1 to 4 generate
    -- Common Coarse counter
    TheCoarseCounter : up_counter
      generic map (
        NUMBER_OF_BITS => 11)
      port map (
        CLK       => CLK_TDC,
        RESET     => coarse_cntr_reset_r(i),
        COUNT_OUT => coarse_cntr(i),
        UP_IN     => '1');
  end generate GenCoarseCounter;

  -- Common Coarse Counter Overflow Counter
  TheEpochCounter : up_counter
    generic map (
      NUMBER_OF_BITS => 28)
    port map (
      CLK       => CLK_TDC,
      RESET     => epoch_cntr_reset_i,
      COUNT_OUT => epoch_cntr,
      UP_IN     => epoch_cntr_up_i);
  epoch_cntr_up_i    <= and_all(coarse_cntr(1));
  epoch_cntr_reset_i <= reset_tdc(0) or coarse_cntr_reset_r(1);

  -- Bus handler for the hit counter signals
  TheHitCounterBus : BusHandler
    generic map (
      BUS_LENGTH => CHANNEL_NUMBER-1)
    port map (
      RESET            => RESET,
      CLK              => CLK_READOUT,
      DATA_IN          => channel_level_hit_number_i,
      READ_EN_IN       => HCB_READ_EN_IN,
      WRITE_EN_IN      => HCB_WRITE_EN_IN,
      ADDR_IN          => HCB_ADDR_IN,
      DATA_OUT         => HCB_DATA_OUT,
      DATAREADY_OUT    => HCB_DATAREADY_OUT,
      UNKNOWN_ADDR_OUT => HCB_UNKNOWN_ADDR_OUT);

  GenHitCounterLevelSignals : for i in 1 to CHANNEL_NUMBER-1 generate
    channel_level_hit_number_i(i) <= scaler_in_i(i) & "0000000" & channel_hit_detect_number(i) when rising_edge(CLK_READOUT);
  end generate GenHitCounterLevelSignals;

  -- Trigger mode control register synchronised to the coarse counter clk
  Readout_trigger_mode_sync : bit_sync
    generic map (
      DEPTH => 3)
    port map (
      RESET => reset_tdc(0),
      CLK0  => CLK_READOUT,
      CLK1  => CLK_TDC,
      D_IN  => readout_trigger_mode,
      D_OUT => readout_trigger_mode_200);

  StartTrgWinCntSync : bit_sync
    generic map (
      DEPTH => 3)
    port map (
      RESET => reset_tdc(0),
      CLK0  => CLK_READOUT,
      CLK1  => CLK_TDC,
      D_IN  => start_trg_win_cnt_i,
      D_OUT => start_trg_win_cnt_200);

  StartTrgWinCntPulse : edge_to_pulse
    port map (
      clock     => CLK_TDC,
      en_clk    => '1',
      signal_in => start_trg_win_cnt_200,
      pulse     => start_trg_win_cnt_200_pulse);

  trg_win_post_200 <= TRG_WIN_POST when rising_edge(CLK_TDC);

  TriggerWinEndSync : bit_sync
    generic map (
      DEPTH => 3)
    port map (
      RESET => RESET,
      CLK0  => CLK_TDC,
      CLK1  => CLK_READOUT,
      D_IN  => trg_win_end_200,
      D_OUT => trg_win_end_100);

  TriggerWinEndPulse100 : edge_to_pulse
    port map (
      clock     => CLK_READOUT,
      en_clk    => '1',
      signal_in => trg_win_end_100,
      pulse     => trg_win_end_100_pulse);

  TriggerWinEndPulse200 : edge_to_pulse
    port map (
      clock     => CLK_TDC,
      en_clk    => '1',
      signal_in => trg_win_end_200,
      pulse     => trg_win_end_200_pulse);
-------------------------------------------------------------------------------
-- READOUT
-------------------------------------------------------------------------------

-- Coarse counter reset
  -- purpose: If the timing trigger is valid, the coarse time of the reference
  Coarse_Counter_Reset : process (CLK_TDC, reset_tdc(0))
  begin
    if rising_edge(CLK_TDC) then
      if reset_tdc(0) = '1' then
        coarse_cntr_reset <= '1';
      elsif readout_trigger_mode_200 = '1' then
        coarse_cntr_reset <= '0';
      else
        coarse_cntr_reset <= trg_win_end_200_pulse;
      end if;
    end if;
  end process Coarse_Counter_Reset;

  GenCoarseCounterReset : for i in 1 to 4 generate
    coarse_cntr_reset_r(i) <= coarse_cntr_reset when rising_edge(CLK_TDC);
  end generate GenCoarseCounterReset;

  GENFifoFullHistory : for i in 0 to CHANNEL_NUMBER - 1 generate
    FifoFullHistory : process (CLK_READOUT, RESET)
    begin
      if rising_edge(CLK_READOUT) then
        if RESET = '1' then
          channel_full_reg(i) <= '0';
        elsif channel_full_i(i) = '1' then
          channel_full_reg(i) <= '1';
        elsif channel_empty_i(i) = '1' then
          channel_full_reg(i) <= '0';
        end if;
      end if;
    end process FifoFullHistory;
  end generate GENFifoFullHistory;

  FSM_READOUT_BUSY : process (FSM_RDO_BUSY_STATE, trg_win_end_200_pulse, data_finished_reg, HIT_IN)
  begin
    FSM_RDO_BUSY_STATE <= NOT_BUSY;
    readout_busy       <= '0';

    case FSM_RDO_BUSY_STATE is
      when NOT_BUSY =>
        if trg_win_end_200_pulse = '1' then
          FSM_RDO_BUSY_STATE <= BUSY;
        else
          FSM_RDO_BUSY_STATE <= NOT_BUSY;
        end if;
        readout_busy <= '0';

      when BUSY =>
        if data_finished_reg = '1' then
          FSM_RDO_BUSY_STATE <= WAIT_FOR_SILINCE;  -- waits until the hit input is zero
        else
          FSM_RDO_BUSY_STATE <= BUSY;
        end if;
        readout_busy <= '1';

      when WAIT_FOR_SILINCE =>
        if or_all(HIT_IN) = '0' then
          FSM_RDO_BUSY_STATE <= NOT_BUSY;
        else
          FSM_RDO_BUSY_STATE <= WAIT_FOR_SILINCE;
        end if;
        readout_busy <= '1';
        
      when others =>
        FSM_RDO_BUSY_STATE <= NOT_BUSY;
    end case;
  end process FSM_READOUT_BUSY;

-------------------------------------------------------------------------------

-- Trigger Window

  --purpose: Generates trigger window end signal
  Check_Trg_Win_End_Conrollers : process (CLK_TDC)
  begin
    if rising_edge(CLK_TDC) then
      if reset_tdc(0) = '1' then
        trg_win_end_200 <= '0';
        trg_win_cnt     <= '1' & trg_win_post_200;
      elsif start_trg_win_cnt_200_pulse = '1' then
        trg_win_end_200 <= '0';
        trg_win_cnt     <= "000000000001";
      elsif trg_win_cnt(10 downto 0) = trg_win_post_200 then
        trg_win_end_200 <= '1';
        trg_win_cnt(11) <= '1';
      else
        trg_win_end_200 <= '0';
        trg_win_cnt     <= std_logic_vector(unsigned(trg_win_cnt) + to_unsigned(1, 1));
      end if;
    end if;
  end process Check_Trg_Win_End_Conrollers;

  --purpose: Calculates the position of the trigger window edges
  Trg_Win_Calculation : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        TW_pre  <= (others => '0');
        TW_post <= (others => '0');
      else
        TW_pre  <= std_logic_vector(to_unsigned(to_integer(unsigned(trigger_time_i)) - to_integer(unsigned(TRG_WIN_PRE)), 39));
        TW_post <= std_logic_vector(to_unsigned(to_integer(unsigned(trigger_time_i)) + to_integer(unsigned(TRG_WIN_POST)), 39));
      end if;
    end if;
  end process Trg_Win_Calculation;

  --purpose: Channel Hit Time Determination
  ChannelEpochCounter : process (CLK_READOUT)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        channel_epoch_cntr_i <= (others => '0');
      elsif channel_empty_3reg(fifo_nr_reg) = '1' and channel_empty_4reg(fifo_nr_reg) = '0' then
        channel_epoch_cntr_i <= (others => '0');
      elsif channel_data_reg(fifo_nr_reg)(31 downto 29) = "011" then
        channel_epoch_cntr_i <= channel_data_reg(fifo_nr_reg)(27 downto 0);
      end if;
    end if;
  end process ChannelEpochCounter;

  --purpose: Channel Hit Time Determination
  ChannelHitTime : process (CLK_READOUT)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        channel_hit_time <= (others => '0');
      elsif channel_data_reg(fifo_nr_reg)(31) = '1' then
        channel_hit_time <= channel_epoch_cntr_i & channel_data_reg(fifo_nr_reg)(10 downto 0);
      elsif channel_data_reg(fifo_nr_reg)(31 downto 29) = "011" then
        channel_hit_time <= (others => '0');
      end if;
    end if;
  end process ChannelHitTime;

  --purpose: Controls if the data coming from the channel is greater than the
  --trigger window pre-edge
  Check_Trg_Win_Left : process (RESET, TW_pre, channel_hit_time)
  begin
--    if rising_edge(CLK_READOUT) then
    if RESET = '1' then
      trg_win_l <= '0';
    elsif to_integer(unsigned(TW_pre)) <= to_integer(unsigned(channel_hit_time)) then
      trg_win_l <= '1';
    else
      trg_win_l <= '0';
    end if;
--    end if;
  end process Check_Trg_Win_Left;

  --purpose: Controls if the data coming from the channel is smaller than the
  --trigger window post-edge
  Check_Trg_Win_Right : process (RESET, TW_post, channel_hit_time)
  begin
--    if rising_edge(CLK_READOUT) then
    if RESET = '1' then
      trg_win_r <= '0';
    elsif to_integer(unsigned(channel_hit_time)) <= to_integer(unsigned(TW_post)) then
      trg_win_r <= '1';
    else
      trg_win_r <= '0';
    end if;
--    end if;
  end process Check_Trg_Win_Right;
-------------------------------------------------------------------------------
-- Creating mask and Generating the fifo nr to be read

  -- purpose: Creats and updates the mask to determine the non-empty FIFOs
  CREAT_MASK : process (CLK_READOUT)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        mask_i         <= (others => '1');
        empty_channels <= (others => '1');
      elsif trg_win_end_100_pulse = '1' then
        mask_i(CHANNEL_NUMBER-1 downto 0)         <= channel_empty_i(CHANNEL_NUMBER-1 downto 0);
        empty_channels(CHANNEL_NUMBER-1 downto 0) <= channel_empty_i(CHANNEL_NUMBER-1 downto 0);
      elsif updt_mask_i = '1' then
        mask_i(fifo_nr) <= '1';
      end if;
    end if;
  end process CREAT_MASK;

  GEN : for i in 0 to 8 generate
    ROM : ROM_FIFO
      port map (
        Address    => mask_i(8*(i+1)-1 downto 8*i),
        OutClock   => CLK_READOUT,
        OutClockEn => '1',
        Reset      => RESET,
        Q          => fifo_nr_hex(i));
  end generate GEN;

  -- purpose: Generates number of the FIFO, to be read, in integer
  CON_FIFO_NR_HEX_TO_INT : process (CLK_READOUT)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        fifo_nr_next <= CHANNEL_NUMBER;
      elsif fifo_nr_hex(0)(3) /= '1' then
        fifo_nr_next <= to_integer("00000" & unsigned(fifo_nr_hex(0)(2 downto 0)));
      elsif fifo_nr_hex(1)(3) /= '1' then
        fifo_nr_next <= to_integer("00001" & unsigned(fifo_nr_hex(1)(2 downto 0)));
      elsif fifo_nr_hex(2)(3) /= '1' then
        fifo_nr_next <= to_integer("00010" & unsigned(fifo_nr_hex(2)(2 downto 0)));
      elsif fifo_nr_hex(3)(3) /= '1' then
        fifo_nr_next <= to_integer("00011" & unsigned(fifo_nr_hex(3)(2 downto 0)));
      elsif fifo_nr_hex(4)(3) /= '1' then
        fifo_nr_next <= to_integer("00100" & unsigned(fifo_nr_hex(4)(2 downto 0)));
      elsif fifo_nr_hex(5)(3) /= '1' then
        fifo_nr_next <= to_integer("00101" & unsigned(fifo_nr_hex(5)(2 downto 0)));
      elsif fifo_nr_hex(6)(3) /= '1' then
        fifo_nr_next <= to_integer("00110" & unsigned(fifo_nr_hex(6)(2 downto 0)));
      elsif fifo_nr_hex(7)(3) /= '1' then
        fifo_nr_next <= to_integer("00111" & unsigned(fifo_nr_hex(7)(2 downto 0)));
      elsif fifo_nr_hex(8)(3) /= '1' then
        fifo_nr_next <= to_integer("01000" & unsigned(fifo_nr_hex(8)(2 downto 0)));
      else
        fifo_nr_next <= CHANNEL_NUMBER;
      end if;
    end if;
  end process CON_FIFO_NR_HEX_TO_INT;

  --purpose: Updates the index number for the array signals
  UPDATE_INDEX_NR : process (CLK_READOUT)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        fifo_nr <= CHANNEL_NUMBER;
      elsif updt_index_reg = '1' then
        fifo_nr <= fifo_nr_next;
      end if;
    end if;
  end process UPDATE_INDEX_NR;
  fifo_nr_reg <= fifo_nr when rising_edge(CLK_READOUT);
-------------------------------------------------------------------------------
-- Data Out, Data Write and Data Finished assigning according to the control
-- signals from the readout final-state-machine.

  Data_Out_MUX : process (CLK_READOUT, RESET)
    variable i : integer := 0;
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        data_out_reg  <= (others => '1');
        data_wr_reg   <= '0';
        stop_status_i <= '0';
      elsif wr_header_i = '1' then
        data_out_reg  <= "001" & "00000" & TRG_CODE_IN & header_error_bits;
        data_wr_reg   <= '1';
        stop_status_i <= '0';
      elsif wr_ch_data_2reg = '1' then
        if trigger_win_en = '1' then    -- if the trigger window is enabled
          if channel_data_2reg(fifo_nr)(31 downto 29) = "011" then
            data_out_reg <= channel_data_2reg(fifo_nr);
            data_wr_reg  <= '1';
            --elsif (TW_pre(10) = '1' and ref_time_coarse(10) = '0') or (TW_post(10) = '0' and ref_time_coarse(10) = '1') then  -- if one of the trigger window edges has an overflow
            --  if (trg_win_l = '0' and trg_win_r = '1') or (trg_win_l = '1' and trg_win_r = '0') then
            --    data_out_reg <= channel_data_2reg(fifo_nr);
            --    data_wr_reg  <= '1';
            --  else
            --    data_out_reg <= (others => '1');
            --    data_wr_reg  <= '0';
            --  end if;
          else  -- if both of the trigger window edges are in the coarse counter boundries
            if (trg_win_l = '1' and trg_win_r = '1') then
              data_out_reg <= channel_data_2reg(fifo_nr);
              data_wr_reg  <= '1';
            else
              data_out_reg <= (others => '1');
              data_wr_reg  <= '0';
            end if;
          end if;
          stop_status_i <= '0';
        elsif trigger_win_en = '0' then
          data_out_reg  <= channel_data_2reg(fifo_nr);
          data_wr_reg   <= '1';
          stop_status_i <= '0';
        end if;
      elsif wr_status_i = '1' then
        case i is
          when 0  => data_out_reg <= "010" & "00000" & std_logic_vector(trig_number);
          when 1  => data_out_reg <= "010" & "00001" & std_logic_vector(release_number);
          when 2  => data_out_reg <= "010" & "00010" & std_logic_vector(valid_tmg_trig_number);
          when 3  => data_out_reg <= "010" & "00011" & std_logic_vector(valid_NOtmg_trig_number);
          when 4  => data_out_reg <= "010" & "00100" & std_logic_vector(invalid_trig_number);
          when 5  => data_out_reg <= "010" & "00101" & std_logic_vector(multi_tmg_trig_number);
          when 6  => data_out_reg <= "010" & "00110" & std_logic_vector(spurious_trig_number);
          when 7  => data_out_reg <= "010" & "00111" & std_logic_vector(wrong_readout_number);
          when 8  => data_out_reg <= "010" & "01000" & std_logic_vector(spike_number);
          when 9  => data_out_reg <= "010" & "01001" & std_logic_vector(idle_time);
          when 10 => data_out_reg <= "010" & "01010" & std_logic_vector(wait_time);
          when 11 => data_out_reg <= "010" & "01011" & std_logic_vector(total_empty_channel);
          when 12 => data_out_reg <= "010" & "01100" & std_logic_vector(readout_time);
                     stop_status_i <= '1';
          when 13 => data_out_reg <= "010" & "01101" & std_logic_vector(timeout_number);
                     i := -1;
          when others => null;
        end case;
        data_wr_reg <= '1';
        i           := i+1;
      elsif wr_trailer_i = '1' then
        data_out_reg  <= "011" & "0000000000000" & trailer_error_bits;
        data_wr_reg   <= '1';
        stop_status_i <= '0';
      else
        data_out_reg  <= (others => '1');
        data_wr_reg   <= '0';
        stop_status_i <= '0';
      end if;
    end if;
  end process Data_Out_MUX;

  DATA_OUT          <= data_out_reg;
  DATA_WRITE_OUT    <= data_wr_reg;
  DATA_FINISHED_OUT <= data_finished_reg;
  TRG_RELEASE_OUT   <= trg_release_reg;
  TRG_STATUSBIT_OUT <= trg_statusbit_reg;

-----------------------------------------------------------------------------
-- Data delay

  channel_data_reg   <= channel_data_i     when rising_edge(CLK_READOUT);
  channel_empty_reg  <= channel_empty_i    when rising_edge(CLK_READOUT);
  channel_data_2reg  <= channel_data_reg   when rising_edge(CLK_READOUT);
  channel_empty_2reg <= channel_empty_reg  when rising_edge(CLK_READOUT);
  channel_data_3reg  <= channel_data_2reg  when rising_edge(CLK_READOUT);
  channel_empty_3reg <= channel_empty_2reg when rising_edge(CLK_READOUT);
  channel_empty_4reg <= channel_empty_3reg when rising_edge(CLK_READOUT);

-------------------------------------------------------------------------------
-- Readout Final-State-Machine
-------------------------------------------------------------------------------

--purpose: FSM for writing data
  FSM_CLK : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        FSM_CURRENT         <= IDLE;
        start_trg_win_cnt_i <= '0';
        fsm_debug_reg       <= x"00";
        updt_index_i        <= '0';
        updt_index_reg      <= '0';
        updt_mask_i         <= '0';
        rd_en_i             <= (others => '0');
        wr_ch_data_i        <= '0';
        wr_ch_data_reg      <= '0';
        wr_ch_data_2reg     <= '0';
        wr_header_i         <= '0';
        wr_status_i         <= '0';
        data_finished_i     <= '0';
        data_finished_reg   <= '0';
        trg_release_reg     <= '0';
        wrong_readout_i     <= '0';
        idle_i              <= '0';
        readout_i           <= '0';
        wait_i              <= '0';
      else
        FSM_CURRENT         <= FSM_NEXT;
        start_trg_win_cnt_i <= start_trg_win_cnt_fsm;
        fsm_debug_reg       <= fsm_debug_fsm;
        updt_index_i        <= updt_index_fsm;
        updt_index_reg      <= updt_index_i;
        updt_mask_i         <= updt_mask_fsm;
        rd_en_i             <= rd_en_fsm;
        wr_ch_data_i        <= wr_ch_data_fsm;
        wr_ch_data_reg      <= wr_ch_data_i;
        wr_ch_data_2reg     <= wr_ch_data_reg;
        wr_header_i         <= wr_header_fsm;
        wr_status_i         <= wr_status_fsm;
        data_finished_i     <= data_finished_fsm;
        data_finished_reg   <= data_finished_i;
        trg_release_reg     <= trg_release_fsm;
        wrong_readout_i     <= wrong_readout_fsm;
        idle_i              <= idle_fsm;
        readout_i           <= readout_fsm;
        wait_i              <= wait_fsm;
      end if;
    end if;
  end process FSM_CLK;

  FSM_PROC : process (FSM_CURRENT, VALID_TIMING_TRG_IN, VALID_NOTIMING_TRG_IN, trg_win_end_100_pulse, fifo_nr_next,
                      fifo_nr, channel_empty_reg, TRG_DATA_VALID_IN, INVALID_TRG_IN, TMGTRG_TIMEOUT_IN,
                      TRG_TYPE_IN, SPURIOUS_TRG_IN, stop_status_i, debug_mode_en_i)
  begin

    start_trg_win_cnt_fsm <= '0';
    updt_index_fsm        <= '0';
    updt_mask_fsm         <= '0';
    rd_en_fsm             <= (others => '0');
    wr_ch_data_fsm        <= '0';
    wr_header_fsm         <= '0';
    data_finished_fsm     <= '0';
    trg_release_fsm       <= '0';
    wrong_readout_fsm     <= '0';
    idle_fsm              <= '0';
    readout_fsm           <= '0';
    wait_fsm              <= '0';
    wr_status_fsm         <= '0';
    fsm_debug_fsm         <= x"00";
    FSM_NEXT              <= IDLE;

    case (FSM_CURRENT) is
      when IDLE =>
        if VALID_TIMING_TRG_IN = '1' then
          FSM_NEXT              <= WAIT_FOR_TRG_WIND_END;
          start_trg_win_cnt_fsm <= '1';
        elsif VALID_NOTIMING_TRG_IN = '1' then
          if TRG_TYPE_IN = x"E" then
            FSM_NEXT <= SEND_STATUS;
          else
            FSM_NEXT <= SEND_TRG_RELEASE_A;
          end if;
          wr_header_fsm <= '1';
        elsif INVALID_TRG_IN = '1' then
          FSM_NEXT          <= SEND_TRG_RELEASE_A;
          data_finished_fsm <= '1';
        else
          FSM_NEXT <= IDLE;
        end if;
        idle_fsm      <= '1';
        fsm_debug_fsm <= x"01";
--
      when WAIT_FOR_TRG_WIND_END =>
        if trg_win_end_100_pulse = '1' then
          FSM_NEXT <= WR_HEADER;
        else
          FSM_NEXT <= WAIT_FOR_TRG_WIND_END;
        end if;
        wait_fsm      <= '1';
        fsm_debug_fsm <= x"02";
-------------------------------------------------------------------------------
-- Readout process starts
      when WR_HEADER =>
        FSM_NEXT      <= WAIT_FOR_FIFO_NR_A;
        wr_header_fsm <= '1';
        readout_fsm   <= '1';
        fsm_debug_fsm <= x"03";

      when WAIT_FOR_FIFO_NR_A =>
        FSM_NEXT       <= WAIT_FOR_FIFO_NR_B;
        updt_index_fsm <= '1';
        wait_fsm       <= '1';
        fsm_debug_fsm  <= x"04";

      when WAIT_FOR_FIFO_NR_B =>
        FSM_NEXT      <= APPLY_MASK;
        wait_fsm      <= '1';
        fsm_debug_fsm <= x"05";

      when APPLY_MASK =>
        if fifo_nr_next = CHANNEL_NUMBER then
          if debug_mode_en_i = '1' then
            FSM_NEXT <= SEND_STATUS;
          else
            FSM_NEXT          <= WAIT_FOR_LVL1_TRG_A;
            data_finished_fsm <= '1';
          end if;
        else
          FSM_NEXT                <= RD_CHANNEL_A;
          rd_en_fsm(fifo_nr_next) <= '1';
          updt_mask_fsm           <= '1';
        end if;
        wait_fsm      <= '1';
        fsm_debug_fsm <= x"06";

      when RD_CHANNEL_A =>
        FSM_NEXT           <= RD_CHANNEL_B;
        rd_en_fsm(fifo_nr) <= '1';
        readout_fsm        <= '1';
        fsm_debug_fsm      <= x"07";
        
      when RD_CHANNEL_B =>
--        if channel_full_reg(fifo_nr) = '1' then
--          wr_ch_data_fsm <= '1';
--        end if;
        FSM_NEXT           <= RD_CHANNEL_C;
        rd_en_fsm(fifo_nr) <= '1';
        readout_fsm        <= '1';
        fsm_debug_fsm      <= x"08";
        
      when RD_CHANNEL_C =>
        if channel_empty_reg(fifo_nr) = '1' then
          FSM_NEXT       <= WAIT_FOR_FIFO_NR_B;
          wr_ch_data_fsm <= '0';
          updt_index_fsm <= '1';
        else
          FSM_NEXT           <= RD_CHANNEL_C;
          wr_ch_data_fsm     <= '1';
          rd_en_fsm(fifo_nr) <= '1';
        end if;
        readout_fsm   <= '1';
        fsm_debug_fsm <= x"09";
-------------------------------------------------------------------------------
      when WAIT_FOR_LVL1_TRG_A =>
        if TRG_DATA_VALID_IN = '1' then
          FSM_NEXT <= WAIT_FOR_LVL1_TRG_B;
        elsif TMGTRG_TIMEOUT_IN = '1' then
          FSM_NEXT <= IDLE;
        else
          FSM_NEXT <= WAIT_FOR_LVL1_TRG_A;
        end if;
        wait_fsm      <= '1';
        fsm_debug_fsm <= x"0A";
--
      when WAIT_FOR_LVL1_TRG_B =>
        FSM_NEXT      <= WAIT_FOR_LVL1_TRG_C;
        wait_fsm      <= '1';
        fsm_debug_fsm <= x"0B";
--
      when WAIT_FOR_LVL1_TRG_C =>
        if SPURIOUS_TRG_IN = '1' then
          wrong_readout_fsm <= '1';
        end if;
        FSM_NEXT      <= SEND_TRG_RELEASE_A;
        wait_fsm      <= '1';
        fsm_debug_fsm <= x"0C";
--
      when SEND_STATUS =>  -- here the status of the TDC should be sent
        if stop_status_i = '1' then
          if debug_mode_en_i = '1' then
            FSM_NEXT <= WAIT_FOR_LVL1_TRG_A;
          else
            FSM_NEXT <= SEND_TRG_RELEASE_A;
          end if;
          data_finished_fsm <= '1';
        else
          FSM_NEXT      <= SEND_STATUS;
          wr_status_fsm <= '1';
        end if;
        fsm_debug_fsm <= x"0D";
--
      when SEND_TRG_RELEASE_A =>
        FSM_NEXT        <= SEND_TRG_RELEASE_B;
        trg_release_fsm <= '1';
        fsm_debug_fsm   <= x"0E";
--
      when SEND_TRG_RELEASE_B =>
        FSM_NEXT      <= IDLE;
        fsm_debug_fsm <= x"0F";
--
      when others =>
        FSM_NEXT      <= IDLE;
        fsm_debug_fsm <= x"FF";
    end case;
  end process FSM_PROC;

-------------------------------------------------------------------------------
-- Header-Trailor Error & Warning Bits
-------------------------------------------------------------------------------
-- Error, warning bits set in the header
  header_error_bits(15 downto 3) <= (others => '0');
  header_error_bits(0)           <= '0';
--header_error_bits(0) <= lost_hit_i;  -- if there is at least one lost hit (can be more if the FIFO is full).
  header_error_bits(1)           <= fifo_full_i;  -- if the channel FIFO is full.
  header_error_bits(2)           <= fifo_almost_full_i;  -- if the channel FIFO is almost full.

-- Error, warning bits set in the trailer
  trailer_error_bits <= (others => '0');
-- trailer_error_bits (0) <= wrong_readout_i;  -- if there is a wrong readout because of a spurious timing trigger.

  fifo_full_i        <= or_all(channel_full_i);
  fifo_almost_full_i <= or_all(channel_almost_full_i);

-------------------------------------------------------------------------------
-- Debug and statistics words
-------------------------------------------------------------------------------

  edge_to_pulse_1 : edge_to_pulse
    port map (
      clock     => CLK_READOUT,
      en_clk    => '1',
      signal_in => VALID_TIMING_TRG_IN,
      pulse     => valid_timing_trg_pulse);

  edge_to_pulse_2 : edge_to_pulse
    port map (
      clock     => CLK_READOUT,
      en_clk    => '1',
      signal_in => VALID_NOTIMING_TRG_IN,
      pulse     => valid_notiming_trg_pulse);

  edge_to_pulse_3 : edge_to_pulse
    port map (
      clock     => CLK_READOUT,
      en_clk    => '1',
      signal_in => INVALID_TRG_IN,
      pulse     => invalid_trg_pulse);

  edge_to_pulse_4 : edge_to_pulse
    port map (
      clock     => CLK_READOUT,
      en_clk    => '1',
      signal_in => MULTI_TMG_TRG_IN,
      pulse     => multi_tmg_trg_pulse);

  edge_to_pulse_5 : edge_to_pulse
    port map (
      clock     => CLK_READOUT,
      en_clk    => '1',
      signal_in => SPURIOUS_TRG_IN,
      pulse     => spurious_trg_pulse);

  edge_to_pulse_6 : edge_to_pulse
    port map (
      clock     => CLK_READOUT,
      en_clk    => '1',
      signal_in => SPIKE_DETECTED_IN,
      pulse     => spike_detected_pulse);

  edge_to_pulse_7 : edge_to_pulse
    port map (
      clock     => CLK_READOUT,
      en_clk    => '1',
      signal_in => TMGTRG_TIMEOUT_IN,
      pulse     => timeout_detected_pulse);

-- purpose: Internal trigger number counter (only valid triggers)
  Statistics_Trigger_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' or counters_reset_i = '1' then
        trig_number <= (others => '0');
      elsif valid_timing_trg_pulse = '1' or valid_notiming_trg_pulse = '1' then
        trig_number <= trig_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Trigger_Number;

-- purpose: Internal release number counter
  Statistics_Release_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' or counters_reset_i = '1' then
        release_number <= (others => '0');
      elsif trg_release_reg = '1' then
        release_number <= release_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Release_Number;

-- purpose: Internal valid timing trigger number counter
  Statistics_Valid_Timing_Trigger_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' or counters_reset_i = '1' then
        valid_tmg_trig_number <= (others => '0');
      elsif valid_timing_trg_pulse = '1' then
        valid_tmg_trig_number <= valid_tmg_trig_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Valid_Timing_Trigger_Number;

-- purpose: Internal valid NOtiming trigger number counter
  Statistics_Valid_NoTiming_Trigger_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' or counters_reset_i = '1' then
        valid_NOtmg_trig_number <= (others => '0');
      elsif valid_notiming_trg_pulse = '1' then
        valid_NOtmg_trig_number <= valid_NOtmg_trig_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Valid_NoTiming_Trigger_Number;

-- purpose: Internal invalid trigger number counter
  Statistics_Invalid_Trigger_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' or counters_reset_i = '1' then
        invalid_trig_number <= (others => '0');
      elsif invalid_trg_pulse = '1' then
        invalid_trig_number <= invalid_trig_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Invalid_Trigger_Number;

-- purpose: Internal multi timing trigger number counter
  Statistics_Multi_Timing_Trigger_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' or counters_reset_i = '1' then
        multi_tmg_trig_number <= (others => '0');
      elsif multi_tmg_trg_pulse = '1' then
        multi_tmg_trig_number <= multi_tmg_trig_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Multi_Timing_Trigger_Number;

-- purpose: Internal spurious trigger number counter
  Statistics_Spurious_Trigger_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' or counters_reset_i = '1' then
        spurious_trig_number <= (others => '0');
      elsif spurious_trg_pulse = '1' then
        spurious_trig_number <= spurious_trig_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Spurious_Trigger_Number;

-- purpose: Number of wrong readout becasue of spurious trigger
  Statistics_Wrong_Readout_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' or counters_reset_i = '1' then
        wrong_readout_number <= (others => '0');
      elsif wrong_readout_i = '1' then
        wrong_readout_number <= wrong_readout_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Wrong_Readout_Number;

-- purpose: Internal spike number counter
  Statistics_Spike_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' or counters_reset_i = '1' then
        spike_number <= (others => '0');
      elsif spike_detected_pulse = '1' then
        spike_number <= spike_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Spike_Number;

-- purpose: Internal timeout number counter
  Statistics_Timeout_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' or counters_reset_i = '1' then
        timeout_number <= (others => '0');
      elsif timeout_detected_pulse = '1' then
        timeout_number <= timeout_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Timeout_Number;

-- purpose: IDLE time of the TDC readout
  Statistics_Idle_Time : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' or counters_reset_i = '1' then
        idle_time <= (others => '0');
      elsif idle_i = '1' then
        idle_time <= idle_time + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Idle_Time;

-- purpose: Readout and Wait time of the TDC readout
  Statistics_Readout_Wait_Time : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' or counters_reset_i = '1' then
        readout_time <= (others => '0');
        wait_time    <= (others => '0');
      elsif readout_i = '1' then
        readout_time <= readout_time + to_unsigned(1, 1);
      elsif wait_i = '1' then
        wait_time <= wait_time + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Readout_Wait_Time;

-- purpose: Empty channel number
  Statistics_Empty_Channel_Number : process (CLK_READOUT, RESET)
    variable i : integer := CHANNEL_NUMBER;
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' or counters_reset_i = '1' then
        total_empty_channel <= (others => '0');
        i                   := CHANNEL_NUMBER;
      elsif trg_win_end_100_pulse = '1' then
        i := 0;
      elsif i = CHANNEL_NUMBER then
        i := i;
      elsif empty_channels(i) = '1' then
        total_empty_channel <= total_empty_channel + to_unsigned(1, 1);
        i                   := i + 1;
      else
        i := i + 1;
      end if;
    end if;
  end process Statistics_Empty_Channel_Number;


-------------------------------------------------------------------------------
-- Logic Analyser Signals
-------------------------------------------------------------------------------
-- Logic Analyser and Test Signals
  REG_LOGIC_ANALYSER_OUTPUT : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        logic_analyser_reg <= (others => '0');
      elsif logic_anal_control = x"1" then  -- TRBNET connections debugging
        logic_analyser_reg(7 downto 0) <= fsm_debug_reg;
        logic_analyser_reg(8)          <= REFERENCE_TIME;
        logic_analyser_reg(9)          <= VALID_TIMING_TRG_IN;
        logic_analyser_reg(10)         <= VALID_NOTIMING_TRG_IN;
        logic_analyser_reg(11)         <= INVALID_TRG_IN;
        logic_analyser_reg(12)         <= TRG_DATA_VALID_IN;
        logic_analyser_reg(13)         <= data_wr_reg;
        logic_analyser_reg(14)         <= data_finished_reg;
        logic_analyser_reg(15)         <= trg_release_reg;

      elsif logic_anal_control = x"2" then  -- Reference channel debugging
        logic_analyser_reg <= ref_debug_i(15 downto 0);

      elsif logic_anal_control = x"3" then  -- Data out
        logic_analyser_reg(7 downto 0)   <= fsm_debug_reg;
        logic_analyser_reg(8)            <= REFERENCE_TIME;
        logic_analyser_reg(9)            <= data_wr_reg;
        logic_analyser_reg(15 downto 10) <= data_out_reg(27 downto 22);

        --elsif logic_anal_control = x"4" then  -- channel debugging
        --  logic_analyser_reg <= channel_debug_i(1)(15 downto 0);
      end if;
    end if;
  end process REG_LOGIC_ANALYSER_OUTPUT;

  LOGIC_ANALYSER_OUT <= logic_analyser_reg;
-------------------------------------------------------------------------------
-- STATUS REGISTERS
-------------------------------------------------------------------------------

-- Register 0x80
  SLOW_CONTROL_REG_OUT(7 downto 0)  <= fsm_debug_reg;
  SLOW_CONTROL_REG_OUT(15 downto 8) <= std_logic_vector(to_unsigned(CHANNEL_NUMBER-1, 8));
  SLOW_CONTROL_REG_OUT(16)          <= REFERENCE_TIME when rising_edge(CLK_READOUT);
--
--  SLOW_CONTROL_REG_OUT(27 downto 24)          <= 
--
--  SLOW_CONTROL_REG_OUT(31 downto 28)          <= 

-- Register 0x81 & 0x82
  SLOW_CONTROL_REG_OUT(1*32+CHANNEL_NUMBER-2 downto 1*32+0) <= channel_empty_2reg(CHANNEL_NUMBER-1 downto 1);

-- Register 0x83
  SLOW_CONTROL_REG_OUT(3*32+31 downto 3*32+0) <= "00000" & TRG_WIN_POST & "00000" & TRG_WIN_PRE;

-- Register 0x84
  SLOW_CONTROL_REG_OUT(4*32+23 downto 4*32+0) <= std_logic_vector(trig_number);

-- Register 0x85
  SLOW_CONTROL_REG_OUT(5*32+23 downto 5*32+0) <= std_logic_vector(valid_tmg_trig_number);

-- Register 0x86
  SLOW_CONTROL_REG_OUT(6*32+23 downto 6*32+0) <= std_logic_vector(valid_NOtmg_trig_number);

-- Register 0x87
  SLOW_CONTROL_REG_OUT(7*32+23 downto 7*32+0) <= std_logic_vector(invalid_trig_number);

-- Register 0x88
  SLOW_CONTROL_REG_OUT(8*32+23 downto 8*32+0) <= std_logic_vector(multi_tmg_trig_number);

-- Register 0x89
  SLOW_CONTROL_REG_OUT(9*32+23 downto 9*32+0) <= std_logic_vector(spurious_trig_number);

-- Register 0x8a
  SLOW_CONTROL_REG_OUT(10*32+23 downto 10*32+0) <= std_logic_vector(wrong_readout_number);

-- Register 0x8b
  SLOW_CONTROL_REG_OUT(11*32+23 downto 11*32+0) <= std_logic_vector(spike_number);

-- Register 0x8c
  SLOW_CONTROL_REG_OUT(12*32+23 downto 12*32+0) <= std_logic_vector(idle_time);

-- Register 0x8d
  SLOW_CONTROL_REG_OUT(13*32+23 downto 13*32+0) <= std_logic_vector(wait_time);

-- Register 0x8e
  SLOW_CONTROL_REG_OUT(14*32+23 downto 14*32+0) <= std_logic_vector(total_empty_channel);

-- Register 0x8f
  SLOW_CONTROL_REG_OUT(15*32+23 downto 15*32+0) <= std_logic_vector(release_number);

-- Register 0x90
  SLOW_CONTROL_REG_OUT(16*32+23 downto 16*32+0) <= std_logic_vector(readout_time);

-- Register 0x91
  SLOW_CONTROL_REG_OUT(17*32+23 downto 17*32+0) <= std_logic_vector(timeout_number);

---- Register 0x93
--  SLOW_CONTROL_REG_OUT(19*32+7 downto 19*32+0) <= scaler_number_i;

---- Register 0x94
--  SLOW_CONTROL_REG_OUT(20*32+23 downto 20*32+0) <= channel_hit_detect_number(1);

---- Register 0x95
--  SLOW_CONTROL_REG_OUT(21*32+23 downto 21*32+0) <= channel_hit_detect_number(2);

---- Register 0x96
--SLOW_CONTROL_REG_OUT(22*32+23 downto 22*32+0) <= channel_hit_detect_number(3);

---- Register 0x97
--SLOW_CONTROL_REG_OUT(23*32+23 downto 23*32+0) <= channel_hit_detect_number(4);

---- Register 0x98
--  SLOW_CONTROL_REG_OUT(24*32+23 downto 24*32+0) <= channel_hit_detect_number(5);

---- Register 0x99
--  SLOW_CONTROL_REG_OUT(25*32+23 downto 25*32+0) <= channel_hit_detect_number(6);

---- Register 0x9a
--  SLOW_CONTROL_REG_OUT(26*32+23 downto 26*32+0) <= channel_hit_detect_number(7);

---- Register 0x9f
--  SLOW_CONTROL_REG_OUT(27*32+23 downto 27*32+0) <= channel_hit_detect_number(8);

end TDC;
