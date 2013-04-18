-------------------------------------------------------------------------------
-- Title      : Readout Entity
-- Project    : 
-------------------------------------------------------------------------------
-- File       : Readout.vhd
-- Author     : cugur@gsi.de
-- Created    : 2012-10-25
-- Last update: 2013-04-17
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2012 
-------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;

entity Readout is
  generic (
    CHANNEL_NUMBER : integer range 2 to 65);

  port (
    CLK_200           : in std_logic;
    RESET_200         : in std_logic;
    CLK_100           : in std_logic;
    RESET_100         : in std_logic;
    RESET_COUNTERS    : in std_logic;
--
    REFERENCE_TIME    : in std_logic;
    TRIGGER_TIME_IN   : in std_logic_vector(38 downto 0);
    TRG_WIN_PRE       : in std_logic_vector(10 downto 0);
    TRG_WIN_POST      : in std_logic_vector(10 downto 0);
-- slow control
    DEBUG_MODE_EN_IN  : in std_logic;
    TRIGGER_WIN_EN_IN : in std_logic;

-- from the channels
    CH_DATA_IN               : in  std_logic_vector_array_36(0 to CHANNEL_NUMBER);
    CH_WCNT_IN               : in  unsigned_array_8(0 to CHANNEL_NUMBER-1);
    CH_EMPTY_IN              : in  std_logic_vector(CHANNEL_NUMBER downto 0);
    CH_FULL_IN               : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
    CH_ALMOST_FULL_IN        : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
-- from the endpoint
    TRG_DATA_VALID_IN        : in  std_logic;
    VALID_TIMING_TRG_IN      : in  std_logic;
    VALID_NOTIMING_TRG_IN    : in  std_logic;
    INVALID_TRG_IN           : in  std_logic;
    TMGTRG_TIMEOUT_IN        : in  std_logic;
    SPIKE_DETECTED_IN        : in  std_logic;
    MULTI_TMG_TRG_IN         : in  std_logic;
    SPURIOUS_TRG_IN          : in  std_logic;
    TRG_NUMBER_IN            : in  std_logic_vector(15 downto 0);
    TRG_CODE_IN              : in  std_logic_vector(7 downto 0);
    TRG_INFORMATION_IN       : in  std_logic_vector(23 downto 0);
    TRG_TYPE_IN              : in  std_logic_vector(3 downto 0);
    DATA_LIMIT_IN            : in  unsigned(7 downto 0);
-- to the endpoint
    TRG_RELEASE_OUT          : out std_logic;
    TRG_STATUSBIT_OUT        : out std_logic_vector(31 downto 0);
    DATA_OUT                 : out std_logic_vector(31 downto 0);
    DATA_WRITE_OUT           : out std_logic;
    DATA_FINISHED_OUT        : out std_logic;
-- to the channels
    READ_EN_OUT              : out std_logic_vector(CHANNEL_NUMBER-1 downto 0);
    TRIGGER_WIN_END_OUT      : out std_logic;
--
    STATUS_REGISTERS_BUS_OUT : out std_logic_vector_array_32(0 to 18);
    READOUT_DEBUG            : out std_logic_vector(31 downto 0)
    );

end Readout;

architecture behavioral of Readout is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

  -- slow control
  signal slow_control_ch_empty_i : std_logic_vector(63 downto 0);

  -- trigger window
  signal start_trg_win_cnt       : std_logic                               := '0';
  signal start_trg_win_cnt_200_p : std_logic;
  signal trg_win_post_200        : std_logic_vector(10 downto 0);
  signal trg_win_cnt             : std_logic_vector(11 downto 0);
  signal trg_win_end_200         : std_logic                               := '0';
  signal trg_win_end_200_p       : std_logic;
  signal trg_win_end_100_p       : std_logic;
  signal trg_win_end_100_reg     : std_logic;
  signal trg_win_end_100_2reg    : std_logic;
  signal trg_win_end_100_3reg    : std_logic;
  signal trg_win_end_100_4reg    : std_logic;
  signal TW_pre                  : std_logic_vector(38 downto 0);
--  signal TW_post                 : std_logic_vector(38 downto 0);
  signal trg_win_l               : std_logic;
