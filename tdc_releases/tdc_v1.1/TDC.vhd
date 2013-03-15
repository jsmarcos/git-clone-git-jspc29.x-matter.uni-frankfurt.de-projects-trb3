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
    --To Bus Handler
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
-- Reset Signals
  signal reset_tdc                 : std_logic;
-- Coarse counters
  signal coarse_cntr               : std_logic_vector_array_11(1 to 4);
  signal coarse_cntr_reset         : std_logic;
  signal coarse_cntr_reset_r       : std_logic_vector(4 downto 1);
-- Slow control
  signal logic_anal_control        : std_logic_vector(3 downto 0);
  signal debug_mode_en_i           : std_logic;
  signal reset_counters_i          : std_logic;
  signal run_mode_i                : std_logic;  -- 0: cc reset every trigger
                                                 -- 1: free running mode
  signal run_mode_200              : std_logic;
  signal trigger_win_en_i          : std_logic;
  signal ch_en_i                   : std_logic_vector(64 downto 1);
-- Logic analyser
  signal logic_anal_data_i         : std_logic_vector(3*32-1 downto 0);
-- Hit signals
  signal hit_in_i                  : std_logic_vector(CHANNEL_NUMBER-1 downto 1);
  signal scaler_in_i               : std_logic_vector(CHANNEL_NUMBER-1 downto 1);
-- To the channels
  signal readout_busy_i            : std_logic;
  signal rd_en_i                   : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal trg_win_end_i             : std_logic;
-- From the channels
  signal ch_data_i                 : std_logic_vector_array_32(0 to CHANNEL_NUMBER);
  signal ch_empty_i                : std_logic_vector(CHANNEL_NUMBER downto 0);
  signal ch_full_i                 : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal ch_almost_full_i          : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal trg_time_i                : std_logic_vector(38 downto 0);
  signal ch_lost_hit_number_i      : std_logic_vector_array_24(0 to CHANNEL_NUMBER-1);
  signal ch_hit_detect_number_i    : std_logic_vector_array_24(0 to CHANNEL_NUMBER-1);
  signal ch_encoder_start_number_i : std_logic_vector_array_24(0 to CHANNEL_NUMBER-1);
  signal ch_fifo_wr_number_i       : std_logic_vector_array_24(0 to CHANNEL_NUMBER-1);
  signal ch_level_hit_number       : std_logic_vector_array_32(0 to CHANNEL_NUMBER-1);
-- To the endpoint
  signal data_finished_i           : std_logic;
-- Epoch counter
  signal epoch_cntr                : std_logic_vector(27 downto 0);
  signal epoch_cntr_up_i           : std_logic;
  signal epoch_cntr_reset_i        : std_logic;
-- Debug signals
  signal ref_debug_i               : std_logic_vector(31 downto 0);
  signal ch_debug_i                : std_logic_vector_array_32(0 to CHANNEL_NUMBER-1);
  signal readout_debug_i           : std_logic_vector(31 downto 0);

  attribute syn_keep                    : boolean;
  attribute syn_keep of reset_tdc       : signal is true;
  attribute syn_keep of coarse_cntr     : signal is true;
  attribute syn_preserve                : boolean;
  attribute syn_preserve of coarse_cntr : signal is true;

begin

-- Slow control signals
  logic_anal_control <= CONTROL_REG_IN(3 downto 0) when rising_edge(CLK_READOUT);
  debug_mode_en_i    <= CONTROL_REG_IN(4);
  reset_counters_i   <= CONTROL_REG_IN(8);
  run_mode_i         <= CONTROL_REG_IN(12);
  run_mode_200       <= run_mode_i                 when rising_edge(CLK_TDC);  -- Run mode control register synchronised to the coarse counter clk
  trigger_win_en_i   <= CONTROL_REG_IN(1*32+31);
  ch_en_i            <= CONTROL_REG_IN(3*32+31 downto 2*32+0);

-- Reset signal
  reset_tdc <= RESET;

-- Channel enable signals
  GEN_Channel_Enable : for i in 1 to CHANNEL_NUMBER-1 generate
    scaler_in_i(i) <= HIT_IN(i) and ch_en_i(i);
    hit_in_i(i)    <= scaler_in_i(i) and not(readout_busy_i);
  end generate GEN_Channel_Enable;

