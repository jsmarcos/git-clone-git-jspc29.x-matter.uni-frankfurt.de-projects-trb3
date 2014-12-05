-------------------------------------------------------------------------------
-- Title      : Channel 200 MHz Part
-- Project    : 
-------------------------------------------------------------------------------
-- File       : Channel_200.vhd
-- Author     : c.ugur@gsi.de
-- Created    : 2012-08-28
-- Last update: 2014-12-04
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
use work.tdc_components.all;
use work.config.all;

entity Channel_200 is

  generic (
    CHANNEL_ID : integer range 0 to 64;
    DEBUG      : integer range 0 to 1;
    SIMULATION : integer range 0 to 1;
    REFERENCE  : integer range 0 to 1);
  port (
    CLK_200               : in  std_logic;  -- 200 MHz clk
    RESET_200             : in  std_logic;  -- reset sync with 200Mhz clk
    CLK_100               : in  std_logic;  -- 100 MHz clk
    RESET_100             : in  std_logic;  -- reset sync with 100Mhz clk
--
    HIT_IN                : in  std_logic;  -- hit in
    HIT_EDGE_IN           : in  std_logic;  -- hit edge in
    TRG_WIN_END_TDC_IN    : in  std_logic;  -- trigger window end strobe
    TRG_WIN_END_RDO_IN    : in  std_logic;  -- trigger window end strobe
    EPOCH_COUNTER_IN      : in  std_logic_vector(27 downto 0);  -- system coarse counter
    COARSE_COUNTER_IN     : in  std_logic_vector(10 downto 0);
    READ_EN_IN            : in  std_logic;  -- read en signal
    FIFO_DATA_OUT         : out std_logic_vector(35 downto 0);  -- fifo data out
    FIFO_DATA_VALID_OUT   : out std_logic;  -- fifo data valid signal
--
    VALID_TIMING_TRG_IN   : in  std_logic;
    VALID_NOTIMING_TRG_IN : in  std_logic;
    SPIKE_DETECTED_IN     : in  std_logic;
    MULTI_TMG_TRG_IN      : in  std_logic;
--
    EPOCH_WRITE_EN_IN     : in  std_logic;
    ENCODER_START_OUT     : out std_logic;
    ENCODER_FINISHED_OUT  : out std_logic;
    FIFO_WRITE_OUT        : out std_logic;
    CHANNEL_200_DEBUG_OUT : out std_logic_vector(31 downto 0)
    );

end Channel_200;

