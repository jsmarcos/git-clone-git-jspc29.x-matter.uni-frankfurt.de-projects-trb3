-----------------------------------------------------------
--Measurement of Time-Walk (latency vs.  energy deposition)
--T. Weber, Mainz University
-----------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;


entity TimeWalk is
  port (
    clk                  : in  std_logic;
    reset                : in  std_logic;
    hitbus               : in  std_logic;
    hitbus_timeout       : in  std_logic_vector(31 downto 0);
    szintillator_trigger : in  std_logic;
    readyToWrite         : in  std_logic;
    measurementFinished  : out std_logic;
    measurementData      : out std_logic_vector(31 downto 0));
end entity TimeWalk;

architecture TimeWalk_Arch of TimeWalk is

  signal latencycounter            : unsigned(15 downto 0)        := (others => '0');
  signal hitbuscounter             : unsigned(15 downto 0)        := (others => '0');
  signal hitbus_delayed            : std_logic := '0';
  signal hitbus_edge               : std_logic_vector(1 downto 0) := (others => '0');
  signal szintillator_trigger_edge : std_logic_vector(1 downto 0) := (others => '0');
  signal szintillator_trigger_buffer : std_logic := '0';
  type TimeWalk_fsm_type is (idle, waitforhitbus, measurehitbus, measurement_done);
  signal timewalk_fsm              : TimeWalk_fsm_type            := idle;

  component SignalDelay is
    generic (
      Width : integer range 1 to 32;
      Delay : integer range 2 to 8);
    port (
      clk_in   : in  std_logic;
      write_en_in : in std_logic;
      delay_in : in  std_logic_vector(Delay - 1 downto 0);
      sig_in   : in  std_logic_vector(Width - 1 downto 0);
      sig_out  : out std_logic_vector(Width - 1 downto 0));
  end component SignalDelay;
  
begin  -- architecture TimeWalk_Arch

  SignalDelay_1: entity work.SignalDelay
    generic map (
      Width => 1,
      Delay => 12)
    port map (
      clk_in   => clk,
      write_en_in => '1',
      delay_in => std_logic_vector(to_unsigned(16,12)),
      sig_in(0)   => hitbus,
      sig_out(0)  => hitbus_delayed);
  
  -- purpose: synchronize signals and edge detection
  signal_synchro: process (clk) is
  begin  -- process clk
    if rising_edge(clk) then
      hitbus_edge               <= hitbus_edge(0) & hitbus_delayed;
      szintillator_trigger_buffer <= szintillator_trigger;
      szintillator_trigger_edge <= szintillator_trigger_edge(0) & szintillator_trigger_buffer;  
    end if;
  end process signal_synchro;

  TimeWalk_Measurement : process (clk, reset) is
  begin  -- process TimeWalk_Measurement
    if rising_edge(clk) then
      measurementFinished  <= '0';
      measurementData      <= (others => '0');
      case timewalk_fsm is
        when idle =>
        latencycounter <= (others => '0');
        hitbuscounter  <= (others => '0');
        if szintillator_trigger_edge = "01" then
          timewalk_fsm   <= waitforhitbus;
          latencycounter <= to_unsigned(1,16);
        end if;
        when waitforhitbus =>
        latencycounter <= latencycounter + 1;
        if latencycounter = unsigned(hitbus_timeout(15 downto 0)) then
          timewalk_fsm <= idle;
        elsif hitbus_edge = "01" then
          timewalk_fsm  <= measurehitbus;
          hitbuscounter <= to_unsigned(1,16);
        else
          timewalk_fsm <= waitforhitbus;
        end if;
        when measurehitbus =>
        hitbuscounter <= hitbuscounter + 1;
        timewalk_fsm  <= measurehitbus;
        if hitbus_edge = "00" then
          timewalk_fsm <= measurement_done;
        end if;
        when measurement_done =>
        timewalk_fsm <= idle;
        if readyToWrite = '1' then
          measurementData        <= std_logic_vector(latencycounter & hitbuscounter);
          measurementFinished    <= '1';
        end if;
        when others => null;
      end case;
    end if;
  end process TimeWalk_Measurement;

end architecture TimeWalk_Arch;
