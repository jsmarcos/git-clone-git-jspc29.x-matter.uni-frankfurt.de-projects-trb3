-------------------------------------------------------------------------------
-- Title      : Channel 200 MHz Part
-- Project    : 
-------------------------------------------------------------------------------
-- File       : Channel_200.vhd
-- Author     : c.ugur@gsi.de
-- Created    : 2012-08-28
-- Last update: 2014-01-22
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

entity Channel_200 is

  generic (
    CHANNEL_ID : integer range 0 to 64;
    SIMULATION : integer range 0 to 1;
    REFERENCE  : integer range 0 to 1);
  port (
    CLK_200              : in  std_logic;  -- 200 MHz clk
    RESET_200            : in  std_logic;  -- reset sync with 200Mhz clk
    CLK_100              : in  std_logic;  -- 100 MHz clk
    RESET_100            : in  std_logic;  -- reset sync with 100Mhz clk
--
    HIT_IN               : in  std_logic;  -- hit in
    TRIGGER_WIN_END_TDC  : in  std_logic;  -- trigger window end strobe
    TRIGGER_WIN_END_RDO  : in  std_logic;  -- trigger window end strobe
    EPOCH_COUNTER_IN     : in  std_logic_vector(27 downto 0);  -- system coarse counter
    COARSE_COUNTER_IN    : in  std_logic_vector(10 downto 0);
    READ_EN_IN           : in  std_logic;  -- read en signal
    FIFO_DATA_OUT        : out std_logic_vector(35 downto 0);  -- fifo data out
    FIFO_DATA_VALID_OUT  : out std_logic;  -- fifo data valid signal
    FIFO_EMPTY_OUT       : out std_logic;  -- fifo empty signal
    FIFO_FULL_OUT        : out std_logic;  -- fifo full signal
    FIFO_ALMOST_FULL_OUT : out std_logic;
--
    VALID_TIMING_TRG_IN  : in  std_logic;
    SPIKE_DETECTED_IN    : in  std_logic;
    MULTI_TMG_TRG_IN     : in  std_logic;
--
    EPOCH_WRITE_EN_IN    : in  std_logic;
    ENCODER_START_OUT    : out std_logic;
    ENCODER_FINISHED_OUT : out std_logic;
    FIFO_WRITE_OUT       : out std_logic;
    CHANNEL_200_DEBUG    : out std_logic_vector(31 downto 0)
    );

end Channel_200;

