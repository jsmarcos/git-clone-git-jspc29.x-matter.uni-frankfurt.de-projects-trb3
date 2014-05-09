library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.config.all;

entity Channel is

  generic (
    CHANNEL_ID : integer range 0 to 64;
    DEBUG      : integer range 0 to 1;
    SIMULATION : integer range 0 to 1;
    REFERENCE  : integer range 0 to 1);
  port (
    RESET_200               : in  std_logic;
    RESET_100               : in  std_logic;
    RESET_COUNTERS          : in  std_logic;
    CLK_200                 : in  std_logic;
    CLK_100                 : in  std_logic;
--
    HIT_IN                  : in  std_logic;
    TRIGGER_WIN_END_TDC     : in  std_logic;
    TRIGGER_WIN_END_RDO     : in  std_logic;
    READ_EN_IN              : in  std_logic;
    FIFO_DATA_OUT           : out std_logic_vector(35 downto 0);
    FIFO_DATA_VALID_OUT     : out std_logic;
    FIFO_EMPTY_OUT          : out std_logic;
    FIFO_FULL_OUT           : out std_logic;
    FIFO_ALMOST_EMPTY_OUT   : out std_logic;
    FIFO_ALMOST_FULL_OUT    : out std_logic;
    COARSE_COUNTER_IN       : in  std_logic_vector(10 downto 0);
    EPOCH_COUNTER_IN        : in  std_logic_vector(27 downto 0);
--
    VALID_TIMING_TRG_IN     : in  std_logic;
    VALID_NOTIMING_TRG_IN   : in  std_logic;
    SPIKE_DETECTED_IN       : in  std_logic;
    MULTI_TMG_TRG_IN        : in  std_logic;
--
    EPOCH_WRITE_EN_IN       : in  std_logic;
    LOST_HIT_NUMBER         : out std_logic_vector(23 downto 0);
    HIT_DETECT_NUMBER       : out std_logic_vector(23 downto 0);
    ENCODER_START_NUMBER    : out std_logic_vector(23 downto 0);
    ENCODER_FINISHED_NUMBER : out std_logic_vector(23 downto 0);
    FIFO_WRITE_NUMBER       : out std_logic_vector(23 downto 0);
--
    Channel_200_DEBUG       : out std_logic_vector(31 downto 0);
    Channel_DEBUG           : out std_logic_vector(31 downto 0)
    );

end Channel;

architecture Channel of Channel is
-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

  -- time stamp
  signal coarse_cntr_reg    : std_logic_vector(10 downto 0);
  signal epoch_cntr_reg     : std_logic_vector(27 downto 0);
  signal trig_win_end_tdc_i : std_logic;
  signal trig_win_end_rdo_i : std_logic;

  -- from channel
  signal ch_data_i        : std_logic_vector(35 downto 0);
  signal ch_data_valid_i  : std_logic;
  signal ch_empty_i       : std_logic;
  signal ch_full_i        : std_logic;
  signal ch_almost_full_i : std_logic;

  -- from buffer
  signal buf_data_i         : std_logic_vector(35 downto 0);
  signal buf_data_valid_i   : std_logic;
  signal buf_empty_i        : std_logic;
  signal buf_empty_reg      : std_logic;
  signal buf_full_i         : std_logic;
  signal buf_almost_full_i  : std_logic;

  -- fron readout
  signal rd_en_reg : std_logic;

  -- debug
  signal sync_q                  : std_logic_vector(2 downto 0);
  signal hit_pulse_100           : std_logic;
  signal encoder_finished_i      : std_logic;
  signal encoder_finished_100    : std_logic;
  signal encoder_start_i         : std_logic;
  signal encoder_start_100       : std_logic;
  signal fifo_write_i            : std_logic;
  signal fifo_write_100          : std_logic;
  signal lost_hit_cntr           : unsigned(23 downto 0);
  signal hit_detect_cntr         : unsigned(23 downto 0);
  signal encoder_start_cntr      : unsigned(23 downto 0);
  signal encoder_finished_cntr   : unsigned(23 downto 0);
  signal fifo_write_cntr         : unsigned(23 downto 0);
  signal channel_200_debug_i     : std_logic_vector(31 downto 0);
  signal ch_buffer_counter       : unsigned(15 downto 0) := (others => '0');
  signal ch_buffer_out_counter   : unsigned(15 downto 0) := (others => '0');
  signal ch_buffer_valid_counter : unsigned(15 downto 0) := (others => '0');

  -- other