architecture Channel_200 of Channel_200 is

  -- carry chain
  signal data_a      : std_logic_vector(303 downto 0);
  signal data_b      : std_logic_vector(303 downto 0);
  signal result      : std_logic_vector(303 downto 0);
  signal ff_array_en : std_logic;

  -- hit detection
  signal result_2_r          : std_logic := '0';
  signal hit_detect          : std_logic := '0';
  signal hit_detect_r        : std_logic;
  signal hit_detect_2r       : std_logic;
  signal edge_type           : std_logic := '1';
  signal rising_edge_written : std_logic := '0';

  -- time stamp
  signal time_stamp              : std_logic_vector(10 downto 0);
  signal time_stamp_r            : std_logic_vector(10 downto 0);
  signal time_stamp_2r           : std_logic_vector(10 downto 0);
  signal time_stamp_3r           : std_logic_vector(10 downto 0);
  signal time_stamp_4r           : std_logic_vector(10 downto 0);
  signal time_stamp_5r           : std_logic_vector(10 downto 0);
  signal time_stamp_6r           : std_logic_vector(10 downto 0);
  signal coarse_cntr_r           : std_logic_vector(10 downto 0);
  signal coarse_cntr_overflow    : std_logic;
  signal coarse_cntr_overflow_r  : std_logic;
  signal coarse_cntr_overflow_2r : std_logic;
  signal coarse_cntr_overflow_3r : std_logic;
  signal coarse_cntr_overflow_4r : std_logic;
  signal coarse_cntr_overflow_5r : std_logic;
  signal coarse_cntr_overflow_6r : std_logic;
  signal coarse_cntr_overflow_7r : std_logic;

  -- encoder
  signal encoder_start    : std_logic;
  signal encoder_finished : std_logic;
  signal encoder_data_out : std_logic_vector(9 downto 0);
  signal encoder_debug    : std_logic_vector(31 downto 0);

  -- epoch counter
  signal epoch_cntr         : std_logic_vector(27 downto 0) := (others => '0');
  signal epoch_cntr_r       : std_logic_vector(27 downto 0) := (others => '0');
  signal epoch_cntr_updated : std_logic                     := '0';
  signal epoch_value        : std_logic_vector(35 downto 0);

  -- ring bugger
  signal ringBuffer_data_out         : std_logic_vector(35 downto 0);
  signal ringBuffer_data_in          : std_logic_vector(35 downto 0);
  signal ringBuffer_empty            : std_logic;
  signal ringBuffer_full             : std_logic;
  signal ringBuffer_almost_full_sync : std_logic;
  signal ringBuffer_almost_full      : std_logic := '0';
  signal ringBuffer_almost_full_flag : std_logic := '0';
  signal ringBuffer_wr_en            : std_logic;
  signal ringBuffer_rd_en            : std_logic;
  signal ringBuffer_rd_data          : std_logic;
  signal fifo_data                   : std_logic_vector(35 downto 0);
  signal fifo_data_valid             : std_logic;

  -- fsm
  type FSM_WR is (WRITE_EPOCH_WORD, WRITE_DATA_WORD, WRITE_STOP_WORD_A, WRITE_STOP_WORD_B,
                  WRITE_STOP_WORD_C, WRITE_STOP_WORD_D, WAIT_FOR_HIT, WAIT_FOR_VALIDITY,
                  EXCEPTION);
  signal FSM_WR_CURRENT           : FSM_WR    := WRITE_EPOCH_WORD;
  signal FSM_WR_NEXT              : FSM_WR;
  signal write_epoch_fsm          : std_logic;
  signal write_epoch              : std_logic := '0';
  signal write_data_fsm           : std_logic;
  signal write_data               : std_logic := '0';
  signal write_stop_a_fsm         : std_logic;
  signal write_stop_a             : std_logic := '0';
  signal write_stop_b_fsm         : std_logic;
  signal write_stop_b             : std_logic := '0';
  signal write_data_flag_fsm      : std_logic;
  signal write_data_flag          : std_logic := '0';
  signal trg_win_end_tdc_flag_fsm : std_logic;
  signal trg_win_end_tdc_flag     : std_logic := '0';
  signal fsm_wr_debug_fsm         : std_logic_vector(3 downto 0);
  signal fsm_wr_debug             : std_logic_vector(3 downto 0);

  type FSM_RD is (IDLE, FLUSH_A, FLUSH_B, FLUSH_C, FLUSH_D, READOUT_EPOCH, READOUT_DATA_A, READOUT_DATA_B, READOUT_DATA_C);
  signal FSM_RD_STATE         : FSM_RD;
  signal trg_win_end_rdo_flag : std_logic := '0';
  signal fsm_rd_debug         : std_logic_vector(3 downto 0);

  -----------------------------------------------------------------------------
  -- debug
  signal data_cnt_total  : integer range 0 to 2147483647 := 0;
  signal data_cnt_event  : integer range 0 to 255        := 0;
  signal epoch_cnt_total : integer range 0 to 65535      := 0;
  signal epoch_cnt_event : integer range 0 to 127        := 0;
  -----------------------------------------------------------------------------

  attribute syn_keep                : boolean;
  attribute syn_keep of ff_array_en : signal is true;

