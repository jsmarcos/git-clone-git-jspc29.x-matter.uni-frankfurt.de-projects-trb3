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

  -- reset
  signal reset_counters_200 : std_logic;

  -- hit signals
  signal hit_in_i       : std_logic;
  signal hit_buf        : std_logic;
  signal hit_detect_reg : std_logic;

  -- time stamp
  signal coarse_cntr_reg : std_logic_vector(10 downto 0);

  -- debug
  signal sync_q             : std_logic_vector(2 downto 0);
  signal hit_pulse          : std_logic;
  signal hit_pulse_r        : std_logic;
  signal fifo_wr_en_i       : std_logic;
  signal fifo_wr_en_reg     : std_logic;
  signal encoder_start_i    : std_logic;
  signal encoder_start_reg  : std_logic;
  signal lost_hit_cntr      : unsigned(23 downto 0);
  signal hit_detect_cntr    : unsigned(23 downto 0);
  signal encoder_start_cntr : unsigned(23 downto 0);
  signal fifo_wr_cntr       : unsigned(23 downto 0);

  -- other
  signal data_finished_i : std_logic;
  signal run_mode_i      : std_logic;

-------------------------------------------------------------------------------

  attribute syn_keep                        : boolean;
  attribute syn_keep of hit_buf             : signal is true;
  attribute syn_preserve                    : boolean;
  attribute syn_preserve of coarse_cntr_reg : signal is true;

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
      HIT_IN                => hit_buf,
      EPOCH_COUNTER_IN      => EPOCH_COUNTER_IN,
      DATA_FINISHED_IN      => data_finished_i,
      RUN_MODE              => run_mode_i,
      COARSE_COUNTER_IN     => coarse_cntr_reg,
      READ_EN_IN            => READ_EN_IN,
      FIFO_DATA_OUT         => FIFO_DATA_OUT,
      FIFO_EMPTY_OUT        => FIFO_EMPTY_OUT,
      FIFO_FULL_OUT         => FIFO_FULL_OUT,
      FIFO_ALMOST_FULL_OUT  => FIFO_ALMOST_FULL_OUT,
      FIFO_WR_OUT           => fifo_wr_en_i,
      ENCODER_START_OUT     => encoder_start_i);

  data_finished_i   <= DATA_FINISHED_IN      when rising_edge(CLK_100);
  run_mode_i        <= RUN_MODE              when rising_edge(CLK_100);
  encoder_start_reg <= encoder_start_i       when rising_edge(CLK_200);
  fifo_wr_en_reg    <= fifo_wr_en_i          when rising_edge(CLK_200);

  CoarseCounter : ShiftRegisterSISO
    generic map (
      DEPTH => 1,
      WIDTH => 11)
    port map (
      CLK   => CLK_200,
      RESET => RESET_200,
      D_IN  => COARSE_COUNTER_IN,
      D_OUT => coarse_cntr_reg);

-------------------------------------------------------------------------------
-- DEBUG Counters
-------------------------------------------------------------------------------
  reset_counters_200 <= RESET_COUNTERS when rising_edge(CLK_200);

  --purpose: Hit Signal Synchroniser
  sync_q(0) <= SCALER_IN when rising_edge(CLK_200);
  sync_q(1) <= sync_q(0) when rising_edge(CLK_200);
  sync_q(2) <= sync_q(1) when rising_edge(CLK_200);

  edge_to_pulse_1 : edge_to_pulse
    port map (
      clock     => CLK_200,
      en_clk    => '1',
      signal_in => sync_q(2),
      pulse     => hit_pulse);

  hit_pulse_r <= hit_pulse when rising_edge(CLK_200);

  --purpose: Counts the detected but unwritten hits
  Lost_Hit_Counter : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' or reset_counters_200 = '1' then
        lost_hit_cntr <= (others => '0');
      elsif hit_pulse_r = '1' then
        lost_hit_cntr <= lost_hit_cntr + to_unsigned(1, 1);
      elsif fifo_wr_en_reg = '1' then
        lost_hit_cntr <= lost_hit_cntr - to_unsigned(1, 1);
      end if;
    end if;
  end process Lost_Hit_Counter;

  LOST_HIT_NUMBER <= std_logic_vector(lost_hit_cntr) when rising_edge(CLK_100);

  --purpose: Counts the detected hits
  Hit_Detect_Counter : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' or reset_counters_200 = '1' then
        hit_detect_cntr <= (others => '0');
      elsif hit_pulse_r = '1' then
        hit_detect_cntr <= hit_detect_cntr + to_unsigned(1, 1);
      end if;
    end if;
  end process Hit_Detect_Counter;

  HIT_DETECT_NUMBER <= std_logic_vector(hit_detect_cntr) when rising_edge(CLK_100);

  --purpose: Counts the encoder start times
  Encoder_Start_Counter : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' or reset_counters_200 = '1' then
        encoder_start_cntr <= (others => '0');
      elsif encoder_start_reg = '1' then
        encoder_start_cntr <= encoder_start_cntr + to_unsigned(1, 1);
      end if;
    end if;
  end process Encoder_Start_Counter;

  ENCODER_START_NUMBER <= std_logic_vector(encoder_start_cntr) when rising_edge(CLK_100);

  --purpose: Counts the written hits
  FIFO_WR_Counter : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' or reset_counters_200 = '1' then
        fifo_wr_cntr <= (others => '0');
      elsif fifo_wr_en_reg = '1' then
        fifo_wr_cntr <= fifo_wr_cntr + to_unsigned(1, 1);
      end if;
    end if;
  end process FIFO_WR_Counter;

  FIFO_WR_NUMBER <= std_logic_vector(fifo_wr_cntr) when rising_edge(CLK_100);

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
