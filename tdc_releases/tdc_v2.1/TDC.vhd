library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.config.all;
use work.tdc_components.all;
use work.version.all;

entity TDC is
  generic (
    CHANNEL_NUMBER : integer range 2 to 65;
    STATUS_REG_NR  : integer range 0 to 31;
    CONTROL_REG_NR : integer range 0 to 6;
    TDC_VERSION    : std_logic_vector(11 downto 0);
    DEBUG          : integer range 0 to 1 := c_NO;
    SIMULATION     : integer range 0 to 1 := c_NO);
  port (
    RESET                 : in  std_logic;
    CLK_TDC               : in  std_logic;
    CLK_READOUT           : in  std_logic;
    REFERENCE_TIME        : in  std_logic;
    HIT_IN                : in  std_logic_vector(CHANNEL_NUMBER-1 downto 1);
    HIT_CAL_IN            : in  std_logic;
    TRG_WIN_PRE           : in  std_logic_vector(10 downto 0);
    TRG_WIN_POST          : in  std_logic_vector(10 downto 0);
--
    -- Trigger signals from handler
    TRG_DATA_VALID_IN     : in  std_logic                     := '0';
    VALID_TIMING_TRG_IN   : in  std_logic                     := '0';
    VALID_NOTIMING_TRG_IN : in  std_logic                     := '0';
    INVALID_TRG_IN        : in  std_logic                     := '0';
    TMGTRG_TIMEOUT_IN     : in  std_logic                     := '0';
    SPIKE_DETECTED_IN     : in  std_logic                     := '0';
    MULTI_TMG_TRG_IN      : in  std_logic                     := '0';
    SPURIOUS_TRG_IN       : in  std_logic                     := '0';
--
    TRG_NUMBER_IN         : in  std_logic_vector(15 downto 0) := (others => '0');
    TRG_CODE_IN           : in  std_logic_vector(7 downto 0)  := (others => '0');
    TRG_INFORMATION_IN    : in  std_logic_vector(23 downto 0) := (others => '0');
    TRG_TYPE_IN           : in  std_logic_vector(3 downto 0)  := (others => '0');
--
    --Response to handler
    TRG_RELEASE_OUT       : out std_logic;
    TRG_STATUSBIT_OUT     : out std_logic_vector(31 downto 0);
    DATA_OUT              : out std_logic_vector(31 downto 0);
    DATA_WRITE_OUT        : out std_logic;
    DATA_FINISHED_OUT     : out std_logic;
--
    --To Bus Handler
    HCB_READ_EN_IN        : in  std_logic;
    HCB_WRITE_EN_IN       : in  std_logic;
    HCB_ADDR_IN           : in  std_logic_vector(6 downto 0);
    HCB_DATA_OUT          : out std_logic_vector(31 downto 0);
    HCB_DATAREADY_OUT     : out std_logic;
    HCB_UNKNOWN_ADDR_OUT  : out std_logic;
    SRB_READ_EN_IN        : in  std_logic;
    SRB_WRITE_EN_IN       : in  std_logic;
    SRB_ADDR_IN           : in  std_logic_vector(6 downto 0);
    SRB_DATA_OUT          : out std_logic_vector(31 downto 0);
    SRB_DATAREADY_OUT     : out std_logic;
    SRB_UNKNOWN_ADDR_OUT  : out std_logic;
    CDB_READ_EN_IN        : in  std_logic;
    CDB_WRITE_EN_IN       : in  std_logic;
    CDB_ADDR_IN           : in  std_logic_vector(6 downto 0);
    CDB_DATA_OUT          : out std_logic_vector(31 downto 0);
    CDB_DATAREADY_OUT     : out std_logic;
    CDB_UNKNOWN_ADDR_OUT  : out std_logic;
    ESB_READ_EN_IN        : in  std_logic;
    ESB_WRITE_EN_IN       : in  std_logic;
    ESB_ADDR_IN           : in  std_logic_vector(6 downto 0);
    ESB_DATA_OUT          : out std_logic_vector(31 downto 0);
    ESB_DATAREADY_OUT     : out std_logic;
    ESB_UNKNOWN_ADDR_OUT  : out std_logic;
    EFB_READ_EN_IN        : in  std_logic;
    EFB_WRITE_EN_IN       : in  std_logic;
    EFB_ADDR_IN           : in  std_logic_vector(6 downto 0);
    EFB_DATA_OUT          : out std_logic_vector(31 downto 0);
    EFB_DATAREADY_OUT     : out std_logic;
    EFB_UNKNOWN_ADDR_OUT  : out std_logic;
    LHB_READ_EN_IN        : in  std_logic;
    LHB_WRITE_EN_IN       : in  std_logic;
    LHB_ADDR_IN           : in  std_logic_vector(6 downto 0);
    LHB_DATA_OUT          : out std_logic_vector(31 downto 0);
    LHB_DATAREADY_OUT     : out std_logic;
    LHB_UNKNOWN_ADDR_OUT  : out std_logic;
--
    LOGIC_ANALYSER_OUT    : out std_logic_vector(15 downto 0);
    CONTROL_REG_IN        : in  std_logic_vector(32*CONTROL_REG_NR-1 downto 0)
    );
