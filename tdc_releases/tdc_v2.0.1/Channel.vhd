library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.tdc_components.all;
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
    HIT_EDGE_IN             : in  std_logic;
    TRG_WIN_END_TDC_IN      : in  std_logic;
    TRG_WIN_END_RDO_IN      : in  std_logic;
    READ_EN_IN              : in  std_logic;
    FIFO_DATA_OUT           : out std_logic_vector(35 downto 0);
    FIFO_DATA_VALID_OUT     : out std_logic;
    FIFO_EMPTY_OUT          : out std_logic;
    FIFO_FULL_OUT           : out std_logic;
    FIFO_ALMOST_EMPTY_OUT   : out std_logic;
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
    HIT_DETECT_NUMBER       : out std_logic_vector(30 downto 0);
    ENCODER_START_NUMBER    : out std_logic_vector(23 downto 0);
    ENCODER_FINISHED_NUMBER : out std_logic_vector(23 downto 0);
    FIFO_WRITE_NUMBER       : out std_logic_vector(23 downto 0);
--
    Channel_200_DEBUG_OUT   : out std_logic_vector(31 downto 0);
    Channel_DEBUG_OUT       : out std_logic_vector(31 downto 0)
    );

end Channel;

architecture Channel of Channel is
-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

  -- time stamp
  signal coarse_cntr_reg : std_logic_vector(10 downto 0);
  signal epoch_cntr_reg  : std_logic_vector(27 downto 0);
  signal trg_win_end_tdc : std_logic;
  signal trg_win_end_rdo : std_logic;

  -- from channel
  signal ch_data       : std_logic_vector(35 downto 0);
  signal ch_data_valid : std_logic;

  -- from buffer
  signal buf_data        : std_logic_vector(35 downto 0);
  signal buf_data_valid  : std_logic;
  signal buf_empty       : std_logic;
  signal buf_empty_reg   : std_logic;
  signal buf_full        : std_logic;
  signal buf_almost_full : std_logic;

  -- fron readout
  signal rd_en_reg : std_logic;

  -- debug
  signal sync_q                  : std_logic_vector(2 downto 0);
  signal hit_pulse_100           : std_logic;
  signal encoder_finished        : std_logic;
  signal encoder_finished_100    : std_logic;
  signal encoder_start           : std_logic;
  signal encoder_start_100       : std_logic;
  signal fifo_write              : std_logic;
  signal fifo_write_100          : std_logic;
  signal lost_hit_cntr           : unsigned(23 downto 0);
  signal hit_detect_cntr         : unsigned(30 downto 0);
  signal encoder_start_cntr      : unsigned(23 downto 0);
  signal encoder_finished_cntr   : unsigned(23 downto 0);
  signal fifo_write_cntr         : unsigned(23 downto 0);
  signal channel_200_debug       : std_logic_vector(31 downto 0);
  signal ch_buffer_counter       : unsigned(15 downto 0) := (others => '0');
  signal ch_buffer_out_counter   : unsigned(15 downto 0) := (others => '0');
  signal ch_buffer_valid_counter : unsigned(15 downto 0) := (others => '0');

  -- other

