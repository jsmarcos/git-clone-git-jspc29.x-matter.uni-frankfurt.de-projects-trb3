-------------------------------------------------------------------------------
-- Title      : Readout Entity
-- Project    : 
-------------------------------------------------------------------------------
-- File       : Readout.vhd
-- Author     : cugur@gsi.de
-- Created    : 2012-10-25
-- Last update: 2014-12-11
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
use work.tdc_components.all;

entity Readout is
  generic (
    CHANNEL_NUMBER : integer range 2 to 65;
    STATUS_REG_NR  : integer range 0 to 31;
    TDC_VERSION    : std_logic_vector(11 downto 0)); 
  port (
    RESET_100                : in  std_logic;
    RESET_200                : in  std_logic;
    RESET_COUNTERS           : in  std_logic;
    CLK_100                  : in  std_logic;
    CLK_200                  : in  std_logic;
    HIT_IN                   : in  std_logic_vector(CHANNEL_NUMBER-1 downto 1);
-- from the channels
    CH_DATA_IN               : in  std_logic_vector_array_36(0 to CHANNEL_NUMBER);
    CH_DATA_VALID_IN         : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
    CH_EMPTY_IN              : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
    CH_FULL_IN               : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
    CH_ALMOST_EMPTY_IN       : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
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
-- trigger window settings
    TRG_WIN_PRE_IN           : in  std_logic_vector(10 downto 0);
    TRG_WIN_POST_IN          : in  std_logic_vector(10 downto 0);
    TRG_WIN_EN_IN            : in  std_logic;
-- from the trigger handler
    TRG_WIN_END_TDC_IN       : in  std_logic;
    TRG_WIN_END_RDO_IN       : in  std_logic;
    TRG_TDC_IN               : in  std_logic;
    TRG_TIME_IN              : in  std_logic_vector(38 downto 0);
-- miscellaneous
    LIGHT_MODE_IN            : in  std_logic;
    COARSE_COUNTER_IN        : in  std_logic_vector(10 downto 0);
    EPOCH_COUNTER_IN         : in  std_logic_vector(27 downto 0);
    DEBUG_MODE_EN_IN         : in  std_logic;
    STATUS_REGISTERS_BUS_OUT : out std_logic_vector_array_32(0 to STATUS_REG_NR-1);
    READOUT_DEBUG            : out std_logic_vector(31 downto 0);
    REFERENCE_TIME           : in  std_logic
    );
end entity Readout;

architecture behavioral of Readout is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

  -- trigger window
  signal trg_win_pre             : unsigned(10 downto 0);
  signal trg_win_post            : unsigned(10 downto 0);
  signal trg_win_en              : std_logic;
  signal trg_time                : std_logic_vector(38 downto 0);
  signal TW_pre                  : std_logic_vector(38 downto 0);
  signal TW_post                 : std_logic_vector(38 downto 0);
  signal trg_win_l               : std_logic;
  signal trg_win_r               : std_logic;
  signal start_trg_win_cnt       : std_logic := '0';
  signal start_trg_win_cnt_200_p : std_logic;
  signal trg_win_cnt             : std_logic_vector(11 downto 0);
  signal trg_win_end_200         : std_logic := '0';
  signal trg_win_end_200_p       : std_logic;
  signal trg_win_end_100_p       : std_logic;
  signal trg_win_end_100_r       : std_logic;
  signal trg_win_end_100_2r      : std_logic;
  signal trg_win_end_100_3r      : std_logic;
  signal trg_win_end_100_4r      : std_logic;
  -- channel signals
  signal ch_data_r               : std_logic_vector_array_36(0 to CHANNEL_NUMBER);
  signal ch_data_2r              : std_logic_vector_array_36(0 to CHANNEL_NUMBER);
  signal ch_data_3r              : std_logic_vector_array_36(0 to CHANNEL_NUMBER);
  signal ch_data_4r              : std_logic_vector(31 downto 0);
  signal ch_hit_time             : std_logic_vector(38 downto 0);
  signal ch_epoch_cntr           : std_logic_vector(27 downto 0);
  signal buffer_transfer_done    : std_logic;
  signal buffer_transfer_done_r  : std_logic;
  signal buffer_transfer_done_2r : std_logic;
  -- readout fsm
  type FSM_READ is (IDLE, WAIT_FOR_TRG_WIND_END, RD_CH, WAIT_FOR_DATA_FINISHED, WAIT_FOR_LVL1_TRG_A,
                    WAIT_FOR_LVL1_TRG_B, WAIT_FOR_LVL1_TRG_C, SEND_STATUS, SEND_TRG_RELEASE_A,
                    SEND_TRG_RELEASE_B, SEND_TRG_RELEASE_C, WAIT_FOR_BUFFER_TRANSFER);
  signal RD_CURRENT             : FSM_READ                          := IDLE;
  signal RD_NEXT                : FSM_READ;
  type FSM_WRITE is (IDLE, WR_CH, WAIT_A, WAIT_B, WAIT_C, WAIT_D);
  signal WR_CURRENT             : FSM_WRITE                         := IDLE;
  signal WR_NEXT                : FSM_WRITE;
  signal start_trg_win_cnt_fsm  : std_logic;
  signal rd_fsm_debug_fsm       : std_logic_vector(3 downto 0);
  signal wr_fsm_debug_fsm       : std_logic_vector(3 downto 0);
  signal rd_en_fsm              : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal data_finished_fsm      : std_logic;
  signal wr_finished_fsm        : std_logic;
  signal trg_release_fsm        : std_logic;
  signal wr_header_fsm          : std_logic;
  signal wr_trailer_fsm         : std_logic;
  signal wr_ch_data_fsm         : std_logic;
  signal wr_status_fsm          : std_logic;
  signal wrong_readout_fsm      : std_logic;
  signal wrong_readout          : std_logic;
  signal wr_number_fsm          : unsigned(7 downto 0);
  signal wr_number              : unsigned(7 downto 0);
  signal fifo_nr_rd_fsm         : integer range 0 to CHANNEL_NUMBER := 0;
  signal fifo_nr_wr_fsm         : integer range 0 to CHANNEL_NUMBER := 0;
  signal buf_delay_fsm          : integer range 0 to 63             := 0;
  signal buf_delay              : integer range 0 to 63             := 0;
