-------------------------------------------------------------------------------
-- Title      : Channel 200 MHz Part
-- Project    : 
-------------------------------------------------------------------------------
-- File       : Channel_200.vhd
-- Author     : c.ugur@gsi.de
-- Created    : 2012-08-28
-- Last update: 2013-03-18
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.version.all;

entity Channel_200 is

  generic (
    CHANNEL_ID : integer range 1 to 64);  
  port (
    CLK_200               : in  std_logic;  -- 200 MHz clk
    RESET_200             : in  std_logic;  -- reset sync with 200Mhz clk
    CLK_100               : in  std_logic;  -- 100 MHz clk
    RESET_100             : in  std_logic;  -- reset sync with 100Mhz clk
    RESET_COUNTERS        : in  std_logic;  -- reset for internal counters
--
    HIT_IN                : in  std_logic;  -- hit in
    SCALER_IN             : in  std_logic;  -- input for the scaler counter
    EPOCH_COUNTER_IN      : in  std_logic_vector(27 downto 0);  -- system coarse counter
    TRIGGER_WINDOW_END_IN : in  std_logic;
    DATA_FINISHED_IN      : in  std_logic;
    RUN_MODE              : in  std_logic;
    COARSE_COUNTER_IN     : in  std_logic_vector(10 downto 0);
    READ_EN_IN            : in  std_logic;  -- read en signal
    FIFO_DATA_OUT         : out std_logic_vector(31 downto 0);  -- fifo data out
    FIFO_EMPTY_OUT        : out std_logic;  -- fifo empty signal
    FIFO_FULL_OUT         : out std_logic;  -- fifo full signal
    FIFO_ALMOST_FULL_OUT  : out std_logic;
--
    LOST_HIT_NUMBER       : out std_logic_vector(23 downto 0);
    HIT_DETECT_NUMBER     : out std_logic_vector(23 downto 0);
    ENCODER_START_NUMBER  : out std_logic_vector(23 downto 0);
    FIFO_WR_NUMBER        : out std_logic_vector(23 downto 0));  -- fifo almost full signal

end Channel_200;

architecture Channel_200 of Channel_200 is

  -- carry chain
  signal data_a_i      : std_logic_vector(303 downto 0);
  signal data_b_i      : std_logic_vector(303 downto 0);
  signal result_i      : std_logic_vector(303 downto 0);
  signal ff_array_en_i : std_logic;

  -- hit detection
  signal result_2_reg    : std_logic;
  signal hit_detect_i    : std_logic;
  signal hit_detect_reg  : std_logic;
  signal hit_detect_2reg : std_logic;

  -- time stamp
  signal time_stamp_i    : std_logic_vector(10 downto 0);
  signal coarse_cntr_reg : std_logic_vector(10 downto 0);

  -- encoder
  signal encoder_start_i    : std_logic;
  signal encoder_start_100  : std_logic;
  signal encoder_finished_i : std_logic;
  signal encoder_data_out_i : std_logic_vector(9 downto 0);
  signal encoder_debug_i    : std_logic_vector(31 downto 0);

  -- coarse counter overflow
  signal coarse_cntr_overflow_release : std_logic;
  signal coarse_cntr_overflow_flag    : std_logic;

  -- epoch counter
  signal epoch_cntr         : std_logic_vector(27 downto 0);
  signal epoch_word_first   : std_logic_vector(31 downto 0);
  signal epoch_cntr_up      : std_logic;
  signal epoch_capture_time : std_logic_vector(10 downto 0);

  -- fifo
  signal fifo_data_out_i    : std_logic_vector(31 downto 0);
  signal fifo_data_in_i     : std_logic_vector(31 downto 0);
  signal fifo_empty_i       : std_logic;
  signal fifo_full_i        : std_logic;
  signal fifo_was_full_i    : std_logic;
  signal fifo_almost_full_i : std_logic;
  signal fifo_wr_en_i       : std_logic;
  signal fifo_wr_en_100     : std_logic;
  signal fifo_rd_en_i       : std_logic;

  -- other
  signal read_en_reg   : std_logic;
  signal read_en_2reg  : std_logic;
  signal first_read_i  : std_logic;
  signal trg_win_end_i : std_logic;

  -- debug
  signal sync_q                : std_logic_vector(2 downto 0);
  signal hit_pulse             : std_logic;
  signal hit_pulse_100         : std_logic;
  signal lost_hit_cntr         : unsigned(23 downto 0);
  signal hit_detect_cntr       : unsigned(23 downto 0);
  signal encoder_start_cntr    : unsigned(23 downto 0);
  signal fifo_wr_cntr          : unsigned(23 downto 0);
  signal debug_cntr            : unsigned(16 downto 0);
  signal debug_cntr_risingedge : std_logic;

  attribute syn_keep                      : boolean;
  attribute syn_keep of ff_array_en_i     : signal is true;
  attribute syn_keep of trg_win_end_i     : signal is true;
  attribute syn_preserve                  : boolean;
  attribute syn_preserve of trg_win_end_i : signal is true;
  


