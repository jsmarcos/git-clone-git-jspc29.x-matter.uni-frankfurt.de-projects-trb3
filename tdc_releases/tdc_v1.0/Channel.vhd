library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.version.all;

entity Channel is

  generic (
    CHANNEL_ID : integer range 1 to 64);
  port (
    RESET_200             : in  std_logic;
    RESET_100             : in  std_logic;
    RESET_COUNTERS        : in  std_logic;
    CLK_200               : in  std_logic;
    CLK_100               : in  std_logic;
--
    HIT_IN                : in  std_logic;
    SCALER_IN             : in  std_logic;
    READ_EN_IN            : in  std_logic;
    FIFO_DATA_OUT         : out std_logic_vector(31 downto 0);
    FIFO_EMPTY_OUT        : out std_logic;
    FIFO_FULL_OUT         : out std_logic;
    FIFO_ALMOST_FULL_OUT  : out std_logic;
    COARSE_COUNTER_IN     : in  std_logic_vector(10 downto 0);
    EPOCH_COUNTER_IN      : in  std_logic_vector(27 downto 0);
    TRIGGER_WINDOW_END_IN : in  std_logic;
    DATA_FINISHED_IN      : in  std_logic;
    RUN_MODE              : in  std_logic;
--
    LOST_HIT_NUMBER       : out std_logic_vector(23 downto 0);
    HIT_DETECT_NUMBER     : out std_logic_vector(23 downto 0);
    ENCODER_START_NUMBER  : out std_logic_vector(23 downto 0);
    FIFO_WR_NUMBER        : out std_logic_vector(23 downto 0);
--
    Channel_DEBUG         : out std_logic_vector(31 downto 0)
    );

end Channel;

architecture Channel of Channel is
-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

  signal hit_in_i       : std_logic;
  signal hit_buf        : std_logic;
  signal hit_detect_reg : std_logic;

  -- time stamp
  signal coarse_cntr_reg : std_logic_vector(10 downto 0);

  -- scaler
  signal lost_hit_number_i      : std_logic_vector(23 downto 0);
  signal hit_detect_number_i    : std_logic_vector(23 downto 0);
  signal encoder_start_number_i : std_logic_vector(23 downto 0);
  signal fifo_wr_number_i       : std_logic_vector(23 downto 0);

  -- other
  signal trg_win_end_i   : std_logic;
  signal data_finished_i : std_logic;
  signal run_mode_i      : std_logic;

-------------------------------------------------------------------------------

  attribute syn_keep                          : boolean;
  attribute syn_keep of hit_buf               : signal is true;
  attribute syn_preserve                      : boolean;
  attribute syn_preserve of coarse_cntr_reg   : signal is true;

-------------------------------------------------------------------------------

begin

  hit_in_i <= HIT_IN;
  hit_buf  <= not hit_in_i;

  Channel_200_1 : Channel_200
    generic map (
      CHANNEL_ID => CHANNEL_ID)
    port map (
      CLK_200               => CLK_200,
      RESET_200             => RESET_200,
      CLK_100               => CLK_100,
      RESET_100             => RESET_100,
      RESET_COUNTERS        => RESET_COUNTERS,
      HIT_IN                => hit_buf,
      HIT_DETECT_OUT        => open,
      TIME_STAMP_IN         => (others => '0'),
      SCALER_IN             => SCALER_IN,
      EPOCH_COUNTER_IN      => EPOCH_COUNTER_IN,
      TRIGGER_WINDOW_END_IN => trg_win_end_i,
      DATA_FINISHED_IN      => data_finished_i,
      RUN_MODE              => run_mode_i,
      COARSE_COUNTER_IN     => coarse_cntr_reg,
      READ_EN_IN            => READ_EN_IN,
      FIFO_DATA_OUT         => FIFO_DATA_OUT,
      FIFO_EMPTY_OUT        => FIFO_EMPTY_OUT,
      FIFO_FULL_OUT         => FIFO_FULL_OUT,
      FIFO_ALMOST_FULL_OUT  => FIFO_ALMOST_FULL_OUT,
      FIFO_WR_OUT           => open,
      ENCODER_START_OUT     => open,
      LOST_HIT_NUMBER       => lost_hit_number_i,
      HIT_DETECT_NUMBER     => hit_detect_number_i,
      ENCODER_START_NUMBER  => encoder_start_number_i,
      FIFO_WR_NUMBER        => fifo_wr_number_i);

  LOST_HIT_NUMBER      <= lost_hit_number_i      when rising_edge(CLK_100);
  HIT_DETECT_NUMBER    <= hit_detect_number_i    when rising_edge(CLK_100);
  ENCODER_START_NUMBER <= encoder_start_number_i when rising_edge(CLK_100);
  FIFO_WR_NUMBER       <= fifo_wr_number_i       when rising_edge(CLK_100);
  trg_win_end_i        <= TRIGGER_WINDOW_END_IN  when rising_edge(CLK_200);
  data_finished_i      <= DATA_FINISHED_IN       when rising_edge(CLK_100);
  run_mode_i           <= RUN_MODE               when rising_edge(CLK_100);

  CoarseCounter : ShiftRegisterSISO
    generic map (
      DEPTH => 1,
      WIDTH => 11)
    port map (
      CLK   => CLK_200,
      RESET => RESET_200,
      D_IN  => COARSE_COUNTER_IN,
      D_OUT => coarse_cntr_reg);

  --Channel_DEBUG(0)            <= HIT_IN;
  --Channel_DEBUG(1)            <= result_2_reg;
  --Channel_DEBUG(2)            <= hit_detect_i;
  --Channel_DEBUG(3)            <= hit_detect_reg;
  --Channel_DEBUG(4)            <= '0';
  --Channel_DEBUG(5)            <= ff_array_en_i;
  --Channel_DEBUG(6)            <= encoder_start_i;
  --Channel_DEBUG(7)            <= fifo_wr_i;
  --Channel_DEBUG(15 downto 8)  <= result_i(7 downto 0);
  --Channel_DEBUG(31 downto 16) <= (others => '0');

end Channel;
