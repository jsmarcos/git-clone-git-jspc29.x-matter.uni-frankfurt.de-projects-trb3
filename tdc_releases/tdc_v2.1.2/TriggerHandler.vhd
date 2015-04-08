-------------------------------------------------------------------------------
-- Title      : TriggerHandler
-------------------------------------------------------------------------------
-- File       : TriggerHandler.vhd
-- Author     : Cahit Ugur  c.ugur@gsi.de
-- Created    : 2013-03-13
-- Last update: 2015-03-10
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_components.all;
use work.trb3_components.all;

entity TriggerHandler is
  generic (
    TRIGGER_NUM            : integer := 2;   -- number of trigger signals sent
    PHYSICAL_EVENT_TRG_NUM : integer := 0);  -- physical event trigger input number for the trigger window calculations
  port (
    CLK_TRG               : in  std_logic;   -- trigger clock domain
    CLK_RDO               : in  std_logic;   -- readout clock domain
    CLK_TDC               : in  std_logic;   -- tdc clock domain
    RESET_TRG             : in  std_logic;
    RESET_RDO             : in  std_logic;
    RESET_TDC             : in  std_logic;
    VALID_TIMING_TRG_IN   : in  std_logic;
    VALID_NOTIMING_TRG_IN : in  std_logic;
    TRG_TYPE_IN           : in  std_logic_vector(3 downto 0);
    TRG_RELEASE_IN        : in  std_logic;
    TRG_IN                : in  std_logic_vector(TRIGGER_NUM-1 downto 0);
    TRG_RDO_OUT           : out std_logic_vector(TRIGGER_NUM-1 downto 0);
    TRG_TDC_OUT           : out std_logic_vector(TRIGGER_NUM-1 downto 0);
    TRG_WIN_EN_IN         : in  std_logic;
    TRG_WIN_POST_IN       : in  unsigned(10 downto 0);
    TRG_WIN_END_RDO_OUT   : out std_logic;
    TRG_WIN_END_TDC_OUT   : out std_logic;
    MISSING_REF_TIME_OUT  : out std_logic;
    COARSE_COUNTER_IN     : in  std_logic_vector(10 downto 0);
    EPOCH_COUNTER_IN      : in  std_logic_vector(27 downto 0);
    TRG_TIME_OUT          : out std_logic_vector(38 downto 0) := (others => '0');
    DEBUG_OUT             : out std_logic_vector(31 downto 0)
    );

end entity TriggerHandler;

architecture behavioral of TriggerHandler is

  -- trigger signals
  signal trg_in_r              : std_logic_vector(TRIGGER_NUM-1 downto 0);
  signal trg_in_2r             : std_logic_vector(TRIGGER_NUM-1 downto 0);
  signal trg_in_3r             : std_logic_vector(TRIGGER_NUM-1 downto 0);
  signal trg_pulse_trg         : std_logic_vector(TRIGGER_NUM-1 downto 0);
  signal trg_pulse_rdo         : std_logic_vector(TRIGGER_NUM-1 downto 0);
  signal trg_pulse_tdc         : std_logic_vector(TRIGGER_NUM-1 downto 0);
  signal trg_length            : unsigned_array_5(TRIGGER_NUM-1 downto 0);
  signal trg_release_200       : std_logic;
  signal valid_timing_200      : std_logic;
  signal valid_notiming_200    : std_logic;
  signal valid_trigger_flag    : std_logic := '0';
  -- trigger window signals
  type TrgWinCounter_FSM is (IDLE, CHECK_TRIGGER_LENGTH, COUNT, COUNT_CALIBRATION, VALIDATE_TRIGGER, WIN_END,
                             MISSING_REFERENCE_TIME, WAIT_NEXT_TRIGGER);
  signal TrgWin_STATE          : TrgWinCounter_FSM;
  signal trg_win_cnt_f         : unsigned(11 downto 0);
  signal trg_win_cnt_r         : unsigned(11 downto 0);
  signal trg_win_end_f         : std_logic;
  signal trg_win_end_tdc       : std_logic;
  signal trg_win_end_rdo       : std_logic;
  signal missing_ref_time_f    : std_logic;
  signal missing_ref_time_tdc  : std_logic;
  signal missing_ref_time_rdo  : std_logic;
  signal trg_time              : std_logic_vector(38 downto 0) := (others => '0');
  signal trg_win_state_debug_f : std_logic_vector(3 downto 0);
  

