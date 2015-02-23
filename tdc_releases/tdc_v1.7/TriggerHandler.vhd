-------------------------------------------------------------------------------
-- Title      : TriggerHandler
-------------------------------------------------------------------------------
-- File       : TriggerHandler.vhd
-- Author     : Cahit Ugur  c.ugur@gsi.de
-- Created    : 2013-03-13
-- Last update: 2014-06-20
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
--use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;


entity TriggerHandler is
  generic (
    TRIGGER_NUM            : integer := 2;   -- number of trigger signals sent
    PHYSICAL_EVENT_TRG_NUM : integer := 0);  -- physical event trigger input number for the trigger window calculations
  port (
    CLK_TRG                 : in  std_logic;  -- trigger clock domain
    CLK_RDO                 : in  std_logic;  -- readout clock domain
    CLK_TDC                 : in  std_logic;  -- tdc clock domain
    RESET_TRG               : in  std_logic;
    RESET_RDO               : in  std_logic;
    RESET_TDC               : in  std_logic;
    TRIGGER_IN              : in  std_logic_vector(TRIGGER_NUM-1 downto 0);
    TRIGGER_RDO_OUT         : out std_logic_vector(TRIGGER_NUM-1 downto 0);
    TRIGGER_TDC_OUT         : out std_logic_vector(TRIGGER_NUM-1 downto 0);
    TRIGGER_WIN_EN_IN       : in  std_logic;
    TRIGGER_WIN_POST_IN     : in  unsigned(10 downto 0);
    TRIGGER_WIN_END_RDO_OUT : out std_logic;
    TRIGGER_WIN_END_TDC_OUT : out std_logic;
    COARSE_COUNTER_IN       : in  std_logic_vector(10 downto 0);
    EPOCH_COUNTER_IN        : in  std_logic_vector(27 downto 0);
    TRIGGER_TIME_OUT        : out std_logic_vector(38 downto 0) := (others => '0')
    );

end entity TriggerHandler;

architecture behavioral of TriggerHandler is

  -- trigger signals
  signal trigger_in_reg    : std_logic_vector(TRIGGER_NUM-1 downto 0);
  signal trigger_in_2reg   : std_logic_vector(TRIGGER_NUM-1 downto 0);
  signal trigger_in_3reg   : std_logic_vector(TRIGGER_NUM-1 downto 0);
  signal trigger_pulse_trg : std_logic_vector(TRIGGER_NUM-1 downto 0);
  signal trigger_pulse_rdo : std_logic_vector(TRIGGER_NUM-1 downto 0);
  signal trigger_pulse_tdc : std_logic_vector(TRIGGER_NUM-1 downto 0);
  signal trigger_length    : unsigned_array_5(TRIGGER_NUM-1 downto 0);
  -- trigger window signals
  type TriggerWinCounter_FSM is (IDLE, COUNT, WIN_END);
  signal TrigWin_STATE     : TriggerWinCounter_FSM;
  signal trig_win_cnt_f    : unsigned(10 downto 0);
  signal trig_win_cnt_r    : unsigned(10 downto 0);
  signal trig_win_end_f    : std_logic;
  signal trig_win_end_tdc  : std_logic;
  signal trig_win_end_rdo  : std_logic;
  signal trigger_time_i    : std_logic_vector(38 downto 0) := (others => '0');
  