--  signal trg_win_r               : std_logic;
  -- channel signals
  signal ch_data_reg             : std_logic_vector_array_36(0 to CHANNEL_NUMBER);
  signal ch_data_2reg            : std_logic_vector_array_36(0 to CHANNEL_NUMBER);
  --signal ch_data_3reg            : std_logic_vector_array_36(0 to CHANNEL_NUMBER);
  signal ch_wcnt_reg             : unsigned_array_8(0 to CHANNEL_NUMBER-1) := (others => (others => '1'));
  signal ch_wcnt_2reg            : unsigned_array_8(0 to CHANNEL_NUMBER-1) := (others => (others => '1'));
  signal ch_empty_reg            : std_logic_vector(CHANNEL_NUMBER downto 0);
  signal ch_empty_2reg           : std_logic_vector(CHANNEL_NUMBER downto 0);
  signal ch_empty_3reg           : std_logic_vector(CHANNEL_NUMBER downto 0);
  signal ch_empty_4reg           : std_logic_vector(CHANNEL_NUMBER downto 0);
  signal ch_hit_time             : std_logic_vector(38 downto 0);
  signal ch_epoch_cntr_i         : std_logic_vector(27 downto 0);
  -- readout fsm
  type FSM_READ is (IDLE, WAIT_FOR_TRG_WIND_END, RD_CH, WAIT_FOR_LVL1_TRG_A, WAIT_FOR_LVL1_TRG_B,
                    WAIT_FOR_LVL1_TRG_C, SEND_STATUS, SEND_TRG_RELEASE_A, SEND_TRG_RELEASE_B);
  signal RD_CURRENT : FSM_READ  := IDLE;
  signal RD_NEXT    : FSM_READ;
  type   FSM_WRITE is (IDLE, WR_CH);
  signal WR_CURRENT : FSM_WRITE := IDLE;
  signal WR_NEXT    : FSM_WRITE;

  signal start_trg_win_cnt_fsm : std_logic;
  signal rd_fsm_debug_fsm      : std_logic_vector(3 downto 0);
  signal wr_fsm_debug_fsm      : std_logic_vector(3 downto 0);
  signal rd_en_fsm             : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal data_finished_fsm     : std_logic;
  signal wr_finished_fsm       : std_logic;
  signal trg_release_fsm       : std_logic;
  signal wr_header_fsm         : std_logic;
  signal wr_ch_data_fsm        : std_logic;
  signal wr_status_fsm         : std_logic;
  signal wrong_readout_fsm     : std_logic;
  signal rd_number_fsm         : unsigned(7 downto 0);
  signal rd_number             : unsigned(7 downto 0);
  signal wr_number_fsm         : unsigned(7 downto 0);
  signal wr_number             : unsigned(7 downto 0);
  signal fifo_nr_rd_fsm        : integer range 0 to CHANNEL_NUMBER := 0;
  signal fifo_nr_wr_fsm        : integer range 0 to CHANNEL_NUMBER := 0;

--  signal wr_trailer_fsm          : std_logic;
  signal idle_fsm                : std_logic;
  signal readout_fsm             : std_logic;
  signal wait_fsm                : std_logic;
  -- fifo number
  type   Std_Logic_8_array is array (0 to 8) of std_logic_vector(3 downto 0);
  signal empty_channels          : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal fifo_nr_rd              : integer range 0 to CHANNEL_NUMBER := 0;
  signal fifo_nr_wr              : integer range 0 to CHANNEL_NUMBER := 0;
  signal fifo_nr_wr_reg          : integer range 0 to CHANNEL_NUMBER := 0;
  signal fifo_nr_wr_2reg         : integer range 0 to CHANNEL_NUMBER := 0;
  signal fifo_nr_wr_3reg         : integer range 0 to CHANNEL_NUMBER := 0;
  -- fifo read
  signal rd_en                   : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  -- data mux
  signal wr_header               : std_logic;
  signal wr_ch_data_i            : std_logic;
  signal wr_ch_data_reg          : std_logic;
  signal wr_ch_data_2reg         : std_logic;
  signal wr_status               : std_logic;
  signal wr_trailer              : std_logic;
  signal stop_status_i           : std_logic;
  -- to endpoint
  signal data_out_reg            : std_logic_vector(31 downto 0);
  signal data_wr_reg             : std_logic;
  signal data_finished           : std_logic;
  signal wr_finished             : std_logic;
  signal wr_finished_reg         : std_logic;
  signal wr_finished_2reg        : std_logic;
  signal trg_release_reg         : std_logic;
  -- statistics
  signal trig_number             : unsigned(23 downto 0)             := (others => '0');
  signal release_number          : unsigned(23 downto 0)             := (others => '0');
  signal valid_tmg_trig_number   : unsigned(23 downto 0)             := (others => '0');
  signal valid_NOtmg_trig_number : unsigned(23 downto 0)             := (others => '0');
  signal invalid_trig_number     : unsigned(23 downto 0)             := (others => '0');
  signal multi_tmg_trig_number   : unsigned(23 downto 0)             := (others => '0');
  signal spurious_trig_number    : unsigned(23 downto 0)             := (others => '0');
  signal wrong_readout_number    : unsigned(23 downto 0)             := (others => '0');
  signal spike_number            : unsigned(23 downto 0)             := (others => '0');
  signal timeout_number          : unsigned(23 downto 0)             := (others => '0');
  signal total_empty_channel     : unsigned(23 downto 0)             := (others => '0');
  signal idle_time               : unsigned(23 downto 0)             := (others => '0');
  signal readout_time            : unsigned(23 downto 0)             := (others => '0');
  signal wait_time               : unsigned(23 downto 0)             := (others => '0');
  signal finished_number         : unsigned(23 downto 0)             := (others => '0');
  signal valid_timing_trg_p      : std_logic;
  signal valid_notiming_trg_p    : std_logic;
  signal invalid_trg_p           : std_logic;
  signal multi_tmg_trg_p         : std_logic;
  signal spurious_trg_p          : std_logic;
  signal spike_detected_p        : std_logic;
  signal timeout_detected_p      : std_logic;
  signal idle_time_up            : std_logic;
  signal readout_time_up         : std_logic;
  signal wait_time_up            : std_logic;
  signal wrong_readout_up        : std_logic;
  signal finished_i              : std_logic;
  -- debug
  signal header_error_bits       : std_logic_vector(15 downto 0);
  signal trailer_error_bits      : std_logic_vector(15 downto 0);
  signal ch_full_i               : std_logic;
  signal ch_almost_full_i        : std_logic;
  signal rd_fsm_debug            : std_logic_vector(3 downto 0);
  signal wr_fsm_debug            : std_logic_vector(3 downto 0);