architecture Channel_200 of Channel_200 is

  -- carry chain
  signal data_a_i      : std_logic_vector(303 downto 0);
  signal data_b_i      : std_logic_vector(303 downto 0);
  signal result_i      : std_logic_vector(303 downto 0);
  signal ff_array_en_i : std_logic;

  -- hit detection
  signal result_2_reg    : std_logic := '0';
  signal hit_detect_i    : std_logic := '0';
  signal hit_detect_reg  : std_logic;
  signal hit_detect_2reg : std_logic;

  -- time stamp
  signal time_stamp_i    : std_logic_vector(10 downto 0);
  signal coarse_cntr_reg : std_logic_vector(10 downto 0);

  -- encoder
  signal encoder_start_i    : std_logic;
  signal encoder_finished_i : std_logic;
  signal encoder_data_out_i : std_logic_vector(9 downto 0);
  signal encoder_debug_i    : std_logic_vector(31 downto 0);

  -- epoch counter
  signal epoch_cntr         : std_logic_vector(27 downto 0) := (others => '0');
  signal epoch_cntr_reg     : std_logic_vector(27 downto 0) := (others => '0');
  signal epoch_cntr_updated : std_logic                     := '0';
  signal epoch_capture_time : std_logic_vector(10 downto 0);
  signal epoch_value        : std_logic_vector(35 downto 0);

  -- fifo
  signal fifo_data_out_i        : std_logic_vector(35 downto 0);
  signal fifo_data_in_i         : std_logic_vector(35 downto 0);
  signal fifo_empty_i           : std_logic;
  signal fifo_full_i            : std_logic;
  signal fifo_almost_full_sync  : std_logic;
  signal fifo_almost_full_sync1 : std_logic;
  signal fifo_almost_full_sync2 : std_logic;
  signal fifo_almost_full_i     : std_logic := '0';
  signal fifo_almost_full_flag  : std_logic := '0';
  signal fifo_wr_en_i           : std_logic;
  signal fifo_rd_en_i           : std_logic;
  signal fifo_rd_data_i         : std_logic;
  signal fifo_data_i            : std_logic_vector(35 downto 0);
  signal fifo_data_valid_i      : std_logic;

  -- fsm
  type FSM_WR is (WRITE_EPOCH, WRITE_DATA, WRITE_STOP_A, WRITE_STOP_B, WRITE_STOP_C, WRITE_STOP_D, WAIT_FOR_HIT,
                  WAIT_FOR_VALIDITY, EXCEPTION);
  signal FSM_WR_CURRENT            : FSM_WR    := WRITE_EPOCH;
  signal FSM_WR_NEXT               : FSM_WR;
  signal write_epoch_fsm           : std_logic;
  signal write_epoch_i             : std_logic := '0';
  signal write_data_fsm            : std_logic;
  signal write_data_i              : std_logic := '0';
  signal write_stop_a_fsm          : std_logic;
  signal write_stop_a_i            : std_logic := '0';
  signal write_stop_b_fsm          : std_logic;
  signal write_stop_b_i            : std_logic := '0';
  signal write_data_flag_fsm       : std_logic;
  signal write_data_flag_i         : std_logic := '0';
  signal trig_win_end_tdc_flag_fsm : std_logic;
  signal trig_win_end_tdc_flag_i   : std_logic := '0';
  signal fsm_wr_debug_fsm          : std_logic_vector(3 downto 0);
  signal fsm_wr_debug_i            : std_logic_vector(3 downto 0);

  type   FSM_RD is (IDLE, FLUSH_A, FLUSH_B, FLUSH_C, FLUSH_D, READOUT_EPOCH, READOUT_DATA_A, READOUT_DATA_B, READOUT_DATA_C);
  signal FSM_RD_STATE               : FSM_RD;
  signal trigger_win_end_rdo_flag_i : std_logic := '0';
  signal fsm_rd_debug_i             : std_logic_vector(3 downto 0);

  -----------------------------------------------------------------------------
  -- debug
  signal data_cnt_total  : integer range 0 to 2147483647 := 0;
  signal data_cnt_event  : integer range 0 to 255        := 0;
  signal epoch_cnt_total : integer range 0 to 65535      := 0;
  signal epoch_cnt_event : integer range 0 to 127        := 0;
  -----------------------------------------------------------------------------

  attribute syn_keep                  : boolean;
  attribute syn_keep of ff_array_en_i : signal is true;

