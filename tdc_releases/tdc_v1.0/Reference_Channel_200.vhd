-------------------------------------------------------------------------------
-- Title      : Reference Channel 200 MHz Part
-- Project    : 
-------------------------------------------------------------------------------
-- File       : Reference_channel_200.vhd
-- Author     : c.ugur@gsi.de
-- Created    : 2012-09-04
-- Last update: 2012-10-23
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

entity Reference_Channel_200 is

  generic (
    CHANNEL_ID : integer range 0 to 0);  
  port (
    CLK_200                : in  std_logic;  -- 200 MHz clk
    RESET_200              : in  std_logic;  -- reset sync with 200Mhz clk
    CLK_100                : in  std_logic;  -- 100 MHz clk
    RESET_100              : in  std_logic;  -- reset sync with 100Mhz clk
--
    VALID_TMG_TRG_IN       : in  std_logic;
    SPIKE_DETECTED_IN      : in  std_logic;
    MULTI_TMG_TRG_IN       : in  std_logic;
--
    HIT_IN                 : in  std_logic;  -- hit in
    READ_EN_IN             : in  std_logic;  -- read en signal
    FIFO_DATA_OUT          : out std_logic_vector(31 downto 0);  -- fifo data out
    FIFO_EMPTY_OUT         : out std_logic;  -- fifo empty signal
    FIFO_FULL_OUT          : out std_logic;  -- fifo full signal
    FIFO_ALMOST_FULL_OUT   : out std_logic;  -- fifo almost full signal
    EPOCH_COUNTER_IN       : in  std_logic_vector(27 downto 0);
    TRIGGER_WINDOW_END_IN  : in  std_logic;
    TRIGGER_TIME_STAMP_OUT : out std_logic_vector(38 downto 0);  -- TRIGGER time stamp
    DATA_FINISHED_IN       : in  std_logic;  -- end of the readout process
    RUN_MODE               : in  std_logic;
    COARSE_COUNTER_IN      : in  std_logic_vector(10 downto 0));

end Reference_Channel_200;

architecture Reference_Channel_200 of Reference_Channel_200 is

  -- carry chain
  signal data_a_i      : std_logic_vector(303 downto 0);
  signal data_b_i      : std_logic_vector(303 downto 0);
  signal result_i      : std_logic_vector(303 downto 0);
  signal ff_array_en_i : std_logic;

  --hit detection
  signal hit_detect_i    : std_logic;
  signal hit_detect_reg  : std_logic;
  signal hit_detect_2reg : std_logic;
  signal result_2_reg    : std_logic;

  -- time stamp
  signal time_stamp_i          : std_logic_vector(10 downto 0);
  signal coarse_cntr_reg       : std_logic_vector(10 downto 0);
  signal time_stamp_epoch_bits : std_logic_vector(27 downto 0);

  -- encoder
  signal encoder_start_i    : std_logic;
  signal encoder_finished_i : std_logic;
  signal encoder_data_out_i : std_logic_vector(9 downto 0);
  signal encoder_debug_i    : std_logic_vector(31 downto 0);

  -- fifo
  signal fifo_data_in_i     : std_logic_vector(31 downto 0);
  signal fifo_data_out_i    : std_logic_vector(31 downto 0);
  signal fifo_empty_i       : std_logic;
  signal fifo_full_i        : std_logic;
  signal fifo_was_full_i    : std_logic;
  signal fifo_almost_full_i : std_logic;
  signal fifo_wr_en_i       : std_logic;
  signal fifo_rd_en_i       : std_logic;

  -- timing trigger
  signal valid_tmg_trg_i  : std_logic;
  signal multi_tmg_trg_i  : std_logic;
  signal spike_detected_i : std_logic;

  -- coarse counter overflow
  signal coarse_cntr_overflow_release : std_logic;
  signal coarse_cntr_overflow_flag    : std_logic;
  signal coarse_cntr_overflow_reset   : std_logic;

  -- epoch counter
  signal epoch_cntr         : std_logic_vector(27 downto 0);
  signal epoch_time         : std_logic_vector(27 downto 0);
  signal epoch_word_first   : std_logic_vector(31 downto 0);
  signal epoch_cntr_up      : std_logic;
  signal epoch_capture_time : std_logic_vector(10 downto 0);

  -- other
  signal read_en_reg   : std_logic;
  signal read_en_2reg  : std_logic;
  signal first_read_i  : std_logic;
  signal trg_win_end_i : std_logic;

  -- fsm
  type   FSM is (IDLE, LOOK_FOR_VALIDITY, ENCODER_FINISHED, WAIT_FOR_FALLING_EDGE);
  signal FSM_CURRENT, FSM_NEXT : FSM;
  signal valid_trigger_i       : std_logic;
  signal valid_trigger_fsm     : std_logic;
  signal fsm_debug_i           : std_logic_vector(3 downto 0);
  signal fsm_debug_fsm         : std_logic_vector(3 downto 0);

  attribute syn_keep                      : boolean;
  attribute syn_keep of ff_array_en_i     : signal is true;
  attribute syn_keep of trg_win_end_i     : signal is true;
  attribute syn_preserve                  : boolean;
  attribute syn_preserve of trg_win_end_i : signal is true;

  