end TDC;

architecture TDC of TDC is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
-- Reset Signals
  signal reset_rdo                  : std_logic;
  signal reset_tdc_i                : std_logic;
  signal reset_tdc                  : std_logic;
-- Coarse counters
  signal coarse_cntr                : std_logic_vector_array_11(0 to 8);
  signal coarse_cntr_reset          : std_logic;
  signal coarse_cntr_reset_r        : std_logic_vector(8 downto 0);
-- Slow control
  signal logic_anal_control         : std_logic_vector(3 downto 0);
  signal debug_mode_en              : std_logic;
  signal light_mode_en              : std_logic;
  signal reset_counters             : std_logic;
  --signal run_mode                   : std_logic;  -- 1: cc reset every trigger
  --                                                  -- 0: free running mode
  --signal run_mode_200                 : std_logic;
  --signal run_mode_edge_200            : std_logic;
  signal reset_coarse_cntr          : std_logic;
  signal reset_coarse_cntr_200      : std_logic;
  signal reset_coarse_cntr_edge_200 : std_logic;
  signal reset_coarse_cntr_flag     : std_logic                                   := '0';
  signal ch_en                      : std_logic_vector(64 downto 1);
  signal data_limit                 : unsigned(7 downto 0);
  signal ring_buffer_full_thres     : std_logic_vector(6 downto 0);
  signal calibration_on             : std_logic                                   := '0';  -- turns on calibration for trig type 0xC
-- Logic analyser
  signal logic_anal_data            : std_logic_vector(3*32-1 downto 0);
-- Hit signals
  signal hit_in_d                   : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal hit_in_s                   : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal hit_in_i                   : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal hit_latch                  : std_logic_vector(CHANNEL_NUMBER-1 downto 1) := (others => '0');
  signal hit_edge                   : std_logic_vector(CHANNEL_NUMBER-1 downto 1);
  signal hit_r                      : std_logic_vector(CHANNEL_NUMBER-1 downto 1);
  signal hit_2r                     : std_logic_vector(CHANNEL_NUMBER-1 downto 1);
  signal hit_3r                     : std_logic_vector(CHANNEL_NUMBER-1 downto 1);
  signal edge_rising                : std_logic_vector(CHANNEL_NUMBER-1 downto 1) := (others => '0');
  signal edge_rising_r              : std_logic_vector(CHANNEL_NUMBER-1 downto 1);
  signal edge_rising_2r             : std_logic_vector(CHANNEL_NUMBER-1 downto 1);
  signal edge_rising_3r             : std_logic_vector(CHANNEL_NUMBER-1 downto 1);
  signal edge_falling               : std_logic_vector(CHANNEL_NUMBER-1 downto 1) := (others => '0');
  signal edge_falling_r             : std_logic_vector(CHANNEL_NUMBER-1 downto 1);
  signal edge_falling_2r            : std_logic_vector(CHANNEL_NUMBER-1 downto 1);
  signal edge_falling_3r            : std_logic_vector(CHANNEL_NUMBER-1 downto 1);
-- Calibration
  signal hit_cal_cntr               : unsigned(15 downto 0)                       := (others => '0');
  signal hit_cal_i                  : std_logic;
  signal hit_cal                    : std_logic;
  signal calibration_freq_select    : unsigned(3 downto 0)                        := (others => '0');
-- To the channels
  signal rd_en                      : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal trg_time                   : std_logic_vector(38 downto 0);
-- From the channels
  signal ch_data                    : std_logic_vector_array_36(0 to CHANNEL_NUMBER);
  signal ch_data_valid              : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal ch_wcnt                    : unsigned_array_8(0 to CHANNEL_NUMBER-1);
  signal ch_empty                   : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal ch_full                    : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal ch_almost_empty            : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal ch_almost_full             : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal ch_lost_hit_number         : std_logic_vector_array_24(0 to CHANNEL_NUMBER-1);
  signal ch_hit_detect_number       : std_logic_vector_array_31(0 to CHANNEL_NUMBER-1);
  signal ch_encoder_start_number    : std_logic_vector_array_24(0 to CHANNEL_NUMBER-1);
  signal ch_encoder_finished_number : std_logic_vector_array_24(0 to CHANNEL_NUMBER-1);
  signal ch_level_hit_number        : std_logic_vector_array_32(0 to CHANNEL_NUMBER-1);
  signal ch_lost_hit_bus            : std_logic_vector_array_32(0 to CHANNEL_NUMBER-1);
  signal ch_encoder_start_bus       : std_logic_vector_array_32(0 to CHANNEL_NUMBER-1);
  signal ch_encoder_finished_bus    : std_logic_vector_array_32(0 to CHANNEL_NUMBER-1);
  signal ch_fifo_write_number       : std_logic_vector_array_24(0 to CHANNEL_NUMBER-1);
-- To the endpoint
  signal ep_trg_release             : std_logic;
  signal ep_trg_statusbit           : std_logic_vector(31 downto 0);
  signal ep_data                    : std_logic_vector(31 downto 0);
  signal ep_data_write              : std_logic;
  signal ep_data_finished           : std_logic;