begin  -- Channel_200

  SimAdderYes : if SIMULATION = c_YES generate
    --purpose: Tapped Delay Line 304 (Carry Chain) with wave launcher (21) double transition
    FC : Adder_304
      port map (
        CLK    => CLK_200,
        RESET  => RESET_200,
        DataA  => data_a_i,
        DataB  => data_b_i,
        ClkEn  => ff_array_en_i,
        Result => result_i);
    data_a_i <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000000FFFFFFF"&x"7FFFFFF";
    data_b_i <= x"000000000000000000000000000000000000000000000000000000000000000000000"& not(HIT_IN) & x"000000"&"00" & HIT_IN;
  end generate SimAdderYes;
  SimAdderNo : if SIMULATION = c_NO generate
    --purpose: Tapped Delay Line 304 (Carry Chain) with wave launcher (21) double transition
    FC : Adder_304
      port map (
        CLK    => CLK_200,
        RESET  => RESET_200,
        DataA  => data_a_i,
        DataB  => data_b_i,
        ClkEn  => ff_array_en_i,
        Result => result_i);
    data_a_i <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"&x"7FFFFFF";
    data_b_i <= x"000000000000000000000000000000000000000000000000000000000000000000000"& not(HIT_IN) & x"000000"&"00" & HIT_IN;
  end generate SimAdderNo;
  ff_array_en_i <= not(hit_detect_i or hit_detect_reg or hit_detect_2reg);

  result_2_reg      <= result_i(2)       when rising_edge(CLK_200);
  hit_detect_i      <= (not result_2_reg) and result_i(2);  -- detects the hit by
                                                            -- comparing the
                                        -- previous state of the
                                        -- hit detection bit
  hit_detect_reg    <= hit_detect_i      when rising_edge(CLK_200);
  hit_detect_2reg   <= hit_detect_reg    when rising_edge(CLK_200);
  coarse_cntr_reg   <= COARSE_COUNTER_IN when rising_edge(CLK_200);
  encoder_start_i   <= hit_detect_reg;
  ENCODER_START_OUT <= encoder_start_i;

  TimeStampCapture : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if hit_detect_reg = '1' then
        time_stamp_i <= coarse_cntr_reg;
      end if;
    end if;
  end process TimeStampCapture;

  epoch_capture_time <= "00000001000";

  isChannelEpoch : if REFERENCE = c_NO generate
    EpochCounterCapture : process (CLK_200)
    begin
      if rising_edge(CLK_200) then
        if coarse_cntr_reg = epoch_capture_time then
          epoch_cntr         <= EPOCH_COUNTER_IN;
          epoch_cntr_updated <= '1';
        elsif write_epoch_i = '1' then
          epoch_cntr_updated <= '0';
        end if;
      end if;
    end process EpochCounterCapture;
  end generate isChannelEpoch;

  isReferenceEpoch: if REFERENCE = c_YES generate
    EpochCounterCapture : process (CLK_200)
    begin
      if rising_edge(CLK_200) then
        if hit_detect_reg = '1' then
          epoch_cntr     <= EPOCH_COUNTER_IN;
          epoch_cntr_reg <= epoch_cntr;
        end if;
        if hit_detect_2reg = '1' and epoch_cntr /= epoch_cntr_reg then
          epoch_cntr_updated <= '1';
        elsif write_epoch_i = '1' then
          epoch_cntr_updated <= '0';
        end if;
      end if;
    end process EpochCounterCapture;
  end generate isReferenceEpoch;
  
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

  FIFO : FIFO_DC_36x128_OutReg
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

  fifo_almost_full_sync  <= fifo_almost_full_i                      when rising_edge(CLK_100);
  fifo_almost_full_sync1 <= fifo_almost_full_sync                   when rising_edge(CLK_100);
  fifo_almost_full_sync2 <= fifo_almost_full_sync1                  when rising_edge(CLK_100);
  fifo_rd_en_i           <= fifo_rd_data_i or fifo_almost_full_sync when rising_edge(CLK_100);

  FifoAlmostmptyFlag : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if FSM_RD_STATE = READOUT_DATA_C then
        fifo_almost_full_flag <= '0';
      elsif fifo_almost_full_sync = '1' then
        fifo_almost_full_flag <= '1';
      end if;
    end if;
  end process FifoAlmostmptyFlag;


-------------------------------------------------------------------------------
-- Write Stage
-------------------------------------------------------------------------------
  -- Readout fsm
  FSM_CLK : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      FSM_WR_CURRENT    <= FSM_WR_NEXT;
      write_epoch_i     <= write_epoch_fsm;
      write_data_i      <= write_data_fsm;
      write_stop_a_i    <= write_stop_a_fsm;
      write_stop_b_i    <= write_stop_b_fsm;
      write_data_flag_i <= write_data_flag_fsm;
--      trig_win_end_tdc_flag_i <= trig_win_end_tdc_flag_fsm;
      fsm_wr_debug_i    <= fsm_wr_debug_fsm;
    end if;
  end process FSM_CLK;

  isChannel : if REFERENCE = c_NO generate  -- if it is a normal channel
    FSM_PROC : process (FSM_WR_CURRENT, encoder_finished_i, epoch_cntr_updated, TRIGGER_WIN_END_TDC,
                        trig_win_end_tdc_flag_i)
    begin

      FSM_WR_NEXT         <= WRITE_EPOCH;
      write_epoch_fsm     <= '0';
      write_data_fsm      <= '0';
      write_stop_a_fsm    <= '0';
      write_stop_b_fsm    <= '0';
      write_data_flag_fsm <= write_data_flag_i;