--  signal isLastTriggerNoTiming  : std_logic                         := '0';
--  signal wr_trailer_fsm          : std_logic;
  signal idle_fsm               : std_logic;
  signal readout_fsm            : std_logic;
  signal wait_fsm               : std_logic;
  -- fifo number
  type Std_Logic_8_array is array (0 to 8) of std_logic_vector(3 downto 0);
  signal empty_channels         : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal fifo_nr_rd             : integer range 0 to CHANNEL_NUMBER := 0;
  signal fifo_nr_wr             : integer range 0 to CHANNEL_NUMBER := 0;
  signal fifo_nr_wr_r           : integer range 0 to CHANNEL_NUMBER := 0;
  signal fifo_nr_wr_2r          : integer range 0 to CHANNEL_NUMBER := 0;
  signal fifo_nr_wr_3r          : integer range 0 to CHANNEL_NUMBER := 0;
  -- fifo read
  signal rd_en                  : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  -- data mux
  signal start_write            : std_logic                         := '0';
  signal wr_header              : std_logic;
  signal wr_ch_data             : std_logic;
  signal wr_ch_data_r           : std_logic;
  signal wr_status              : std_logic;
  signal wr_trailer             : std_logic;
  signal wr_info                : std_logic;
  signal wr_time                : std_logic;
  signal wr_epoch               : std_logic;
  signal stop_status            : std_logic;
  -- to endpoint
  signal data_out_r             : std_logic_vector(31 downto 0);
  signal data_wr_r              : std_logic;
  signal data_finished          : std_logic;
  signal wr_finished            : std_logic;
  signal trg_release            : std_logic;
  signal trg_statusbit          : std_logic_vector(31 downto 0)     := (others => '0');
  -- statistics
  signal trg_number             : unsigned(23 downto 0)             := (others => '0');
  signal release_number         : unsigned(23 downto 0)             := (others => '0');
  signal valid_tmg_trg_number   : unsigned(23 downto 0)             := (others => '0');
  signal valid_NOtmg_trg_number : unsigned(23 downto 0)             := (others => '0');
  signal invalid_trg_number     : unsigned(23 downto 0)             := (others => '0');
  signal multi_tmg_trg_number   : unsigned(23 downto 0)             := (others => '0');
  signal spurious_trg_number    : unsigned(23 downto 0)             := (others => '0');
  signal wrong_readout_number   : unsigned(23 downto 0)             := (others => '0');
  signal spike_number           : unsigned(23 downto 0)             := (others => '0');
  signal timeout_number         : unsigned(23 downto 0)             := (others => '0');
  signal total_empty_channel    : unsigned(23 downto 0)             := (others => '0');
  signal idle_time              : unsigned(23 downto 0)             := (others => '0');
  signal readout_time           : unsigned(23 downto 0)             := (others => '0');
  signal wait_time              : unsigned(23 downto 0)             := (others => '0');
  signal finished_number        : unsigned(23 downto 0)             := (others => '0');
  signal valid_timing_trg_p     : std_logic;
  signal valid_notiming_trg_p   : std_logic;
  signal invalid_trg_p          : std_logic;
  signal multi_tmg_trg_p        : std_logic;
  signal spurious_trg_p         : std_logic;
  signal spike_detected_p       : std_logic;
  signal timeout_detected_p     : std_logic;
  signal idle_time_up           : std_logic;
  signal readout_time_up        : std_logic;
  signal wait_time_up           : std_logic;
  signal wrong_readout_up       : std_logic;
  signal finished               : std_logic;
  -- control
  signal sync_q                 : std_logic_vector((CHANNEL_NUMBER-2)*3+2 downto 0);
  signal isNoHit                : std_logic                         := '0';
  signal isNoHit_r              : std_logic                         := '0';
  signal hit_in_i               : std_logic_vector(CHANNEL_NUMBER-1 downto 1);
  -- debug
  signal header_error_bits      : std_logic_vector(15 downto 0);
  signal trailer_error_bits     : std_logic_vector(15 downto 0);
  signal ch_full                : std_logic;
  signal rd_fsm_debug           : std_logic_vector(3 downto 0);
  signal rd_fsm_debug_r         : std_logic_vector(3 downto 0);
  signal history_rd_fsm         : std_logic_vector(31 downto 0)     := (others => '0');
  signal wr_fsm_debug           : std_logic_vector(3 downto 0);
  signal wr_fsm_debug_r         : std_logic_vector(3 downto 0);
  signal history_wr_fsm         : std_logic_vector(31 downto 0)     := (others => '0');
  signal status_registers_bus   : std_logic_vector(31 downto 0);
  signal any_hit                : std_logic                         := '0';
  