begin  -- behavioral
-------------------------------------------------------------------------------
-- Trigger window
-------------------------------------------------------------------------------
-- Trigger window start logic
  StartTrgWinCntSync : pulse_sync
    port map (
      CLK_A_IN    => CLK_100,
      RESET_A_IN  => RESET_100,
      PULSE_A_IN  => start_trg_win_cnt,
      CLK_B_IN    => CLK_200,
      RESET_B_IN  => RESET_200,
      PULSE_B_OUT => start_trg_win_cnt_200_p);

-- Trigger window end logic
  Check_Trg_Win_End_Conrollers : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        trg_win_cnt <= '1' & trg_win_post_200;
      elsif start_trg_win_cnt_200_p = '1' then
        trg_win_end_200 <= '0';
        trg_win_cnt     <= "000000000001";
      elsif trg_win_cnt(10 downto 0) = trg_win_post_200 then
        trg_win_end_200 <= '1';
        trg_win_cnt(11) <= '1';
      else
        trg_win_end_200 <= '0';
        trg_win_cnt     <= std_logic_vector(unsigned(trg_win_cnt) + to_unsigned(1, 1));
      end if;
    end if;
  end process Check_Trg_Win_End_Conrollers;

  TriggerWinEndPulse200 : edge_to_pulse
    port map (
      clock     => CLK_200,
      en_clk    => '1',
      signal_in => trg_win_end_200,
      pulse     => trg_win_end_200_p);
  TRIGGER_WIN_END_OUT <= trg_win_end_200_p;

  SyncTriggerWinEndPulse100 : pulse_sync
    port map (
      CLK_A_IN    => CLK_200,
      RESET_A_IN  => RESET_200,
      PULSE_A_IN  => trg_win_end_200_p,
      CLK_B_IN    => CLK_100,
      RESET_B_IN  => RESET_100,
      PULSE_B_OUT => trg_win_end_100_p);
  trg_win_end_100_reg  <= trg_win_end_100_p    when rising_edge(CLK_100);
  trg_win_end_100_2reg <= trg_win_end_100_reg  when rising_edge(CLK_100);
  trg_win_end_100_3reg <= trg_win_end_100_2reg when rising_edge(CLK_100);
  trg_win_end_100_4reg <= trg_win_end_100_3reg when rising_edge(CLK_100);

-- Trigger window borders
  Trg_Win_Calculation : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      TW_pre <= std_logic_vector(to_unsigned(to_integer(unsigned(TRIGGER_TIME_IN))-to_integer(unsigned(TRG_WIN_PRE)), 39));
--    TW_post <= std_logic_vector(to_unsigned(to_integer(unsigned(TRIGGER_TIME_IN))+to_integer(unsigned(TRG_WIN_POST)), 39));
    end if;
  end process Trg_Win_Calculation;

  ---- Number of words to write out to trbnet
  --Gen : for i in 0 to CHANNEL_NUMBER-1 generate
  --  CaptureChannelWCount : process (CLK_200)
  --  begin
  --    if rising_edge(CLK_200) then
  --      if trg_win_end_200_p = '1' then
  --        if CH_WCNT_IN(i) < DATA_LIMIT_IN then
  --          ch_wcnt_reg(i) <= CH_WCNT_IN(i) after 10 ps;
  --        else
  --          ch_wcnt_reg(i) <= DATA_LIMIT_IN after 10 ps;
  --        end if;
  --      end if;
  --    end if;
  --  end process CaptureChannelWCount;
  --end generate Gen;

  -- Number of words to read from the fifos
  CaptureChannelRCount : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if trg_win_end_200_p = '1' then
        ch_wcnt_reg <= CH_WCNT_IN after 10 ps;
      end if;
    end if;
  end process CaptureChannelRCount;

  ch_wcnt_2reg <= ch_wcnt_reg when rising_edge(CLK_100);

-- Channel Hit Time Determination
  ChannelEpochCounter : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if ch_data_reg(fifo_nr_wr_2reg)(31 downto 29) = "011" then
        ch_epoch_cntr_i <= ch_data_reg(fifo_nr_wr_2reg)(27 downto 0);
      end if;
    end if;
  end process ChannelEpochCounter;

  ChannelHitTime : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if ch_data_reg(fifo_nr_wr_2reg)(31) = '1' then
        ch_hit_time <= ch_epoch_cntr_i & ch_data_reg(fifo_nr_wr_2reg)(10 downto 0);
      elsif ch_data_reg(fifo_nr_wr_2reg)(31 downto 29) = "011" then
        ch_hit_time <= (others => '0');
      end if;
    end if;
  end process ChannelHitTime;

-- Controls if the data coming from the channel is greater than the trigger window pre-edge
  Check_Trg_Win_Left : process (TW_pre, ch_hit_time)
  begin
    --if rising_edge(CLK_100) then
    if to_integer(unsigned(TW_pre)) <= to_integer(unsigned(ch_hit_time)) then
      trg_win_l <= '1';
    else
      trg_win_l <= '0';
    end if;
    --end if;
  end process Check_Trg_Win_Left;