--      trig_win_end_tdc_flag_fsm <= trig_win_end_tdc_flag_i;
      fsm_wr_debug_fsm    <= x"0";

      case (FSM_WR_CURRENT) is
        when WRITE_EPOCH =>
          if encoder_finished_i = '1' or write_data_flag_i = '1' then
            write_epoch_fsm     <= '1';
            write_data_flag_fsm <= '0';
            FSM_WR_NEXT         <= EXCEPTION;
          elsif trig_win_end_tdc_flag_i = '1' or TRIGGER_WIN_END_TDC = '1' then
            FSM_WR_NEXT <= WRITE_STOP_A;
          else
            write_epoch_fsm <= '0';
            FSM_WR_NEXT     <= WRITE_EPOCH;
          end if;
          --if TRIGGER_WIN_END_TDC = '1' then
          --  trig_win_end_tdc_flag_fsm <= '1';
          --end if;
          fsm_wr_debug_fsm <= x"1";
--
        when WRITE_DATA =>
          if epoch_cntr_updated = '1' then
            write_epoch_fsm <= '1';
            FSM_WR_NEXT     <= EXCEPTION;
          else
            write_data_fsm <= '1';
            if trig_win_end_tdc_flag_i = '1' or TRIGGER_WIN_END_TDC = '1' then
              FSM_WR_NEXT <= WRITE_STOP_A;
            else
              FSM_WR_NEXT <= WAIT_FOR_HIT;
            end if;
          end if;
          --if TRIGGER_WIN_END_TDC = '1' then
          --  trig_win_end_tdc_flag_fsm <= '1';
          --end if;
          fsm_wr_debug_fsm <= x"2";
--
        when EXCEPTION =>
          write_data_fsm <= '1';
          if trig_win_end_tdc_flag_i = '1' or TRIGGER_WIN_END_TDC = '1' then
            FSM_WR_NEXT <= WRITE_STOP_A;
          else
            FSM_WR_NEXT <= WAIT_FOR_HIT;
          end if;
          fsm_wr_debug_fsm <= x"3";
--
        when WAIT_FOR_HIT =>
          if epoch_cntr_updated = '1' and encoder_finished_i = '0' then
            FSM_WR_NEXT <= WRITE_EPOCH;
          elsif epoch_cntr_updated = '0' and encoder_finished_i = '1' then
            FSM_WR_NEXT <= WRITE_DATA;
          elsif epoch_cntr_updated = '1' and encoder_finished_i = '1' then
            write_epoch_fsm <= '1';
            FSM_WR_NEXT     <= WRITE_DATA;
          elsif trig_win_end_tdc_flag_i = '1' or TRIGGER_WIN_END_TDC = '1' then
            FSM_WR_NEXT <= WRITE_STOP_A;
          else
            FSM_WR_NEXT <= WAIT_FOR_HIT;
          end if;
          --if TRIGGER_WIN_END_TDC = '1' then
          --  trig_win_end_tdc_flag_fsm <= '1';
          --end if;
          fsm_wr_debug_fsm <= x"4";
--
        when WRITE_STOP_A =>
          write_stop_a_fsm <= '1';
          FSM_WR_NEXT      <= WRITE_STOP_B;
          if encoder_finished_i = '1' then
            write_data_flag_fsm <= '1';
          end if;
          fsm_wr_debug_fsm <= x"5";
--
        when WRITE_STOP_B =>
          write_stop_a_fsm <= '1';
          FSM_WR_NEXT      <= WRITE_STOP_C;
          if encoder_finished_i = '1' then
            write_data_flag_fsm <= '1';
          end if;
          fsm_wr_debug_fsm <= x"5";
--
        when WRITE_STOP_C =>
          write_stop_b_fsm <= '1';
          FSM_WR_NEXT      <= WRITE_STOP_D;
          if encoder_finished_i = '1' then
            write_data_flag_fsm <= '1';
          end if;
          fsm_wr_debug_fsm <= x"5";
--
        when WRITE_STOP_D =>
          write_stop_b_fsm <= '1';
