-------------------------------------------------------------------------------
-- Title      : Readout Entity
-- Project    : 
-------------------------------------------------------------------------------
-- File       : Readout.vhd
-- Author     : cugur@gsi.de
-- Created    : 2012-10-25
-- Last update: 2013-03-15
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
    CHANNEL_NUMBER : integer range 2 to 65;
    STATUS_REG_NR  : integer range 0 to 6);

  port (
    CLK_200           : in std_logic;
    RESET_200         : in std_logic;
    CLK_100           : in std_logic;
    RESET_100         : in std_logic;
    RESET_COUNTERS    : in std_logic;
--
    HIT_IN            : in std_logic_vector(CHANNEL_NUMBER-1 downto 1);
    REFERENCE_TIME    : in std_logic;
    TRIGGER_TIME_IN   : in std_logic_vector(38 downto 0);
    TRG_WIN_PRE       : in std_logic_vector(10 downto 0);
    TRG_WIN_POST      : in std_logic_vector(10 downto 0);
-- slow control
    DEBUG_MODE_EN_IN  : in std_logic;
    TRIGGER_WIN_EN_IN : in std_logic;

-- from the channels
    CH_DATA_IN            : in  std_logic_vector_array_32(0 to CHANNEL_NUMBER);
    CH_EMPTY_IN           : in  std_logic_vector(CHANNEL_NUMBER downto 0);
    CH_FULL_IN            : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
    CH_ALMOST_FULL_IN     : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
-- from the endpoint
    TRG_DATA_VALID_IN     : in  std_logic;
    VALID_TIMING_TRG_IN   : in  std_logic;
    VALID_NOTIMING_TRG_IN : in  std_logic;
    INVALID_TRG_IN        : in  std_logic;
    TMGTRG_TIMEOUT_IN     : in  std_logic;
    SPIKE_DETECTED_IN     : in  std_logic;
    MULTI_TMG_TRG_IN      : in  std_logic;
    SPURIOUS_TRG_IN       : in  std_logic;
    TRG_NUMBER_IN         : in  std_logic_vector(15 downto 0);
    TRG_CODE_IN           : in  std_logic_vector(7 downto 0);
    TRG_INFORMATION_IN    : in  std_logic_vector(23 downto 0);
    TRG_TYPE_IN           : in  std_logic_vector(3 downto 0);
-- to the endpoint
    TRG_RELEASE_OUT       : out std_logic;
    TRG_STATUSBIT_OUT     : out std_logic_vector(31 downto 0);
    DATA_OUT              : out std_logic_vector(31 downto 0);
    DATA_WRITE_OUT        : out std_logic;
    DATA_FINISHED_OUT     : out std_logic;
-- to the channels
    READOUT_BUSY_OUT      : out std_logic;
    READ_EN_OUT           : out std_logic_vector(CHANNEL_NUMBER-1 downto 0);
    TRIGGER_WIN_END_OUT   : out std_logic;
--
    SLOW_CONTROL_REG_OUT  : out std_logic_vector(32*2**STATUS_REG_NR-1 downto 0);
    READOUT_DEBUG         : out std_logic_vector(31 downto 0)
    );

end Readout;

architecture behavioral of Readout is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

  -- slow control

  -- trigger window
  signal start_trg_win_cnt       : std_logic;
  signal start_trg_win_cnt_200   : std_logic;
  signal start_trg_win_cnt_200_p : std_logic;
  signal trg_win_post_200        : std_logic_vector(10 downto 0);
  signal trg_win_cnt             : std_logic_vector(11 downto 0);
  signal trg_win_end_200         : std_logic;
  signal trg_win_end_200_p       : std_logic;
  signal trg_win_end_100         : std_logic;
  signal trg_win_end_100_p       : std_logic;
  signal TW_pre                  : std_logic_vector(38 downto 0);
  signal TW_post                 : std_logic_vector(38 downto 0);
  signal trg_win_l               : std_logic;
  signal trg_win_r               : std_logic;
  -- channel signals
  signal ch_data_reg             : std_logic_vector_array_32(0 to CHANNEL_NUMBER);
  signal ch_data_2reg            : std_logic_vector_array_32(0 to CHANNEL_NUMBER);
  --signal ch_data_3reg            : std_logic_vector_array_32(0 to CHANNEL_NUMBER);
  signal ch_empty_reg            : std_logic_vector(CHANNEL_NUMBER downto 0);
  signal ch_empty_2reg           : std_logic_vector(CHANNEL_NUMBER downto 0);
  signal ch_empty_3reg           : std_logic_vector(CHANNEL_NUMBER downto 0);
  signal ch_empty_4reg           : std_logic_vector(CHANNEL_NUMBER downto 0);
  signal ch_hit_time             : std_logic_vector(38 downto 0);
  signal ch_epoch_cntr_i         : std_logic_vector(27 downto 0);
  -- readout fsm
  type FSM is (IDLE, WAIT_FOR_TRG_WIND_END, WAIT_FOR_LVL1_TRG_A, WAIT_FOR_LVL1_TRG_B,
               WAIT_FOR_LVL1_TRG_C, SEND_STATUS, SEND_TRG_RELEASE_A, SEND_TRG_RELEASE_B,
               WAIT_FOR_FIFO_NR_A, WAIT_FOR_FIFO_NR_B, WAIT_FOR_FIFO_NR_C, WR_HEADER_A,
               APPLY_MASK, RD_CHANNEL_A, RD_CHANNEL_B, RD_CHANNEL_C);
  signal FSM_CURRENT, FSM_NEXT   : FSM;
  signal start_trg_win_cnt_fsm   : std_logic;
  signal fsm_debug_fsm           : std_logic_vector(7 downto 0);
  signal updt_index_fsm          : std_logic;
  signal updt_mask_fsm           : std_logic;
  signal rd_en_fsm               : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal data_finished_fsm       : std_logic;
  signal trg_release_fsm         : std_logic;
  signal wr_header_fsm           : std_logic;
  signal wr_ch_data_fsm          : std_logic;
  signal wr_status_fsm           : std_logic;
  signal wrong_readout_fsm       : std_logic;