begin  -- Channel_200

  SimAdderYes : if SIMULATION = c_YES generate
    --purpose: Tapped Delay Line 304 (Carry Chain) with wave launcher (21) double transition
    FC : Adder_304
      port map (
        CLK    => CLK_200,
        RESET  => RESET_200,
        DataA  => data_a,
        DataB  => data_b,
        ClkEn  => ff_array_en,
        Result => result);
    data_a <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000000FFFFFFF"&x"7FFFFFF";
    data_b <= x"000000000000000000000000000000000000000000000000000000000000000000000"& HIT_IN & x"000000"&"00" & not(HIT_IN);
  end generate SimAdderYes;
  SimAdderNo : if SIMULATION = c_NO generate
    --purpose: Tapped Delay Line 304 (Carry Chain) with wave launcher (21) double transition
    FC : Adder_304
      port map (
        CLK    => CLK_200,
        RESET  => RESET_200,
        DataA  => data_a,
        DataB  => data_b,
        ClkEn  => ff_array_en,
        Result => result);
    data_a <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"&x"7FFFFFF";
    data_b <= x"000000000000000000000000000000000000000000000000000000000000000000000"& HIT_IN & x"000000"&"00" & not(HIT_IN);
  end generate SimAdderNo;

  ff_array_en <= not(hit_detect or hit_detect_r or hit_detect_2r);

  result_2_r        <= result(2)         when rising_edge(CLK_200);
  hit_detect        <= (not result_2_r) and result(2);  -- detects the hit by
                                                        -- comparing the
                                                        -- previous state of the
                                                        -- hit detection bit
  hit_detect_r      <= hit_detect        when rising_edge(CLK_200);
  hit_detect_2r     <= hit_detect_r      when rising_edge(CLK_200);
  coarse_cntr_r     <= COARSE_COUNTER_IN when rising_edge(CLK_200);
  encoder_start     <= hit_detect_r;
  ENCODER_START_OUT <= encoder_start;

  isReferenceEdge : if REFERENCE = c_YES generate
    edge_type <= '1';
  end generate isReferenceEdge;

  isChannelEdge : if REFERENCE = c_NO generate
    EdgeTypeCapture : process (CLK_200) is
    begin  -- process EdgeTypeCapture
      if rising_edge(CLK_200) then
        if write_data = '1' and edge_type = '1' then
          rising_edge_written <= '1';
        elsif write_data = '1' and edge_type = '0' then
          rising_edge_written <= '0';
        end if;
        if HIT_EDGE_IN = '1' and edge_type = '0' then
          edge_type <= '1';
        elsif rising_edge_written = '1' then
          edge_type <= '0';
        end if;
      end if;
    end process EdgeTypeCapture;
  end generate isChannelEdge;

  TimeStampCapture : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if hit_detect_r = '1' then
        time_stamp <= coarse_cntr_r;
      end if;
      time_stamp_r  <= time_stamp;
      time_stamp_2r <= time_stamp_r;
      time_stamp_3r <= time_stamp_2r;
      time_stamp_4r <= time_stamp_3r;
      time_stamp_5r <= time_stamp_4r;
      time_stamp_6r <= time_stamp_5r;
    end if;
  end process TimeStampCapture;

  CoarseCounterOverflow : entity work.fallingEdgeDetect
    port map (
      CLK       => CLK_200,
      SIGNAL_IN => coarse_cntr_r(10),
      PULSE_OUT => coarse_cntr_overflow);

  coarse_cntr_overflow_r  <= coarse_cntr_overflow    when rising_edge(CLK_200);
  coarse_cntr_overflow_2r <= coarse_cntr_overflow_r  when rising_edge(CLK_200);
  coarse_cntr_overflow_3r <= coarse_cntr_overflow_2r when rising_edge(CLK_200);
  coarse_cntr_overflow_4r <= coarse_cntr_overflow_3r when rising_edge(CLK_200);
  coarse_cntr_overflow_5r <= coarse_cntr_overflow_4r when rising_edge(CLK_200);
  coarse_cntr_overflow_6r <= coarse_cntr_overflow_5r when rising_edge(CLK_200);
  coarse_cntr_overflow_7r <= coarse_cntr_overflow_6r when rising_edge(CLK_200);

  EpochCounterCapture : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if coarse_cntr_overflow_7r = '1' then
        epoch_cntr         <= EPOCH_COUNTER_IN;
        epoch_cntr_updated <= '1';
      elsif write_epoch = '1' then
        epoch_cntr_updated <= '0';
      end if;
    end if;
  end process EpochCounterCapture;

  --purpose: Encoder
  Encoder : Encoder_304_Bit
    port map (
      RESET           => RESET_200,
      CLK             => CLK_200,
      START_IN        => encoder_start,
      THERMOCODE_IN   => result,
      FINISHED_OUT    => encoder_finished,
      BINARY_CODE_OUT => encoder_data_out,
      ENCODER_DEBUG   => encoder_debug);

  RingBuffer_128 : if RING_BUFFER_SIZE = 3 generate
    FIFO : FIFO_DC_36x128_OutReg
      port map (
        Data       => ringBuffer_data_in,
        WrClock    => CLK_200,
        RdClock    => CLK_100,
        WrEn       => ringBuffer_wr_en,
        RdEn       => ringBuffer_rd_en,
        Reset      => RESET_100,
        RPReset    => RESET_100,
        Q          => ringBuffer_data_out,
        Empty      => ringBuffer_empty,
        Full       => ringBuffer_full,
        AlmostFull => ringBuffer_almost_full);
  end generate RingBuffer_128;

  RingBuffer_64 : if RING_BUFFER_SIZE = 1 generate
    FIFO : FIFO_DC_36x64_OutReg
      port map (
        Data       => ringBuffer_data_in,
        WrClock    => CLK_200,
        RdClock    => CLK_100,
        WrEn       => ringBuffer_wr_en,
        RdEn       => ringBuffer_rd_en,
        Reset      => RESET_100,
        RPReset    => RESET_100,
        Q          => ringBuffer_data_out,
        Empty      => ringBuffer_empty,
        Full       => ringBuffer_full,
        AlmostFull => ringBuffer_almost_full);
  end generate RingBuffer_64;

  RingBuffer_32 : if RING_BUFFER_SIZE = 0 generate
    FIFO : FIFO_DC_36x32_OutReg
      port map (
        Data       => ringBuffer_data_in,
        WrClock    => CLK_200,
        RdClock    => CLK_100,
        WrEn       => ringBuffer_wr_en,
        RdEn       => ringBuffer_rd_en,
        Reset      => RESET_100,
        RPReset    => RESET_100,
        Q          => ringBuffer_data_out,
        Empty      => ringBuffer_empty,
        Full       => ringBuffer_full,
        AlmostFull => ringBuffer_almost_full);
  end generate RingBuffer_32;

  ringBuffer_almost_full_sync <= ringBuffer_almost_full                            when rising_edge(CLK_100);
  ringBuffer_rd_en            <= ringBuffer_rd_data or ringBuffer_almost_full_sync when rising_edge(CLK_100);

  FifoAlmostEmptyFlag : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' then
        ringBuffer_almost_full_flag <= '0';
      elsif FSM_RD_STATE = READOUT_DATA_C then
        ringBuffer_almost_full_flag <= '0';
      elsif ringBuffer_almost_full_sync = '1' then
        ringBuffer_almost_full_flag <= '1';
      end if;
    end if;
  end process FifoAlmostEmptyFlag;