-- Controls if the data coming from the channel is smaller than the trigger window post-edge
  --Check_Trg_Win_Right : process (RESET_100, TW_post, ch_hit_time)
  --begin
  --  --if rising_edge(CLK_100) then
  --  if RESET_100 = '1' then
  --    trg_win_r <= '0';
  --  elsif to_integer(unsigned(ch_hit_time)) <= to_integer(unsigned(TW_post)) then
  --    trg_win_r <= '1';
  --  else
  --    trg_win_r <= '0';
  --  end if;
  --  --end if;
  --end process Check_Trg_Win_Right;

-------------------------------------------------------------------------------
-- Readout
-------------------------------------------------------------------------------
-- Readout fsm
  RD_FSM_CLK : process (CLK_100, RESET_100)
  begin
    if rising_edge(CLK_100) then
      RD_CURRENT        <= RD_NEXT;
      start_trg_win_cnt <= start_trg_win_cnt_fsm;
      rd_en             <= rd_en_fsm;
      wr_header         <= wr_header_fsm;
      wr_status         <= wr_status_fsm;
      data_finished     <= data_finished_fsm;
      trg_release_reg   <= trg_release_fsm;
      wrong_readout_up  <= wrong_readout_fsm;
      idle_time_up      <= idle_fsm;
      readout_time_up   <= readout_fsm;
      wait_time_up      <= wait_fsm;
      rd_number         <= rd_number_fsm;
      fifo_nr_rd        <= fifo_nr_rd_fsm;
      rd_fsm_debug      <= rd_fsm_debug_fsm;
    end if;
  end process RD_FSM_CLK;
  READ_EN_OUT <= rd_en;

  RD_FSM_PROC : process (RD_CURRENT, VALID_TIMING_TRG_IN, VALID_NOTIMING_TRG_IN, trg_win_end_100_p,
                         ch_empty_reg, TRG_DATA_VALID_IN, INVALID_TRG_IN, TMGTRG_TIMEOUT_IN, TRG_TYPE_IN,
                         SPURIOUS_TRG_IN, stop_status_i, DEBUG_MODE_EN_IN, rd_number, fifo_nr_rd, ch_wcnt_2reg)
  begin

    start_trg_win_cnt_fsm <= '0';
    rd_en_fsm             <= (others => '0');
    wr_header_fsm         <= '0';
    data_finished_fsm     <= '0';
    trg_release_fsm       <= '0';
    wrong_readout_fsm     <= '0';
    idle_fsm              <= '0';
    readout_fsm           <= '0';
    wait_fsm              <= '0';
    wr_status_fsm         <= '0';
    rd_number_fsm         <= (others => '0');
    fifo_nr_rd_fsm        <= fifo_nr_rd;
    rd_fsm_debug_fsm      <= x"0";
    RD_NEXT               <= IDLE;

    case (RD_CURRENT) is
      when IDLE =>
        if VALID_TIMING_TRG_IN = '1' then
          RD_NEXT               <= WAIT_FOR_TRG_WIND_END;  --WR_HEADER_A;
          start_trg_win_cnt_fsm <= '1';
          wr_header_fsm         <= '1';
          readout_fsm           <= '1';
        elsif VALID_NOTIMING_TRG_IN = '1' then
          if TRG_TYPE_IN = x"E" then
            wr_header_fsm <= '1';
            RD_NEXT       <= SEND_STATUS;
          else
            data_finished_fsm <= '1';
            RD_NEXT           <= SEND_TRG_RELEASE_A;
          end if;
        elsif INVALID_TRG_IN = '1' then
          RD_NEXT           <= SEND_TRG_RELEASE_A;
          data_finished_fsm <= '1';
        else
          RD_NEXT <= IDLE;
        end if;
        idle_fsm         <= '1';
        rd_fsm_debug_fsm <= x"1";

        --when WR_HEADER_A =>
        --  RD_NEXT       <= WAIT_FOR_TRG_WIND_END;
        --  wr_header_fsm <= '1';
        --  readout_fsm   <= '1';
        --  rd_fsm_debug_fsm <= x"3";
        
      when WAIT_FOR_TRG_WIND_END =>
        if trg_win_end_100_p = '1' then
          RD_NEXT <= RD_CH;
        else
          RD_NEXT <= WAIT_FOR_TRG_WIND_END;
        end if;
        wait_fsm         <= '1';
        rd_fsm_debug_fsm <= x"2";

      when RD_CH =>
        if rd_number /= ch_wcnt_2reg(fifo_nr_rd) then
          rd_en_fsm(fifo_nr_rd) <= '1';
          rd_number_fsm         <= rd_number + to_unsigned(1, 1);
          fifo_nr_rd_fsm        <= fifo_nr_rd;
          RD_NEXT               <= RD_CH;
        elsif fifo_nr_rd = CHANNEL_NUMBER-1 then
          rd_en_fsm(fifo_nr_rd) <= '0';
          rd_number_fsm         <= (others => '0');
          if DEBUG_MODE_EN_IN = '1' then
            RD_NEXT <= SEND_STATUS;
          else
            RD_NEXT <= WAIT_FOR_LVL1_TRG_A;
          end if;
        else
          rd_number_fsm  <= (others => '0');
          fifo_nr_rd_fsm <= fifo_nr_rd + 1;
          RD_NEXT        <= RD_CH;
        end if;
        readout_fsm      <= '1';
        rd_fsm_debug_fsm <= x"3";

      when WAIT_FOR_LVL1_TRG_A =>
        if TRG_DATA_VALID_IN = '1' then
          RD_NEXT <= WAIT_FOR_LVL1_TRG_B;
        elsif TMGTRG_TIMEOUT_IN = '1' then
          RD_NEXT <= IDLE;
        else
          RD_NEXT <= WAIT_FOR_LVL1_TRG_A;
        end if;
        wait_fsm         <= '1';
        rd_fsm_debug_fsm <= x"4";

      when WAIT_FOR_LVL1_TRG_B =>
        RD_NEXT          <= WAIT_FOR_LVL1_TRG_C;
        wait_fsm         <= '1';
        rd_fsm_debug_fsm <= x"5";

      when WAIT_FOR_LVL1_TRG_C =>
        if SPURIOUS_TRG_IN = '1' then
          wrong_readout_fsm <= '1';
        end if;
        RD_NEXT          <= SEND_TRG_RELEASE_A;
        wait_fsm         <= '1';
        rd_fsm_debug_fsm <= x"6";

      when SEND_STATUS =>
        if stop_status_i = '1' then
          if DEBUG_MODE_EN_IN = '1' then
            RD_NEXT <= WAIT_FOR_LVL1_TRG_A;
          else
            RD_NEXT <= SEND_TRG_RELEASE_A;
          end if;
          data_finished_fsm <= '1';
        else
          RD_NEXT       <= SEND_STATUS;
          wr_status_fsm <= '1';
        end if;
        readout_fsm      <= '1';
        rd_fsm_debug_fsm <= x"7";

      when SEND_TRG_RELEASE_A =>
        RD_NEXT          <= SEND_TRG_RELEASE_B;
        trg_release_fsm  <= '1';
        fifo_nr_rd_fsm   <= 0;
        readout_fsm      <= '1';
        rd_fsm_debug_fsm <= x"8";

      when SEND_TRG_RELEASE_B =>
        RD_NEXT          <= IDLE;
        wait_fsm         <= '1';
        rd_fsm_debug_fsm <= x"9";

      when others =>
        RD_NEXT          <= IDLE;
        rd_fsm_debug_fsm <= x"F";
    end case;
  end process RD_FSM_PROC;

  --purpose: FSM for writing data to buffer 0
  WR_FSM_CLK : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      WR_CURRENT   <= WR_NEXT;
      wr_ch_data_i <= wr_ch_data_fsm;
      wr_number    <= wr_number_fsm;
      fifo_nr_wr   <= fifo_nr_wr_fsm;
      wr_finished  <= wr_finished_fsm;
      wr_fsm_debug <= wr_fsm_debug_fsm;
    end if;
  end process WR_FSM_CLK;

  WR_FSM : process (WR_CURRENT, trg_win_end_100_3reg, TRG_TYPE_IN, wr_number, ch_wcnt_2reg, fifo_nr_wr)

  begin

    WR_NEXT         <= WR_CURRENT;
    wr_ch_data_fsm  <= '0';
    wr_number_fsm   <= (others => '0');
    fifo_nr_wr_fsm  <= 0;
    wr_finished_fsm <= '0';

    case (WR_CURRENT) is
      when IDLE =>
        if trg_win_end_100_3reg = '1' then
          WR_NEXT <= WR_CH;
        else
          WR_NEXT <= IDLE;
        end if;
        wr_fsm_debug_fsm <= x"1";