begin  -- architecture behavioral

  -- the trigger signals have to be synced
  trg_in_r  <= TRG_IN    when rising_edge(CLK_TDC);
  trg_in_2r <= trg_in_r  when rising_edge(CLK_TDC);
  trg_in_3r <= trg_in_2r when rising_edge(CLK_TDC);

  GEN_TRIGGER : for i in 0 to TRIGGER_NUM-1 generate
    Validation : process (CLK_TDC)
    begin
      if rising_edge(CLK_TDC) then

        -- calculate trigger length
        if trg_in_3r(i) = '0' then
          trg_length(i) <= (others => '0');
        else
          trg_length(i) <= trg_length(i) + to_unsigned(1, 5);
        end if;

        -- accept trigger if it is longer than 100 ns
        if RESET_TDC = '1' then
          trg_pulse_tdc(i) <= '0';
        elsif trg_length(i) = to_unsigned(20, 5) then
          trg_pulse_tdc(i) <= '1';
        else
          trg_pulse_tdc(i) <= '0';
        end if;
        
      end if;
    end process Validation;
  end generate GEN_TRIGGER;

  -- sync the strobes to the readout clock domain
  GEN_TDC : for i in 0 to TRIGGER_NUM-1 generate
    ThePulseSync : pulse_sync
      port map (
        CLK_A_IN    => CLK_TDC,
        RESET_A_IN  => RESET_TDC,
        PULSE_A_IN  => trg_pulse_tdc(i),
        CLK_B_IN    => CLK_RDO,
        RESET_B_IN  => RESET_RDO,
        PULSE_B_OUT => trg_pulse_rdo(i));
  end generate GEN_TDC;

  TRG_RDO_OUT <= trg_pulse_rdo when rising_edge(CLK_RDO);
  TRG_TDC_OUT <= trg_pulse_tdc when rising_edge(CLK_TDC);

  ValidateTrigger : process (CLK_TDC) is
  begin
    if rising_edge(CLK_TDC) then        -- rising clock edge
      if RESET_TDC = '1' then
        valid_trigger_flag <= '0';
      elsif valid_timing_200 = '1' then
        valid_trigger_flag <= '1';
      elsif trg_release_200 = '1' then
        valid_trigger_flag <= '0';
      end if;
    end if;
  end process ValidateTrigger;

  TriggerReleaseSync : entity work.pulse_sync
    port map (
      CLK_A_IN    => CLK_RDO,
      RESET_A_IN  => RESET_RDO,
      PULSE_A_IN  => TRG_RELEASE_IN,
      CLK_B_IN    => CLK_TDC,
      RESET_B_IN  => RESET_TDC,
      PULSE_B_OUT => trg_release_200);

  ValidTriggerSync : entity work.pulse_sync
    port map (
      CLK_A_IN    => CLK_RDO,
      RESET_A_IN  => RESET_RDO,
      PULSE_A_IN  => VALID_TIMING_TRG_IN,
      CLK_B_IN    => CLK_TDC,
      RESET_B_IN  => RESET_TDC,
      PULSE_B_OUT => valid_timing_200);
  
  ValidNoTriggerSync : entity work.pulse_sync
    port map (
      CLK_A_IN    => CLK_RDO,
      RESET_A_IN  => RESET_RDO,
      PULSE_A_IN  => VALID_NOTIMING_TRG_IN,
      CLK_B_IN    => CLK_TDC,
      RESET_B_IN  => RESET_TDC,
      PULSE_B_OUT => valid_notiming_200);

  -- A Moore machine's outputs are dependent only on the current state.
  -- The output is written only when the state changes.  (State
  -- transitions are synchronous.)
  -- Logic to advance to the next state
  TrgWinState : process (CLK_TDC)
  begin
    if rising_edge(CLK_TDC) then
      if RESET_TDC = '1' then
        TrgWin_STATE <= IDLE;
      else
        case TrgWin_STATE is
          when IDLE =>
            if trg_in_3r(0) = '1' then
              if TRG_WIN_EN_IN = '1' then
                TrgWin_STATE <= COUNT;
              else
                TrgWin_STATE <= VALIDATE_TRIGGER;
              end if;
            elsif valid_notiming_200 = '1' then
              if TRG_TYPE_IN = x"D" then
                TrgWin_STATE <= COUNT_CALIBRATION;
              else
                TrgWin_STATE <= WIN_END;
              end if;
            elsif valid_timing_200 = '1' then
              TrgWin_STATE <= MISSING_REFERENCE_TIME;
            else
              TrgWin_STATE <= IDLE;
            end if;
            

          when COUNT =>
            if trg_win_cnt_r(10 downto 0) = TRG_WIN_POST_IN then
              TrgWin_STATE <= VALIDATE_TRIGGER;
            else
              TrgWin_STATE <= COUNT;
            end if;

          when COUNT_CALIBRATION =>
            if trg_win_cnt_r(5) = '1' then
              TrgWin_STATE <= WIN_END;
            else
              TrgWin_STATE <= COUNT_CALIBRATION;
            end if;

          when VALIDATE_TRIGGER =>
            if valid_trigger_flag = '1' then
              TrgWin_STATE <= WIN_END;
            else
              TrgWin_STATE <= VALIDATE_TRIGGER;
            end if;

          when WIN_END =>
            TrgWin_STATE <= WAIT_NEXT_TRIGGER;

          when MISSING_REFERENCE_TIME =>
            TrgWin_STATE <= WAIT_NEXT_TRIGGER;

          when WAIT_NEXT_TRIGGER =>
            if trg_release_200 = '1' then
              TrgWin_STATE <= IDLE;
            else
              TrgWin_STATE <= WAIT_NEXT_TRIGGER;
            end if;
          when others =>
            TrgWin_STATE <= IDLE;
        end case;
      end if;
    end if;
  end process TrgWinState;

  -- Output depends solely on the current state
  TrgWinOutput : process (TrgWin_STATE, trg_win_cnt_r)
  begin
    trg_win_cnt_f         <= x"00a";
    trg_win_end_f         <= '0';
    missing_ref_time_f    <= '0';
    trg_win_state_debug_f <= x"0";
    case TrgWin_STATE is
      when IDLE =>
        trg_win_state_debug_f <= x"1";

      when CHECK_TRIGGER_LENGTH =>
        trg_win_state_debug_f <= x"2";
        
      when COUNT =>
        trg_win_cnt_f         <= trg_win_cnt_r + to_unsigned(1, 12);
        trg_win_state_debug_f <= x"3";
        
      when COUNT_CALIBRATION =>
        trg_win_cnt_f         <= trg_win_cnt_r + to_unsigned(1, 12);
        trg_win_state_debug_f <= x"4";

      when VALIDATE_TRIGGER =>
        trg_win_end_f         <= '0';
        trg_win_state_debug_f <= x"5";
        
      when WIN_END =>
        trg_win_end_f         <= '1';
        trg_win_state_debug_f <= x"6";

      when MISSING_REFERENCE_TIME =>
        trg_win_end_f         <= '1';
        missing_ref_time_f    <= '1';
        trg_win_state_debug_f <= x"7";
        
      when WAIT_NEXT_TRIGGER =>
        trg_win_end_f         <= '0';
        trg_win_state_debug_f <= x"8";
    end case;
  end process TrgWinOutput;
  trg_win_cnt_r           <= trg_win_cnt_f         when rising_edge(CLK_TDC);
  trg_win_end_tdc         <= trg_win_end_f         when rising_edge(CLK_TDC);
  missing_ref_time_tdc    <= missing_ref_time_f    when rising_edge(CLK_TDC);
  DEBUG_OUT(23 downto 20) <= trg_win_state_debug_f when rising_edge(CLK_RDO);

  DEBUG_OUT(19 downto 0)  <= (others => '0');
  DEBUG_OUT(31 downto 24) <= (others => '0');

  -- syn trg window end strobe to readout clock domain
  TrgWinEndPulseSync : pulse_sync
    port map (
      CLK_A_IN    => CLK_TDC,
      RESET_A_IN  => RESET_TDC,
      PULSE_A_IN  => trg_win_end_tdc,
      CLK_B_IN    => CLK_RDO,
      RESET_B_IN  => RESET_RDO,
      PULSE_B_OUT => trg_win_end_rdo);

  TRG_WIN_END_TDC_OUT <= trg_win_end_tdc;
  TRG_WIN_END_RDO_OUT <= trg_win_end_rdo;

  -- syn missing reference time strobe to readout clock domain
  MissRefTimePulseSync : pulse_sync
    port map (
      CLK_A_IN    => CLK_TDC,
      RESET_A_IN  => RESET_TDC,
      PULSE_A_IN  => missing_ref_time_tdc,
      CLK_B_IN    => CLK_RDO,
      RESET_B_IN  => RESET_RDO,
      PULSE_B_OUT => missing_ref_time_rdo);

  MISSING_REF_TIME_OUT <= missing_ref_time_rdo;

  TriggerTime : process (CLK_TDC)
  begin
    if rising_edge(CLK_TDC) then
      if trg_in_2r(0) = '1' and trg_in_3r(0) = '0' then
        trg_time <= EPOCH_COUNTER_IN & COARSE_COUNTER_IN;
      end if;
      if trg_pulse_tdc(0) = '1' then
        TRG_TIME_OUT <= std_logic_vector(unsigned(trg_time) - to_unsigned(2, 39));
      end if;
    end if;
  end process TriggerTime;


end architecture behavioral;