begin  -- behavioral

  trg_win_pre  <= unsigned(TRG_WIN_PRE_IN);
  trg_win_post <= unsigned(TRG_WIN_POST_IN);
  trg_win_en   <= TRG_WIN_EN_IN when rising_edge(CLK_100);

-------------------------------------------------------------------------------
-- Trigger window
-------------------------------------------------------------------------------
-- Trigger window borders
  TrigWinCalculation : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      TW_pre  <= std_logic_vector(unsigned(trg_time)-trg_win_pre);
      TW_post <= std_logic_vector(unsigned(trg_time)+trg_win_post);
    end if;
  end process TrigWinCalculation;

-- Trigger Time Determination
  DefineTriggerTime : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        trg_time <= (others => '0');
      elsif TRG_TDC_IN = '1' then
        trg_time <= TRG_TIME_IN;
      end if;
    end if;
  end process DefineTriggerTime;

-- Channel Hit Time Determination
  ChannelHitTime : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if ch_data_r(fifo_nr_wr)(35 downto 32) = x"1" and ch_data_r(fifo_nr_wr)(31 downto 29) = "011" then
        ch_epoch_cntr <= ch_data_r(fifo_nr_wr)(27 downto 0);
      end if;

      if ch_data_r(fifo_nr_wr)(35 downto 32) = x"1" and ch_data_r(fifo_nr_wr)(31) = '1' then
        ch_hit_time <= ch_epoch_cntr& ch_data_r(fifo_nr_wr)(10 downto 0);
      elsif ch_data_r(fifo_nr_wr)(35 downto 32) = x"1" and ch_data_r(fifo_nr_wr)(31 downto 29) = "011" then
        ch_hit_time <= (others => '0');
      end if;
    end if;
  end process ChannelHitTime;

-- Controls if the data coming from the channel is greater than the trigger window pre-edge
  Check_Trigger_Win_Left : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if unsigned(TW_pre) <= unsigned(ch_hit_time) then
        trg_win_l <= '1';
      else
        trg_win_l <= '0';
      end if;
    end if;
  end process Check_Trigger_Win_Left;

-- Controls if the data coming from the channel is smaller than the trigger window post-edge
  Check_Trigger_Win_Right : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if unsigned(ch_hit_time) <= unsigned(TW_post) then
        trg_win_r <= '1';
      else
        trg_win_r <= '0';
      end if;
    end if;
  end process Check_Trigger_Win_Right;

-------------------------------------------------------------------------------
-- Readout
-------------------------------------------------------------------------------
  --LastTriggerNoTiming : process (CLK_100) is
  --begin
  --  if rising_edge(CLK_100) then        -- rising clock edge
  --    if TRG_DATA_VALID_IN = '1' then
  --      isLastTriggerNoTiming   <= TRG_TYPE_IN(3);
  --    end if;
  --  end if;
  --end process LastTriggerNoTiming;