--
      when WR_CH =>
        if wr_number /= ch_wcnt_2reg(fifo_nr_wr) then
          if wr_number >= DATA_LIMIT_IN then
            wr_ch_data_fsm <= '0';
          else
            wr_ch_data_fsm <= '1';
          end if;
          wr_number_fsm    <= wr_number + to_unsigned(1, 1);
          fifo_nr_wr_fsm   <= fifo_nr_wr;
          wr_fsm_debug_fsm <= x"2";
        elsif fifo_nr_wr = CHANNEL_NUMBER-1 then
          wr_ch_data_fsm   <= '0';
          wr_number_fsm    <= (others => '0');
          wr_finished_fsm  <= '1';
          wr_fsm_debug_fsm <= x"3";
          WR_NEXT          <= IDLE;
        else
          wr_number_fsm    <= (others => '0');
          fifo_nr_wr_fsm   <= fifo_nr_wr + 1;
          wr_fsm_debug_fsm <= x"4";
        end if;
--      
      when others =>
        WR_NEXT          <= IDLE;
        wr_fsm_debug_fsm <= x"F";

    end case;
  end process WR_FSM;

  fifo_nr_wr_reg   <= fifo_nr_wr      when rising_edge(CLK_100);
  fifo_nr_wr_2reg  <= fifo_nr_wr_reg  when rising_edge(CLK_100);
  fifo_nr_wr_3reg  <= fifo_nr_wr_2reg when rising_edge(CLK_100);
  wr_ch_data_reg   <= wr_ch_data_i    when rising_edge(CLK_100);
  wr_ch_data_2reg  <= wr_ch_data_reg  when rising_edge(CLK_100);
  wr_finished_reg  <= wr_finished     when rising_edge(CLK_100);
  wr_finished_2reg <= wr_finished_reg when rising_edge(CLK_100);