--          trig_win_end_tdc_flag_fsm <= '0';
          FSM_WR_NEXT      <= WRITE_EPOCH;
          if encoder_finished_i = '1' then
            write_data_flag_fsm <= '1';
          end if;
          fsm_wr_debug_fsm <= x"5";
--        
        when others =>
          FSM_WR_NEXT      <= WRITE_EPOCH;
          write_epoch_fsm  <= '0';
          write_data_fsm   <= '0';
          write_stop_a_fsm <= '0';
          write_stop_b_fsm <= '0';
          fsm_wr_debug_fsm <= x"0";
      end case;
    end process FSM_PROC;
  end generate isChannel;  -- if it is a normal channel

  isReference : if REFERENCE = c_YES generate  -- if it is the reference channel
    FSM_PROC : process (FSM_WR_CURRENT, encoder_finished_i, epoch_cntr_updated, TRIGGER_WIN_END_TDC,
                        trig_win_end_tdc_flag_i, VALID_TIMING_TRG_IN, MULTI_TMG_TRG_IN, SPIKE_DETECTED_IN)
    begin

      FSM_WR_NEXT      <= WRITE_EPOCH;
      write_epoch_fsm  <= '0';
      write_data_fsm   <= '0';
      write_stop_a_fsm <= '0';
      write_stop_b_fsm <= '0';
--      trig_win_end_tdc_flag_fsm <= trig_win_end_tdc_flag_i;
      fsm_wr_debug_fsm <= x"0";

      case (FSM_WR_CURRENT) is
        when WRITE_EPOCH =>
          if encoder_finished_i = '1' then
            FSM_WR_NEXT <= WAIT_FOR_VALIDITY;
          elsif trig_win_end_tdc_flag_i = '1' or TRIGGER_WIN_END_TDC = '1' then
            FSM_WR_NEXT <= WRITE_STOP_A;
          else
            write_epoch_fsm <= '0';
            FSM_WR_NEXT     <= WRITE_EPOCH;
          end if;
          --if TRIGGER_WIN_END_TDC = '1' then
          --  trig_win_end_tdc_flag_fsm <= '1';
          --end if;
          fsm_wr_debug_fsm <= x"1";
--
        when WAIT_FOR_VALIDITY =>
          if VALID_TIMING_TRG_IN = '1' then
            write_epoch_fsm <= '1';
            FSM_WR_NEXT     <= EXCEPTION;
          elsif MULTI_TMG_TRG_IN = '1' or SPIKE_DETECTED_IN = '1' then
            FSM_WR_NEXT <= WRITE_EPOCH;
          else
            FSM_WR_NEXT <= WAIT_FOR_VALIDITY;
          end if;
          fsm_wr_debug_fsm <= x"6";
--
        when WRITE_DATA =>
          if epoch_cntr_updated = '1' then
            write_epoch_fsm <= '1';
            FSM_WR_NEXT     <= EXCEPTION;
          else
            write_data_fsm <= '1';
            if trig_win_end_tdc_flag_i = '1' or TRIGGER_WIN_END_TDC = '1' then
              FSM_WR_NEXT <= WRITE_STOP_A;
            else
              FSM_WR_NEXT <= WAIT_FOR_HIT;
            end if;
          end if;
          --if TRIGGER_WIN_END_TDC = '1' then
          --  trig_win_end_tdc_flag_fsm <= '1';
          --end if;
          fsm_wr_debug_fsm <= x"2";
--
        when EXCEPTION =>
          write_data_fsm <= '1';
          if trig_win_end_tdc_flag_i = '1' or TRIGGER_WIN_END_TDC = '1' then
            FSM_WR_NEXT <= WRITE_STOP_A;
          else
            FSM_WR_NEXT <= WAIT_FOR_HIT;
          end if;
          fsm_wr_debug_fsm <= x"3";
