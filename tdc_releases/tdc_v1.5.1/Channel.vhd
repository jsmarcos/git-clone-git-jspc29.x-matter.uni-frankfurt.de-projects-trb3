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
    CHANNEL_ID : integer range 0 to 64);
  port (
    RESET_200               : in  std_logic;
    RESET_100               : in  std_logic;
    RESET_COUNTERS          : in  std_logic;
    CLK_200                 : in  std_logic;
    CLK_100                 : in  std_logic;
--
    HIT_IN                  : in  std_logic;
    TRIGGER_WIN_END_IN      : in  std_logic;
    READ_EN_IN              : in  std_logic;
    FIFO_DATA_OUT           : out std_logic_vector(35 downto 0);
    FIFO_WCNT_OUT           : out unsigned(7 downto 0);
    FIFO_EMPTY_OUT          : out std_logic;
    FIFO_FULL_OUT           : out std_logic;
    FIFO_ALMOST_FULL_OUT    : out std_logic;
    COARSE_COUNTER_IN       : in  std_logic_vector(10 downto 0);
    EPOCH_COUNTER_IN        : in  std_logic_vector(27 downto 0);
--    DATA_FINISHED_IN        : in  std_logic;
--
    LOST_HIT_NUMBER         : out std_logic_vector(23 downto 0);
    HIT_DETECT_NUMBER       : out std_logic_vector(23 downto 0);
    ENCODER_START_NUMBER    : out std_logic_vector(23 downto 0);
    ENCODER_FINISHED_NUMBER : out std_logic_vector(23 downto 0);
--
    Channel_DEBUG           : out std_logic_vector(31 downto 0)
    );

end Channel;

architecture Channel of Channel is
-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

  -- hit signals
  signal hit_in_i : std_logic;
  signal hit_buf  : std_logic;

  -- time stamp
  signal coarse_cntr_reg : std_logic_vector(10 downto 0);
  signal trig_win_end_i  : std_logic;

  -- debug
  signal sync_q                : std_logic_vector(2 downto 0);
  signal hit_pulse             : std_logic;
  signal hit_pulse_100         : std_logic;
  signal encoder_start_i       : std_logic;
  signal encoder_start_100     : std_logic;
  signal encoder_finished_i    : std_logic;
  signal encoder_finished_100  : std_logic;
  signal lost_hit_cntr         : unsigned(23 downto 0) := (others => '0');
  signal hit_detect_cntr       : unsigned(23 downto 0) := (others => '0');
  signal encoder_start_cntr    : unsigned(23 downto 0) := (others => '0');
  signal encoder_finished_cntr : unsigned(23 downto 0) := (others => '0');

  -- other
-- signal data_finished_i : std_logic;

-------------------------------------------------------------------------------

  attribute syn_keep                        : boolean;
  attribute syn_keep of hit_buf             : signal is true;
  attribute syn_preserve                    : boolean;
  attribute syn_preserve of coarse_cntr_reg : signal is true;
  attribute syn_preserve of hit_buf         : signal is true;
  attribute syn_preserve of trig_win_end_i  : signal is true;
  attribute nomerge                         : string;
  attribute nomerge of hit_buf              : signal is "true";

-------------------------------------------------------------------------------

begin

  hit_in_i <= HIT_IN;
  hit_buf  <= not hit_in_i;

  Channel_200_1 : entity work.Channel_200
    generic map (
      CHANNEL_ID => CHANNEL_ID)
    port map (
      CLK_200              => CLK_200,
      RESET_200            => RESET_200,
      CLK_100              => CLK_100,
      RESET_100            => RESET_100,
      HIT_IN               => hit_buf,
      TRIGGER_WIN_END_IN   => trig_win_end_i,
      EPOCH_COUNTER_IN     => EPOCH_COUNTER_IN,
--      DATA_FINISHED_IN     => data_finished_i,
      COARSE_COUNTER_IN    => coarse_cntr_reg,
      READ_EN_IN           => READ_EN_IN,
      FIFO_DATA_OUT        => FIFO_DATA_OUT,
      FIFO_WCNT_OUT        => FIFO_WCNT_OUT,
      FIFO_EMPTY_OUT       => FIFO_EMPTY_OUT,
      FIFO_FULL_OUT        => FIFO_FULL_OUT,
      FIFO_ALMOST_FULL_OUT => FIFO_ALMOST_FULL_OUT,
      ENCODER_START_OUT    => encoder_start_i,
      ENCODER_FINISHED_OUT => encoder_finished_i);

  trig_win_end_i <= TRIGGER_WIN_END_IN when rising_edge(CLK_200);