begin  -- Channel_200

  trg_win_end_i      <= TRIGGER_WINDOW_END_IN when rising_edge(CLK_200);

  --purpose: Tapped Delay Line 304 (Carry Chain) with wave launcher (21) double transition
  FC : Adder_304
    port map (
      CLK    => CLK_200,
      RESET  => RESET_200,
      DataA  => data_a_i,
      DataB  => data_b_i,
      ClkEn  => ff_array_en_i,
      Result => result_i);
  data_a_i      <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" & x"7FFFFFF";
  data_b_i      <= x"000000000000000000000000000000000000000000000000000000000000000000000" & not(HIT_IN) & x"000000" & "00" & HIT_IN;
  ff_array_en_i <= not(hit_detect_i or hit_detect_reg or hit_detect_2reg);

  result_2_reg    <= result_i(2)       when rising_edge(CLK_200);
  hit_detect_i    <= (not result_2_reg) and result_i(2);  -- detects the hit by
                                                          -- comparing the
                                                          -- previous state of the
                                                          -- hit detection bit
  hit_detect_reg  <= hit_detect_i      when rising_edge(CLK_200);
  hit_detect_2reg <= hit_detect_reg    when rising_edge(CLK_200);
  coarse_cntr_reg <= COARSE_COUNTER_IN when rising_edge(CLK_200);
  encoder_start_i <= hit_detect_reg;

  TimeStampCapture : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        time_stamp_i <= (others => '0');
      elsif hit_detect_reg = '1' then
        time_stamp_i <= coarse_cntr_reg;
      end if;
    end if;
  end process TimeStampCapture;

  epoch_capture_time <= "00000000111";
  
  EpochCounterCapture : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        epoch_cntr    <= (others => '0');
        epoch_cntr_up <= '0';
      elsif coarse_cntr_reg = epoch_capture_time then
        epoch_cntr    <= EPOCH_COUNTER_IN;
        epoch_cntr_up <= '1';
      end if;
    end if;
  end process EpochCounterCapture;

  --purpose: Encoder
  Encoder : Encoder_304_Bit
    port map (
      RESET           => RESET_200,
      CLK             => CLK_200,
      START_IN        => encoder_start_i,
      THERMOCODE_IN   => result_i,
      FINISHED_OUT    => encoder_finished_i,
      BINARY_CODE_OUT => encoder_data_out_i,
      ENCODER_DEBUG   => encoder_debug_i);

  FIFO : FIFO_32x32_OutReg
    port map (
      Data       => fifo_data_in_i,
      WrClock    => CLK_200,
      RdClock    => CLK_100,
      WrEn       => fifo_wr_en_i,
      RdEn       => fifo_rd_en_i,
      Reset      => RESET_100,
      RPReset    => RESET_200,
      Q          => fifo_data_out_i,
      Empty      => fifo_empty_i,
      Full       => fifo_full_i,
      AlmostFull => fifo_almost_full_i);

  fifo_rd_en_i <= READ_EN_IN or fifo_full_i;

  -- purpose: Sets the Overflow Flag
  CoarseCounterOverflowFlag : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        coarse_cntr_overflow_flag <= '0';
      elsif epoch_cntr_up = '1' or trg_win_end_i = '1' then
        coarse_cntr_overflow_flag <= '1';
      elsif coarse_cntr_overflow_release = '1' then
        coarse_cntr_overflow_flag <= '0';
      end if;
    end if;
  end process CoarseCounterOverflowFlag;

  -- purpose: Generate Fifo Wr Signal
  FifoWriteSignal : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        fifo_data_in_i               <= (others => '0');
        coarse_cntr_overflow_release <= '0';
        fifo_wr_en_i                 <= '0';
      elsif encoder_finished_i = '1' then
        --if coarse_cntr_overflow_flag = '0' then
        --  fifo_data_in_i(31)           <= '1';               -- data marker
        --  fifo_data_in_i(30 downto 29) <= "00";              -- reserved bits
        --  fifo_data_in_i(28 downto 22) <= std_logic_vector(to_unsigned(CHANNEL_ID, 7));  -- channel number
        --  fifo_data_in_i(21 downto 12) <= encoder_data_out_i;  -- fine time from the encoder
        --  fifo_data_in_i(11)           <= '1';  --edge_type_i;  -- rising '1' or falling '0' edge
        ----  fifo_data_in_i(10 downto 0)  <= time_stamp_reg;    -- hit time stamp
        --  fifo_data_in_i(10 downto 0)  <= time_stamp_i;    -- hit time stamp
        --  coarse_cntr_overflow_release <= '0';
        --  fifo_wr_en_i                 <= '1';
        --else
        --if and_all(TIME_STAMP_IN(10 downto 3)) = '1' then  -- for the hits after 0x7f8
        --if and_all(time_stamp_i(10 downto 3)) = '1' then  -- for the hits after 0x7f8
        --  fifo_data_in_i(31)           <= '1';             -- data marker
        --  fifo_data_in_i(30 downto 29) <= "00";            -- reserved bits
        --  fifo_data_in_i(28 downto 22) <= std_logic_vector(to_unsigned(CHANNEL_ID, 7));  -- channel number
        --  fifo_data_in_i(21 downto 12) <= encoder_data_out_i;  -- fine time from the encoder
        --  fifo_data_in_i(11)           <= '1';  --edge_type_i;  -- rising '1' or falling '0' edge
        --  --fifo_data_in_i(10 downto 0)  <= time_stamp_reg;  -- hit time stamp
        --  fifo_data_in_i(10 downto 0)  <= time_stamp_i;  -- hit time stamp
        --  coarse_cntr_overflow_release <= '0';
        --  fifo_wr_en_i                 <= '1';
        --else
        
        fifo_data_in_i(31 downto 29) <= "011";
        fifo_data_in_i(28)           <= '0';
        fifo_data_in_i(27 downto 0)  <= epoch_cntr;
        coarse_cntr_overflow_release <= '1';
        fifo_wr_en_i                 <= '1';
        --end if;
        --end if;
      elsif coarse_cntr_overflow_release = '1' then
        fifo_data_in_i(31)           <= '1';                 -- data marker
        fifo_data_in_i(30 downto 29) <= "00";                -- reserved bits
        fifo_data_in_i(28 downto 22) <= std_logic_vector(to_unsigned(CHANNEL_ID, 7));  -- channel number
        fifo_data_in_i(21 downto 12) <= encoder_data_out_i;  -- fine time from the encoder
        fifo_data_in_i(11)           <= '1';  --edge_type_i;  -- rising '1' or falling '0' edge
        --fifo_data_in_i(10 downto 0)  <= time_stamp_reg;      -- hit time stamp
        fifo_data_in_i(10 downto 0)  <= time_stamp_i;        -- hit time stamp
        coarse_cntr_overflow_release <= '0';
        fifo_wr_en_i                 <= '1';
      else
        fifo_data_in_i               <= (others => '0');
        coarse_cntr_overflow_release <= '0';
        fifo_wr_en_i                 <= '0';
      end if;
    end if;
  end process FifoWriteSignal;

  EpochCounterCaptureFirstWord : process (CLK_100, RESET_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' then
        epoch_word_first <= x"60000000";
      elsif DATA_FINISHED_IN = '1' and RUN_MODE = '0' then
        epoch_word_first <= x"60000000";
      elsif fifo_data_out_i(31 downto 29) = "011" then
        epoch_word_first <= fifo_data_out_i;
      end if;
    end if;
  end process EpochCounterCaptureFirstWord;

  read_en_reg     <= READ_EN_IN                                            when rising_edge(CLK_100);
  read_en_2reg    <= read_en_reg                                           when rising_edge(CLK_100);
  first_read_i    <= read_en_reg and not(read_en_2reg)                     when rising_edge(CLK_100);

  FifoWasFull : process (CLK_100, RESET_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' then
        fifo_was_full_i <= '0';
      elsif fifo_full_i = '1' then
        fifo_was_full_i <= '1';
      elsif fifo_empty_i = '1' then
        fifo_was_full_i <= '0';
      end if;
    end if;
  end process FifoWasFull;
  
  RegisterOutputs : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' then
        FIFO_DATA_OUT        <= (others => '1');
        FIFO_EMPTY_OUT       <= '0';
        FIFO_FULL_OUT        <= '0';
        FIFO_ALMOST_FULL_OUT <= '0';
      else
        if first_read_i = '1' and fifo_was_full_i = '1' then
          FIFO_DATA_OUT <= epoch_word_first;
        else
          FIFO_DATA_OUT <= fifo_data_out_i;
        end if;
        FIFO_EMPTY_OUT       <= fifo_empty_i;
        FIFO_FULL_OUT        <= fifo_full_i;
        FIFO_ALMOST_FULL_OUT <= fifo_almost_full_i;
      end if;
    end if;
  end process RegisterOutputs;

-------------------------------------------------------------------------------
-- Lost Hit Detection
-------------------------------------------------------------------------------
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

  HitPulse : pulse_sync
    port map (
      CLK_A_IN    => CLK_200,
      RESET_A_IN  => RESET_200,
      PULSE_A_IN  => hit_pulse,
      CLK_B_IN    => CLK_100,
      RESET_B_IN  => RESET_100,
      PULSE_B_OUT => hit_pulse_100);

  FifoWrite : pulse_sync
    port map (
      CLK_A_IN    => CLK_200,
      RESET_A_IN  => RESET_200,
      PULSE_A_IN  => fifo_wr_en_i,
      CLK_B_IN    => CLK_100,
      RESET_B_IN  => RESET_100,
      PULSE_B_OUT => fifo_wr_en_100);

  EmcpderStart : pulse_sync
    port map (
      CLK_A_IN    => CLK_200,
      RESET_A_IN  => RESET_200,
      PULSE_A_IN  => encoder_start_i,
      CLK_B_IN    => CLK_100,
      RESET_B_IN  => RESET_100,
      PULSE_B_OUT => encoder_start_100);

  --purpose: Counts the detected but unwritten hits
  Lost_Hit_Counter : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        lost_hit_cntr <= (others => '0');
      elsif hit_pulse_100 = '1' then
        lost_hit_cntr <= lost_hit_cntr + to_unsigned(1, 1);
      elsif fifo_wr_en_100 = '1' then
        lost_hit_cntr <= lost_hit_cntr - to_unsigned(1, 1);
      end if;
    end if;
  end process Lost_Hit_Counter;

  LOST_HIT_NUMBER <= lost_hit_cntr;

-------------------------------------------------------------------------------
-- DEBUG
-------------------------------------------------------------------------------
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

  HIT_DETECT_NUMBER <= hit_detect_cntr;

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

  ENCODER_START_NUMBER <= encoder_start_cntr;

  --purpose: Counts the written hits
  FIFO_WR_Counter : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        fifo_wr_cntr <= (others => '0');
      elsif fifo_wr_en_100 = '1' then
        fifo_wr_cntr <= fifo_wr_cntr + to_unsigned(1, 1);
      end if;
    end if;
  end process FIFO_WR_Counter;

  FIFO_WR_NUMBER <= fifo_wr_cntr;

end Channel_200;