--
        when WAIT_FOR_HIT =>
          if epoch_cntr_updated = '1' and encoder_finished_i = '0' then
            FSM_WR_NEXT <= WRITE_EPOCH;
          elsif epoch_cntr_updated = '0' and encoder_finished_i = '1' then
            FSM_WR_NEXT <= WRITE_DATA;
          elsif epoch_cntr_updated = '1' and encoder_finished_i = '1' then
            write_epoch_fsm <= '1';
            FSM_WR_NEXT     <= WRITE_DATA;
          elsif trig_win_end_tdc_flag_i = '1' or TRIGGER_WIN_END_TDC = '1' then
            FSM_WR_NEXT <= WRITE_STOP_A;
          else
            FSM_WR_NEXT <= WAIT_FOR_HIT;
          end if;
          --if TRIGGER_WIN_END_TDC = '1' then
          --  trig_win_end_tdc_flag_fsm <= '1';
          --end if;
          fsm_wr_debug_fsm <= x"4";
--
        when WRITE_STOP_A =>
          write_stop_a_fsm <= '1';
          FSM_WR_NEXT      <= WRITE_STOP_B;
          fsm_wr_debug_fsm <= x"5";
--
        when WRITE_STOP_B =>
          write_stop_a_fsm <= '1';
          FSM_WR_NEXT      <= WRITE_STOP_C;
          fsm_wr_debug_fsm <= x"5";
--
        when WRITE_STOP_C =>
          write_stop_b_fsm <= '1';
          FSM_WR_NEXT      <= WRITE_STOP_D;
          fsm_wr_debug_fsm <= x"5";
--
        when WRITE_STOP_D =>
          write_stop_b_fsm <= '1';
--          trig_win_end_tdc_flag_fsm <= '0';
          FSM_WR_NEXT      <= WRITE_EPOCH;
          fsm_wr_debug_fsm <= x"5";
--        
        when others =>
          FSM_WR_NEXT      <= WRITE_EPOCH;
          write_epoch_fsm  <= '0';
          write_data_fsm   <= '0';
          write_stop_a_fsm <= '0';
          write_stop_b_fsm <= '0';
          fsm_wr_debug_fsm <= x"0";
      end case;
    end process FSM_PROC;
  end generate isReference;  -- if it is the reference channel

  TriggerWindowFlag : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if TRIGGER_WIN_END_TDC = '1' then
        trig_win_end_tdc_flag_i <= '1';
      elsif FSM_WR_CURRENT = WRITE_STOP_D then
        trig_win_end_tdc_flag_i <= '0';
      end if;
    end if;
  end process TriggerWindowFlag;

  -- purpose: Generate Fifo Wr Signal
  FifoWriteSignal : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if write_epoch_i = '1' and EPOCH_WRITE_EN_IN = '1' then
        fifo_data_in_i(35 downto 32) <= x"1";
        fifo_data_in_i(31 downto 29) <= "011";
        fifo_data_in_i(28)           <= '0';
        fifo_data_in_i(27 downto 0)  <= epoch_cntr;
        fifo_wr_en_i                 <= '1';
      elsif write_data_i = '1' then
        fifo_data_in_i(35 downto 32) <= x"1";
        fifo_data_in_i(31)           <= '1';                 -- data marker
        fifo_data_in_i(30 downto 29) <= "00";                -- reserved bits
        fifo_data_in_i(28 downto 22) <= std_logic_vector(to_unsigned(CHANNEL_ID, 7));  -- channel number
        fifo_data_in_i(21 downto 12) <= encoder_data_out_i;  -- fine time from the encoder
        fifo_data_in_i(11)           <= '1';  --edge_type_i;  -- rising '1' or falling '0' edge
        fifo_data_in_i(10 downto 0)  <= time_stamp_i;        -- hit time stamp
        fifo_wr_en_i                 <= '1';
      elsif write_stop_a_i = '1' then
        fifo_data_in_i(35 downto 32) <= x"f";
        fifo_data_in_i(31 downto 0)  <= (others => '0');
        fifo_wr_en_i                 <= '1';
      elsif write_stop_b_i = '1' then
        fifo_data_in_i(35 downto 32) <= x"0";
        fifo_data_in_i(31 downto 0)  <= (others => '0');
        fifo_wr_en_i                 <= '1';
      else
        fifo_data_in_i(35 downto 32) <= x"e";
        fifo_data_in_i(31 downto 0)  <= (others => '0');
        fifo_wr_en_i                 <= '0';
      end if;
    end if;
  end process FifoWriteSignal;

  FIFO_WRITE_OUT       <= fifo_wr_en_i;
  ENCODER_FINISHED_OUT <= encoder_finished_i;