-------------------------------------------------------------------------------
-- Write Stage
-------------------------------------------------------------------------------
  -- Readout fsm
  FSM_CLK : process (CLK_200)
  begin
    if RESET_200 = '1' then
      FSM_WR_CURRENT <= WRITE_EPOCH_WORD;
    elsif rising_edge(CLK_200) then
      FSM_WR_CURRENT  <= FSM_WR_NEXT;
      write_epoch     <= write_epoch_fsm;
      write_data      <= write_data_fsm;
      write_stop_a    <= write_stop_a_fsm;
      write_stop_b    <= write_stop_b_fsm;
      write_data_flag <= write_data_flag_fsm;
      fsm_wr_debug    <= fsm_wr_debug_fsm;
    end if;
  end process FSM_CLK;

  FSM_PROC : process (FSM_WR_CURRENT, encoder_finished, epoch_cntr_updated, TRG_WIN_END_TDC_IN,
                      trg_win_end_tdc_flag, write_data_flag)
  begin

    FSM_WR_NEXT         <= WRITE_EPOCH_WORD;
    write_epoch_fsm     <= '0';
    write_data_fsm      <= '0';
    write_stop_a_fsm    <= '0';
    write_stop_b_fsm    <= '0';
    write_data_flag_fsm <= write_data_flag;
    fsm_wr_debug_fsm    <= x"0";

    case (FSM_WR_CURRENT) is
      when WRITE_EPOCH_WORD =>
        if encoder_finished = '1' or write_data_flag = '1' then
          write_epoch_fsm     <= '1';
          write_data_flag_fsm <= '0';
          FSM_WR_NEXT         <= EXCEPTION;
        elsif trg_win_end_tdc_flag = '1' or TRG_WIN_END_TDC_IN = '1' then
          FSM_WR_NEXT <= WRITE_STOP_WORD_A;
        else
          write_epoch_fsm <= '0';
          FSM_WR_NEXT     <= WRITE_EPOCH_WORD;
        end if;
        fsm_wr_debug_fsm <= x"1";