-------------------------------------------------------------------------------
-- Data out mux
-------------------------------------------------------------------------------
  Data_Out_MUX : process (CLK_100)
    variable i : integer := 0;
  begin
    if rising_edge(CLK_100) then
      if wr_header = '1' then
        data_out_reg  <= "001" & "0" & TRG_TYPE_IN & TRG_CODE_IN & header_error_bits;
        data_wr_reg   <= '1';
        stop_status_i <= '0';
      elsif wr_ch_data_2reg = '1' then
        if TRIGGER_WIN_EN_IN = '1' then  -- trigger window enabled
          if ch_data_2reg(fifo_nr_wr_3reg)(31 downto 29) = "011" then
            data_out_reg <= ch_data_2reg(fifo_nr_wr_3reg)(31 downto 0);
            data_wr_reg  <= '1';
            --elsif (TW_pre(10) = '1' and ref_time_coarse(10) = '0') or (TW_post(10) = '0' and ref_time_coarse(10) = '1') then  -- if one of the trigger window edges has an overflow
            --  if (trg_win_l = '0' and trg_win_r = '1') or (trg_win_l = '1' and trg_win_r = '0') then
            --    data_out_reg <= ch_data_2reg(fifo_nr);
            --    data_wr_reg  <= '1';
            --  else
            --    data_out_reg <= (others => '1');
            --    data_wr_reg  <= '0';
            --  end if;
          else  -- if both of the trigger window edges are in the coarse counter boundries
            if (trg_win_l = '1') then   -- and trg_win_r = '1') then
              data_out_reg <= ch_data_2reg(fifo_nr_wr_3reg)(31 downto 0);
              data_wr_reg  <= '1';
            else
              data_out_reg <= (others => '1');
              data_wr_reg  <= '0';
            end if;
          end if;
          stop_status_i <= '0';
        else                            -- trigger window disabled          
          data_out_reg  <= ch_data_2reg(fifo_nr_wr_3reg)(31 downto 0);
          data_wr_reg   <= '1';
          stop_status_i <= '0';
        end if;
      elsif wr_status = '1' then
        case i is
          when 0  => data_out_reg <= "010" & "00000" & std_logic_vector(trig_number);
          when 1  => data_out_reg <= "010" & "00001" & std_logic_vector(release_number);
          when 2  => data_out_reg <= "010" & "00010" & std_logic_vector(valid_tmg_trig_number);
          when 3  => data_out_reg <= "010" & "00011" & std_logic_vector(valid_NOtmg_trig_number);
          when 4  => data_out_reg <= "010" & "00100" & std_logic_vector(invalid_trig_number);
          when 5  => data_out_reg <= "010" & "00101" & std_logic_vector(multi_tmg_trig_number);
          when 6  => data_out_reg <= "010" & "00110" & std_logic_vector(spurious_trig_number);
          when 7  => data_out_reg <= "010" & "00111" & std_logic_vector(wrong_readout_number);
          when 8  => data_out_reg <= "010" & "01000" & std_logic_vector(spike_number);
          when 9  => data_out_reg <= "010" & "01001" & std_logic_vector(idle_time);
          when 10 => data_out_reg <= "010" & "01010" & std_logic_vector(wait_time);
          when 11 => data_out_reg <= "010" & "01011" & std_logic_vector(total_empty_channel);
          when 12 => data_out_reg <= "010" & "01100" & std_logic_vector(readout_time);
                     stop_status_i <= '1';
          when 13 => data_out_reg <= "010" & "01101" & std_logic_vector(timeout_number);
                     i := -1;
          when others => null;
        end case;
        data_wr_reg <= '1';
        i           := i+1;
      elsif wr_trailer = '1' then
        data_out_reg  <= "011" & "0000000000000" & trailer_error_bits;
        data_wr_reg   <= '1';
        stop_status_i <= '0';
      else
        data_out_reg  <= (others => '1');
        data_wr_reg   <= '0';
        stop_status_i <= '0';
      end if;
    end if;
  end process Data_Out_MUX;

  DATA_OUT                    <= data_out_reg;
  DATA_WRITE_OUT              <= data_wr_reg;
  finished_i                  <= (data_finished or wr_finished_2reg) when rising_edge(CLK_100);
  DATA_FINISHED_OUT           <= finished_i;
  TRG_RELEASE_OUT             <= trg_release_reg;
  TRG_STATUSBIT_OUT           <= (others => '0');
  READOUT_DEBUG(3 downto 0)   <= rd_fsm_debug;
  READOUT_DEBUG(7 downto 4)   <= wr_fsm_debug;
  READOUT_DEBUG(8)            <= data_wr_reg;
  READOUT_DEBUG(9)            <= finished_i;
  READOUT_DEBUG(10)           <= trg_release_reg;
  READOUT_DEBUG(16 downto 11) <= data_out_reg(27 downto 22);
  READOUT_DEBUG(31 downto 17) <= (others => '0');

  -- Error, warning bits set in the header
  header_error_bits(15 downto 3) <= (others => '0');
  header_error_bits(0)           <= '0';
--header_error_bits(0) <= lost_hit_i;  -- if there is at least one lost hit (can be more if the FIFO is full).
  header_error_bits(1)           <= ch_full_i;
  header_error_bits(2)           <= '0';  --ch_almost_full_i;

  -- Error, warning bits set in the trailer
  trailer_error_bits <= (others => '0');
  -- trailer_error_bits (0) <= wrong_readout_i;  -- if there is a wrong readout because of a spurious timing trigger

  ch_full_i        <= or_all(CH_FULL_IN);
  ch_almost_full_i <= or_all(CH_ALMOST_FULL_IN);



