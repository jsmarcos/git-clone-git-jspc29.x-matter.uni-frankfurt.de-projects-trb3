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

entity Channel is

  generic (
    CHANNEL_ID : integer range 1 to 64);
  port (
    RESET_200            : in  std_logic;
    RESET_100            : in  std_logic;
    CLK_200              : in  std_logic;
    CLK_100              : in  std_logic;
--
    HIT_IN               : in  std_logic;
    READ_EN_IN           : in  std_logic;
    FIFO_DATA_OUT        : out std_logic_vector(31 downto 0);
    FIFO_EMPTY_OUT       : out std_logic;
    FIFO_FULL_OUT        : out std_logic;
    FIFO_ALMOST_FULL_OUT : out std_logic;
    COARSE_COUNTER_IN    : in  std_logic_vector(10 downto 0);
--
    LOST_HIT_NUMBER      : out std_logic_vector(23 downto 0);
    HIT_DETECT_NUMBER    : out std_logic_vector(23 downto 0);
    ENCODER_START_NUMBER : out std_logic_vector(23 downto 0);
    FIFO_WR_NUMBER       : out std_logic_vector(23 downto 0);
--
    Channel_DEBUG        : out std_logic_vector(31 downto 0)
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
  signal time_stamp_i   : std_logic_vector(10 downto 0);
  signal time_stamp_reg : std_logic_vector(10 downto 0);

-------------------------------------------------------------------------------
-- Debug Signals
-------------------------------------------------------------------------------

  signal fifo_wr_i              : std_logic;
  signal encoder_start_i        : std_logic;
  signal sync_q                 : std_logic_vector(3 downto 0);
  signal hit_pulse              : std_logic;
  signal lost_hit_cntr          : std_logic_vector(23 downto 0);
  signal lost_hit_cntr_reg      : std_logic_vector(23 downto 0);
  signal hit_detect_cntr        : std_logic_vector(23 downto 0);
  signal hit_detect_cntr_reg    : std_logic_vector(23 downto 0);
  signal encoder_start_cntr     : std_logic_vector(23 downto 0);
  signal encoder_start_cntr_reg : std_logic_vector(23 downto 0);
  signal fifo_wr_cntr           : std_logic_vector(23 downto 0);
  signal fifo_wr_cntr_reg       : std_logic_vector(23 downto 0);

-------------------------------------------------------------------------------

  attribute syn_keep            : boolean;
  attribute syn_keep of hit_buf : signal is true;

-------------------------------------------------------------------------------

begin

  hit_in_i <= HIT_IN;
  hit_buf  <= not hit_in_i;

  Channel_200_1 : Channel_200
    generic map (
      CHANNEL_ID => CHANNEL_ID)
    port map (
      CLK_200              => CLK_200,
      RESET_200            => RESET_200,
      CLK_100              => CLK_100,
      RESET_100            => RESET_100,
      HIT_IN               => hit_buf,
      HIT_DETECT_OUT       => hit_detect_reg,
--      COARSE_CNTR_IN       => COARSE_COUNTER_IN,
      TIME_STAMP_IN        => time_stamp_reg,
      READ_EN_IN           => READ_EN_IN,
      FIFO_DATA_OUT        => FIFO_DATA_OUT,
      FIFO_EMPTY_OUT       => FIFO_EMPTY_OUT,
      FIFO_FULL_OUT        => FIFO_FULL_OUT,
      FIFO_ALMOST_FULL_OUT => FIFO_ALMOST_FULL_OUT,
      FIFO_WR_OUT          => fifo_wr_i ,
      ENCODER_START_OUT    => encoder_start_i);

  --purpose: Captures the time stamp of the hit
  TimeStamp : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        time_stamp_i <= (others => '0');
      elsif hit_detect_reg = '1' then
        time_stamp_i <= COARSE_COUNTER_IN;
      end if;
    end if;
  end process TimeStamp;

  time_stamp_reg <= time_stamp_i when rising_edge(CLK_200);

-------------------------------------------------------------------------------
-- Lost Hit Detection
-------------------------------------------------------------------------------
  --purpose: Hit Signal Synchroniser
  GEN_flipflops : for i in 1 to 3 generate
    Hit_Sync : process (CLK_200)
    begin
      if rising_edge(CLK_200) then
        if RESET_200 = '1' then
          sync_q(i) <= '0';
        else
          sync_q(i) <= sync_q(i-1);
        end if;
      end if;
    end process Hit_Sync;
  end generate GEN_flipflops;
  sync_q(0) <= HIT_IN;

  --purpose: Creates a pulse out of the synchronised hit signal
  Edge_To_Pulse_Hit : edge_to_pulse
    port map (
      clock     => CLK_200,
      en_clk    => '1',
      signal_in => sync_q(3),
      pulse     => hit_pulse);

  --purpose: Counts the detected but unwritten hits
  Lost_Hit_Counter : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        lost_hit_cntr <= (others => '0');
      elsif hit_pulse = '1' then
        lost_hit_cntr <= lost_hit_cntr + 1;
      elsif fifo_wr_i = '1' then
        lost_hit_cntr <= lost_hit_cntr - 1;
      end if;
    end if;
  end process Lost_Hit_Counter;

  --purpose: Synchronises the lost hit counter to the slowcontrol clock
  Lost_Hit_Sync : signal_sync
    generic map (
      WIDTH => 24,
      DEPTH => 3)
    port map (
      RESET => RESET_100,
      CLK0  => CLK_200,
      CLK1  => CLK_100,
      D_IN  => lost_hit_cntr,
      D_OUT => lost_hit_cntr_reg);

  LOST_HIT_NUMBER <= lost_hit_cntr_reg;

-------------------------------------------------------------------------------
-- DEBUG
-------------------------------------------------------------------------------
  --purpose: Counts the detected hits
  Hit_Detect_Counter : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        hit_detect_cntr <= (others => '0');
      elsif hit_pulse = '1' then
        hit_detect_cntr <= hit_detect_cntr + 1;
      end if;
    end if;
  end process Hit_Detect_Counter;

  --purpose: Synchronises the hit detect counter to the slowcontrol clock
  Hit_Detect_Sync : signal_sync
    generic map (
      WIDTH => 24,
      DEPTH => 3)
    port map (
      RESET => RESET_100,
      CLK0  => CLK_200,
      CLK1  => CLK_100,
      D_IN  => hit_detect_cntr,
      D_OUT => hit_detect_cntr_reg);

  HIT_DETECT_NUMBER <= hit_detect_cntr_reg;

  --purpose: Counts the encoder start times
  Encoder_Start_Counter : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        encoder_start_cntr <= (others => '0');
      elsif encoder_start_i = '1' then
        encoder_start_cntr <= encoder_start_cntr + 1;
      end if;
    end if;
  end process Encoder_Start_Counter;

  --purpose: Synchronises the encoder start counter to the slowcontrol clock
  Encoder_Start_Sync : signal_sync
    generic map (
      WIDTH => 24,
      DEPTH => 3)
    port map (
      RESET => RESET_100,
      CLK0  => CLK_200,
      CLK1  => CLK_100,
      D_IN  => encoder_start_cntr,
      D_OUT => encoder_start_cntr_reg);

  ENCODER_START_NUMBER <= encoder_start_cntr_reg;

  --purpose: Counts the written hits
  FIFO_WR_Counter : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        fifo_wr_cntr <= (others => '0');
      elsif fifo_wr_i = '1' then
        fifo_wr_cntr <= fifo_wr_cntr + 1;
      end if;
    end if;
  end process FIFO_WR_Counter;

  --purpose: Synchronises the fifo wr counter to the slowcontrol clock
  FIFO_WR_Sync : signal_sync
    generic map (
      WIDTH => 24,
      DEPTH => 3)
    port map (
      RESET => RESET_100,
      CLK0  => CLK_200,
      CLK1  => CLK_100,
      D_IN  => fifo_wr_cntr,
      D_OUT => fifo_wr_cntr_reg);

  FIFO_WR_NUMBER <= fifo_wr_cntr_reg;

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

-------------------------------------------------------------------------------

end Channel;