begin  -- architecture behavioral

  -- the trigger signals have to be synced
  trigger_in_reg  <= TRIGGER_IN      when rising_edge(CLK_TDC);
  trigger_in_2reg <= trigger_in_reg  when rising_edge(CLK_TDC);
  trigger_in_3reg <= trigger_in_2reg when rising_edge(CLK_TDC);

  GEN_TRIGGER : for i in 0 to TRIGGER_NUM-1 generate
    Validation : process (CLK_TDC)
    begin
      if rising_edge(CLK_TDC) then

        -- calculate trigger length
        if trigger_in_3reg(i) = '0' then
          trigger_length(i) <= (others => '0');
        else
          trigger_length(i) <= trigger_length(i) + to_unsigned(1, 5);
        end if;

        -- accept trigger if it is longer than 150 ns
        if RESET_TDC = '1' then
          trigger_pulse_tdc(i) <= '0';
        elsif trigger_length(i) = to_unsigned(15, 5) then
          trigger_pulse_tdc(i) <= '1';
        else
          trigger_pulse_tdc(i) <= '0';
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
        PULSE_A_IN  => trigger_pulse_tdc(i),
        CLK_B_IN    => CLK_RDO,
        RESET_B_IN  => RESET_RDO,
        PULSE_B_OUT => trigger_pulse_rdo(i));
  end generate GEN_TDC;

  TRIGGER_RDO_OUT <= trigger_pulse_rdo;
  TRIGGER_TDC_OUT <= trigger_pulse_tdc;

  -- A Moore machine's outputs are dependent only on the current state.
  -- The output is written only when the state changes.  (State
  -- transitions are synchronous.)
  -- Logic to advance to the next state
  TrigWinState : process (CLK_TDC)
  begin
    if rising_edge(CLK_TDC) then
      if RESET_TDC = '1' then
        TrigWin_STATE <= IDLE;
      else
        case TrigWin_STATE is
          when IDLE =>
            if trigger_pulse_tdc(0) = '1' then
              if TRIGGER_WIN_EN_IN = '1' then
                TrigWin_STATE <= COUNT;
              else
                TrigWin_STATE <= WIN_END;
              end if;
            --elsif trigger_pulse_tdc(1) = '1' then
            --  TrigWin_STATE <= WIN_END;
            else
              TrigWin_STATE <= IDLE;
            end if;
          when COUNT =>
            if trig_win_cnt_r = TRIGGER_WIN_POST_IN + to_unsigned(4,11) then
              TrigWin_STATE <= WIN_END;
            else
              TrigWin_STATE <= COUNT;
            end if;
          when WIN_END =>
            TrigWin_STATE <= IDLE;
          when others =>
            TrigWin_STATE <= IDLE;
        end case;
      end if;
    end if;
  end process TrigWinState;

  -- Output depends solely on the current state
  TrigWinOutput : process (TrigWin_STATE, trig_win_cnt_r)
  begin
    trig_win_cnt_f <= "00000000011";
    trig_win_end_f <= '0';
    case TrigWin_STATE is
      when IDLE =>

      when COUNT =>
        trig_win_cnt_f <= trig_win_cnt_r + to_unsigned(1, 1);
      when WIN_END =>
        trig_win_end_f <= '1';
    end case;
  end process TrigWinOutput;
  trig_win_cnt_r   <= trig_win_cnt_f when rising_edge(CLK_TDC);
  trig_win_end_tdc <= trig_win_end_f when rising_edge(CLK_TDC);

  -- syn trigger window end strobe to readout clock domain
  ThePulseSync : pulse_sync
    port map (
      CLK_A_IN    => CLK_TDC,
      RESET_A_IN  => RESET_TDC,
      PULSE_A_IN  => trig_win_end_tdc,
      CLK_B_IN    => CLK_RDO,
      RESET_B_IN  => RESET_RDO,
      PULSE_B_OUT => trig_win_end_rdo);

  TRIGGER_WIN_END_TDC_OUT <= trig_win_end_tdc;
  TRIGGER_WIN_END_RDO_OUT <= trig_win_end_rdo;

  TriggerTime : process (CLK_TDC)
  begin
    if rising_edge(CLK_TDC) then
      if trigger_in_2reg(0) = '1' and trigger_in_3reg(0) = '0' then
        trigger_time_i <= EPOCH_COUNTER_IN & COARSE_COUNTER_IN;
      end if;
      if trigger_pulse_tdc(0) = '1' then
        TRIGGER_TIME_OUT <= trigger_time_i;
      end if;
    end if;
  end process TriggerTime;


end architecture behavioral;