-- Readout fsm
  RD_FSM_CLK : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' then
        RD_CURRENT <= IDLE;
        fifo_nr_rd <= 0;
      else
        RD_CURRENT              <= RD_NEXT;
        rd_en                   <= rd_en_fsm;
        wr_header               <= wr_header_fsm;
        wr_trailer              <= wr_trailer_fsm;
        wr_status               <= wr_status_fsm;
        data_finished           <= data_finished_fsm;
        trg_release             <= trg_release_fsm;
        buf_delay               <= buf_delay_fsm;
        wrong_readout           <= wrong_readout_fsm;
        idle_time_up            <= idle_fsm;
        readout_time_up         <= readout_fsm;
        wait_time_up            <= wait_fsm;
        fifo_nr_rd              <= fifo_nr_rd_fsm;
        rd_fsm_debug            <= rd_fsm_debug_fsm;
        buffer_transfer_done    <= and_all(CH_EMPTY_IN);
        buffer_transfer_done_r  <= buffer_transfer_done;
        buffer_transfer_done_2r <= buffer_transfer_done_r;
      end if;
    end if;
  end process RD_FSM_CLK;
  READ_EN_OUT <= rd_en;

  RD_FSM_PROC : process (RD_CURRENT, VALID_TIMING_TRG_IN, VALID_NOTIMING_TRG_IN, TRG_DATA_VALID_IN,
                         INVALID_TRG_IN, TMGTRG_TIMEOUT_IN, TRG_TYPE_IN, finished,
                         SPURIOUS_TRG_IN, stop_status, DEBUG_MODE_EN_IN, fifo_nr_rd,
                         TRG_WIN_END_RDO_IN, buf_delay, CH_EMPTY_IN, CLK_100, buffer_transfer_done_2r)
  begin

    rd_en_fsm         <= (others => '0');
    wr_header_fsm     <= '0';
    wr_trailer_fsm    <= '0';
    data_finished_fsm <= '0';
    trg_release_fsm   <= '0';
    wrong_readout_fsm <= wrong_readout;
    idle_fsm          <= '0';
    readout_fsm       <= '0';
    wait_fsm          <= '0';
    wr_status_fsm     <= '0';
    buf_delay_fsm     <= 0;
    fifo_nr_rd_fsm    <= fifo_nr_rd;
    rd_fsm_debug_fsm  <= x"0";
    RD_NEXT           <= RD_CURRENT;

    case (RD_CURRENT) is
      when IDLE =>
        if VALID_TIMING_TRG_IN = '1' then  -- physical trigger
          RD_NEXT <= WAIT_FOR_TRG_WIND_END;
          if isNoHit = '0' then
            wr_header_fsm <= '1';
          end if;
          --if isLastTriggerNoTiming = '1' then
          --  wrong_readout_fsm <= '1';
          --end if;
          readout_fsm <= '1';
        elsif VALID_NOTIMING_TRG_IN = '1' then
          if TRG_TYPE_IN = x"E" then       -- status trigger
            wr_header_fsm <= '1';
            RD_NEXT       <= SEND_STATUS;
          elsif TRG_TYPE_IN = x"D" then    -- tdc calibration trigger
            RD_NEXT       <= WAIT_FOR_TRG_WIND_END;
            wr_header_fsm <= '1';
            readout_fsm   <= '1';
          else                             -- the other triggers
            RD_NEXT           <= SEND_TRG_RELEASE_A;
            data_finished_fsm <= '1';
          end if;
        elsif INVALID_TRG_IN = '1' then    -- invalid trigger
          RD_NEXT           <= SEND_TRG_RELEASE_A;
          data_finished_fsm <= '1';
        end if;
        idle_fsm         <= '1';
        rd_fsm_debug_fsm <= x"1";
        
      when WAIT_FOR_TRG_WIND_END =>
        if TRG_WIN_END_RDO_IN = '1' then
          RD_NEXT <= WAIT_FOR_BUFFER_TRANSFER;
        end if;
        wait_fsm         <= '1';
        rd_fsm_debug_fsm <= x"2";

      when WAIT_FOR_BUFFER_TRANSFER =>  -- the data from channel fifo is written to the buffer
        if buffer_transfer_done_2r = '0' or buf_delay = 63 then
          RD_NEXT <= RD_CH;
        else
          buf_delay_fsm <= buf_delay+ 1;
        end if;
        rd_fsm_debug_fsm <= x"3";

      when RD_CH =>
        if CH_EMPTY_IN(fifo_nr_rd) = '0' then  -- read from channel if not empty
          rd_en_fsm(fifo_nr_rd) <= '1';
          fifo_nr_rd_fsm        <= fifo_nr_rd;
        elsif fifo_nr_rd = CHANNEL_NUMBER-1 then  -- the last channel
          rd_en_fsm(fifo_nr_rd) <= '0';
          if DEBUG_MODE_EN_IN = '1' then  -- send status after channel data
            RD_NEXT <= SEND_STATUS;
          else
            RD_NEXT <= WAIT_FOR_LVL1_TRG_A;
          end if;
        else                            -- go to the next channel
          fifo_nr_rd_fsm <= fifo_nr_rd + 1 after 10 ps;
        end if;
        readout_fsm      <= '1';
        rd_fsm_debug_fsm <= x"4";

      when WAIT_FOR_LVL1_TRG_A =>       -- wait for trigger data valid
        if TRG_DATA_VALID_IN = '1' then
          RD_NEXT <= WAIT_FOR_LVL1_TRG_B;
        elsif TMGTRG_TIMEOUT_IN = '1' then
          RD_NEXT           <= SEND_TRG_RELEASE_A;
          data_finished_fsm <= '1';
        end if;
        wait_fsm         <= '1';
        rd_fsm_debug_fsm <= x"6";

      when WAIT_FOR_LVL1_TRG_B =>
        RD_NEXT          <= WAIT_FOR_LVL1_TRG_C;
        wait_fsm         <= '1';
        rd_fsm_debug_fsm <= x"7";

      when WAIT_FOR_LVL1_TRG_C =>
        if SPURIOUS_TRG_IN = '1' then
          wrong_readout_fsm <= '1';