--
      when WRITE_DATA_WORD =>
        if epoch_cntr_updated = '1' then
          write_epoch_fsm <= '1';
          FSM_WR_NEXT     <= EXCEPTION;
        else
          write_data_fsm <= '1';
          if trg_win_end_tdc_flag = '1' or TRG_WIN_END_TDC_IN = '1' then
            FSM_WR_NEXT <= WRITE_STOP_WORD_A;
          else
            FSM_WR_NEXT <= WAIT_FOR_HIT;
          end if;
        end if;
        fsm_wr_debug_fsm <= x"2";
--
      when EXCEPTION =>
        write_data_fsm <= '1';
        if trg_win_end_tdc_flag = '1' or TRG_WIN_END_TDC_IN = '1' then
          FSM_WR_NEXT <= WRITE_STOP_WORD_A;
        else
          FSM_WR_NEXT <= WAIT_FOR_HIT;
        end if;
        fsm_wr_debug_fsm <= x"3";
--
      when WAIT_FOR_HIT =>
        if epoch_cntr_updated = '1' and encoder_finished = '0' then
          FSM_WR_NEXT <= WRITE_EPOCH_WORD;
        elsif epoch_cntr_updated = '0' and encoder_finished = '1' then
          FSM_WR_NEXT <= WRITE_DATA_WORD;
        elsif epoch_cntr_updated = '1' and encoder_finished = '1' then
          FSM_WR_NEXT <= WRITE_DATA_WORD;
        elsif trg_win_end_tdc_flag = '1' or TRG_WIN_END_TDC_IN = '1' then
          FSM_WR_NEXT <= WRITE_STOP_WORD_A;
        else
          FSM_WR_NEXT <= WAIT_FOR_HIT;
        end if;
        fsm_wr_debug_fsm <= x"4";
--
      when WRITE_STOP_WORD_A =>
        write_stop_a_fsm <= '1';
        FSM_WR_NEXT      <= WRITE_STOP_WORD_B;
        if encoder_finished = '1' then
          write_data_flag_fsm <= '1';
        end if;
        fsm_wr_debug_fsm <= x"5";
--
      when WRITE_STOP_WORD_B =>
        write_stop_a_fsm <= '1';
        FSM_WR_NEXT      <= WRITE_STOP_WORD_C;
        if encoder_finished = '1' then
          write_data_flag_fsm <= '1';
        end if;
        fsm_wr_debug_fsm <= x"5";
--
      when WRITE_STOP_WORD_C =>
        write_stop_b_fsm <= '1';
        FSM_WR_NEXT      <= WRITE_STOP_WORD_D;
        if encoder_finished = '1' then
          write_data_flag_fsm <= '1';
        end if;
        fsm_wr_debug_fsm <= x"5";
--
      when WRITE_STOP_WORD_D =>
        write_stop_b_fsm <= '1';
        FSM_WR_NEXT      <= WRITE_EPOCH_WORD;
        if encoder_finished = '1' then
          write_data_flag_fsm <= '1';
        end if;
        fsm_wr_debug_fsm <= x"5";
