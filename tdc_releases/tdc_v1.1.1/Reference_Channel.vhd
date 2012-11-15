library IEEE;
use IEEE.STD_LOGIC_UNSIGNED.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.version.all;

entity Reference_Channel is

  generic (
    CHANNEL_ID : integer range 0 to 0);
  port (
    RESET_200              : in  std_logic;
    RESET_100              : in  std_logic;
    CLK_200                : in  std_logic;
    CLK_100                : in  std_logic;
--
    HIT_IN                 : in  std_logic;
    READ_EN_IN             : in  std_logic;
    VALID_TMG_TRG_IN       : in  std_logic;
    SPIKE_DETECTED_IN      : in  std_logic;
    MULTI_TMG_TRG_IN       : in  std_logic;
    FIFO_DATA_OUT          : out std_logic_vector(31 downto 0);
    FIFO_EMPTY_OUT         : out std_logic;
    FIFO_FULL_OUT          : out std_logic;
    FIFO_ALMOST_FULL_OUT   : out std_logic;
    COARSE_COUNTER_IN      : in  std_logic_vector(10 downto 0);
    EPOCH_COUNTER_IN       : in  std_logic_vector(27 downto 0);
    TRIGGER_WINDOW_END_IN  : in  std_logic;
    DATA_FINISHED_IN       : in  std_logic;  -- end of the readout process
    RUN_MODE               : in  std_logic;
    TRIGGER_TIME_STAMP_OUT : out std_logic_vector(38 downto 0);  -- coarse time of the timing trigger
    REF_DEBUG_OUT          : out std_logic_vector(31 downto 0)
    );

end Reference_Channel;

architecture Reference_Channel of Reference_Channel is
-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

  --hit detection
  signal hit_in_i : std_logic;
  signal hit_buf  : std_logic;

  -- time stamp
  signal coarse_cntr_reg    : std_logic_vector(10 downto 0);

  -- other
  signal trg_win_end_i   : std_logic;
  signal data_finished_i : std_logic;
  signal run_mode_i      : std_logic;

  attribute syn_keep                        : boolean;
  attribute syn_keep of hit_buf             : signal is true;
  attribute NOMERGE                         : string;
  attribute NOMERGE of hit_buf              : signal is "true";
  attribute syn_preserve                    : boolean;
  attribute syn_preserve of coarse_cntr_reg : signal is true;
-------------------------------------------------------------------------------

begin

  hit_in_i <= HIT_IN;
  hit_buf  <= not hit_in_i;

  Reference_Channel_200_1 : Reference_Channel_200
    generic map (
      CHANNEL_ID => CHANNEL_ID)
    port map (
      CLK_200                => CLK_200,
      RESET_200              => RESET_200,
      CLK_100                => CLK_100,
      RESET_100              => RESET_100,
      VALID_TMG_TRG_IN       => VALID_TMG_TRG_IN,
      SPIKE_DETECTED_IN      => SPIKE_DETECTED_IN,
      MULTI_TMG_TRG_IN       => MULTI_TMG_TRG_IN,
      HIT_IN                 => hit_buf,
      READ_EN_IN             => READ_EN_IN,
      FIFO_DATA_OUT          => FIFO_DATA_OUT,
      FIFO_EMPTY_OUT         => FIFO_EMPTY_OUT,
      FIFO_FULL_OUT          => FIFO_FULL_OUT,
      FIFO_ALMOST_FULL_OUT   => FIFO_ALMOST_FULL_OUT,
      EPOCH_COUNTER_IN       => EPOCH_COUNTER_IN,
      TRIGGER_WINDOW_END_IN  => trg_win_end_i,
      TRIGGER_TIME_STAMP_OUT => TRIGGER_TIME_STAMP_OUT,
      DATA_FINISHED_IN       => data_finished_i,
      RUN_MODE               => run_mode_i,
      COARSE_COUNTER_IN      => coarse_cntr_reg);

  trg_win_end_i   <= TRIGGER_WINDOW_END_IN when rising_edge(CLK_200);
  data_finished_i <= DATA_FINISHED_IN      when rising_edge(CLK_100);
  run_mode_i      <= RUN_MODE              when rising_edge(CLK_100);

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
-- Debug signals
-------------------------------------------------------------------------------
  --REF_DEBUG_OUT(3 downto 0) <= fsm_debug_i;
  --REF_DEBUG_OUT(4)          <= HIT_IN;
  --REF_DEBUG_OUT(5)          <= result_i(2);
  --REF_DEBUG_OUT(6)          <= result_2_reg;
  --REF_DEBUG_OUT(7)          <= '0';     --hit_detect_i;
  --REF_DEBUG_OUT(8)          <= '0';     --hit_detect_reg;
  --REF_DEBUG_OUT(9)          <= '0';
  --REF_DEBUG_OUT(10)         <= '0';
  --REF_DEBUG_OUT(11)         <= ff_array_en_i;
  --REF_DEBUG_OUT(12)         <= encoder_start_i;
  --REF_DEBUG_OUT(13)         <= encoder_finished_i;
  --REF_DEBUG_OUT(14)         <= fifo_wr_en_i;

  --REF_DEBUG_OUT(15) <= CLK_200;

  REF_DEBUG_OUT(31 downto 0) <= (others => '0');
end Reference_Channel;
