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

  signal data_a_i             : std_logic_vector(303 downto 0);
  signal data_b_i             : std_logic_vector(303 downto 0);
  signal result_i             : std_logic_vector(303 downto 0);
  signal result_reg           : std_logic_vector(303 downto 0);
  signal hit_in_i             : std_logic;
  signal hit_buf              : std_logic;
  signal hit_detect_i         : std_logic;
  signal hit_detect_reg       : std_logic;
  signal hit_detect_2reg      : std_logic;
  signal release_delay_line_i : std_logic;
  signal result_2_reg         : std_logic;
  signal coarse_cntr_i        : std_logic_vector(10 downto 0);
  signal hit_time_stamp_i     : std_logic_vector(10 downto 0);
  signal fine_counter_i       : std_logic_vector(9 downto 0);
  signal encoder_start_i      : std_logic;
  signal fifo_data_out_i      : std_logic_vector(31 downto 0);
  signal fifo_data_in_i       : std_logic_vector(31 downto 0);
  signal fifo_empty_i         : std_logic;
  signal fifo_full_i          : std_logic;
  signal fifo_almost_full_i   : std_logic;
  signal fifo_wr_en_i         : std_logic;
  signal fifo_rd_en_i         : std_logic;
  signal sync_q               : std_logic_vector(3 downto 0);
  signal hit_pulse            : std_logic;
  signal lost_hit_cntr        : std_logic_vector(23 downto 0);
  signal lost_hit_number_reg  : std_logic_vector(23 downto 0);
  signal ff_array_en_i        : std_logic := '1';

-------------------------------------------------------------------------------
-- Debug Signals
-------------------------------------------------------------------------------

  signal hit_detect_cntr        : std_logic_vector(23 downto 0);
  signal hit_detect_cntr_reg    : std_logic_vector(23 downto 0);
  signal encoder_start_cntr     : std_logic_vector(23 downto 0);
  signal encoder_start_cntr_reg : std_logic_vector(23 downto 0);
  signal fifo_wr_cntr           : std_logic_vector(23 downto 0);
  signal fifo_wr_cntr_reg       : std_logic_vector(23 downto 0);
  signal encoder_debug_i        : std_logic_vector(31 downto 0);
-------------------------------------------------------------------------------

  attribute syn_keep                  : boolean;
  attribute syn_keep of hit_buf       : signal is true;
  attribute syn_keep of hit_in_i      : signal is true;
  attribute syn_keep of ff_array_en_i : signal is true;
  attribute NOMERGE                   : string;
  attribute NOMERGE of hit_buf        : signal is "true";
  attribute NOMERGE of ff_array_en_i  : signal is "true";

-------------------------------------------------------------------------------