--        
      when others =>
        FSM_WR_NEXT      <= WRITE_EPOCH_WORD;
        write_epoch_fsm  <= '0';
        write_data_fsm   <= '0';
        write_stop_a_fsm <= '0';
        write_stop_b_fsm <= '0';
        fsm_wr_debug_fsm <= x"0";
    end case;
  end process FSM_PROC;

  TriggerWindowFlag : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        trg_win_end_tdc_flag <= '0';
      elsif TRG_WIN_END_TDC_IN = '1' then
        trg_win_end_tdc_flag <= '1';
      elsif FSM_WR_CURRENT = WRITE_STOP_WORD_D then
        trg_win_end_tdc_flag <= '0';
      end if;
    end if;
  end process TriggerWindowFlag;

  -- purpose: Generate Fifo Wr Signal
  FifoWriteSignal : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if write_epoch = '1' and EPOCH_WRITE_EN_IN = '1' then
        ringBuffer_data_in(35 downto 32) <= x"1";
        ringBuffer_data_in(31 downto 29) <= "011";
        ringBuffer_data_in(28)           <= '0';
        ringBuffer_data_in(27 downto 0)  <= epoch_cntr;
        ringBuffer_wr_en                 <= '1';
      elsif write_data = '1' then
        ringBuffer_data_in(35 downto 32) <= x"1";
        ringBuffer_data_in(31)           <= '1';        -- data marker
        ringBuffer_data_in(30 downto 29) <= "00";       -- reserved bits
        ringBuffer_data_in(28 downto 22) <= std_logic_vector(to_unsigned(CHANNEL_ID, 7));  -- channel number
        ringBuffer_data_in(21 downto 12) <= encoder_data_out;  -- fine time from the encoder
        ringBuffer_data_in(11)           <= edge_type;  -- rising '1' or falling '0' edge
        ringBuffer_data_in(10 downto 0)  <= time_stamp_6r;  -- hit time stamp
        ringBuffer_wr_en                 <= '1';
      elsif write_stop_a = '1' then
        ringBuffer_data_in(35 downto 32) <= x"f";
        ringBuffer_data_in(31 downto 0)  <= (others => '0');
        ringBuffer_wr_en                 <= '1';
      elsif write_stop_b = '1' then
        ringBuffer_data_in(35 downto 32) <= x"0";
        ringBuffer_data_in(31 downto 0)  <= (others => '0');
        ringBuffer_wr_en                 <= '1';
      else
        ringBuffer_data_in(35 downto 32) <= x"e";
        ringBuffer_data_in(31 downto 0)  <= (others => '0');
        ringBuffer_wr_en                 <= '0';
      end if;
    end if;
  end process FifoWriteSignal;

  FIFO_WRITE_OUT       <= ringBuffer_wr_en;
  ENCODER_FINISHED_OUT <= encoder_finished;

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
            if TRG_WIN_END_RDO_IN = '1' then
              FSM_RD_STATE <= READOUT_DATA_A;
            -- if the data readout is triggered by full fifo
            elsif ringBuffer_almost_full_flag = '1' then
              FSM_RD_STATE <= FLUSH_A;
            else
              FSM_RD_STATE <= IDLE;
            end if;
          --
          when FLUSH_A =>
            FSM_RD_STATE <= FLUSH_D;
          --
          when FLUSH_B =>
            FSM_RD_STATE <= FLUSH_C;
          --
          when FLUSH_C =>
            FSM_RD_STATE <= FLUSH_D;
          --
          when FLUSH_D =>
            -- wait until a readout request and register the last epoch word
            if TRG_WIN_END_RDO_IN = '1' or trg_win_end_rdo_flag = '1' then
              FSM_RD_STATE <= READOUT_EPOCH;
            else
              FSM_RD_STATE <= FLUSH_D;
            end if;
          --
          when READOUT_EPOCH =>
            -- first epoch word should be readout
            FSM_RD_STATE <= READOUT_DATA_A;
          --
          when READOUT_DATA_A =>
            FSM_RD_STATE <= READOUT_DATA_B;
          --
          when READOUT_DATA_B =>
            FSM_RD_STATE <= READOUT_DATA_C;
          --  
          when READOUT_DATA_C =>
            -- normal data readout until the end of the readout request
            if ringBuffer_data_out(35 downto 32) = x"f" then
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
  FSM_DATA_OUTPUT : process (FSM_RD_STATE, TRG_WIN_END_RDO_IN, ringBuffer_data_out, epoch_value)
  begin
    trg_win_end_rdo_flag <= trg_win_end_rdo_flag;
    epoch_value          <= epoch_value;

    case FSM_RD_STATE is
      when IDLE =>
        fifo_data          <= (others => '0');
        fifo_data_valid    <= '0';
        ringBuffer_rd_data <= '0';
        fsm_rd_debug       <= x"1";
      when FLUSH_A =>
        fifo_data          <= (others => '0');
        fifo_data_valid    <= '0';
        ringBuffer_rd_data <= '0';
        if TRG_WIN_END_RDO_IN = '1' then
          trg_win_end_rdo_flag <= '1';
        end if;
        fsm_rd_debug <= x"2";
      when FLUSH_B =>
        fifo_data          <= (others => '0');
        fifo_data_valid    <= '0';
        ringBuffer_rd_data <= '0';
        if TRG_WIN_END_RDO_IN = '1' then
          trg_win_end_rdo_flag <= '1';
        end if;
        fsm_rd_debug <= x"3";
      when FLUSH_C =>
        fifo_data          <= (others => '0');
        fifo_data_valid    <= '0';
        ringBuffer_rd_data <= '0';
        if TRG_WIN_END_RDO_IN = '1' then
          trg_win_end_rdo_flag <= '1';
        end if;
        fsm_rd_debug <= x"4";
      when FLUSH_D =>
        fifo_data          <= (others => '0');
        fifo_data_valid    <= '0';
        ringBuffer_rd_data <= '0';
        if ringBuffer_data_out(31 downto 29) = "011" then
          epoch_value <= ringBuffer_data_out;
        end if;
        fsm_rd_debug <= x"5";
      when READOUT_EPOCH =>
        fifo_data          <= epoch_value;
        fifo_data_valid    <= '1';
        ringBuffer_rd_data <= '1';
        fsm_rd_debug       <= x"6";
      when READOUT_DATA_A =>
        fifo_data            <= (others => '0');
        fifo_data_valid      <= '0';
        ringBuffer_rd_data   <= '1';
        trg_win_end_rdo_flag <= '0';
        fsm_rd_debug         <= x"7";
      when READOUT_DATA_B =>
        fifo_data          <= (others => '0');
        fifo_data_valid    <= '0';
        ringBuffer_rd_data <= '1';
        fsm_rd_debug       <= x"8";
      when READOUT_DATA_C =>
        fifo_data <= ringBuffer_data_out;
        if ringBuffer_data_out(35 downto 32) = x"0" then
          fifo_data_valid <= '0';
        else
          fifo_data_valid <= '1';
        end if;
        ringBuffer_rd_data <= '1';
        fsm_rd_debug       <= x"9";
      when others =>
        fifo_data          <= (others => '0');
        fifo_data_valid    <= '0';
        ringBuffer_rd_data <= '0';
        fsm_rd_debug       <= x"0";
    end case;
  end process FSM_DATA_OUTPUT;

  FIFO_DATA_OUT       <= fifo_data;
  FIFO_DATA_VALID_OUT <= fifo_data_valid;