--          wr_trailer_fsm    <= '1';
        end if;
        RD_NEXT          <= SEND_TRG_RELEASE_A;
        wait_fsm         <= '1';
        rd_fsm_debug_fsm <= x"8";

      when SEND_STATUS =>
        if stop_status = '1' then
          if DEBUG_MODE_EN_IN = '1' then
            RD_NEXT <= WAIT_FOR_LVL1_TRG_A;
          else
            RD_NEXT           <= SEND_TRG_RELEASE_A;
            data_finished_fsm <= '1';
          end if;
        else
          wr_status_fsm <= '1';
        end if;
        readout_fsm      <= '1';
        rd_fsm_debug_fsm <= x"9";

      when SEND_TRG_RELEASE_A =>
        RD_NEXT          <= SEND_TRG_RELEASE_B;
        fifo_nr_rd_fsm   <= 0;
        readout_fsm      <= '1';
        rd_fsm_debug_fsm <= x"A";

      when SEND_TRG_RELEASE_B =>
        RD_NEXT           <= SEND_TRG_RELEASE_C;
        data_finished_fsm <= '1';
        readout_fsm       <= '1';
        rd_fsm_debug_fsm  <= x"B";

      when SEND_TRG_RELEASE_C =>
        RD_NEXT           <= IDLE;
        trg_release_fsm   <= '1';
        wrong_readout_fsm <= '0';
        readout_fsm       <= '1';
        rd_fsm_debug_fsm  <= x"C";

      when others =>
        RD_NEXT          <= IDLE;
        rd_fsm_debug_fsm <= x"F";
    end case;
  end process RD_FSM_PROC;


  --purpose: FSM for writing data to endpoint buffer
  WR_FSM_CLK : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' then
        WR_CURRENT <= IDLE;
      else
        WR_CURRENT   <= WR_NEXT;
        wr_ch_data   <= wr_ch_data_fsm;
        wr_number    <= wr_number_fsm;
        fifo_nr_wr   <= fifo_nr_wr_fsm;
        wr_finished  <= wr_finished_fsm;
        wr_fsm_debug <= wr_fsm_debug_fsm;
        start_write  <= or_all(CH_DATA_VALID_IN);
      end if;
    end if;
  end process WR_FSM_CLK;

  WR_FSM : process (WR_CURRENT, wr_number, fifo_nr_wr, DATA_LIMIT_IN, start_write, CH_DATA_VALID_IN,
                    ch_data_2r)

  begin

    WR_NEXT         <= WR_CURRENT;
    wr_ch_data_fsm  <= '0';
    wr_number_fsm   <= (others => '0');
    fifo_nr_wr_fsm  <= 0;
    wr_finished_fsm <= '0';

    case (WR_CURRENT) is
      when IDLE =>
        if start_write = '1' then
          fifo_nr_wr_fsm <= 0;
          WR_NEXT        <= WR_CH;
        end if;
        wr_fsm_debug_fsm <= x"1";
--
      when WR_CH =>
        if ch_data_2r(fifo_nr_wr)(35 downto 32) /= x"f" then
          if wr_number >= DATA_LIMIT_IN or isNoHit_r = '1' then
            wr_ch_data_fsm <= '0';
          else
            wr_ch_data_fsm <= '1';
          end if;
          wr_number_fsm  <= wr_number + to_unsigned(1, 8);
          fifo_nr_wr_fsm <= fifo_nr_wr;
        --wr_fsm_debug_fsm <= x"4";
        elsif CH_DATA_VALID_IN(fifo_nr_wr) = '1' then
          wr_number_fsm  <= wr_number;
          fifo_nr_wr_fsm <= fifo_nr_wr;
        --wr_fsm_debug_fsm <= x"6";
        elsif fifo_nr_wr = CHANNEL_NUMBER-1 then
          wr_number_fsm   <= (others => '0');
          wr_finished_fsm <= '1';
          WR_NEXT         <= IDLE;
        --wr_fsm_debug_fsm <= x"5";
        else
          wr_number_fsm  <= (others => '0');
          fifo_nr_wr_fsm <= fifo_nr_wr + 1;
          WR_NEXT        <= WAIT_A;
        --wr_fsm_debug_fsm <= x"7";
        end if;
        wr_fsm_debug_fsm <= x"2";
--
      when WAIT_A =>
        WR_NEXT          <= WAIT_B;
        fifo_nr_wr_fsm   <= fifo_nr_wr;
        wr_fsm_debug_fsm <= x"3";
--
      when WAIT_B =>
        WR_NEXT          <= WR_CH;      --WAIT_C;
        fifo_nr_wr_fsm   <= fifo_nr_wr;
        wr_fsm_debug_fsm <= x"3";
--
      when WAIT_C =>
        WR_NEXT          <= WAIT_D;
        fifo_nr_wr_fsm   <= fifo_nr_wr;
        wr_fsm_debug_fsm <= x"3";