-- Epoch counter
  signal epoch_cntr        : std_logic_vector(27 downto 0);
  signal epoch_cntr_up     : std_logic;
  signal epoch_cntr_reset  : std_logic;
-- Trigger Handler signals
  signal trg_in            : std_logic;
  signal trg_rdo           : std_logic;
  signal trg_tdc           : std_logic;
  signal trg_win_en        : std_logic;
  signal trg_win_end_rdo   : std_logic;
  signal trg_win_end_tdc   : std_logic;
  signal trg_win_end_tdc_r : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal valid_trg_rdo     : std_logic;
  signal valid_trg_tdc     : std_logic;

-- Debug signals
  signal ref_debug            : std_logic_vector(31 downto 0);
  signal ch_debug             : std_logic_vector_array_32(0 to CHANNEL_NUMBER-1);
  signal ch_200_debug         : std_logic_vector_array_32(0 to CHANNEL_NUMBER-1);
  signal readout_debug        : std_logic_vector(31 downto 0);
-- Bus signals
  signal status_registers_bus : std_logic_vector_array_32(0 to STATUS_REG_NR-1);

  attribute syn_keep                            : boolean;
  attribute syn_keep of reset_tdc               : signal is true;
  attribute syn_keep of coarse_cntr             : signal is true;
  attribute syn_keep of coarse_cntr_reset_r     : signal is true;
  attribute syn_keep of trg_win_end_tdc_r       : signal is true;
  attribute syn_keep of hit_in_i                : signal is true;
  attribute syn_preserve                        : boolean;
  attribute syn_preserve of coarse_cntr         : signal is true;
  attribute syn_preserve of coarse_cntr_reset_r : signal is true;
  attribute syn_preserve of trg_win_end_tdc_r   : signal is true;
  attribute syn_preserve of hit_in_i            : signal is true;
  attribute nomerge                             : string;
  attribute nomerge of hit_in_i                 : signal is "true";
  

begin

-- Slow control signals
  logic_anal_control      <= CONTROL_REG_IN(3 downto 0)     when rising_edge(CLK_READOUT);
  debug_mode_en           <= CONTROL_REG_IN(4);
  light_mode_en           <= CONTROL_REG_IN(5)              when rising_edge(CLK_READOUT);
  reset_counters          <= CONTROL_REG_IN(8) or reset_tdc when rising_edge(CLK_TDC);
  --run_mode              <= CONTROL_REG_IN(12);
  --run_mode_200            <= run_mode                     when rising_edge(CLK_TDC);
  reset_coarse_cntr       <= CONTROL_REG_IN(13)             when rising_edge(CLK_TDC);
  reset_coarse_cntr_200   <= reset_coarse_cntr              when rising_edge(CLK_TDC);
  calibration_freq_select <= unsigned(CONTROL_REG_IN(31 downto 28));

  trg_win_en             <= CONTROL_REG_IN(1*32+31);
  ch_en                  <= CONTROL_REG_IN(3*32+31 downto 2*32+0);
  data_limit             <= unsigned(CONTROL_REG_IN(4*32+7 downto 4*32+0));
  ring_buffer_full_thres <= CONTROL_REG_IN(5*32+6 downto 5*32+0) when rising_edge(CLK_READOUT);


-- Reset signals
  reset_tdc_i <= RESET       when rising_edge(CLK_TDC);
  reset_tdc   <= reset_tdc_i when rising_edge(CLK_TDC);
  reset_rdo   <= RESET;

