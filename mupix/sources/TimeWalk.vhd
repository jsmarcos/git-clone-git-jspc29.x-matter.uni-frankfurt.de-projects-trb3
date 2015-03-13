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
  signal hitbus_edge               : std_logic_vector(1 downto 0) := (others => '0');
  signal szintillator_trigger_edge : std_logic_vector(1 downto 0) := (others => '0');
  signal hitbusBuffer : std_logic := '0';
  signal szintilatorTriggerBuffer : std_logic := '0';
  type TimeWalk_fsm_type is (idle, waitforhitbus, measurehitbus, measurement_done);
  signal timewalk_fsm              : TimeWalk_fsm_type            := idle;

  
begin  -- architecture TimeWalk_Arch

  -- purpose: synchronize signals and edge detection
  signal_synchro: process (clk) is
  begin  -- process clk
    if rising_edge(clk) then
      hitbusBuffer <= hitbus;
      szintilatorTriggerBuffer <= szintillator_trigger;
      hitbus_edge               <= hitbus_edge(0) & hitbusBuffer;
      szintillator_trigger_edge <= szintillator_trigger_edge(0) & szintilatorTriggerBuffer;  
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
          latencycounter <= latencycounter + 1;
        end if;
        when waitforhitbus =>
        latencycounter <= latencycounter + 1;
        if latencycounter = unsigned(hitbus_timeout(15 downto 0)) then
          timewalk_fsm <= idle;
        elsif hitbus_edge = "01" then
          timewalk_fsm  <= measurehitbus;
          hitbuscounter <= hitbuscounter + 1;
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