-------------------------------------------------------------------------------

  attribute syn_keep                           : boolean;
  attribute syn_keep of trig_win_end_tdc_i     : signal is true;
  attribute syn_keep of trig_win_end_rdo_i     : signal is true;
  attribute syn_keep of epoch_cntr_reg         : signal is true;
  attribute syn_preserve                       : boolean;
  attribute syn_preserve of coarse_cntr_reg    : signal is true;
  attribute syn_preserve of trig_win_end_tdc_i : signal is true;
  attribute syn_preserve of epoch_cntr_reg     : signal is true;
  attribute nomerge                            : string;
  attribute nomerge of trig_win_end_tdc_i      : signal is "true";
  attribute nomerge of trig_win_end_rdo_i      : signal is "true";
  attribute nomerge of epoch_cntr_reg          : signal is "true";

-------------------------------------------------------------------------------

begin

  Channel200 : Channel_200
    generic map (
      CHANNEL_ID => CHANNEL_ID,
      DEBUG      => DEBUG,
      SIMULATION => SIMULATION,
      REFERENCE  => REFERENCE)
    port map (
      CLK_200               => CLK_200,
      RESET_200             => RESET_200,
      CLK_100               => CLK_100,
      RESET_100             => RESET_100,
      RESET_COUNTERS        => RESET_COUNTERS,
      HIT_IN                => HIT_IN,
      TRIGGER_WIN_END_TDC   => trig_win_end_tdc_i,
      TRIGGER_WIN_END_RDO   => trig_win_end_rdo_i,
      EPOCH_COUNTER_IN      => epoch_cntr_reg,
      COARSE_COUNTER_IN     => coarse_cntr_reg,
      READ_EN_IN            => READ_EN_IN,
      FIFO_DATA_OUT         => ch_data_i,
      FIFO_DATA_VALID_OUT   => ch_data_valid_i,
      FIFO_EMPTY_OUT        => ch_empty_i,
      FIFO_FULL_OUT         => ch_full_i,
      FIFO_ALMOST_FULL_OUT  => ch_almost_full_i,
      VALID_TIMING_TRG_IN   => VALID_TIMING_TRG_IN,
      VALID_NOTIMING_TRG_IN => VALID_NOTIMING_TRG_IN,
      SPIKE_DETECTED_IN     => SPIKE_DETECTED_IN,
      MULTI_TMG_TRG_IN      => MULTI_TMG_TRG_IN,
      EPOCH_WRITE_EN_IN     => EPOCH_WRITE_EN_IN,
      ENCODER_START_OUT     => encoder_start_i,
      ENCODER_FINISHED_OUT  => encoder_finished_i,
      FIFO_WRITE_OUT        => fifo_write_i,
      CHANNEL_200_DEBUG     => channel_200_debug_i);

  Buffer_128 : if RING_BUFFER_SIZE = 128 generate
    The_Buffer : FIFO_36x128_OutReg
      port map (
        Data        => ch_data_i,
        Clock       => CLK_100,
        WrEn        => ch_data_valid_i,
        RdEn        => READ_EN_IN,
        Reset       => RESET_100,
        Q           => buf_data_i,
        Empty       => buf_empty_i,
        Full        => buf_full_i);
  end generate Buffer_128;

  Buffer_64 : if RING_BUFFER_SIZE = 64 generate
    The_Buffer : FIFO_36x64_OutReg
      port map (
        Data        => ch_data_i,
        Clock       => CLK_100,
        WrEn        => ch_data_valid_i,
        RdEn        => READ_EN_IN,
        Reset       => RESET_100,
        Q           => buf_data_i,
        Empty       => buf_empty_i,
        Full        => buf_full_i);
  end generate Buffer_64;

  Buffer_32 : if RING_BUFFER_SIZE = 32 generate
    The_Buffer : FIFO_36x32_OutReg
      port map (
        Data        => ch_data_i,
        Clock       => CLK_100,
        WrEn        => ch_data_valid_i,
        RdEn        => READ_EN_IN,
        Reset       => RESET_100,
        Q           => buf_data_i,
        Empty       => buf_empty_i,
        Full        => buf_full_i);
  end generate Buffer_32;

  Buffer_16 : if RING_BUFFER_SIZE = 16 generate
    The_Buffer : FIFO_36x16_OutReg
      port map (
        Data        => ch_data_i,
        Clock       => CLK_100,
        WrEn        => ch_data_valid_i,
        RdEn        => READ_EN_IN,
        Reset       => RESET_100,
        Q           => buf_data_i,
        Empty       => buf_empty_i,
        Full        => buf_full_i);
  end generate Buffer_16;

  FIFO_DATA_OUT         <= buf_data_i;
  FIFO_DATA_VALID_OUT   <= buf_data_valid_i;
  FIFO_EMPTY_OUT        <= buf_empty_i;
  FIFO_ALMOST_EMPTY_OUT <= '0';
  trig_win_end_tdc_i    <= TRIGGER_WIN_END_TDC;
  trig_win_end_rdo_i    <= TRIGGER_WIN_END_RDO;
  rd_en_reg             <= READ_EN_IN                      when rising_edge(CLK_100);
  buf_empty_reg         <= buf_empty_i                     when rising_edge(CLK_100);
  buf_data_valid_i      <= rd_en_reg and not buf_empty_reg when rising_edge(CLK_100);

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

  pulse_sync_fifo_write : pulse_sync
    port map (
      CLK_A_IN    => CLK_200,
      RESET_A_IN  => RESET_200,
      PULSE_A_IN  => fifo_write_i,
      CLK_B_IN    => CLK_100,
      RESET_B_IN  => RESET_100,
      PULSE_B_OUT => fifo_write_100);

  CoarseCounter : ShiftRegisterSISO
    generic map (
      DEPTH => 1,
      WIDTH => 11)
    port map (
      CLK   => CLK_200,
      D_IN  => COARSE_COUNTER_IN,
      D_OUT => coarse_cntr_reg);

  epoch_cntr_reg <= EPOCH_COUNTER_IN when rising_edge(CLK_200);