-------------------------------------------------------------------------------
-- Hit Process
-------------------------------------------------------------------------------
  -- Hit for calibration generation
  hit_cal_cntr <= hit_cal_cntr + to_unsigned(1, 16) when rising_edge(HIT_CAL_IN);
  hit_cal_i    <= hit_cal_cntr(to_integer(calibration_freq_select));

  HitCalPulse: entity work.risingEdgeDetect
    port map (
      CLK       => HIT_CAL_IN,
      SIGNAL_IN => hit_cal_i,
      PULSE_OUT => hit_cal);

  GEN_HitSelect : for i in 1 to CHANNEL_NUMBER-1 generate
    HitSelect: process (calibration_on, HIT_IN, hit_cal)is
    begin
      if calibration_on = '0' then
        hit_in_s(i) <= HIT_IN(i);
      else
        hit_in_s(i) <= hit_cal;
      end if;      
    end process HitSelect;
  end generate GEN_HitSelect;

  gen_double_withStretcher : if DOUBLE_EDGE_TYPE = 3 generate
    The_Stretcher : entity work.Stretcher
      generic map (
        CHANNEL => CHANNEL_NUMBER-1,
        DEPTH   => 4)
      port map (
        PULSE_IN  => hit_in_s(CHANNEL_NUMBER-1 downto 1),
        PULSE_OUT => hit_in_d(CHANNEL_NUMBER-1 downto 1));
  end generate gen_double_withStretcher;

  gen_double_withoutStretcher : if DOUBLE_EDGE_TYPE = 1 generate
    hit_in_d(CHANNEL_NUMBER-1 downto 1) <= hit_in_s(CHANNEL_NUMBER-1 downto 1);
  end generate gen_double_withoutStretcher;


  -- Blocks the input after the rising edge against short pulses
  GEN_HitBlock : for i in 1 to CHANNEL_NUMBER-1 generate
    gen_double : if DOUBLE_EDGE_TYPE = 1 or DOUBLE_EDGE_TYPE = 3 generate
      edge_rising(i) <= '0' when edge_rising_3r(i) = '1' else
                        '1' when rising_edge(hit_in_s(i));
      edge_rising_r(i)  <= edge_rising(i)                             when rising_edge(CLK_READOUT);  -- using 100MHz clk for longer reset time
      edge_rising_2r(i) <= edge_rising_r(i)                           when rising_edge(CLK_READOUT);
      edge_rising_3r(i) <= edge_rising_r(i) and not edge_rising_2r(i) when rising_edge(CLK_READOUT);

      edge_falling(i) <= '0' when edge_falling_3r(i) = '1' else
                         '1' when falling_edge(hit_in_d(i));
      edge_falling_r(i)  <= edge_falling(i)                              when rising_edge(CLK_READOUT);  -- using 100MHz clk for longer reset time
      edge_falling_2r(i) <= edge_falling_r(i)                            when rising_edge(CLK_READOUT);
      edge_falling_3r(i) <= edge_falling_r(i) and not edge_falling_2r(i) when rising_edge(CLK_READOUT);

      hit_latch(i) <= edge_rising(i) or edge_falling(i);
      hit_edge(i)  <= '0' when edge_falling(i) = '1' else
                      '1' when rising_edge(edge_rising(i));
    end generate gen_double;

    -- for single edge and double edge in alternating channel setup
    gen_single : if DOUBLE_EDGE_TYPE = 0 or DOUBLE_EDGE_TYPE = 2 generate
      hit_latch(i) <= '0' when hit_3r(i) = '1' else
                      '1' when rising_edge(hit_in_s(i));
      hit_edge(i) <= '1';
      hit_r       <= hit_latch            when rising_edge(CLK_READOUT);  -- using 100MHz clk for longer reset time
      hit_2r      <= hit_r                when rising_edge(CLK_READOUT);
      hit_3r      <= hit_r and not hit_2r when rising_edge(CLK_READOUT);
    end generate gen_single;
  end generate GEN_HitBlock;

  GEN_hit_mux : for i in 1 to CHANNEL_NUMBER-1 generate
    hit_mux_ch : hit_mux
      port map (
        CH_EN_IN           => ch_en(i),
        CALIBRATION_EN_IN  => '0', --calibration_on,
        HIT_CALIBRATION_IN => '0', --hit_cal,
        HIT_PHYSICAL_IN    => hit_latch(i),
        HIT_OUT            => hit_in_i(i));
  end generate GEN_hit_mux;

  hit_mux_ref : hit_mux
    port map (
      CH_EN_IN           => '1',
      CALIBRATION_EN_IN  => calibration_on,
      HIT_CALIBRATION_IN => hit_cal,
      HIT_PHYSICAL_IN    => REFERENCE_TIME,
      HIT_OUT            => hit_in_i(0));

  CalibrationSwitch : process (CLK_READOUT)
  begin
    if rising_edge(CLK_READOUT) then
      if trg_win_end_rdo = '1' then
        calibration_on <= '0';
      elsif VALID_NOTIMING_TRG_IN = '1' and TRG_TYPE_IN = x"D" then
        calibration_on <= '1';
      end if;
    end if;
  end process CalibrationSwitch;