-------------------------------------------------------------------------------
-- Read Stage
-------------------------------------------------------------------------------
  -- Determine the next state synchronously, based on the current state and the
  -- input
  FSM_DATA_STATE : process (CLK_100)
  begin
    if (rising_edge(CLK_100)) then
      if RESET_100 = '1' then
        FSM_RD_STATE <= IDLE;
      else
        
        case FSM_RD_STATE is
          when IDLE =>
            -- if the data readout is triggered by the end of the trigger window
            if TRIGGER_WIN_END_RDO = '1' then
              FSM_RD_STATE <= READOUT_DATA_A;
              -- if the data readout is triggered by full fifo
            elsif fifo_almost_full_flag = '1' then
              FSM_RD_STATE <= FLUSH_A;
            else
              FSM_RD_STATE <= IDLE;
            end if;
--
          when FLUSH_A =>
            FSM_RD_STATE <= FLUSH_B;
--
          when FLUSH_B =>
            FSM_RD_STATE <= FLUSH_C;
--
          when FLUSH_C =>
            FSM_RD_STATE <= FLUSH_D;
--
          when FLUSH_D =>
            -- wait until a readout request and register the last epoch word
            if TRIGGER_WIN_END_RDO = '1' or trigger_win_end_rdo_flag_i = '1' then
              FSM_RD_STATE <= READOUT_EPOCH;
            else
              FSM_RD_STATE <= FLUSH_D;
            end if;
--
          when READOUT_EPOCH =>
            -- first epoch word should be readout
            FSM_RD_STATE <= READOUT_DATA_C;
--
          when READOUT_DATA_A =>
            FSM_RD_STATE <= READOUT_DATA_B;
--
          when READOUT_DATA_B =>
            FSM_RD_STATE <= READOUT_DATA_C;
            
          when READOUT_DATA_C =>
            -- normal data readout until the end of the readout request
            if fifo_data_out_i(35 downto 32) = x"f" then
              FSM_RD_STATE <= IDLE;
            else
              FSM_RD_STATE <= READOUT_DATA_C;
            end if;