begin  -- Reference_Channel_200

  trg_win_end_i <= TRIGGER_WINDOW_END_IN when rising_edge(CLK_200);

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

  EpochCounterUpdate : process (CLK_200)
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
  end process EpochCounterUpdate;

  EpochCounterCapture : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        epoch_time <= (others => '0');
      elsif encoder_finished_i = '1' then
        epoch_time <= epoch_cntr;
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
        time_stamp_epoch_bits        <= (others => '0');
      elsif valid_trigger_i = '1' then
        --if coarse_cntr_overflow_flag = '0' then
        --  fifo_data_in_i(31)           <= '1';               -- data marker
        --  fifo_data_in_i(30 downto 29) <= "00";              -- reserved bits
        --  fifo_data_in_i(28 downto 22) <= std_logic_vector(to_unsigned(CHANNEL_ID, 7));  -- channel number
        --  fifo_data_in_i(21 downto 12) <= encoder_data_out_i;  -- fine time from the encoder
        --  fifo_data_in_i(11)           <= '1';  --edge_type_i;  -- rising '1' or falling '0' edge
        --  fifo_data_in_i(10 downto 0)  <= time_stamp_reg;    -- hit time stamp
        --  coarse_cntr_overflow_release <= '0';
        --  fifo_wr_en_i                 <= '1';
        --else
        --if and_all(TIME_STAMP_IN(10 downto 3)) = '1' then
        --  fifo_data_in_i(31)           <= '1';               -- data marker
        --  fifo_data_in_i(30 downto 29) <= "00";              -- reserved bits
        --  fifo_data_in_i(28 downto 22) <= std_logic_vector(to_unsigned(CHANNEL_ID, 7));  -- channel number
        --  fifo_data_in_i(21 downto 12) <= encoder_data_out_i;  -- fine time from the encoder
        --  fifo_data_in_i(11)           <= '1';  --edge_type_i;  -- rising '1' or falling '0' edge
        --  fifo_data_in_i(10 downto 0)  <= time_stamp_reg;    -- hit time stamp
        --  coarse_cntr_overflow_release <= '0';
        --  fifo_wr_en_i                 <= '1';
        --else
        
        fifo_data_in_i(31 downto 29) <= "011";
        fifo_data_in_i(28)           <= '0';
        fifo_data_in_i(27 downto 0)  <= epoch_time;
        coarse_cntr_overflow_release <= '1';
        fifo_wr_en_i                 <= '1';
        time_stamp_epoch_bits        <= epoch_time;
        --end if;
        --end if;
      elsif coarse_cntr_overflow_release = '1' then
        fifo_data_in_i(31)           <= '1';                 -- data marker
        fifo_data_in_i(30 downto 29) <= "00";                -- reserved bits
        fifo_data_in_i(28 downto 22) <= std_logic_vector(to_unsigned(CHANNEL_ID, 7));  -- channel number
        fifo_data_in_i(21 downto 12) <= encoder_data_out_i;  -- fine time from the encoder
        fifo_data_in_i(11)           <= '1';  --edge_type_i;  -- rising '1' or falling '0' edge
        fifo_data_in_i(10 downto 0)  <= time_stamp_i;        -- hit time stamp
        coarse_cntr_overflow_release <= '0';
        fifo_wr_en_i                 <= '1';
      elsif DATA_FINISHED_IN = '1' then
        time_stamp_epoch_bits <= (others => '0');
      else
        fifo_data_in_i               <= (others => '0');
        coarse_cntr_overflow_release <= '0';
        fifo_wr_en_i                 <= '0';
      end if;
    end if;
  end process FifoWriteSignal;

  TRIGGER_TIME_STAMP_OUT <= time_stamp_epoch_bits & time_stamp_i;

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

  --purpose: FSM for controlling the validity of the timing signal
  FSM_CLK : process (CLK_200, RESET_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        FSM_CURRENT     <= IDLE;
        valid_trigger_i <= '0';
        fsm_debug_i     <= (others => '0');
      else
        FSM_CURRENT     <= FSM_NEXT;
        valid_trigger_i <= valid_trigger_fsm;
        fsm_debug_i     <= fsm_debug_fsm;
      end if;
    end if;
  end process FSM_CLK;

  FSM_PROC : process (FSM_CURRENT, hit_detect_i, encoder_finished_i, valid_tmg_trg_i, multi_tmg_trg_i,
                      spike_detected_i)
  begin
    valid_trigger_fsm <= '0';
    fsm_debug_fsm     <= (others => '0');

    case (FSM_CURRENT) is
      when IDLE =>
        if hit_detect_i = '1' then
          FSM_NEXT <= ENCODER_FINISHED;
        else
          FSM_NEXT <= IDLE;
        end if;
        fsm_debug_fsm <= x"1";

      when ENCODER_FINISHED =>
        if encoder_finished_i = '1' then
          FSM_NEXT <= LOOK_FOR_VALIDITY;
        elsif valid_tmg_trg_i = '1' then
          FSM_NEXT <= IDLE;
        else
          FSM_NEXT <= ENCODER_FINISHED;
        end if;
        fsm_debug_fsm <= x"2";
        
      when LOOK_FOR_VALIDITY =>
        if valid_tmg_trg_i = '1' then
          FSM_NEXT          <= IDLE;
          valid_trigger_fsm <= '1';
        elsif multi_tmg_trg_i = '1' or spike_detected_i = '1' then
          FSM_NEXT <= IDLE;
        else
          FSM_NEXT <= LOOK_FOR_VALIDITY;
        end if;
        fsm_debug_fsm <= x"3";

                                        --when WAIT_FOR_FALLING_EDGE =>
                                        --  if encoder_finished_i = '1' then
                                        --    FSM_NEXT       <= IDLE;
                                        --    valid_trigger_fsm <= '1';
                                        --    fsm_debug_fsm  <= x"C";
                                        --  else
                                        --    FSM_NEXT       <= WAIT_FOR_FALLING_EDGE;
                                        --    valid_trigger_fsm <= '0';
                                        --    fsm_debug_fsm  <= x"D";
                                        --  end if;
        
      when others =>
        FSM_NEXT <= IDLE;
    end case;
  end process FSM_PROC;

  bit_sync_1 : bit_sync
    generic map (
      DEPTH => 3)
    port map (
      RESET => RESET_200,
      CLK0  => CLK_100,
      CLK1  => CLK_200,
      D_IN  => VALID_TMG_TRG_IN,
      D_OUT => valid_tmg_trg_i);
  bit_sync_2 : bit_sync
    generic map (
      DEPTH => 3)
    port map (
      RESET => RESET_200,
      CLK0  => CLK_100,
      CLK1  => CLK_200,
      D_IN  => SPIKE_DETECTED_IN,
      D_OUT => spike_detected_i);
  bit_sync_3 : bit_sync
    generic map (
      DEPTH => 3)
    port map (
      RESET => RESET_200,
      CLK0  => CLK_100,
      CLK1  => CLK_200,
      D_IN  => MULTI_TMG_TRG_IN,
      D_OUT => multi_tmg_trg_i);

end Reference_Channel_200;