--  data_finished_i <= DATA_FINISHED_IN when rising_edge(CLK_100);

  pulse_sync_encoder_start : pulse_sync
    port map (
      CLK_A_IN    => CLK_200,
      RESET_A_IN  => RESET_200,
      PULSE_A_IN  => encoder_start_i,
      CLK_B_IN    => CLK_100,
      RESET_B_IN  => RESET_100,
      PULSE_B_OUT => encoder_start_100);

  pulse_sync_encoder_finished : pulse_sync
    port map (
      CLK_A_IN    => CLK_200,
      RESET_A_IN  => RESET_200,
      PULSE_A_IN  => encoder_finished_i,
      CLK_B_IN    => CLK_100,
      RESET_B_IN  => RESET_100,
      PULSE_B_OUT => encoder_finished_100);

  CoarseCounter : ShiftRegisterSISO
    generic map (
      DEPTH => 1,
      WIDTH => 11)
    port map (
      CLK   => CLK_200,
      D_IN  => COARSE_COUNTER_IN,
      D_OUT => coarse_cntr_reg);

-------------------------------------------------------------------------------
-- DEBUG Counters
-------------------------------------------------------------------------------
  --purpose: Hit Signal Synchroniser
  sync_q(0) <= HIT_IN    when rising_edge(CLK_200);
  sync_q(1) <= sync_q(0) when rising_edge(CLK_200);
  sync_q(2) <= sync_q(1) when rising_edge(CLK_200);

  edge_to_pulse_1 : edge_to_pulse
    port map (
      clock     => CLK_200,
      en_clk    => '1',
      signal_in => sync_q(2),
      pulse     => hit_pulse);

  pulse_sync_hit : pulse_sync
    port map (
      CLK_A_IN    => CLK_200,
      RESET_A_IN  => RESET_200,
      PULSE_A_IN  => hit_pulse,
      CLK_B_IN    => CLK_100,
      RESET_B_IN  => RESET_100,
      PULSE_B_OUT => hit_pulse_100);

  --purpose: Counts the detected but unwritten hits
  Lost_Hit_Counter : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        lost_hit_cntr <= (others => '0');
      elsif hit_pulse_100 = '1' then
        lost_hit_cntr <= lost_hit_cntr + to_unsigned(1, 1);
      elsif encoder_finished_100 = '1' then
        lost_hit_cntr <= lost_hit_cntr - to_unsigned(1, 1);
      end if;
    end if;
  end process Lost_Hit_Counter;

  LOST_HIT_NUMBER <= std_logic_vector(lost_hit_cntr) when rising_edge(CLK_100);

  --purpose: Counts the detected hits
  Hit_Detect_Counter : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        hit_detect_cntr <= (others => '0');
      elsif hit_pulse_100 = '1' then
        hit_detect_cntr <= hit_detect_cntr + to_unsigned(1, 1);
      end if;
    end if;
  end process Hit_Detect_Counter;

  HIT_DETECT_NUMBER <= std_logic_vector(hit_detect_cntr) when rising_edge(CLK_100);

  --purpose: Counts the encoder start times
  Encoder_Start_Counter : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        encoder_start_cntr <= (others => '0');
      elsif encoder_start_100 = '1' then
        encoder_start_cntr <= encoder_start_cntr + to_unsigned(1, 1);
      end if;
    end if;
  end process Encoder_Start_Counter;

  ENCODER_START_NUMBER <= std_logic_vector(encoder_start_cntr) when rising_edge(CLK_100);

  --purpose: Counts the written hits
  Encoder_Finished_Counter : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        encoder_finished_cntr <= (others => '0');
      elsif encoder_finished_100 = '1' then
        encoder_finished_cntr <= encoder_finished_cntr + to_unsigned(1, 1);
      end if;
    end if;
  end process Encoder_Finished_Counter;

  ENCODER_FINISHED_NUMBER <= std_logic_vector(encoder_finished_cntr) when rising_edge(CLK_100);

  --Channel_DEBUG(0)            <= HIT_IN;
  --Channel_DEBUG(1)            <= result_2_reg;
  --Channel_DEBUG(2)            <= hit_detect_i;
  --Channel_DEBUG(3)            <= hit_detect_reg;
  --Channel_DEBUG(4)            <= '0';
  --Channel_DEBUG(5)            <= ff_array_en_i;
  --Channel_DEBUG(6)            <= encoder_start_i;
  --Channel_DEBUG(7)            <= encoder_finished_i;
  --Channel_DEBUG(15 downto 8)  <= result_i(7 downto 0);
  --Channel_DEBUG(31 downto 16) <= (others => '0');

end Channel;