-------------------------------------------------------------------------------
-- Channels
-------------------------------------------------------------------------------
  -- Reference Channel to measure the reference time
  ReferenceChannel : Channel
    generic map (
      CHANNEL_ID => 0,
      DEBUG      => DEBUG,
      SIMULATION => SIMULATION,
      REFERENCE  => c_YES)
    port map (
      RESET_200                 => reset_tdc,
      RESET_100                 => reset_rdo,
      RESET_COUNTERS            => reset_counters,
      CLK_200                   => CLK_TDC,
      CLK_100                   => CLK_READOUT,
      HIT_IN                    => hit_in_i(0),
      HIT_EDGE_IN               => '1',
      TRG_WIN_END_TDC_IN        => trg_win_end_tdc_r(0),
      TRG_WIN_END_RDO_IN        => trg_win_end_rdo,
      EPOCH_COUNTER_IN          => epoch_cntr,
      COARSE_COUNTER_IN         => coarse_cntr(1),
      READ_EN_IN                => rd_en(0),
      FIFO_DATA_OUT             => ch_data(0),
      FIFO_DATA_VALID_OUT       => ch_data_valid(0),
      FIFO_EMPTY_OUT            => ch_empty(0),
      FIFO_FULL_OUT             => ch_full(0),
      FIFO_ALMOST_EMPTY_OUT     => ch_almost_empty(0),
      RING_BUFFER_FULL_THRES_IN => ring_buffer_full_thres,
      VALID_TIMING_TRG_IN       => VALID_TIMING_TRG_IN,
      VALID_NOTIMING_TRG_IN     => VALID_NOTIMING_TRG_IN,
      SPIKE_DETECTED_IN         => SPIKE_DETECTED_IN,
      MULTI_TMG_TRG_IN          => MULTI_TMG_TRG_IN,
      EPOCH_WRITE_EN_IN         => '1',
      LOST_HIT_NUMBER           => ch_lost_hit_number(0),
      HIT_DETECT_NUMBER         => ch_hit_detect_number(0),
      ENCODER_START_NUMBER      => ch_encoder_start_number(0),
      ENCODER_FINISHED_NUMBER   => ch_encoder_finished_number(0),
      FIFO_WRITE_NUMBER         => ch_fifo_write_number(0),
      Channel_200_DEBUG_OUT     => ch_200_debug(0),
      Channel_DEBUG_OUT         => ch_debug(0));

  -- TDC Channels
  GEN_Channels : for i in 1 to CHANNEL_NUMBER-1 generate
    Channels : Channel
      generic map (
        CHANNEL_ID => i,
        DEBUG      => DEBUG,
        SIMULATION => SIMULATION,
        REFERENCE  => c_NO)
      port map (
        RESET_200                 => reset_tdc,
        RESET_100                 => reset_rdo,
        RESET_COUNTERS            => reset_counters,
        CLK_200                   => CLK_TDC,
        CLK_100                   => CLK_READOUT,
        HIT_IN                    => hit_in_i(i),
        HIT_EDGE_IN               => hit_edge(i),
        TRG_WIN_END_TDC_IN        => trg_win_end_tdc_r(i),
        TRG_WIN_END_RDO_IN        => trg_win_end_rdo,
        EPOCH_COUNTER_IN          => epoch_cntr,
        COARSE_COUNTER_IN         => coarse_cntr(integer(ceil(real(i)/real(8)))),
        READ_EN_IN                => rd_en(i),
        FIFO_DATA_OUT             => ch_data(i),
        FIFO_DATA_VALID_OUT       => ch_data_valid(i),
        FIFO_EMPTY_OUT            => ch_empty(i),
        FIFO_FULL_OUT             => ch_full(i),
        FIFO_ALMOST_EMPTY_OUT     => ch_almost_empty(i),
        RING_BUFFER_FULL_THRES_IN => ring_buffer_full_thres,
        VALID_TIMING_TRG_IN       => '0',
        VALID_NOTIMING_TRG_IN     => '0',
        SPIKE_DETECTED_IN         => '0',
        MULTI_TMG_TRG_IN          => '0',
        EPOCH_WRITE_EN_IN         => '1',
        LOST_HIT_NUMBER           => ch_lost_hit_number(i),
        HIT_DETECT_NUMBER         => ch_hit_detect_number(i),
        ENCODER_START_NUMBER      => ch_encoder_start_number(i),
        ENCODER_FINISHED_NUMBER   => ch_encoder_finished_number(i),
        FIFO_WRITE_NUMBER         => ch_fifo_write_number(i),
        Channel_200_DEBUG_OUT     => ch_200_debug(i),
        Channel_DEBUG_OUT         => ch_debug(i));
  end generate GEN_Channels;
  ch_data(CHANNEL_NUMBER) <= (others => '1');

-------------------------------------------------------------------------------
-- Trigger
-------------------------------------------------------------------------------
  -- Valid Trigger Sync
  ValidTriggerPulseSync : entity work.pulse_sync
    port map (
      CLK_A_IN    => CLK_READOUT,
      RESET_A_IN  => reset_rdo,
      PULSE_A_IN  => valid_trg_rdo,
      CLK_B_IN    => CLK_TDC,
      RESET_B_IN  => reset_tdc,
      PULSE_B_OUT => valid_trg_tdc);
  valid_trg_rdo <= VALID_NOTIMING_TRG_IN or VALID_TIMING_TRG_IN;

  -- Timing Trigger handler
  TheTriggerHandler : TriggerHandler
    generic map (
      TRIGGER_NUM            => 1,
      PHYSICAL_EVENT_TRG_NUM => 0)
    port map (
      CLK_TRG               => CLK_READOUT,
      CLK_RDO               => CLK_READOUT,
      CLK_TDC               => CLK_TDC,
      RESET_TRG             => reset_rdo,
      RESET_RDO             => reset_rdo,
      RESET_TDC             => reset_tdc,
      VALID_NOTIMING_TRG_IN => VALID_NOTIMING_TRG_IN,
      TRG_TYPE_IN           => TRG_TYPE_IN,
      TRG_RELEASE_IN        => ep_trg_release,
      TRG_IN(0)             => trg_in,
      TRG_RDO_OUT(0)        => trg_rdo,
      TRG_TDC_OUT(0)        => trg_tdc,
      TRG_WIN_EN_IN         => trg_win_en,
      TRG_WIN_POST_IN       => unsigned(TRG_WIN_POST),
      TRG_WIN_END_RDO_OUT   => trg_win_end_rdo,
      TRG_WIN_END_TDC_OUT   => trg_win_end_tdc,
      COARSE_COUNTER_IN     => coarse_cntr(0),
      EPOCH_COUNTER_IN      => epoch_cntr,
      TRG_TIME_OUT          => trg_time
      );
  trg_in <= REFERENCE_TIME;
  GenTriggerWindowEnd : for i in 0 to CHANNEL_NUMBER-1 generate
    trg_win_end_tdc_r(i) <= trg_win_end_tdc when rising_edge(CLK_TDC);
  end generate GenTriggerWindowEnd;