-------------------------------------------------------------------------------
-- DEBUG
-------------------------------------------------------------------------------
  --CHANNEL_200_DEBUG_OUT(7 downto 0)   <= ringBuffer_data_in(35 downto 28);
  --CHANNEL_200_DEBUG_OUT(15 downto 8)  <= fifo_data(35 downto 28);
  --CHANNEL_200_DEBUG_OUT(16)           <= ringBuffer_wr_en;
  --CHANNEL_200_DEBUG_OUT(17)           <= fifo_data_valid;
  --CHANNEL_200_DEBUG_OUT(18)           <= ringBuffer_rd_en;
  --CHANNEL_200_DEBUG_OUT(23 downto 19) <= (others => '0');
  CHANNEL_200_DEBUG_OUT(23 downto 0)  <= (others => '0');
  CHANNEL_200_DEBUG_OUT(27 downto 24) <= fsm_rd_debug;
  CHANNEL_200_DEBUG_OUT(31 downto 28) <= fsm_wr_debug;

  gen_SIMULATION : if SIMULATION = c_YES generate
    -- count data written
    data_cntr : process
    begin
      wait until rising_edge(CLK_100);
      if fifo_data_valid = '1' and fifo_data(31 downto 29) = "100" then
        data_cnt_event <= data_cnt_event + 1;
      elsif fifo_data_valid = '1' and fifo_data(31 downto 29) = "011" then
        epoch_cnt_event <= epoch_cnt_event + 1;
      elsif TRG_WIN_END_RDO_IN = '1' then
        data_cnt_event  <= 0;
        epoch_cnt_event <= 0;
      end if;
    end process data_cntr;

    process(fifo_data_valid)
    begin  -- process
      data_cnt_total  <= data_cnt_total + data_cnt_event;
      epoch_cnt_total <= epoch_cnt_total + epoch_cnt_event;
    end process;

    -- check if data count per event is correct
    --CheckEpochCounter : process
    --begin
    --  wait until falling_edge(fifo_data_valid);
    --  wait for 1 ns;
    --  if data_cnt_event /= 30 then
    --    report "wrong number of hits in channel " & integer'image(CHANNEL_ID) severity error;
    --  end if;
    --end process CheckEpochCounter;

  end generate gen_SIMULATION;
  
end Channel_200;