--  signal wr_trailer_fsm          : std_logic;
  signal idle_fsm                : std_logic;
  signal readout_fsm             : std_logic;
  signal wait_fsm                : std_logic;
  -- readout busy fsm
  type   FSM_RDO_BUSY is (NOT_BUSY, BUSY, WAIT_FOR_SILINCE);
  signal FSM_RDO_BUSY_STATE      : FSM_RDO_BUSY                      := NOT_BUSY;
  signal readout_busy            : std_logic;
  -- fifo number
  type   Std_Logic_8_array is array (0 to 8) of std_logic_vector(3 downto 0);
  signal updt_index              : std_logic;
  signal fifo_nr                 : integer range 0 to CHANNEL_NUMBER := CHANNEL_NUMBER;
  signal fifo_nr_reg             : integer range 0 to CHANNEL_NUMBER := CHANNEL_NUMBER;
  signal fifo_nr_next            : integer range 0 to CHANNEL_NUMBER := CHANNEL_NUMBER;
  signal fifo_nr_hex             : Std_Logic_8_array;
  signal empty_channels          : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal updt_index_reg          : std_logic;
  signal updt_mask               : std_logic;
  signal mask                    : std_logic_vector(71 downto 0);
  -- fifo read
  signal rd_en                   : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  -- data mux
  signal wr_header               : std_logic;
  signal wr_ch_data              : std_logic;
  signal wr_ch_data_reg          : std_logic;
  signal wr_ch_data_2reg         : std_logic;
  signal wr_status               : std_logic;
  signal wr_trailer              : std_logic;
  signal stop_status_i           : std_logic;
  -- to endpoint
  signal data_out_reg            : std_logic_vector(31 downto 0);
  signal data_wr_reg             : std_logic;
  signal data_finished           : std_logic;
  signal data_finished_reg       : std_logic;
  signal trg_release_reg         : std_logic;
  -- statistics
  signal trig_number             : unsigned(23 downto 0);
  signal release_number          : unsigned(23 downto 0);
  signal valid_tmg_trig_number   : unsigned(23 downto 0);
  signal valid_NOtmg_trig_number : unsigned(23 downto 0);
  signal invalid_trig_number     : unsigned(23 downto 0);
  signal multi_tmg_trig_number   : unsigned(23 downto 0);
  signal spurious_trig_number    : unsigned(23 downto 0);
  signal wrong_readout_number    : unsigned(23 downto 0);
  signal spike_number            : unsigned(23 downto 0);
  signal timeout_number          : unsigned(23 downto 0);
  signal total_empty_channel     : unsigned(23 downto 0);
  signal idle_time               : unsigned(23 downto 0);
  signal readout_time            : unsigned(23 downto 0);
  signal wait_time               : unsigned(23 downto 0);
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
  -- debug
  signal header_error_bits       : std_logic_vector(15 downto 0);
  signal trailer_error_bits      : std_logic_vector(15 downto 0);
  signal ch_full_i               : std_logic;
  signal ch_almost_full_i        : std_logic;
  signal fsm_debug               : std_logic_vector(7 downto 0);

begin  -- behavioral
-------------------------------------------------------------------------------
-- Trigger window
-------------------------------------------------------------------------------
-- Trigger window start logic
  StartTrgWinCntSync : bit_sync
    generic map (
      DEPTH => 3)
    port map (
      RESET => RESET_200,
      CLK0  => CLK_100,
      CLK1  => CLK_200,
      D_IN  => start_trg_win_cnt,
      D_OUT => start_trg_win_cnt_200);

  StartTrgWinCntPulse : edge_to_pulse
    port map (
      clock     => CLK_200,
      en_clk    => '1',
      signal_in => start_trg_win_cnt_200,
      pulse     => start_trg_win_cnt_200_p);