-------------------------------------------------------------------------------

  attribute syn_keep                        : boolean;
  attribute syn_keep of trg_win_end_tdc     : signal is true;
  attribute syn_keep of trg_win_end_rdo     : signal is true;
  attribute syn_keep of epoch_cntr_reg      : signal is true;
  attribute syn_preserve                    : boolean;
  attribute syn_preserve of coarse_cntr_reg : signal is true;
  attribute syn_preserve of trg_win_end_tdc : signal is true;
  attribute syn_preserve of epoch_cntr_reg  : signal is true;
  attribute nomerge                         : string;
  attribute nomerge of trg_win_end_tdc      : signal is "true";
  attribute nomerge of trg_win_end_rdo      : signal is "true";
  attribute nomerge of epoch_cntr_reg       : signal is "true";

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
      HIT_IN                => HIT_IN,
      HIT_EDGE_IN           => HIT_EDGE_IN,
      TRG_WIN_END_TDC_IN    => trg_win_end_tdc,
      TRG_WIN_END_RDO_IN    => trg_win_end_rdo,
      EPOCH_COUNTER_IN      => epoch_cntr_reg,
      COARSE_COUNTER_IN     => coarse_cntr_reg,
      READ_EN_IN            => READ_EN_IN,
      FIFO_DATA_OUT         => ch_data,
      FIFO_DATA_VALID_OUT   => ch_data_valid,
      VALID_TIMING_TRG_IN   => VALID_TIMING_TRG_IN,
      VALID_NOTIMING_TRG_IN => VALID_NOTIMING_TRG_IN,
      SPIKE_DETECTED_IN     => SPIKE_DETECTED_IN,
      MULTI_TMG_TRG_IN      => MULTI_TMG_TRG_IN,
      EPOCH_WRITE_EN_IN     => EPOCH_WRITE_EN_IN,
      ENCODER_START_OUT     => encoder_start,
      ENCODER_FINISHED_OUT  => encoder_finished,
      FIFO_WRITE_OUT        => fifo_write,
      CHANNEL_200_DEBUG_OUT     => channel_200_debug);

  Buffer_128 : if RING_BUFFER_SIZE = 3 generate
    The_Buffer : FIFO_36x128_OutReg
      port map (
        Data  => ch_data,
        Clock => CLK_100,
        WrEn  => ch_data_valid,
        RdEn  => READ_EN_IN,
        Reset => RESET_100,
        Q     => buf_data,
        Empty => buf_empty,
        Full  => buf_full);
  end generate Buffer_128;

  Buffer_64 : if RING_BUFFER_SIZE = 1 generate
    The_Buffer : FIFO_36x64_OutReg
      port map (
        Data  => ch_data,
        Clock => CLK_100,
        WrEn  => ch_data_valid,
        RdEn  => READ_EN_IN,
        Reset => RESET_100,
        Q     => buf_data,
        Empty => buf_empty,
        Full  => buf_full);
  end generate Buffer_64;

  Buffer_32 : if RING_BUFFER_SIZE = 0 generate
    The_Buffer : FIFO_36x32_OutReg
      port map (
        Data  => ch_data,
        Clock => CLK_100,
        WrEn  => ch_data_valid,
        RdEn  => READ_EN_IN,
        Reset => RESET_100,
        Q     => buf_data,
        Empty => buf_empty,
        Full  => buf_full);
  end generate Buffer_32;

  FIFO_DATA_OUT         <= buf_data;
  FIFO_DATA_VALID_OUT   <= buf_data_valid;
  FIFO_EMPTY_OUT        <= buf_empty;
  FIFO_ALMOST_EMPTY_OUT <= '0';
  trg_win_end_tdc       <= TRG_WIN_END_TDC_IN;
  trg_win_end_rdo       <= TRG_WIN_END_RDO_IN;
  rd_en_reg             <= READ_EN_IN                      when rising_edge(CLK_100);
  buf_empty_reg         <= buf_empty                       when rising_edge(CLK_100);
  buf_data_valid        <= rd_en_reg and not buf_empty_reg when rising_edge(CLK_100);

  pulse_sync_encoder_start : pulse_sync
    port map (
      CLK_A_IN    => CLK_200,
      RESET_A_IN  => RESET_200,
      PULSE_A_IN  => encoder_start,
      CLK_B_IN    => CLK_100,
      RESET_B_IN  => RESET_100,
      PULSE_B_OUT => encoder_start_100);

  pulse_sync_encoder_finished : pulse_sync
    port map (
      CLK_A_IN    => CLK_200,
      RESET_A_IN  => RESET_200,
      PULSE_A_IN  => encoder_finished,
      CLK_B_IN    => CLK_100,
      RESET_B_IN  => RESET_100,
      PULSE_B_OUT => encoder_finished_100);

  pulse_sync_fifo_write : pulse_sync
    port map (
      CLK_A_IN    => CLK_200,
      RESET_A_IN  => RESET_200,
      PULSE_A_IN  => fifo_write,
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
  --purpose: Hit Signal Synchroniser
  sync_q(0) <= HIT_IN    when rising_edge(CLK_100);
  sync_q(1) <= sync_q(0) when rising_edge(CLK_100);
  sync_q(2) <= sync_q(1) when rising_edge(CLK_100);

  risingEdgeDetect_1 : risingEdgeDetect
    port map (
      CLK       => CLK_100,
      SIGNAL_IN => sync_q(2),
      PULSE_OUT => hit_pulse_100);

  --purpose: Counts the detected hits
  Hit_Detect_Counter : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        hit_detect_cntr <= (others => '0');
      elsif hit_pulse_100 = '1' then
        hit_detect_cntr <= hit_detect_cntr + to_unsigned(1, 31);
      end if;
    end if;
  end process Hit_Detect_Counter;

  HIT_DETECT_NUMBER <= std_logic_vector(hit_detect_cntr) when rising_edge(CLK_100);

  gen_DEBUG : if DEBUG = c_YES generate
    --purpose: Counts the detected but unwritten hits
    Lost_Hit_Counter : process (CLK_100)
    begin
      if rising_edge(CLK_100) then
        if RESET_COUNTERS = '1' then
          lost_hit_cntr <= (others => '0');
        elsif hit_pulse_100 = '1' then
          lost_hit_cntr <= lost_hit_cntr + to_unsigned(1, 24);
        elsif fifo_write_100 = '1' then
          lost_hit_cntr <= lost_hit_cntr - to_unsigned(1, 24);
        end if;
      end if;
    end process Lost_Hit_Counter;

    LOST_HIT_NUMBER <= std_logic_vector(lost_hit_cntr) when rising_edge(CLK_100);

    --purpose: Counts the encoder start times
    Encoder_Start_Counter : process (CLK_100)
    begin
      if rising_edge(CLK_100) then
        if RESET_COUNTERS = '1' then
          ch_buffer_counter <= (others => '0');
        elsif ch_data_valid = '1' then
          if ch_data(35 downto 31) = "00011" then  -- it is a data word
            ch_buffer_counter <= ch_buffer_counter + to_unsigned(1, 16);
          end if;
        end if;
      --elsif encoder_start_100 = '1' then
      --  encoder_start_cntr <= encoder_start_cntr + to_unsigned(1, 24);
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
        elsif buf_data(35 downto 31) = "00011" then
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
        elsif buf_data_valid = '1' then
          if buf_data(35 downto 31) = "00011" then
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
  Channel_DEBUG_OUT(7 downto 0) <= buf_data(35 downto 28);
  Channel_DEBUG_OUT(8)          <= buf_data_valid;
  Channel_DEBUG_OUT(9)          <= READ_EN_IN;


  Channel_200_DEBUG_OUT <= channel_200_debug;
  --Channel_DEBUG_OUT(0) <= fifo_write_100 when rising_edge(CLK_100);
  --Channel_DEBUG_OUT(1)            <= result_2_reg;
  --Channel_DEBUG_OUT(2)            <= hit_detect;
  --Channel_DEBUG_OUT(3)            <= hit_detect_reg;
  --Channel_DEBUG_OUT(4)            <= '0';
  --Channel_DEBUG_OUT(5)            <= ff_array_en;
  --Channel_DEBUG_OUT(6)            <= encoder_start;
  --Channel_DEBUG_OUT(7)            <= encoder_finished;
  --Channel_DEBUG_OUT(15 downto 8)  <= result(7 downto 0);
  --Channel_DEBUG_OUT(31 downto 16) <= (others => '0');

end Channel;