-------------------------------------------------------------------------------
-- Debug and statistics words
-------------------------------------------------------------------------------

  edge_to_pulse_1 : edge_to_pulse
    port map (
      clock     => CLK_100,
      en_clk    => '1',
      signal_in => VALID_TIMING_TRG_IN,
      pulse     => valid_timing_trg_p);

  edge_to_pulse_2 : edge_to_pulse
    port map (
      clock     => CLK_100,
      en_clk    => '1',
      signal_in => VALID_NOTIMING_TRG_IN,
      pulse     => valid_notiming_trg_p);

  edge_to_pulse_3 : edge_to_pulse
    port map (
      clock     => CLK_100,
      en_clk    => '1',
      signal_in => INVALID_TRG_IN,
      pulse     => invalid_trg_p);

  edge_to_pulse_4 : edge_to_pulse
    port map (
      clock     => CLK_100,
      en_clk    => '1',
      signal_in => MULTI_TMG_TRG_IN,
      pulse     => multi_tmg_trg_p);

  edge_to_pulse_5 : edge_to_pulse
    port map (
      clock     => CLK_100,
      en_clk    => '1',
      signal_in => SPURIOUS_TRG_IN,
      pulse     => spurious_trg_p);

  edge_to_pulse_6 : edge_to_pulse
    port map (
      clock     => CLK_100,
      en_clk    => '1',
      signal_in => SPIKE_DETECTED_IN,
      pulse     => spike_detected_p);

  edge_to_pulse_7 : edge_to_pulse
    port map (
      clock     => CLK_100,
      en_clk    => '1',
      signal_in => TMGTRG_TIMEOUT_IN,
      pulse     => timeout_detected_p);

-- Internal trigger number counter (only valid triggers)
  Statistics_Trigger_Number : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        trig_number <= (others => '0');
      elsif valid_timing_trg_p = '1' or valid_notiming_trg_p = '1' then
        trig_number <= trig_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Trigger_Number;

-- Internal release number counter
  Statistics_Release_Number : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        release_number <= (others => '0');
      elsif trg_release_reg = '1' then
        release_number <= release_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Release_Number;

-- Internal valid timing trigger number counter
  Statistics_Valid_Timing_Trigger_Number : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        valid_tmg_trig_number <= (others => '0');
      elsif valid_timing_trg_p = '1' then
        valid_tmg_trig_number <= valid_tmg_trig_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Valid_Timing_Trigger_Number;

-- Internal valid NOtiming trigger number counter
  Statistics_Valid_NoTiming_Trigger_Number : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        valid_NOtmg_trig_number <= (others => '0');
      elsif valid_notiming_trg_p = '1' then
        valid_NOtmg_trig_number <= valid_NOtmg_trig_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Valid_NoTiming_Trigger_Number;

-- Internal invalid trigger number counter
  Statistics_Invalid_Trigger_Number : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        invalid_trig_number <= (others => '0');
      elsif invalid_trg_p = '1' then
        invalid_trig_number <= invalid_trig_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Invalid_Trigger_Number;

-- Internal multi timing trigger number counter
  Statistics_Multi_Timing_Trigger_Number : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        multi_tmg_trig_number <= (others => '0');
      elsif multi_tmg_trg_p = '1' then
        multi_tmg_trig_number <= multi_tmg_trig_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Multi_Timing_Trigger_Number;

-- Internal spurious trigger number counter
  Statistics_Spurious_Trigger_Number : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        spurious_trig_number <= (others => '0');
      elsif spurious_trg_p = '1' then
        spurious_trig_number <= spurious_trig_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Spurious_Trigger_Number;

-- Number of wrong readout becasue of spurious trigger
  Statistics_Wrong_Readout_Number : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        wrong_readout_number <= (others => '0');
      elsif wrong_readout_up = '1' then
        wrong_readout_number <= wrong_readout_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Wrong_Readout_Number;

-- Internal spike number counter
  Statistics_Spike_Number : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        spike_number <= (others => '0');
      elsif spike_detected_p = '1' then
        spike_number <= spike_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Spike_Number;

-- Internal timeout number counter
  Statistics_Timeout_Number : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        timeout_number <= (others => '0');
      elsif timeout_detected_p = '1' then
        timeout_number <= timeout_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Timeout_Number;

-- IDLE time of the TDC readout
  Statistics_Idle_Time : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        idle_time <= (others => '0');
      elsif idle_time_up = '1' then
        idle_time <= idle_time + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Idle_Time;

-- Readout and Wait time of the TDC readout
  Statistics_Readout_Wait_Time : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        readout_time <= (others => '0');
        wait_time    <= (others => '0');
      elsif readout_time_up = '1' then
        readout_time <= readout_time + to_unsigned(1, 1);
      elsif wait_time_up = '1' then
        wait_time <= wait_time + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Readout_Wait_Time;

-- Empty channel number
  Statistics_Empty_Channel_Number : process (CLK_100)
    variable i : integer := CHANNEL_NUMBER;
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        total_empty_channel <= (others => '0');
        i                   := CHANNEL_NUMBER;
      elsif trg_win_end_100_p = '1' then
        empty_channels(CHANNEL_NUMBER-1 downto 0) <= CH_EMPTY_IN(CHANNEL_NUMBER-1 downto 0);
        i                                         := 0;
      elsif i = CHANNEL_NUMBER then
        i := i;
      elsif empty_channels(i) = '1' then
        total_empty_channel <= total_empty_channel + to_unsigned(1, 1);
        i                   := i + 1;
      else
        i := i + 1;
      end if;
    end if;
  end process Statistics_Empty_Channel_Number;

  -- Number of sent data finished
  Statistics_Finished_Number : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        finished_number <= (others => '0');
      elsif finished_i = '1' then
        finished_number <= finished_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Finished_Number;