begin

  fifo_rd_en_i  <= READ_EN_IN;
  coarse_cntr_i <= COARSE_COUNTER_IN;
  hit_in_i      <= HIT_IN;
  hit_buf       <= not hit_in_i;

  --purpose: Tapped Delay Line 304 (Carry Chain) with wave launcher (21) double transition
  FC : Adder_304
    port map (
      CLK    => CLK_200,
      RESET  => RESET_200,
      DataA  => data_a_i,
      DataB  => data_b_i,
      ClkEn  => '1',                    --ff_array_en_i,
      Result => result_i);
  data_a_i <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" & x"7FFFFFF";
  data_b_i <= x"000000000000000000000000000000000000000000000000000000000000000000000" & not(hit_buf) & x"000000" & "00" & hit_buf;

  --purpose: Registers the hit detection bit
  Hit_Detect_Register : process (CLK_200, RESET_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        result_2_reg    <= '0';
        hit_detect_reg  <= '0';
        hit_detect_2reg <= '0';
      else
        result_2_reg    <= result_i(2);
        hit_detect_reg  <= hit_detect_i;
        hit_detect_2reg <= hit_detect_reg;
      end if;
    end if;
  end process Hit_Detect_Register;

  --purpose: Detects the hit
  Hit_Detect : process (result_2_reg, result_i)
  begin
    hit_detect_i <= (not result_2_reg) and result_i(2);
  end process Hit_Detect;

  --purpose: Double Synchroniser
  Double_Syncroniser : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        result_reg <= (others => '1');
      elsif hit_detect_i = '1' then
        result_reg <= result_i;
      end if;
    end if;
  end process Double_Syncroniser;

  --purpose: Start Encoder and captures the time stamp of the hit
  Start_Encoder : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        encoder_start_i  <= '0';
        hit_time_stamp_i <= (others => '0');
      elsif hit_detect_reg = '1' then
        encoder_start_i  <= '1';
        hit_time_stamp_i <= coarse_cntr_i;
      else
        encoder_start_i <= '0';
      end if;
    end if;
  end process Start_Encoder;

  --purpose: Encoder
  Encoder : Encoder_304_Bit
    port map (
      RESET           => RESET_200,
      CLK             => CLK_200,
      START_IN        => encoder_start_i,
      THERMOCODE_IN   => result_reg,    --result_i,
      FINISHED_OUT    => fifo_wr_en_i,
      BINARY_CODE_OUT => fine_counter_i,
      ENCODER_DEBUG   => encoder_debug_i);

  FIFO : FIFO_32x32_OutReg
    port map (
      Data       => fifo_data_in_i,
      WrClock    => CLK_200,
      RdClock    => CLK_100,
      WrEn       => fifo_wr_en_i,
      RdEn       => fifo_rd_en_i,
      Reset      => RESET_100,
      RPReset    => RESET_100,
      Q          => fifo_data_out_i,
      Empty      => fifo_empty_i,
      Full       => fifo_full_i,
      AlmostFull => fifo_almost_full_i);
  fifo_data_in_i(31)           <= '1';  -- data marker
  fifo_data_in_i(30 downto 29) <= "00";            -- reserved bits
  fifo_data_in_i(28 downto 22) <= conv_std_logic_vector(CHANNEL_ID, 7);  -- channel number
  fifo_data_in_i(21 downto 12) <= fine_counter_i;  -- fine time from the encoder
  fifo_data_in_i(11)           <= '1';  --edge_type_i;  -- rising '1' or falling '0' edge
  fifo_data_in_i(10 downto 0)  <= hit_time_stamp_i;  -- hit time stamp

  Register_Outputs : process (CLK_100, RESET_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' then
        FIFO_DATA_OUT        <= (others => '1');
        FIFO_EMPTY_OUT       <= '0';
        FIFO_FULL_OUT        <= '0';
        FIFO_ALMOST_FULL_OUT <= '0';
      else
        FIFO_DATA_OUT        <= fifo_data_out_i;
        FIFO_EMPTY_OUT       <= fifo_empty_i;
        FIFO_FULL_OUT        <= fifo_full_i;
        FIFO_ALMOST_FULL_OUT <= fifo_almost_full_i;
      end if;
    end if;
  end process Register_Outputs;

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
      elsif fifo_wr_en_i = '1' then
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
      D_OUT => lost_hit_number_reg);

  LOST_HIT_NUMBER <= lost_hit_number_reg;

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
      elsif fifo_wr_en_i = '1' then
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

  Channel_DEBUG(0)            <= HIT_IN;
  Channel_DEBUG(1)            <= result_2_reg when rising_edge(CLK_200);
  Channel_DEBUG(2)            <= hit_detect_i when rising_edge(CLK_200);
  Channel_DEBUG(3)            <= hit_detect_reg when rising_edge(CLK_200);
  Channel_DEBUG(4)            <= '0';
  Channel_DEBUG(5)            <= ff_array_en_i when rising_edge(CLK_200);
  Channel_DEBUG(6)            <= encoder_start_i when rising_edge(CLK_200);
  Channel_DEBUG(7)            <= fifo_wr_en_i when rising_edge(CLK_200);
  Channel_DEBUG(15 downto 8)  <= result_i(7 downto 0) when rising_edge(CLK_200);
  Channel_DEBUG(31 downto 16) <= (others => '0');

-------------------------------------------------------------------------------

end Channel;