--
          when others =>
            FSM_RD_STATE <= IDLE;
        end case;
      end if;
    end if;
  end process FSM_DATA_STATE;

  -- Determine the output based only on the current state and the input (do not wait for a clock
  -- edge).
  FSM_DATA_OUTPUT : process (FSM_RD_STATE, TRIGGER_WIN_END_RDO, fifo_data_out_i, epoch_value)
  begin
    trigger_win_end_rdo_flag_i <= trigger_win_end_rdo_flag_i;
    epoch_value                <= epoch_value;

    case FSM_RD_STATE is
      when IDLE =>
        fifo_data_i       <= (others => '0');
        fifo_data_valid_i <= '0';
        fifo_rd_data_i    <= '0';
        fsm_rd_debug_i    <= x"1";
      when FLUSH_A =>
        fifo_data_i       <= (others => '0');
        fifo_data_valid_i <= '0';
        fifo_rd_data_i    <= '0';
        if TRIGGER_WIN_END_RDO = '1' then
          trigger_win_end_rdo_flag_i <= '1';
        end if;
        fsm_rd_debug_i <= x"2";
      when FLUSH_B =>
        fifo_data_i       <= (others => '0');
        fifo_data_valid_i <= '0';
        fifo_rd_data_i    <= '0';
        if TRIGGER_WIN_END_RDO = '1' then
          trigger_win_end_rdo_flag_i <= '1';
        end if;
        fsm_rd_debug_i <= x"3";
      when FLUSH_C =>
        fifo_data_i       <= (others => '0');
        fifo_data_valid_i <= '0';
        fifo_rd_data_i    <= '0';
        if TRIGGER_WIN_END_RDO = '1' then
          trigger_win_end_rdo_flag_i <= '1';
        end if;
        fsm_rd_debug_i <= x"4";
      when FLUSH_D =>
        fifo_data_i       <= (others => '0');
        fifo_data_valid_i <= '0';
        fifo_rd_data_i    <= '0';
        if fifo_data_out_i(31 downto 29) = "011" then
          epoch_value <= fifo_data_out_i;
        end if;
        fsm_rd_debug_i <= x"5";
      when READOUT_EPOCH =>
        fifo_data_i       <= epoch_value;
        fifo_data_valid_i <= '1';
        fifo_rd_data_i    <= '0';
        fsm_rd_debug_i    <= x"6";
      when READOUT_DATA_A =>
        fifo_data_i                <= (others => '0');
        fifo_data_valid_i          <= '0';
        fifo_rd_data_i             <= '1';
        trigger_win_end_rdo_flag_i <= '0';
        fsm_rd_debug_i             <= x"7";
      when READOUT_DATA_B =>
        fifo_data_i       <= (others => '0');
        fifo_data_valid_i <= '0';
        fifo_rd_data_i    <= '1';
        fsm_rd_debug_i    <= x"8";
      when READOUT_DATA_C =>
        fifo_data_i <= fifo_data_out_i;
        if fifo_data_out_i(35 downto 32) = x"0" then
          fifo_data_valid_i <= '0';
        else
          fifo_data_valid_i <= '1';
        end if;
        fifo_rd_data_i <= '1';
        fsm_rd_debug_i <= x"9";
      when others =>
        fifo_data_i       <= (others => '0');
        fifo_data_valid_i <= '0';
        fifo_rd_data_i    <= '0';
        fsm_rd_debug_i    <= x"0";
    end case;
  end process FSM_DATA_OUTPUT;

  FIFO_DATA_OUT       <= fifo_data_i;
  FIFO_DATA_VALID_OUT <= fifo_data_valid_i;

  RegisterOutputs : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      FIFO_EMPTY_OUT <= fifo_empty_i;
    end if;
  end process RegisterOutputs;

  FIFO_FULL_OUT        <= fifo_full_i        when rising_edge(CLK_200);
  FIFO_ALMOST_FULL_OUT <= fifo_almost_full_i when rising_edge(CLK_200);

-------------------------------------------------------------------------------
-- DEBUG
-------------------------------------------------------------------------------
  CHANNEL_200_DEBUG(7 downto 0)   <= fifo_data_in_i(35 downto 28);
  CHANNEL_200_DEBUG(15 downto 8)  <= fifo_data_i(35 downto 28);
  CHANNEL_200_DEBUG(16)           <= fifo_wr_en_i;
  CHANNEL_200_DEBUG(17)           <= fifo_data_valid_i;
  CHANNEL_200_DEBUG(18)           <= fifo_rd_en_i;
  CHANNEL_200_DEBUG(23 downto 19) <= (others => '0');
  CHANNEL_200_DEBUG(27 downto 24) <= fsm_rd_debug_i;
  CHANNEL_200_DEBUG(31 downto 28) <= fsm_wr_debug_i;

  gen_SIMULATION : if SIMULATION = c_YES generate
    -- count data written
    data_cntr : process
    begin
      wait until rising_edge(CLK_100);
      if fifo_data_valid_i = '1' and fifo_data_i(31 downto 29) = "100" then
        data_cnt_event <= data_cnt_event + 1;
      elsif fifo_data_valid_i = '1' and fifo_data_i(31 downto 29) = "011" then
        epoch_cnt_event <= epoch_cnt_event + 1;
      elsif TRIGGER_WIN_END_RDO = '1' then
        data_cnt_event  <= 0;
        epoch_cnt_event <= 0;
      end if;
    end process data_cntr;

    process(fifo_data_valid_i)
    begin  -- process
      data_cnt_total  <= data_cnt_total + data_cnt_event;
      epoch_cnt_total <= epoch_cnt_total + epoch_cnt_event;
    end process;

    -- check if data count per event is correct
    --CheckEpochCounter : process
    --begin
    --  wait until falling_edge(fifo_data_valid_i);
    --  wait for 1 ns;
    --  if data_cnt_event /= 30 then
    --    report "wrong number of hits in channel " & integer'image(CHANNEL_ID) severity error;
    --  end if;
    --end process CheckEpochCounter;


    
    

    
  end generate gen_SIMULATION;
  
end Channel_200;