--
      when WAIT_D =>
        WR_NEXT          <= WR_CH;
        fifo_nr_wr_fsm   <= fifo_nr_wr;
        wr_fsm_debug_fsm <= x"3";
--      
      when others =>
        WR_NEXT          <= IDLE;
        wr_fsm_debug_fsm <= x"F";

    end case;
  end process WR_FSM;

  fifo_nr_wr_r  <= fifo_nr_wr    when rising_edge(CLK_100);
  fifo_nr_wr_2r <= fifo_nr_wr_r  when rising_edge(CLK_100);
  fifo_nr_wr_3r <= fifo_nr_wr_2r when rising_edge(CLK_100);
  wr_ch_data_r  <= wr_ch_data    when rising_edge(CLK_100);

-------------------------------------------------------------------------------
-- Data out mux
-------------------------------------------------------------------------------
  -- Trigger window selection
  TriggerWindowElimination : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if ch_data_3r(fifo_nr_wr_r)(35 downto 32) = x"1" and ch_data_3r(fifo_nr_wr_r)(31) = '1' then  --DATA word
        if TRG_WIN_EN_IN = '1' then     -- trigger window enabled
          --elsif (TW_pre(10) = '1' and ref_time_coarse(10) = '0') or (TW_post(10) = '0' and ref_time_coarse(10) = '1') then  -- if one of the trigger window edges has an overflow
          --  if (trg_win_l = '0' and trg_win_r = '1') or (trg_win_l = '1' and trg_win_r = '0') then
          --    ch_data_4r <= ch_data_3r(fifo_nr);
          --    data_wr_r  <= '1';
          --  else
          --    ch_data_4r <= (others => '1');
          --    data_wr_r  <= '0';
          --  end if;
          if trg_win_l = '1' and trg_win_r = '1' then  -- if both of the trigger window edges are in the coarse counter boundries
            ch_data_4r <= ch_data_3r(fifo_nr_wr_r)(31 downto 0);
          elsif trg_win_r = '0' then  -- any hit that might come after the trigger window 
            ch_data_4r <= (others => '0');
          --else
          --  ch_data_4r <= (others => '0');
          end if;
        else
          ch_data_4r <= ch_data_3r(fifo_nr_wr_r)(31 downto 0);
        end if;
      else
        ch_data_4r <= ch_data_3r(fifo_nr_wr_r)(31 downto 0);
      end if;
    end if;
  end process TriggerWindowElimination;


  Data_Out_MUX : process (CLK_100)
    variable i : integer := 0;
  begin
    if rising_edge(CLK_100) then
      if wr_header = '1' then
        data_out_r  <= "001" & "0" & TRG_TYPE_IN & TRG_CODE_IN & header_error_bits;
        stop_status <= '0';
      elsif wr_ch_data_r = '1' then
        data_out_r  <= ch_data_4r;
        stop_status <= '0';
      elsif wr_status = '1' then
        case i is
          when 0  => data_out_r <= "010" & "00000" & std_logic_vector(trg_number);
          when 1  => data_out_r <= "010" & "00001" & std_logic_vector(release_number);
          when 2  => data_out_r <= "010" & "00010" & std_logic_vector(valid_tmg_trg_number);
          when 3  => data_out_r <= "010" & "00011" & std_logic_vector(valid_NOtmg_trg_number);
          when 4  => data_out_r <= "010" & "00100" & std_logic_vector(invalid_trg_number);
          when 5  => data_out_r <= "010" & "00101" & std_logic_vector(multi_tmg_trg_number);
          when 6  => data_out_r <= "010" & "00110" & std_logic_vector(spurious_trg_number);
          when 7  => data_out_r <= "010" & "00111" & std_logic_vector(wrong_readout_number);
          when 8  => data_out_r <= "010" & "01000" & std_logic_vector(spike_number);
          when 9  => data_out_r <= "010" & "01001" & std_logic_vector(idle_time);
          when 10 => data_out_r <= "010" & "01010" & std_logic_vector(wait_time);
          when 11 => data_out_r <= "010" & "01011" & std_logic_vector(total_empty_channel);
          when 12 => data_out_r <= "010" & "01100" & std_logic_vector(readout_time);
                     stop_status <= '1';
          when 13 => data_out_r <= "010" & "01101" & std_logic_vector(timeout_number);
                     i := -1;
          when others => null;
        end case;
        i := i+1;
      --elsif wr_trailer = '1' then
      --  data_out_r  <= "011" & "0000000000000" & trailer_error_bits;
      --  data_wr_r   <= '1';
      --  stop_status<= '0';
      else
        data_out_r  <= (others => '1');
        stop_status <= '0';
      end if;
    end if;
  end process Data_Out_MUX;

  wr_info  <= wr_header or wr_status          when rising_edge(CLK_100);
  wr_time  <= wr_ch_data_r and ch_data_4r(31) when rising_edge(CLK_100);
  wr_epoch <= wr_ch_data_r and not data_out_r(31) and data_out_r(30) and data_out_r(29) and ch_data_4r(31);


  DATA_OUT                    <= data_out_r;
  DATA_WRITE_OUT              <= wr_info or wr_time or wr_epoch;  --data_wr_r;
  DATA_FINISHED_OUT           <= data_finished;
  TRG_RELEASE_OUT             <= trg_release;
  trg_statusbit(23)           <= wrong_readout when rising_edge(CLK_100);
  TRG_STATUSBIT_OUT           <= trg_statusbit;
  READOUT_DEBUG(3 downto 0)   <= rd_fsm_debug;
  READOUT_DEBUG(7 downto 4)   <= wr_fsm_debug;
  READOUT_DEBUG(8)            <= data_wr_r;
  READOUT_DEBUG(9)            <= finished;
  READOUT_DEBUG(10)           <= trg_release;
  READOUT_DEBUG(16 downto 11) <= data_out_r(27 downto 22);
  READOUT_DEBUG(31 downto 17) <= (others => '0');

  -- Error, warning bits set in the header
  header_error_bits(15 downto 3) <= (others => '0');
  header_error_bits(0)           <= '0';