-------------------------------------------------------------------------------
-- Readout
  TheReadout : Readout
    generic map (
      CHANNEL_NUMBER => CHANNEL_NUMBER,
      STATUS_REG_NR  => STATUS_REG_NR,
      TDC_VERSION    => TDC_VERSION)
    port map (
      RESET_100                => reset_rdo,
      RESET_200                => reset_tdc,
      RESET_COUNTERS           => reset_counters,
      CLK_100                  => CLK_READOUT,
      CLK_200                  => CLK_TDC,
      HIT_IN                   => hit_in_i(CHANNEL_NUMBER-1 downto 1),
      -- from the channels
      CH_DATA_IN               => ch_data,
      CH_DATA_VALID_IN         => ch_data_valid,
      CH_EMPTY_IN              => ch_empty,
      CH_FULL_IN               => ch_full,
      CH_ALMOST_EMPTY_IN       => ch_almost_empty,
      -- from the endpoint
      TRG_DATA_VALID_IN        => TRG_DATA_VALID_IN,
      VALID_TIMING_TRG_IN      => VALID_TIMING_TRG_IN,
      VALID_NOTIMING_TRG_IN    => VALID_NOTIMING_TRG_IN,
      INVALID_TRG_IN           => INVALID_TRG_IN,
      TMGTRG_TIMEOUT_IN        => TMGTRG_TIMEOUT_IN,
      SPIKE_DETECTED_IN        => SPIKE_DETECTED_IN,
      MULTI_TMG_TRG_IN         => MULTI_TMG_TRG_IN,
      SPURIOUS_TRG_IN          => SPURIOUS_TRG_IN,
      TRG_NUMBER_IN            => TRG_NUMBER_IN,
      TRG_CODE_IN              => TRG_CODE_IN,
      TRG_INFORMATION_IN       => TRG_INFORMATION_IN,
      TRG_TYPE_IN              => TRG_TYPE_IN,
      DATA_LIMIT_IN            => data_limit,
      -- to the endpoint
      TRG_RELEASE_OUT          => ep_trg_release,
      TRG_STATUSBIT_OUT        => ep_trg_statusbit,
      DATA_OUT                 => ep_data,
      DATA_WRITE_OUT           => ep_data_write,
      DATA_FINISHED_OUT        => ep_data_finished,
      -- to the channels
      READ_EN_OUT              => rd_en,
      -- trigger window settings
      TRG_WIN_PRE_IN           => TRG_WIN_PRE,
      TRG_WIN_POST_IN          => TRG_WIN_POST,
      TRG_WIN_EN_IN            => trg_win_en,
      -- from the trigger handler
      TRG_WIN_END_TDC_IN       => trg_win_end_tdc_r(1),
      TRG_WIN_END_RDO_IN       => trg_win_end_rdo,
      TRG_TDC_IN               => trg_tdc,
      TRG_TIME_IN              => trg_time,
      -- miscellaneous
      LIGHT_MODE_IN            => light_mode_en,
      COARSE_COUNTER_IN        => coarse_cntr(0),
      EPOCH_COUNTER_IN         => epoch_cntr,
      DEBUG_MODE_EN_IN         => debug_mode_en,
      STATUS_REGISTERS_BUS_OUT => status_registers_bus,
      READOUT_DEBUG            => readout_debug,
      REFERENCE_TIME           => REFERENCE_TIME
      );

  TRG_RELEASE_OUT   <= ep_trg_release   when rising_edge(CLK_READOUT);
  TRG_STATUSBIT_OUT <= ep_trg_statusbit when rising_edge(CLK_READOUT);
  DATA_OUT          <= ep_data          when rising_edge(CLK_READOUT);
  DATA_WRITE_OUT    <= ep_data_write    when rising_edge(CLK_READOUT);
  DATA_FINISHED_OUT <= ep_data_finished when rising_edge(CLK_READOUT);