-------------------------------------------------------------------------------
-- STATUS REGISTERS BUS
-------------------------------------------------------------------------------
  STATUS_REGISTERS_BUS_OUT(0)(3 downto 0)    <= rd_fsm_debug;
  STATUS_REGISTERS_BUS_OUT(0)(7 downto 4)    <= wr_fsm_debug;
  STATUS_REGISTERS_BUS_OUT(0)(15 downto 8)   <= std_logic_vector(to_unsigned(CHANNEL_NUMBER-1, 8));
  STATUS_REGISTERS_BUS_OUT(0)(16)            <= REFERENCE_TIME when rising_edge(CLK_100);
  STATUS_REGISTERS_BUS_OUT(0)(27 downto 17)  <= (others => '0');
  STATUS_REGISTERS_BUS_OUT(0)(31 downto 28)  <= TRG_TYPE_IN    when rising_edge(CLK_100);
  STATUS_REGISTERS_BUS_OUT(1)                <= slow_control_ch_empty_i(31 downto 0);
  STATUS_REGISTERS_BUS_OUT(2)                <= slow_control_ch_empty_i(63 downto 32);
  STATUS_REGISTERS_BUS_OUT(3)(10 downto 0)   <= TRG_WIN_PRE;
  STATUS_REGISTERS_BUS_OUT(3)(15 downto 11)  <= (others => '0');
  STATUS_REGISTERS_BUS_OUT(3)(26 downto 16)  <= TRG_WIN_POST;
  STATUS_REGISTERS_BUS_OUT(3)(30 downto 27)  <= (others => '0');
  STATUS_REGISTERS_BUS_OUT(3)(31)            <= TRIGGER_WIN_EN_IN;
  STATUS_REGISTERS_BUS_OUT(4)(23 downto 0)   <= std_logic_vector(trig_number);
  STATUS_REGISTERS_BUS_OUT(5)(23 downto 0)   <= std_logic_vector(valid_tmg_trig_number);
  STATUS_REGISTERS_BUS_OUT(6)(23 downto 0)   <= std_logic_vector(valid_NOtmg_trig_number);
  STATUS_REGISTERS_BUS_OUT(7)(23 downto 0)   <= std_logic_vector(invalid_trig_number);
  STATUS_REGISTERS_BUS_OUT(8)(23 downto 0)   <= std_logic_vector(multi_tmg_trig_number);
  STATUS_REGISTERS_BUS_OUT(9)(23 downto 0)   <= std_logic_vector(spurious_trig_number);
  STATUS_REGISTERS_BUS_OUT(10)(23 downto 0)  <= std_logic_vector(wrong_readout_number);
  STATUS_REGISTERS_BUS_OUT(11)(23 downto 0)  <= std_logic_vector(spike_number);
  STATUS_REGISTERS_BUS_OUT(12)(23 downto 0)  <= std_logic_vector(idle_time);
  STATUS_REGISTERS_BUS_OUT(13)(23 downto 0)  <= std_logic_vector(wait_time);
  STATUS_REGISTERS_BUS_OUT(14)(23 downto 0)  <= std_logic_vector(total_empty_channel);
  STATUS_REGISTERS_BUS_OUT(15)(23 downto 0)  <= std_logic_vector(release_number);
  STATUS_REGISTERS_BUS_OUT(16)(23 downto 0)  <= std_logic_vector(readout_time);
  STATUS_REGISTERS_BUS_OUT(17)(23 downto 0)  <= std_logic_vector(timeout_number);
  STATUS_REGISTERS_BUS_OUT(18)(23 downto 0)  <= std_logic_vector(finished_number);
  STATUS_REGISTERS_BUS_OUT(18)(31 downto 24) <= std_logic_vector(wr_number);

  FILL_BUS1 : for i in 4 to 17 generate
    STATUS_REGISTERS_BUS_OUT(i)(31 downto 24) <= (others => '0');
  end generate FILL_BUS1;

  slow_control_ch_empty_i(63 downto CHANNEL_NUMBER-1) <= (others => '1');
  slow_control_ch_empty_i(CHANNEL_NUMBER-2 downto 0)  <= ch_empty_2reg(CHANNEL_NUMBER-1 downto 1);

-------------------------------------------------------------------------------
-- Registering
-------------------------------------------------------------------------------
  ch_data_reg   <= CH_DATA_IN    when rising_edge(CLK_100);
  ch_data_2reg  <= ch_data_reg   when rising_edge(CLK_100);
  ch_empty_reg  <= CH_EMPTY_IN   when rising_edge(CLK_100);
  ch_empty_2reg <= ch_empty_reg  when rising_edge(CLK_100);
  ch_empty_3reg <= ch_empty_2reg when rising_edge(CLK_100);
  ch_empty_4reg <= ch_empty_3reg when rising_edge(CLK_100);

  trg_win_post_200 <= std_logic_vector(unsigned(TRG_WIN_POST)-8) when rising_edge(CLK_200);

end behavioral;