--header_error_bits(0) <= lost_hit;  -- if there is at least one lost hit (can be more if the FIFO is full).
  header_error_bits(1)           <= '0';  -- ch_full;
  header_error_bits(2)           <= '0';

  -- Error, warning bits set in the trailer
  trailer_error_bits <= (others => '0');
  -- trailer_error_bits (0) <= wrong_readout;  -- if there is a wrong readout because of a spurious timing trigger

  ch_full <= or_all(CH_FULL_IN);

-------------------------------------------------------------------------------
-- Control bits
-------------------------------------------------------------------------------
  --purpose: Hit Signal Synchroniser
  HitSignalSync : for i in 0 to CHANNEL_NUMBER-2 generate
    sync_q(i*3)   <= HIT_IN(i+1) when rising_edge(CLK_100);
    sync_q(i*3+1) <= sync_q(i*3);       -- when rising_edge(CLK_100);
    sync_q(i*3+2) <= sync_q(i*3+1);     -- when rising_edge(CLK_100);
    hit_in_i(i+1) <= sync_q(i*3+2);
  end generate HitSignalSync;

  any_hit <= or_all(hit_in_i);

  CheckHitStatus : process (CLK_100) is
  begin
    if rising_edge(CLK_100) then        -- rising clock edge
      if LIGHT_MODE_IN = '0' or TRG_WIN_EN_IN = '1' then
        isNoHit   <= '0';
        isNoHit_r <= '0';
      elsif VALID_TIMING_TRG_IN = '1' then
        isNoHit   <= '1';
        isNoHit_r <= isNoHit;
      elsif or_all(hit_in_i) = '1' then
        isNoHit <= '0';
      end if;
    end if;
  end process CheckHitStatus;
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
        trg_number <= (others => '0');
      elsif valid_timing_trg_p = '1' or valid_notiming_trg_p = '1' then
        trg_number <= trg_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Trigger_Number;

-- Internal release number counter
  Statistics_Release_Number : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        release_number <= (others => '0');
      elsif trg_release = '1' then
        release_number <= release_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Release_Number;

-- Internal valid timing trigger number counter
  Statistics_Valid_Timing_Trigger_Number : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        valid_tmg_trg_number <= (others => '0');
      elsif valid_timing_trg_p = '1' then
        valid_tmg_trg_number <= valid_tmg_trg_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Valid_Timing_Trigger_Number;

-- Internal valid NOtiming trigger number counter
  Statistics_Valid_NoTiming_Trigger_Number : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        valid_NOtmg_trg_number <= (others => '0');
      elsif valid_notiming_trg_p = '1' then
        valid_NOtmg_trg_number <= valid_NOtmg_trg_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Valid_NoTiming_Trigger_Number;

-- Internal invalid trigger number counter
  Statistics_Invalid_Trigger_Number : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        invalid_trg_number <= (others => '0');
      elsif invalid_trg_p = '1' then
        invalid_trg_number <= invalid_trg_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Invalid_Trigger_Number;

-- Internal multi timing trigger number counter
  Statistics_Multi_Timing_Trigger_Number : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        multi_tmg_trg_number <= (others => '0');
      elsif multi_tmg_trg_p = '1' then
        multi_tmg_trg_number <= multi_tmg_trg_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Multi_Timing_Trigger_Number;