-- Trigger window end logic
  Check_Trg_Win_End_Conrollers : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        trg_win_end_200 <= '0';
        trg_win_cnt     <= '1' & trg_win_post_200;
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

  TriggerWinEndSync : bit_sync
    generic map (
      DEPTH => 3)
    port map (
      RESET => RESET_100,
      CLK0  => CLK_200,
      CLK1  => CLK_100,
      D_IN  => trg_win_end_200,
      D_OUT => trg_win_end_100);

  TriggerWinEndPulse100 : edge_to_pulse
    port map (
      clock     => CLK_100,
      en_clk    => '1',
      signal_in => trg_win_end_100,
      pulse     => trg_win_end_100_p);

-- Trigger window borders
  Trg_Win_Calculation : process (CLK_100, RESET_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' then
        TW_pre  <= (others => '0');
        TW_post <= (others => '0');
      else
        TW_pre  <= std_logic_vector(to_unsigned(to_integer(unsigned(TRIGGER_TIME_IN)) - to_integer(unsigned(TRG_WIN_PRE)), 39));
        TW_post <= std_logic_vector(to_unsigned(to_integer(unsigned(TRIGGER_TIME_IN)) + to_integer(unsigned(TRG_WIN_POST)), 39));
      end if;
    end if;
  end process Trg_Win_Calculation;

-- Channel Hit Time Determination
  ChannelEpochCounter : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' then
        ch_epoch_cntr_i <= (others => '0');
      elsif ch_empty_3reg(fifo_nr_reg) = '1' and ch_empty_4reg(fifo_nr_reg) = '0' then
        ch_epoch_cntr_i <= (others => '0');
      elsif ch_data_reg(fifo_nr_reg)(31 downto 29) = "011" then
        ch_epoch_cntr_i <= ch_data_reg(fifo_nr_reg)(27 downto 0);
      end if;
    end if;
  end process ChannelEpochCounter;

  ChannelHitTime : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' then
        ch_hit_time <= (others => '0');
      elsif ch_data_reg(fifo_nr_reg)(31) = '1' then
        ch_hit_time <= ch_epoch_cntr_i & ch_data_reg(fifo_nr_reg)(10 downto 0);
      elsif ch_data_reg(fifo_nr_reg)(31 downto 29) = "011" then
        ch_hit_time <= (others => '0');
      end if;
    end if;
  end process ChannelHitTime;

-- Controls if the data coming from the channel is greater than the trigger window pre-edge
  Check_Trg_Win_Left : process (RESET_100, TW_pre, ch_hit_time)
  begin
    --if rising_edge(CLK_100) then
    if RESET_100 = '1' then
      trg_win_l <= '0';
    elsif to_integer(unsigned(TW_pre)) <= to_integer(unsigned(ch_hit_time)) then
      trg_win_l <= '1';
    else
      trg_win_l <= '0';
    end if;
    --end if;
  end process Check_Trg_Win_Left;

-- Controls if the data coming from the channel is smaller than the trigger window post-edge
  Check_Trg_Win_Right : process (RESET_100, TW_post, ch_hit_time)
  begin
    --if rising_edge(CLK_100) then
    if RESET_100 = '1' then
      trg_win_r <= '0';
    elsif to_integer(unsigned(ch_hit_time)) <= to_integer(unsigned(TW_post)) then
      trg_win_r <= '1';
    else
      trg_win_r <= '0';
    end if;
    --end if;
  end process Check_Trg_Win_Right;

-------------------------------------------------------------------------------
-- Readout
-------------------------------------------------------------------------------
-- Readout fsm
  FSM_CLK : process (CLK_100, RESET_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' then
        FSM_CURRENT       <= IDLE;
        start_trg_win_cnt <= '0';
        updt_index        <= '0';
        updt_mask         <= '0';
        rd_en             <= (others => '0');
        wr_ch_data        <= '0';
        wr_header         <= '0';
        wr_status         <= '0';
        data_finished     <= '0';
        trg_release_reg   <= '0';
        wrong_readout_up  <= '0';
        idle_time_up      <= '0';
        readout_time_up   <= '0';
        wait_time_up      <= '0';
        fsm_debug         <= x"00";
      else
        FSM_CURRENT       <= FSM_NEXT;
        start_trg_win_cnt <= start_trg_win_cnt_fsm;
        updt_index        <= updt_index_fsm;
        updt_mask         <= updt_mask_fsm;
        rd_en             <= rd_en_fsm;
        wr_ch_data        <= wr_ch_data_fsm;
        wr_header         <= wr_header_fsm;
        wr_status         <= wr_status_fsm;
        data_finished     <= data_finished_fsm;
        trg_release_reg   <= trg_release_fsm;
        wrong_readout_up  <= wrong_readout_fsm;
        idle_time_up      <= idle_fsm;
        readout_time_up   <= readout_fsm;
        wait_time_up      <= wait_fsm;
        fsm_debug         <= fsm_debug_fsm;
      end if;
    end if;
  end process FSM_CLK;
  READ_EN_OUT               <= rd_en;

  FSM_PROC : process (FSM_CURRENT, VALID_TIMING_TRG_IN, VALID_NOTIMING_TRG_IN, trg_win_end_100_p, fifo_nr_next,
                      fifo_nr, ch_empty_reg, TRG_DATA_VALID_IN, INVALID_TRG_IN, TMGTRG_TIMEOUT_IN,
                      TRG_TYPE_IN, SPURIOUS_TRG_IN, stop_status_i, DEBUG_MODE_EN_IN)
  begin

    start_trg_win_cnt_fsm <= '0';
    updt_index_fsm        <= '0';
    updt_mask_fsm         <= '0';
    rd_en_fsm             <= (others => '0');
    wr_ch_data_fsm        <= '0';
    wr_header_fsm         <= '0';
    data_finished_fsm     <= '0';
    trg_release_fsm       <= '0';
    wrong_readout_fsm     <= '0';
    idle_fsm              <= '0';
    readout_fsm           <= '0';
    wait_fsm              <= '0';
    wr_status_fsm         <= '0';
    fsm_debug_fsm         <= x"00";
    FSM_NEXT              <= IDLE;

    case (FSM_CURRENT) is
      when IDLE =>
        if VALID_TIMING_TRG_IN = '1' then
          FSM_NEXT              <= WAIT_FOR_TRG_WIND_END;
          start_trg_win_cnt_fsm <= '1';
        elsif VALID_NOTIMING_TRG_IN = '1' then
          if TRG_TYPE_IN = x"E" then
            wr_header_fsm <= '1';
            FSM_NEXT      <= SEND_STATUS;
          else
            data_finished_fsm <= '1';
            FSM_NEXT          <= SEND_TRG_RELEASE_A;
          end if;
        elsif INVALID_TRG_IN = '1' then
          FSM_NEXT          <= SEND_TRG_RELEASE_A;
          data_finished_fsm <= '1';
        else
          FSM_NEXT <= IDLE;
        end if;
        idle_fsm      <= '1';
        fsm_debug_fsm <= x"01";

      when WAIT_FOR_TRG_WIND_END =>
        if trg_win_end_100_p = '1' then
          FSM_NEXT <= WR_HEADER_A;
        else
          FSM_NEXT <= WAIT_FOR_TRG_WIND_END;
        end if;
        wait_fsm      <= '1';
        fsm_debug_fsm <= x"02";
-------------------------------------------------------------------------------
-- Readout process starts
      when WR_HEADER_A =>
        FSM_NEXT      <= WAIT_FOR_FIFO_NR_A;
        wr_header_fsm <= '1';
        readout_fsm   <= '1';
        fsm_debug_fsm <= x"03";

      when WAIT_FOR_FIFO_NR_A =>
        FSM_NEXT       <= WAIT_FOR_FIFO_NR_B;
        updt_index_fsm <= '1';
        wait_fsm       <= '1';
        fsm_debug_fsm  <= x"04";

      when WAIT_FOR_FIFO_NR_B =>
        FSM_NEXT      <= APPLY_MASK;
        wait_fsm      <= '1';
        fsm_debug_fsm <= x"05";

      when APPLY_MASK =>
        if fifo_nr_next = CHANNEL_NUMBER then
          if DEBUG_MODE_EN_IN = '1' then
            FSM_NEXT <= SEND_STATUS;
          else
            FSM_NEXT          <= WAIT_FOR_LVL1_TRG_A;
            data_finished_fsm <= '1';
          end if;
        else
          FSM_NEXT                <= RD_CHANNEL_A;
          rd_en_fsm(fifo_nr_next) <= '1';
          updt_mask_fsm           <= '1';
        end if;
        wait_fsm      <= '1';
        fsm_debug_fsm <= x"06";

      when RD_CHANNEL_A =>
        FSM_NEXT           <= RD_CHANNEL_B;
        rd_en_fsm(fifo_nr) <= '1';
        readout_fsm        <= '1';
        fsm_debug_fsm      <= x"07";
        
      when RD_CHANNEL_B =>
        FSM_NEXT           <= RD_CHANNEL_C;
        rd_en_fsm(fifo_nr) <= '1';
        readout_fsm        <= '1';
        fsm_debug_fsm      <= x"08";
        
      when RD_CHANNEL_C =>
        if ch_empty_reg(fifo_nr) = '1' then
          FSM_NEXT       <= WAIT_FOR_FIFO_NR_B;
          wr_ch_data_fsm <= '0';
          updt_index_fsm <= '1';
        else
          FSM_NEXT           <= RD_CHANNEL_C;
          wr_ch_data_fsm     <= '1';
          rd_en_fsm(fifo_nr) <= '1';
        end if;
        readout_fsm   <= '1';
        fsm_debug_fsm <= x"09";
-------------------------------------------------------------------------------
      when WAIT_FOR_LVL1_TRG_A =>
        if TRG_DATA_VALID_IN = '1' then
          FSM_NEXT <= WAIT_FOR_LVL1_TRG_B;
        elsif TMGTRG_TIMEOUT_IN = '1' then
          FSM_NEXT <= IDLE;
        else
          FSM_NEXT <= WAIT_FOR_LVL1_TRG_A;
        end if;
        wait_fsm      <= '1';
        fsm_debug_fsm <= x"0A";

      when WAIT_FOR_LVL1_TRG_B =>
        FSM_NEXT      <= WAIT_FOR_LVL1_TRG_C;
        wait_fsm      <= '1';
        fsm_debug_fsm <= x"0B";

      when WAIT_FOR_LVL1_TRG_C =>
        if SPURIOUS_TRG_IN = '1' then
          wrong_readout_fsm <= '1';
        end if;
        FSM_NEXT      <= SEND_TRG_RELEASE_A;
        wait_fsm      <= '1';
        fsm_debug_fsm <= x"0C";

      when SEND_STATUS =>
        if stop_status_i = '1' then
          if DEBUG_MODE_EN_IN = '1' then
            FSM_NEXT <= WAIT_FOR_LVL1_TRG_A;
          else
            FSM_NEXT <= SEND_TRG_RELEASE_A;
          end if;
          data_finished_fsm <= '1';
        else
          FSM_NEXT      <= SEND_STATUS;
          wr_status_fsm <= '1';
        end if;
        fsm_debug_fsm <= x"0D";

      when SEND_TRG_RELEASE_A =>
        FSM_NEXT        <= SEND_TRG_RELEASE_B;
        trg_release_fsm <= '1';
        fsm_debug_fsm   <= x"0E";

      when SEND_TRG_RELEASE_B =>
        FSM_NEXT      <= IDLE;
        fsm_debug_fsm <= x"0F";

      when others =>
        FSM_NEXT      <= IDLE;
        fsm_debug_fsm <= x"FF";
    end case;
  end process FSM_PROC;

-- Readout busy fsm
  FSM_READOUT_BUSY : process (FSM_RDO_BUSY_STATE, trg_win_end_200_p, data_finished_reg, HIT_IN)
  begin
    FSM_RDO_BUSY_STATE <= NOT_BUSY;
    readout_busy       <= '0';

    case FSM_RDO_BUSY_STATE is
      when NOT_BUSY =>
        if trg_win_end_200_p = '1' then
          FSM_RDO_BUSY_STATE <= BUSY;
        else
          FSM_RDO_BUSY_STATE <= NOT_BUSY;
        end if;
        readout_busy <= '0';

      when BUSY =>
        if data_finished_reg = '1' then
          FSM_RDO_BUSY_STATE <= WAIT_FOR_SILINCE;  -- waits until the hit input is zero
        else
          FSM_RDO_BUSY_STATE <= BUSY;
        end if;
        readout_busy <= '1';

      when WAIT_FOR_SILINCE =>
        if or_all(HIT_IN) = '0' then
          FSM_RDO_BUSY_STATE <= NOT_BUSY;
        else
          FSM_RDO_BUSY_STATE <= WAIT_FOR_SILINCE;
        end if;
        readout_busy <= '1';
        
      when others =>
        FSM_RDO_BUSY_STATE <= NOT_BUSY;
    end case;
  end process FSM_READOUT_BUSY;

  READOUT_BUSY_OUT <= readout_busy;

-- Fifo number determination
  CREAT_MASK : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' then
        mask           <= (others => '1');
        empty_channels <= (others => '1');
      elsif trg_win_end_100_p = '1' then
        mask(CHANNEL_NUMBER-1 downto 0)           <= CH_EMPTY_IN(CHANNEL_NUMBER-1 downto 0);
        empty_channels(CHANNEL_NUMBER-1 downto 0) <= CH_EMPTY_IN(CHANNEL_NUMBER-1 downto 0);
      elsif updt_mask = '1' then
        mask(fifo_nr) <= '1';
      end if;
    end if;
  end process CREAT_MASK;

  GEN : for i in 0 to 8 generate
    ROM : ROM_FIFO
      port map (
        Address    => mask(8*(i+1)-1 downto 8*i),
        OutClock   => CLK_100,
        OutClockEn => '1',
        Reset      => RESET_100,
        Q          => fifo_nr_hex(i));
  end generate GEN;

  CON_FIFO_NR_HEX_TO_INT : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' then
        fifo_nr_next <= CHANNEL_NUMBER;
      elsif fifo_nr_hex(0)(3) /= '1' then
        fifo_nr_next <= to_integer("00000" & unsigned(fifo_nr_hex(0)(2 downto 0)));
      elsif fifo_nr_hex(1)(3) /= '1' then
        fifo_nr_next <= to_integer("00001" & unsigned(fifo_nr_hex(1)(2 downto 0)));
      elsif fifo_nr_hex(2)(3) /= '1' then
        fifo_nr_next <= to_integer("00010" & unsigned(fifo_nr_hex(2)(2 downto 0)));
      elsif fifo_nr_hex(3)(3) /= '1' then
        fifo_nr_next <= to_integer("00011" & unsigned(fifo_nr_hex(3)(2 downto 0)));
      elsif fifo_nr_hex(4)(3) /= '1' then
        fifo_nr_next <= to_integer("00100" & unsigned(fifo_nr_hex(4)(2 downto 0)));
      elsif fifo_nr_hex(5)(3) /= '1' then
        fifo_nr_next <= to_integer("00101" & unsigned(fifo_nr_hex(5)(2 downto 0)));
      elsif fifo_nr_hex(6)(3) /= '1' then
        fifo_nr_next <= to_integer("00110" & unsigned(fifo_nr_hex(6)(2 downto 0)));
      elsif fifo_nr_hex(7)(3) /= '1' then
        fifo_nr_next <= to_integer("00111" & unsigned(fifo_nr_hex(7)(2 downto 0)));
      elsif fifo_nr_hex(8)(3) /= '1' then
        fifo_nr_next <= to_integer("01000" & unsigned(fifo_nr_hex(8)(2 downto 0)));
      else
        fifo_nr_next <= CHANNEL_NUMBER;
      end if;
    end if;
  end process CON_FIFO_NR_HEX_TO_INT;

  UPDATE_INDEX_NR : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' then
        fifo_nr <= CHANNEL_NUMBER;
      elsif updt_index_reg = '1' then
        fifo_nr <= fifo_nr_next;
      end if;
    end if;
  end process UPDATE_INDEX_NR;

-------------------------------------------------------------------------------
-- Data out mux
-------------------------------------------------------------------------------
  Data_Out_MUX : process (CLK_100, RESET_100)
    variable i : integer := 0;
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' then
        data_out_reg  <= (others => '1');
        data_wr_reg   <= '0';
        stop_status_i <= '0';
      elsif wr_header = '1' then
        data_out_reg  <= "001" & "00000" & TRG_CODE_IN & header_error_bits;
        data_wr_reg   <= '1';
        stop_status_i <= '0';
      elsif wr_ch_data_2reg = '1' then
        if TRIGGER_WIN_EN_IN = '1' then  -- if the trigger window is enabled
          if ch_data_2reg(fifo_nr)(31 downto 29) = "011" then
            data_out_reg <= ch_data_2reg(fifo_nr);
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
            if (trg_win_l = '1' and trg_win_r = '1') then
              data_out_reg <= ch_data_2reg(fifo_nr);
              data_wr_reg  <= '1';
            else
              data_out_reg <= (others => '1');
              data_wr_reg  <= '0';
            end if;
          end if;
          stop_status_i <= '0';
        elsif TRIGGER_WIN_EN_IN = '0' then
          data_out_reg  <= ch_data_2reg(fifo_nr);
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
  DATA_FINISHED_OUT           <= data_finished_reg;
  TRG_RELEASE_OUT             <= trg_release_reg;
  TRG_STATUSBIT_OUT           <= (others => '0');
  READOUT_DEBUG(7 downto 0)   <= fsm_debug;
  READOUT_DEBUG(8)            <= data_wr_reg;
  READOUT_DEBUG(9)            <= data_finished_reg;
  READOUT_DEBUG(10)           <= trg_release_reg;
  READOUT_DEBUG(16 downto 11) <= data_out_reg(27 downto 22);
  READOUT_DEBUG(31 downto 17) <= (others => '0');

  -- Error, warning bits set in the header
  header_error_bits(15 downto 3) <= (others => '0');
  header_error_bits(0)           <= '0';
--header_error_bits(0) <= lost_hit_i;  -- if there is at least one lost hit (can be more if the FIFO is full).
  header_error_bits(1)           <= ch_full_i;  -- if the channel FIFO is full.
  header_error_bits(2)           <= ch_almost_full_i;  -- if the channel FIFO is almost full.

  -- Error, warning bits set in the trailer
  trailer_error_bits <= (others => '0');
  -- trailer_error_bits (0) <= wrong_readout_i;  -- if there is a wrong readout because of a spurious timing trigger.

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
  Statistics_Trigger_Number : process (CLK_100, RESET_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' or RESET_COUNTERS = '1' then
        trig_number <= (others => '0');
      elsif valid_timing_trg_p = '1' or valid_notiming_trg_p = '1' then
        trig_number <= trig_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Trigger_Number;

-- Internal release number counter
  Statistics_Release_Number : process (CLK_100, RESET_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' or RESET_COUNTERS = '1' then
        release_number <= (others => '0');
      elsif trg_release_reg = '1' then
        release_number <= release_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Release_Number;

-- Internal valid timing trigger number counter
  Statistics_Valid_Timing_Trigger_Number : process (CLK_100, RESET_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' or RESET_COUNTERS = '1' then
        valid_tmg_trig_number <= (others => '0');
      elsif valid_timing_trg_p = '1' then
        valid_tmg_trig_number <= valid_tmg_trig_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Valid_Timing_Trigger_Number;

-- Internal valid NOtiming trigger number counter
  Statistics_Valid_NoTiming_Trigger_Number : process (CLK_100, RESET_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' or RESET_COUNTERS = '1' then
        valid_NOtmg_trig_number <= (others => '0');
      elsif valid_notiming_trg_p = '1' then
        valid_NOtmg_trig_number <= valid_NOtmg_trig_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Valid_NoTiming_Trigger_Number;

-- Internal invalid trigger number counter
  Statistics_Invalid_Trigger_Number : process (CLK_100, RESET_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' or RESET_COUNTERS = '1' then
        invalid_trig_number <= (others => '0');
      elsif invalid_trg_p = '1' then
        invalid_trig_number <= invalid_trig_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Invalid_Trigger_Number;

-- Internal multi timing trigger number counter
  Statistics_Multi_Timing_Trigger_Number : process (CLK_100, RESET_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' or RESET_COUNTERS = '1' then
        multi_tmg_trig_number <= (others => '0');
      elsif multi_tmg_trg_p = '1' then
        multi_tmg_trig_number <= multi_tmg_trig_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Multi_Timing_Trigger_Number;

-- Internal spurious trigger number counter
  Statistics_Spurious_Trigger_Number : process (CLK_100, RESET_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' or RESET_COUNTERS = '1' then
        spurious_trig_number <= (others => '0');
      elsif spurious_trg_p = '1' then
        spurious_trig_number <= spurious_trig_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Spurious_Trigger_Number;

-- Number of wrong readout becasue of spurious trigger
  Statistics_Wrong_Readout_Number : process (CLK_100, RESET_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' or RESET_COUNTERS = '1' then
        wrong_readout_number <= (others => '0');
      elsif wrong_readout_up = '1' then
        wrong_readout_number <= wrong_readout_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Wrong_Readout_Number;

-- Internal spike number counter
  Statistics_Spike_Number : process (CLK_100, RESET_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' or RESET_COUNTERS = '1' then
        spike_number <= (others => '0');
      elsif spike_detected_p = '1' then
        spike_number <= spike_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Spike_Number;

-- Internal timeout number counter
  Statistics_Timeout_Number : process (CLK_100, RESET_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' or RESET_COUNTERS = '1' then
        timeout_number <= (others => '0');
      elsif timeout_detected_p = '1' then
        timeout_number <= timeout_number + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Timeout_Number;

-- IDLE time of the TDC readout
  Statistics_Idle_Time : process (CLK_100, RESET_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' or RESET_COUNTERS = '1' then
        idle_time <= (others => '0');
      elsif idle_time_up = '1' then
        idle_time <= idle_time + to_unsigned(1, 1);
      end if;
    end if;
  end process Statistics_Idle_Time;

-- Readout and Wait time of the TDC readout
  Statistics_Readout_Wait_Time : process (CLK_100, RESET_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' or RESET_COUNTERS = '1' then
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
  Statistics_Empty_Channel_Number : process (CLK_100, RESET_100)
    variable i : integer := CHANNEL_NUMBER;
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' or RESET_COUNTERS = '1' then
        total_empty_channel <= (others => '0');
        i                   := CHANNEL_NUMBER;
      elsif trg_win_end_100_p = '1' then
        i := 0;
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

-------------------------------------------------------------------------------
-- STATUS REGISTERS
-------------------------------------------------------------------------------
-- Register 0x80
  SLOW_CONTROL_REG_OUT(7 downto 0)  <= fsm_debug;
  SLOW_CONTROL_REG_OUT(15 downto 8) <= std_logic_vector(to_unsigned(CHANNEL_NUMBER-1, 8));
  SLOW_CONTROL_REG_OUT(16)          <= REFERENCE_TIME when rising_edge(CLK_100);

-- Register 0x81 & 0x82
  SLOW_CONTROL_REG_OUT(1*32+CHANNEL_NUMBER-2 downto 1*32+0) <= ch_empty_2reg(CHANNEL_NUMBER-1 downto 1);

-- Register 0x83
  SLOW_CONTROL_REG_OUT(3*32+31 downto 3*32+0) <= "00000" & TRG_WIN_POST & "00000" & TRG_WIN_PRE;

-- Register 0x84
  SLOW_CONTROL_REG_OUT(4*32+23 downto 4*32+0) <= std_logic_vector(trig_number);

-- Register 0x85
  SLOW_CONTROL_REG_OUT(5*32+23 downto 5*32+0) <= std_logic_vector(valid_tmg_trig_number);

-- Register 0x86
  SLOW_CONTROL_REG_OUT(6*32+23 downto 6*32+0) <= std_logic_vector(valid_NOtmg_trig_number);

-- Register 0x87
  SLOW_CONTROL_REG_OUT(7*32+23 downto 7*32+0) <= std_logic_vector(invalid_trig_number);

-- Register 0x88
  SLOW_CONTROL_REG_OUT(8*32+23 downto 8*32+0) <= std_logic_vector(multi_tmg_trig_number);

-- Register 0x89
  SLOW_CONTROL_REG_OUT(9*32+23 downto 9*32+0) <= std_logic_vector(spurious_trig_number);

-- Register 0x8a
  SLOW_CONTROL_REG_OUT(10*32+23 downto 10*32+0) <= std_logic_vector(wrong_readout_number);

-- Register 0x8b
  SLOW_CONTROL_REG_OUT(11*32+23 downto 11*32+0) <= std_logic_vector(spike_number);

-- Register 0x8c
  SLOW_CONTROL_REG_OUT(12*32+23 downto 12*32+0) <= std_logic_vector(idle_time);

-- Register 0x8d
  SLOW_CONTROL_REG_OUT(13*32+23 downto 13*32+0) <= std_logic_vector(wait_time);

-- Register 0x8e
  SLOW_CONTROL_REG_OUT(14*32+23 downto 14*32+0) <= std_logic_vector(total_empty_channel);

-- Register 0x8f
  SLOW_CONTROL_REG_OUT(15*32+23 downto 15*32+0) <= std_logic_vector(release_number);

-- Register 0x90
  SLOW_CONTROL_REG_OUT(16*32+23 downto 16*32+0) <= std_logic_vector(readout_time);

-- Register 0x91
  SLOW_CONTROL_REG_OUT(17*32+23 downto 17*32+0) <= std_logic_vector(timeout_number);

---- Register 0x93
--  SLOW_CONTROL_REG_OUT(19*32+7 downto 19*32+0) <= scaler_number_i;

---- Register 0x94
--  SLOW_CONTROL_REG_OUT(20*32+23 downto 20*32+0) <= ch_hit_detect_number(1);

---- Register 0x95
--  SLOW_CONTROL_REG_OUT(21*32+23 downto 21*32+0) <= ch_hit_detect_number(2);

---- Register 0x96
--SLOW_CONTROL_REG_OUT(22*32+23 downto 22*32+0) <= ch_hit_detect_number(3);

---- Register 0x97
--SLOW_CONTROL_REG_OUT(23*32+23 downto 23*32+0) <= ch_hit_detect_number(4);

---- Register 0x98
--  SLOW_CONTROL_REG_OUT(24*32+23 downto 24*32+0) <= ch_hit_detect_number(5);

---- Register 0x99
--  SLOW_CONTROL_REG_OUT(25*32+23 downto 25*32+0) <= ch_hit_detect_number(6);

---- Register 0x9a
--  SLOW_CONTROL_REG_OUT(26*32+23 downto 26*32+0) <= ch_hit_detect_number(7);

---- Register 0x9f
--  SLOW_CONTROL_REG_OUT(27*32+23 downto 27*32+0) <= ch_hit_detect_number(8);


-------------------------------------------------------------------------------
-- Registering
-------------------------------------------------------------------------------
-- 100 MHz
  updt_index_reg    <= updt_index     when rising_edge(CLK_100);
  wr_ch_data_reg    <= wr_ch_data     when rising_edge(CLK_100);
  wr_ch_data_2reg   <= wr_ch_data_reg when rising_edge(CLK_100);
  data_finished_reg <= data_finished  when rising_edge(CLK_100);
  fifo_nr_reg       <= fifo_nr        when rising_edge(CLK_100);
  ch_data_reg       <= CH_DATA_IN     when rising_edge(CLK_100);
  ch_data_2reg      <= ch_data_reg    when rising_edge(CLK_100);
--  ch_data_3reg      <= ch_data_2reg   when rising_edge(CLK_100);
  ch_empty_reg      <= CH_EMPTY_IN    when rising_edge(CLK_100);
  ch_empty_2reg     <= ch_empty_reg   when rising_edge(CLK_100);
  ch_empty_3reg     <= ch_empty_2reg  when rising_edge(CLK_100);
  ch_empty_4reg     <= ch_empty_3reg  when rising_edge(CLK_100);

-- 200 MHz
  trg_win_post_200 <= TRG_WIN_POST when rising_edge(CLK_200);

end behavioral;
