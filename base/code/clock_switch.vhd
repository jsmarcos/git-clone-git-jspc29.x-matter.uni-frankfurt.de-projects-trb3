library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  
library work;
  use work.trb_net_components.all;
  use work.trb_net_std.all;
  use work.config.all;

entity clock_switch is
  generic(
    DEFAULT_INTERNAL_TRIGGER  : integer := c_NO
    );
  port (
    INT_CLK_IN   : in std_logic;  -- dont care which clock
    SYS_CLK_IN   : in std_logic;
    
    BUS_RX       : in  CTRLBUS_RX;
    BUS_TX       : out CTRLBUS_TX;

    PLL_LOCK     : in std_logic;
    RESET_IN     : in  std_logic;
    RESET_OUT    : out std_logic;

    CLOCK_SELECT : out std_logic;
    TRIG_SELECT  : out std_logic;
    CLK_MNGR1_USER : out std_logic_vector(3 downto 0);
    CLK_MNGR2_USER : out std_logic_vector(3 downto 0);
    
    DEBUG_OUT      : out std_logic_vector(31 downto 0)
    );
end entity;

architecture clock_switch_arch of clock_switch is
  constant USE_EXTERNAL_CLOCK_std : std_logic := std_logic_vector(to_unsigned(USE_EXTERNAL_CLOCK,1))(0);
  constant DEFAULT_INTERNAL_TRIGGER_std : std_logic := std_logic_vector(to_unsigned(DEFAULT_INTERNAL_TRIGGER,1))(0);

  type INT_FSM_STATES_T is (WAIT_FOR_LOCK, WAIT_PLL_STABLE, OPERATING);
  signal int_fsm_i : INT_FSM_STATES_T := WAIT_FOR_LOCK;
  signal int_fsm_code_i : std_logic_vector(3 downto 0);

  signal select_tc  : std_logic_vector(7 downto 0);
  signal select_trg : std_logic := DEFAULT_INTERNAL_TRIGGER_std;
  signal select_clk : std_logic := USE_EXTERNAL_CLOCK_std;
--   signal select_clk_sys  : std_logic := USE_EXTERNAL_CLOCK_std;
  signal select_clk_qsys : std_logic;
  
begin
  int_fsm_proc: process is
      variable counter_v : integer range 0 to 2**16-1;
  begin
    wait until rising_edge(INT_CLK_IN);
    RESET_OUT <= '1';
    case int_fsm_i is
      when WAIT_FOR_LOCK =>
        int_fsm_code_i <= x"1";
        if PLL_LOCK = '1' then
          int_fsm_i <= WAIT_PLL_STABLE;
          counter_v := 0;
        elsif counter_v = 2**16-1 then
          select_clk <= '0'; 
        else 
          counter_v := counter_v + 1;
        end if;
      
      when WAIT_PLL_STABLE =>
        int_fsm_code_i <= x"2";
        if PLL_LOCK = '0' then
          counter_v := 0;
          int_fsm_i <= WAIT_FOR_LOCK;
        elsif counter_v = 2**12-1 then
          int_fsm_i <= OPERATING;
        else
          counter_v := counter_v + 1;
        end if;  
        
      when OPERATING =>
        int_fsm_code_i <= x"3";
        RESET_OUT <= '0';
--         if PLL_LOCK = '0' and RESET_IN = '0' then
--           int_fsm_i <= WAIT_FOR_LOCK;
--         elsif RESET_IN = '1' then
--           int_fsm_i <= WAIT_RESET;
--           counter_v := 0;
--         end if;
--         
--       when WAIT_RESET =>
--         if RESET_IN = '0' then
--           counter_v := counter_v + 1;\
--         elsif counter_v = 2**16-1 then
--           counter_v := 0;
--           int_fsm_i <= WAIT_FOR_LOCK;
--         else
--           counter_v := 0;
--         end if;  
    end case;
  end process;
            


  TRIG_SELECT    <= select_trg;
  CLOCK_SELECT   <= select_clk; --use on-board oscillator
  CLK_MNGR1_USER <= select_tc(3 downto 0);
  CLK_MNGR2_USER <= select_tc(7 downto 4);  

  
proc_bus : process begin
  wait until rising_edge(SYS_CLK_IN);
  BUS_TX.ack  <= '0';
  BUS_TX.nack <= '0';
  BUS_TX.unknown <= '0';
  BUS_TX.data <= (others => '0');
  
  if BUS_RX.read = '1' then
    BUS_TX.ack <= '1';
    if BUS_RX.addr(0) = '0' then
      BUS_TX.data(0) <= select_trg;
      BUS_TX.data(8) <= select_clk_qsys;
      BUS_TX.data(19 downto 16) <= select_tc(3 downto 0);
      BUS_TX.data(27 downto 24) <= select_tc(7 downto 4);
    else
      BUS_TX.data(3 downto 0) <= int_fsm_code_i;
    end if;
  elsif BUS_RX.write = '1' then
    if BUS_RX.addr(0) = '0' then
      select_trg     <= BUS_RX.data(0);
--       select_clk_sys <= BUS_RX.data(8);
      select_tc(3 downto 0) <= BUS_RX.data(19 downto 16);
      select_tc(7 downto 4) <= BUS_RX.data(27 downto 24);
      BUS_TX.ack <= '1';
    else
      BUS_TX.unknown <= '1';
    end if;
  end if;
end process;  
  
  
SYNC_CLK_INT : signal_sync port map(RESET => '0', CLK0 => SYS_CLK_IN, CLK1 => SYS_CLK_IN, D_IN(0) => select_clk,     D_OUT(0) => select_clk_qsys);  
-- SYNC_CLK_SYS : signal_sync port map(RESET => '0', CLK0 => INT_CLK_IN, CLK1 => INT_CLK_IN, D_IN(0) => select_clk_sys, D_OUT(0) => select_clk_qint);

end architecture;