-------------------------------------------------------------------------------
-- Coarse & Epoch Counters
-------------------------------------------------------------------------------
-- Coarse counter
  GenCoarseCounter : for i in 0 to 8 generate
    TheCoarseCounter : up_counter
      generic map (
        NUMBER_OF_BITS => 11)
      port map (
        CLK       => CLK_TDC,
        RESET     => coarse_cntr_reset_r(i),
        COUNT_OUT => coarse_cntr(i),
        UP_IN     => '1');
  end generate GenCoarseCounter;

  Coarse_Counter_Reset : process (CLK_TDC)
  begin
    if rising_edge(CLK_TDC) then
      if reset_tdc = '1' then
        coarse_cntr_reset <= '1';
      --elsif run_mode_200 = '0' then
      --  coarse_cntr_reset <= trg_win_end_tdc_r(1);
      --elsif run_mode_edge_200 = '1' then
      --  coarse_cntr_reset <= '1';
      elsif reset_coarse_cntr_flag = '1' and valid_trg_tdc = '1' then
        coarse_cntr_reset <= '1';
      else
        coarse_cntr_reset <= '0';
      end if;
      if reset_coarse_cntr_edge_200 = '1' then
        reset_coarse_cntr_flag <= '1';
      elsif valid_trg_tdc = '1' then
        reset_coarse_cntr_flag <= '0';
      end if;
    end if;
  end process Coarse_Counter_Reset;

  --Run_Mode_Edge_Detect : risingEdgeDetect
  --  port map (
  --    CLK       => CLK_TDC,
  --    SIGNAL_IN => run_mode_200,
  --    PULSE_OUT => run_mode_edge_200);

  Reset_Coarse_Counter_Edge_Detect : risingEdgeDetect
    port map (
      CLK       => CLK_TDC,
      SIGNAL_IN => reset_coarse_cntr_200,
      PULSE_OUT => reset_coarse_cntr_edge_200);

  GenCoarseCounterReset : for i in 0 to 8 generate
    coarse_cntr_reset_r(i) <= coarse_cntr_reset when rising_edge(CLK_TDC);
  end generate GenCoarseCounterReset;

-- EPOCH counter
  TheEpochCounter : up_counter
    generic map (
      NUMBER_OF_BITS => 28)
    port map (
      CLK       => CLK_TDC,
      RESET     => epoch_cntr_reset,
      COUNT_OUT => epoch_cntr,
      UP_IN     => epoch_cntr_up);
  epoch_cntr_up    <= and_all(coarse_cntr(0));
  epoch_cntr_reset <= coarse_cntr_reset_r(0);

-------------------------------------------------------------------------------
-- Slow Control Data Busses
-------------------------------------------------------------------------------
-- Hit counter
  TheHitCounterBus : BusHandler
    generic map (
      BUS_LENGTH => CHANNEL_NUMBER-1)
    port map (
      RESET            => reset_rdo,
      CLK              => CLK_READOUT,
      DATA_IN          => ch_level_hit_number,
      READ_EN_IN       => HCB_READ_EN_IN,
      WRITE_EN_IN      => HCB_WRITE_EN_IN,
      ADDR_IN          => HCB_ADDR_IN,
      DATA_OUT         => HCB_DATA_OUT,
      DATAREADY_OUT    => HCB_DATAREADY_OUT,
      UNKNOWN_ADDR_OUT => HCB_UNKNOWN_ADDR_OUT);

  ch_level_hit_number(0)(31)          <= REFERENCE_TIME          when rising_edge(CLK_READOUT);
  ch_level_hit_number(0)(30 downto 0) <= ch_hit_detect_number(0) when rising_edge(CLK_READOUT);
  GenHitDetectNumber : for i in 1 to CHANNEL_NUMBER-1 generate
    ch_level_hit_number(i)(31)          <= HIT_IN(i) and ch_en(i)  when rising_edge(CLK_READOUT);
    ch_level_hit_number(i)(30 downto 0) <= ch_hit_detect_number(i) when rising_edge(CLK_READOUT);
  end generate GenHitDetectNumber;

-- Status register
  TheStatusRegistersBus : BusHandler
    generic map (
      BUS_LENGTH => STATUS_REG_NR - 1)
    port map (
      RESET            => reset_rdo,
      CLK              => CLK_READOUT,
      DATA_IN          => status_registers_bus,
      READ_EN_IN       => SRB_READ_EN_IN,
      WRITE_EN_IN      => SRB_WRITE_EN_IN,
      ADDR_IN          => SRB_ADDR_IN,
      DATA_OUT         => SRB_DATA_OUT,
      DATAREADY_OUT    => SRB_DATAREADY_OUT,
      UNKNOWN_ADDR_OUT => SRB_UNKNOWN_ADDR_OUT);