-- Reference channel
  The_Reference_Time : Reference_Channel
    generic map (
      CHANNEL_ID => 0)
    port map (
      RESET_200              => reset_tdc,
      RESET_100              => RESET,
      CLK_200                => CLK_TDC,
      CLK_100                => CLK_READOUT,
      HIT_IN                 => REFERENCE_TIME,
      READ_EN_IN             => rd_en_i(0),
      VALID_TMG_TRG_IN       => VALID_TIMING_TRG_IN,
      SPIKE_DETECTED_IN      => SPIKE_DETECTED_IN,
      MULTI_TMG_TRG_IN       => MULTI_TMG_TRG_IN,
      FIFO_DATA_OUT          => ch_data_i(0),
      FIFO_EMPTY_OUT         => ch_empty_i(0),
      FIFO_FULL_OUT          => ch_full_i(0),
      FIFO_ALMOST_FULL_OUT   => ch_almost_full_i(0),
      COARSE_COUNTER_IN      => coarse_cntr(1),
      EPOCH_COUNTER_IN       => epoch_cntr,
      TRIGGER_WINDOW_END_IN  => trg_win_end_i,
      DATA_FINISHED_IN       => data_finished_i,
      RUN_MODE               => run_mode_i,
      TRIGGER_TIME_STAMP_OUT => trg_time_i,
      REF_DEBUG_OUT          => ref_debug_i);

-- Channels
  GEN_Channels : for i in 1 to CHANNEL_NUMBER - 1 generate
    Channels : Channel
      generic map (
        CHANNEL_ID => i)
      port map (
        RESET_200             => reset_tdc,
        RESET_100             => RESET,
        RESET_COUNTERS        => reset_counters_i,
        CLK_200               => CLK_TDC,
        CLK_100               => CLK_READOUT,
        HIT_IN                => hit_in_i(i),
        SCALER_IN             => scaler_in_i(i),
        READ_EN_IN            => rd_en_i(i),
        FIFO_DATA_OUT         => ch_data_i(i),
        FIFO_EMPTY_OUT        => ch_empty_i(i),
        FIFO_FULL_OUT         => ch_full_i(i),
        FIFO_ALMOST_FULL_OUT  => ch_almost_full_i(i),
        COARSE_COUNTER_IN     => coarse_cntr(integer(ceil(real(i)/real(16)))),
        EPOCH_COUNTER_IN      => epoch_cntr,
        TRIGGER_WINDOW_END_IN => trg_win_end_i,
        DATA_FINISHED_IN      => data_finished_i,
        RUN_MODE              => run_mode_i,
        LOST_HIT_NUMBER       => open,  --ch_lost_hit_number_i(i),
        HIT_DETECT_NUMBER     => ch_hit_detect_number_i(i),
        ENCODER_START_NUMBER  => open,  --ch_encoder_start_number_i(i),
        FIFO_WR_NUMBER        => open,  --ch_fifo_wr_number_i(i),
        Channel_DEBUG         => ch_debug_i(i));
  end generate GEN_Channels;
  ch_data_i(CHANNEL_NUMBER) <= x"FFFFFFFF";

-- Coarse counter
  GenCoarseCounter : for i in 1 to 4 generate
    TheCoarseCounter : up_counter
      generic map (
        NUMBER_OF_BITS => 11)
      port map (
        CLK       => CLK_TDC,
        RESET     => coarse_cntr_reset_r(i),
        COUNT_OUT => coarse_cntr(i),
        UP_IN     => '1');
  end generate GenCoarseCounter;

  Coarse_Counter_Reset : process (CLK_TDC, reset_tdc)
  begin
    if rising_edge(CLK_TDC) then
      if reset_tdc = '1' then
        coarse_cntr_reset <= '1';
      elsif run_mode_200 = '1' then
        coarse_cntr_reset <= '0';
      else
        coarse_cntr_reset <= trg_win_end_i;
      end if;
    end if;
  end process Coarse_Counter_Reset;

  GenCoarseCounterReset : for i in 1 to 4 generate
    coarse_cntr_reset_r(i) <= coarse_cntr_reset when rising_edge(CLK_TDC);
  end generate GenCoarseCounterReset;

-- EPOCH counter
  TheEpochCounter : up_counter
    generic map (
      NUMBER_OF_BITS => 28)
    port map (
      CLK       => CLK_TDC,
      RESET     => epoch_cntr_reset_i,
      COUNT_OUT => epoch_cntr,
      UP_IN     => epoch_cntr_up_i);
  epoch_cntr_up_i    <= and_all(coarse_cntr(1));
  epoch_cntr_reset_i <= reset_tdc or coarse_cntr_reset;

-- Bus handler for the hit counter signals
  TheHitCounterBus : BusHandler
    generic map (
      BUS_LENGTH => CHANNEL_NUMBER-1)
    port map (
      RESET            => RESET,
      CLK              => CLK_READOUT,
      DATA_IN          => ch_level_hit_number,
      READ_EN_IN       => HCB_READ_EN_IN,
      WRITE_EN_IN      => HCB_WRITE_EN_IN,
      ADDR_IN          => HCB_ADDR_IN,
      DATA_OUT         => HCB_DATA_OUT,
      DATAREADY_OUT    => HCB_DATAREADY_OUT,
      UNKNOWN_ADDR_OUT => HCB_UNKNOWN_ADDR_OUT);

  GenHitCounterLevelSignals : for i in 1 to CHANNEL_NUMBER-1 generate
    ch_level_hit_number(i) <= scaler_in_i(i) & "0000000" & ch_hit_detect_number_i(i) when rising_edge(CLK_READOUT);
  end generate GenHitCounterLevelSignals;