-- Internal spurious trigger number counter
  Statistics_Spurious_Trigger_Number : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        spurious_trg_number <= (others => '0');
      elsif spurious_trg_p = '1' then
        spurious_trg_number <= spurious_trg_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Spurious_Trigger_Number;

  wrongReadoutUp : entity work.risingEdgeDetect
    port map (
      CLK       => CLK_100,
      SIGNAL_IN => wrong_readout,
      PULSE_OUT => wrong_readout_up);
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

  -- Number of sent data finished
  Statistics_Finished_Number : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_COUNTERS = '1' then
        finished_number <= (others => '0');
      elsif data_finished = '1' then    --finished = '1' then
        finished_number <= finished_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Finished_Number;

  HistoryReadDebug : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if rd_fsm_debug_r /= rd_fsm_debug then
        history_rd_fsm <= history_rd_fsm(27 downto 0) & rd_fsm_debug;
      end if;
      rd_fsm_debug_r <= rd_fsm_debug;
    end if;
  end process HistoryReadDebug;

  HistoryWriteDebug : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if wr_fsm_debug_r /= wr_fsm_debug then
        history_wr_fsm <= history_wr_fsm(27 downto 0) & wr_fsm_debug;
      end if;
      wr_fsm_debug_r <= wr_fsm_debug;
    end if;
  end process HistoryWriteDebug;

-------------------------------------------------------------------------------
-- STATUS REGISTERS BUS
-------------------------------------------------------------------------------
  STATUS_REGISTERS_BUS_OUT(0)(3 downto 0)   <= rd_fsm_debug;
  STATUS_REGISTERS_BUS_OUT(0)(7 downto 4)   <= wr_fsm_debug;
  STATUS_REGISTERS_BUS_OUT(0)(15 downto 8)  <= std_logic_vector(to_unsigned(CHANNEL_NUMBER-1, 8));
  STATUS_REGISTERS_BUS_OUT(0)(16)           <= REFERENCE_TIME when rising_edge(CLK_100);
  STATUS_REGISTERS_BUS_OUT(0)(27 downto 17) <= TDC_VERSION(10 downto 0);
  STATUS_REGISTERS_BUS_OUT(0)(31 downto 28) <= TRG_TYPE_IN    when rising_edge(CLK_100);

  STATUS_REGISTERS_BUS_OUT(1)               <= (others => '0');
  STATUS_REGISTERS_BUS_OUT(2)               <= (others => '0');
  STATUS_REGISTERS_BUS_OUT(3)(10 downto 0)  <= TRG_WIN_PRE_IN;
  STATUS_REGISTERS_BUS_OUT(3)(15 downto 11) <= (others => '0');
  STATUS_REGISTERS_BUS_OUT(3)(26 downto 16) <= TRG_WIN_POST_IN;
  STATUS_REGISTERS_BUS_OUT(3)(30 downto 27) <= (others => '0');
  STATUS_REGISTERS_BUS_OUT(3)(31)           <= TRG_WIN_EN_IN;
  STATUS_REGISTERS_BUS_OUT(4)(23 downto 0)  <= std_logic_vector(trg_number);
  STATUS_REGISTERS_BUS_OUT(5)(23 downto 0)  <= std_logic_vector(valid_tmg_trg_number);
  STATUS_REGISTERS_BUS_OUT(6)(23 downto 0)  <= std_logic_vector(valid_NOtmg_trg_number);
  STATUS_REGISTERS_BUS_OUT(7)(23 downto 0)  <= std_logic_vector(invalid_trg_number);
  STATUS_REGISTERS_BUS_OUT(8)(23 downto 0)  <= std_logic_vector(multi_tmg_trg_number);
  STATUS_REGISTERS_BUS_OUT(9)(23 downto 0)  <= std_logic_vector(spurious_trg_number);
  STATUS_REGISTERS_BUS_OUT(10)(23 downto 0) <= std_logic_vector(wrong_readout_number);
  STATUS_REGISTERS_BUS_OUT(11)(23 downto 0) <= std_logic_vector(spike_number);
  STATUS_REGISTERS_BUS_OUT(12)(23 downto 0) <= std_logic_vector(idle_time);
  STATUS_REGISTERS_BUS_OUT(13)(23 downto 0) <= std_logic_vector(wait_time);
  STATUS_REGISTERS_BUS_OUT(14)(23 downto 0) <= std_logic_vector(total_empty_channel);
  STATUS_REGISTERS_BUS_OUT(15)(23 downto 0) <= std_logic_vector(release_number);
  STATUS_REGISTERS_BUS_OUT(16)(23 downto 0) <= std_logic_vector(readout_time);
  STATUS_REGISTERS_BUS_OUT(17)(23 downto 0) <= std_logic_vector(timeout_number);
  STATUS_REGISTERS_BUS_OUT(18)(23 downto 0) <= std_logic_vector(finished_number);

  STATUS_REGISTERS_BUS_OUT(19) <= history_rd_fsm;
  STATUS_REGISTERS_BUS_OUT(20) <= history_wr_fsm;

  FILL_BUS1 : for i in 4 to 18 generate
    STATUS_REGISTERS_BUS_OUT(i)(31 downto 24) <= (others => '0');
  end generate FILL_BUS1;

-------------------------------------------------------------------------------
-- Registering
-------------------------------------------------------------------------------
  ch_data_r  <= CH_DATA_IN when rising_edge(CLK_100);
  ch_data_2r <= ch_data_r  when rising_edge(CLK_100);
  ch_data_3r <= ch_data_2r when rising_edge(CLK_100);

end behavioral;
