library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_arith.all;
use IEEE.STD_LOGIC_unsigned.all;


entity f_divider is

  generic(
    cnt : integer := 4000  -- Der Teiler teilt durch "cnt" , wenn Test = 0  ist.  --
    );

  port (
    clk     : in  std_logic;
    ena_cnt : in  std_logic;
    f_div   : out std_logic
    );

end f_divider;



architecture arch_f_divider of f_divider is

  function How_many_Bits (int : integer) return integer is
    variable i, tmp           : integer;
  begin
    tmp   := int;
    i     := 0;
    while tmp > 0 loop
      tmp := tmp / 2;
      i   := i + 1;
    end loop;
    return i;
  end How_many_bits;


  --+          
  --| Wie Breit muss der Teiler sein, um durch "cnt" teilen zu können?                                                  |
  --+          
  constant c_counter_width : integer := How_many_Bits(cnt - 2);

  --+                                   ---------------------------------------------------------------------------------------------+
  --| Des Zähler "s_counter" muss ein Bit breiter definiert werden, als zur Abarbeitung des "cnt"       |
  --| nötig wäre. Dieses Bit wird beim Zählerunterlauf '1'. Der Zählerablauf wird dadurch ohne  |
  --| Komparator erkannt, er steht als getaktetes physikalisches Signal zur Verfügung.                  |
  --+                                   ---------------------------------------------------------------------------------------------+
  signal s_counter : std_logic_vector(c_counter_width downto 0) := conv_std_logic_vector(0, c_counter_width+1);

  --+                                   ---------------------------------------------------------------------------------------------+
  --| Teiler muss mit einen um -2 geringeren Wert geladen werden. Da das Neuladen erst durch dem        |
  --| Unterlauf Zählers erfolgt. D.h. die Null und minus Eins werden mitgezählt.                                        |
  --+                                   ---------------------------------------------------------------------------------------------+
  constant c_ld_value : integer := cnt - 2;

begin
  p_f_divider : process (clk)
  begin
    if clk'event and clk = '1' then
      if s_counter(s_counter'high) = '1' then  -- Bei underflow wird neu geladen  --
        s_counter   <= conv_std_logic_vector(c_ld_value, s_counter'length);
      elsif ena_cnt = '1' then
        if s_counter(s_counter'high) = '0' then  -- Kein underflow erreicht weiter  --
          s_counter <= s_counter - 1;  -- subtrahieren.  --
        end if;
      end if;
    end if;
  end process p_f_divider;

  f_div <= s_counter(s_counter'high);

end arch_f_divider;




library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;


--library synplify;
--use synplify.attributes.all;


entity edge_to_pulse is

  port (
    clock     : in  std_logic;
    en_clk    : in  std_logic;
    signal_in : in  std_logic;
    pulse     : out std_logic);

end edge_to_pulse;

architecture arch_edge_to_pulse of edge_to_pulse is
--  signal signal_sync               : std_logic;
--  signal old_sync                  : std_logic;
  signal pulse_fsm                 : std_logic;
  type state is (idle, high, wait_for_low);  -- state
  signal current_state, next_state : state;

begin  -- arch_edge_to_pulse

  fsm : process (clock)
  begin  -- process fsm
    if rising_edge(clock) then          -- rising clock edge
      if en_clk = '1' then
        current_state <= next_state;
--        signal_sync   <= signal_in;
        pulse         <= pulse_fsm;
      end if;
    end if;
  end process fsm;


  fsm_comb : process (current_state, signal_in)
  begin  -- process fsm_comb
    case current_state is
      when idle         =>
        pulse_fsm    <= '0';
        if signal_in = '1' then
          next_state <= high;
        else
          next_state <= idle;
        end if;
--
      when high         =>
        pulse_fsm    <= '1';
        next_state   <= wait_for_low;
-- when wait_for_low_1 =>
-- pulse <= '1';
-- next_state <= wait_for_low;
--
      when wait_for_low =>
        pulse_fsm    <= '0';
        if signal_in = '0' then
          next_state <= idle;
        else
          next_state <= wait_for_low;
        end if;
--
      when others       =>
        pulse_fsm    <= '0';
        next_state   <= idle;
    end case;
  end process fsm_comb;


end arch_edge_to_pulse;



library IEEE;
use IEEE.STD_LOGIC_1164.all;

package support is

  component f_divider
    generic (
      cnt     :     integer);
    port (
      clk     : in  std_logic;
      ena_cnt : in  std_logic;
      f_div   : out std_logic);
  end component;

  component edge_to_pulse
    port (
      clock     : in  std_logic;
      en_clk    : in  std_logic;
      signal_in : in  std_logic;
      pulse     : out std_logic);
  end component;
  

end support;