-- Readout
  TheReadout : Readout
    generic map (
      CHANNEL_NUMBER => CHANNEL_NUMBER,
      STATUS_REG_NR  => STATUS_REG_NR)
    port map (
      CLK_200               => CLK_TDC,
      RESET_200             => reset_tdc,
      CLK_100               => CLK_READOUT,
      RESET_100             => RESET,
      RESET_COUNTERS        => reset_counters_i,
      HIT_IN                => scaler_in_i,
      REFERENCE_TIME        => REFERENCE_TIME,
      TRIGGER_TIME_IN       => trg_time_i,
      TRG_WIN_PRE           => TRG_WIN_PRE,
      TRG_WIN_POST          => TRG_WIN_POST,
      DEBUG_MODE_EN_IN      => debug_mode_en_i,
      TRIGGER_WIN_EN_IN     => trigger_win_en_i,
      CH_DATA_IN            => ch_data_i,
      CH_EMPTY_IN           => ch_empty_i,
      CH_FULL_IN            => ch_full_i,
      CH_ALMOST_FULL_IN     => ch_almost_full_i,
      TRG_DATA_VALID_IN     => TRG_DATA_VALID_IN,
      VALID_TIMING_TRG_IN   => VALID_TIMING_TRG_IN,
      VALID_NOTIMING_TRG_IN => VALID_NOTIMING_TRG_IN,
      INVALID_TRG_IN        => INVALID_TRG_IN,
      TMGTRG_TIMEOUT_IN     => TMGTRG_TIMEOUT_IN,
      SPIKE_DETECTED_IN     => SPIKE_DETECTED_IN,
      MULTI_TMG_TRG_IN      => MULTI_TMG_TRG_IN,
      SPURIOUS_TRG_IN       => SPURIOUS_TRG_IN,
      TRG_NUMBER_IN         => TRG_NUMBER_IN,
      TRG_CODE_IN           => TRG_CODE_IN,
      TRG_INFORMATION_IN    => TRG_INFORMATION_IN,
      TRG_TYPE_IN           => TRG_TYPE_IN,
      TRG_RELEASE_OUT       => TRG_RELEASE_OUT,
      TRG_STATUSBIT_OUT     => TRG_STATUSBIT_OUT,
      DATA_OUT              => DATA_OUT,
      DATA_WRITE_OUT        => DATA_WRITE_OUT,
      DATA_FINISHED_OUT     => data_finished_i,
      READOUT_BUSY_OUT      => readout_busy_i,
      READ_EN_OUT           => rd_en_i,
      TRIGGER_WIN_END_OUT   => trg_win_end_i,
      SLOW_CONTROL_REG_OUT  => SLOW_CONTROL_REG_OUT,
      READOUT_DEBUG         => readout_debug_i);
  DATA_FINISHED_OUT <= data_finished_i;

-- Logic Analyser
  TheLogicAnalyser : LogicAnalyser
    generic map (
      CHANNEL_NUMBER => CHANNEL_NUMBER,
      STATUS_REG_NR  => STATUS_REG_NR)
    port map (
      CLK        => CLK_READOUT,
      RESET      => RESET,
      DATA_IN    => logic_anal_data_i,
      CONTROL_IN => logic_anal_control,
      DATA_OUT   => LOGIC_ANALYSER_OUT);

  logic_anal_data_i(7 downto 0)   <= readout_debug_i(7 downto 0);
  logic_anal_data_i(8)            <= REFERENCE_TIME;
  logic_anal_data_i(9)            <= VALID_TIMING_TRG_IN;
  logic_anal_data_i(10)           <= VALID_NOTIMING_TRG_IN;
  logic_anal_data_i(11)           <= INVALID_TRG_IN;
  logic_anal_data_i(12)           <= TRG_DATA_VALID_IN;
  logic_anal_data_i(13)           <= readout_debug_i(8);   --data_wr_reg;
  logic_anal_data_i(14)           <= readout_debug_i(9);   --data_finished_reg;
  logic_anal_data_i(15)           <= readout_debug_i(10);  --trg_release_reg;
  logic_anal_data_i(31 downto 16) <= ref_debug_i(15 downto 0);
  logic_anal_data_i(37 downto 32) <= readout_debug_i(16 downto 11);  --data_out_reg(27 downto 22);
  logic_anal_data_i(47 downto 38) <= (others => '0');
  logic_anal_data_i(63 downto 48) <= ch_debug_i(1)(15 downto 0);
  logic_anal_data_i(95 downto 64) <= (others => '0');
  
end TDC;