-- Channel debug
  TheChannelDebugBus : BusHandler
    generic map (
      BUS_LENGTH => CHANNEL_NUMBER - 1)
    port map (
      RESET            => reset_rdo,
      CLK              => CLK_READOUT,
      DATA_IN          => ch_200_debug,
      READ_EN_IN       => CDB_READ_EN_IN,
      WRITE_EN_IN      => CDB_WRITE_EN_IN,
      ADDR_IN          => CDB_ADDR_IN,
      DATA_OUT         => CDB_DATA_OUT,
      DATAREADY_OUT    => CDB_DATAREADY_OUT,
      UNKNOWN_ADDR_OUT => CDB_UNKNOWN_ADDR_OUT);


  --TheLostHitBus : BusHandler
  --  generic map (
  --    BUS_LENGTH => CHANNEL_NUMBER-1)
  --  port map (
  --    RESET            => reset_rdo,
  --    CLK              => CLK_READOUT,
  --    DATA_IN          => ch_lost_hit_bus,
  --    READ_EN_IN       => LHB_READ_EN_IN,
  --    WRITE_EN_IN      => LHB_WRITE_EN_IN,
  --    ADDR_IN          => LHB_ADDR_IN,
  --    DATA_OUT         => LHB_DATA_OUT,
  --    DATAREADY_OUT    => LHB_DATAREADY_OUT,
  --    UNKNOWN_ADDR_OUT => LHB_UNKNOWN_ADDR_OUT);

  --GenLostHit_In_number : for i in 1 to CHANNEL_NUMBER-1 generate
  --  ch_lost_hit_bus(i) <= ch_encoder_start_number(i)(15 downto 0) & ch_200_debug(i)(15 downto 0) when rising_edge(CLK_READOUT);
  --end generate GenLostHit_In_number;

  LHB_DATA_OUT         <= (others => '0');
  LHB_DATAREADY_OUT    <= '0';
  LHB_UNKNOWN_ADDR_OUT <= '0';

  --TheEncoderStartBus : BusHandler
  --  generic map (
  --    BUS_LENGTH => CHANNEL_NUMBER-1)
  --  port map (
  --    RESET            => reset_rdo,
  --    CLK              => CLK_READOUT,
  --    DATA_IN          => ch_encoder_start_bus,
  --    READ_EN_IN       => ESB_READ_EN_IN,
  --    WRITE_EN_IN      => ESB_WRITE_EN_IN,
  --    ADDR_IN          => ESB_ADDR_IN,
  --    DATA_OUT         => ESB_DATA_OUT,
  --    DATAREADY_OUT    => ESB_DATAREADY_OUT,
  --    UNKNOWN_ADDR_OUT => ESB_UNKNOWN_ADDR_OUT);

  --GenEncoderStartNumber : for i in 1 to CHANNEL_NUMBER-1 generate
  --  ch_encoder_start_bus(i) <= x"00" & ch_encoder_start_number(i) when rising_edge(CLK_READOUT);
  --end generate GenEncoderStartNumber;

  ESB_DATA_OUT         <= (others => '0');
  ESB_DATAREADY_OUT    <= '0';
  ESB_UNKNOWN_ADDR_OUT <= '0';

  --TheEncoderFinishedBus : BusHandler
  --  generic map (
  --    BUS_LENGTH => CHANNEL_NUMBER-1)
  --  port map (
  --    RESET            => reset_rdo,
  --    CLK              => CLK_READOUT,
  --    DATA_IN          => ch_encoder_finished_bus,
  --    READ_EN_IN       => EFB_READ_EN_IN,
  --    WRITE_EN_IN      => EFB_WRITE_EN_IN,
  --    ADDR_IN          => EFB_ADDR_IN,
  --    DATA_OUT         => EFB_DATA_OUT,
  --    DATAREADY_OUT    => EFB_DATAREADY_OUT,
  --    UNKNOWN_ADDR_OUT => EFB_UNKNOWN_ADDR_OUT);

  --GenFifoWriteNumber : for i in 1 to CHANNEL_NUMBER-1 generate
  --  --ch_encoder_finished_bus(i) <= x"00" & ch_encoder_finished_number(i) when rising_edge(CLK_READOUT);
  --  ch_encoder_finished_bus(i) <= ch_fifo_write_number(i)(15 downto 0)& ch_encoder_finished_number(i)(15 downto 0) when rising_edge(CLK_READOUT);
  --end generate GenFifoWriteNumber;

  EFB_DATA_OUT         <= (others => '0');
  EFB_DATAREADY_OUT    <= '0';
  EFB_UNKNOWN_ADDR_OUT <= '0';

-------------------------------------------------------------------------------
-- Debug
-------------------------------------------------------------------------------
-- Logic Analyser
  TheLogicAnalyser : LogicAnalyser
    generic map (
      CHANNEL_NUMBER => CHANNEL_NUMBER)
    port map (
      CLK        => CLK_READOUT,
      RESET      => reset_rdo,
      DATA_IN    => logic_anal_data,
      CONTROL_IN => logic_anal_control,
      DATA_OUT   => LOGIC_ANALYSER_OUT);

  logic_anal_data(7 downto 0)   <= readout_debug(7 downto 0);
  logic_anal_data(8)            <= REFERENCE_TIME;
  logic_anal_data(9)            <= VALID_TIMING_TRG_IN;
  logic_anal_data(10)           <= VALID_NOTIMING_TRG_IN;
  logic_anal_data(11)           <= INVALID_TRG_IN;
  logic_anal_data(12)           <= TRG_DATA_VALID_IN;
  logic_anal_data(13)           <= readout_debug(8);   --data_wr_r;
  logic_anal_data(14)           <= readout_debug(9);   --data_finished_r;
  logic_anal_data(15)           <= readout_debug(10);  --trg_release_r;
  logic_anal_data(31 downto 16) <= ref_debug(15 downto 0);
  logic_anal_data(37 downto 32) <= readout_debug(16 downto 11);  --data_out_r(27 downto 22);
  logic_anal_data(47 downto 38) <= (others => '0');
  logic_anal_data(63 downto 48) <= ch_debug(1)(15 downto 0);
  logic_anal_data(95 downto 64) <= (others => '0');
  
end TDC;