-------------------------------------------------------------------------------
-- DEBUG Counters
-------------------------------------------------------------------------------
  gen_DEBUG : if DEBUG = c_YES generate
    --purpose: Hit Signal Synchroniser
    sync_q(0) <= HIT_IN    when rising_edge(CLK_100);
    sync_q(1) <= sync_q(0) when rising_edge(CLK_100);
    sync_q(2) <= sync_q(1) when rising_edge(CLK_100);

    risingEdgeDetect_1 : risingEdgeDetect
      port map (
        CLK       => CLK_100,
        SIGNAL_IN => sync_q(2),
        PULSE_OUT => hit_pulse_100);

    --purpose: Counts the detected but unwritten hits
    Lost_Hit_Counter : process (CLK_100)
    begin
      if rising_edge(CLK_100) then
        if RESET_COUNTERS = '1' then
          lost_hit_cntr <= (others => '0');
        elsif hit_pulse_100 = '1' then
          lost_hit_cntr <= lost_hit_cntr + to_unsigned(1, 1);
        elsif fifo_write_100 = '1' then
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
          ch_buffer_counter <= (others => '0');
        elsif ch_data_valid_i = '1' then
          if ch_data_i(35 downto 31) = "00011" then  -- it is a data word
            ch_buffer_counter <= ch_buffer_counter + to_unsigned(1, 16);
          end if;
        end if;
      --elsif encoder_start_100 = '1' then
      --  encoder_start_cntr <= encoder_start_cntr + to_unsigned(1, 1);
      --end if;
      end if;
    end process Encoder_Start_Counter;

    --ENCODER_START_NUMBER <= std_logic_vector(encoder_start_cntr) when rising_edge(CLK_100);
    ENCODER_START_NUMBER(15 downto 0) <= std_logic_vector(ch_buffer_counter) when rising_edge(CLK_100);

    --purpose: Counts the encoder finished signals
    ENCODER_FINISHED_Counter : process (CLK_100)
    begin
      if rising_edge(CLK_100) then
        if RESET_COUNTERS = '1' then
          ch_buffer_out_counter <= (others => '0');
        elsif buf_data_i(35 downto 31) = "00011" then
          ch_buffer_out_counter <= ch_buffer_out_counter + to_unsigned(1, 16);
        end if;
      end if;
    end process ENCODER_FINISHED_Counter;

    --ENCODER_FINISHED_NUMBER <= std_logic_vector(encoder_finished_cntr) when rising_edge(CLK_100);
    ENCODER_FINISHED_NUMBER(15 downto 0) <= std_logic_vector(ch_buffer_out_counter) when rising_edge(CLK_100);

    --purpose: Counts the written hits
    FIFO_WRITE_Counter : process (CLK_100)
    begin
      if rising_edge(CLK_100) then
        if RESET_COUNTERS = '1' then
          ch_buffer_valid_counter <= (others => '0');
        elsif buf_data_valid_i = '1' then
          if buf_data_i(35 downto 31) = "00011" then
            ch_buffer_valid_counter <= ch_buffer_valid_counter + to_unsigned(1, 16);
          end if;
        end if;
      end if;
    end process FIFO_WRITE_Counter;

    --FIFO_WRITE_NUMBER <= std_logic_vector(fifo_write_cntr) when rising_edge(CLK_100);
    FIFO_WRITE_NUMBER(15 downto 0) <= std_logic_vector(ch_buffer_valid_counter) when rising_edge(CLK_100);
  end generate gen_DEBUG;

-------------------------------------------------------------------------------
-- DEBUG
-------------------------------------------------------------------------------
  Channel_DEBUG(7 downto 0) <= buf_data_i(35 downto 28);
  Channel_DEBUG(8)          <= buf_data_valid_i;
  Channel_DEBUG(9)          <= READ_EN_IN;


  Channel_200_DEBUG <= channel_200_debug_i;
  --Channel_DEBUG(0) <= fifo_write_100 when rising_edge(CLK_100);
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
