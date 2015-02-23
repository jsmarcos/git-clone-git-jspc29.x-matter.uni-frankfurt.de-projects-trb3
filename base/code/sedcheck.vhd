library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;

entity sedcheck is
  port(
    CLK        : in std_logic;
    ERROR_OUT  : out std_logic;
    
    BUS_RX     : in  CTRLBUS_RX;
    BUS_TX     : out CTRLBUS_TX;
    DEBUG      : out std_logic_vector(31 downto 0)
    );
end entity;


architecture sed_arch of sedcheck is
 
  component SEDCA
    generic (
      OSC_DIV : integer :=4 ;
      CHECKALWAYS : string :="DISABLED";
      AUTORECONFIG: string :="OFF" ;
      MCCLK_FREQ : string :="20" ;
      DEV_DENSITY : string :="150K" 
      );
    port (
      SEDENABLE : in std_logic;
      SEDSTART : in std_logic;
      SEDFRCERR : in std_logic;
      SEDERR : out std_logic;
      SEDDONE : out std_logic;
      SEDINPROG : out std_logic;
      SEDCLKOUT : out std_logic
      );
  end component;  
 
  type state_t is (IDLE, INIT_1, INIT_2, INIT_3, START_1, START_2, WAITACTIVE, WAITDONE);
  signal state          : state_t;
  signal state_bits     : std_logic_vector(3 downto 0);

  signal sed_edge       : std_logic;
  signal sed_clock_last : std_logic;

  signal sed_clock      : std_logic;
  signal sed_done       : std_logic;
  signal sed_enable     : std_logic;
  signal sed_error      : std_logic;
  signal sed_inprogress : std_logic;
  signal sed_start      : std_logic;

  signal sed_clock_q      : std_logic;
  signal sed_done_q       : std_logic;
  signal sed_error_q      : std_logic;
  signal sed_inprogress_q : std_logic;

  signal control_i      : std_logic_vector(31 downto 0) := (others => '0');
  signal status_i       : std_logic_vector(31 downto 0);
  
  signal run_counter    : unsigned(7 downto 0) := (others => '0');
  signal error_counter  : unsigned(7 downto 0) := (others => '0');
  signal timer          : unsigned(5 downto 0);
  
begin

sed_clock_last <= sed_clock_q when rising_edge(CLK);
sed_edge       <= sed_clock_q and not sed_clock_last when rising_edge(CLK);

sed_clock_q      <= sed_clock when rising_edge(CLK);
sed_done_q       <= sed_done when rising_edge(CLK);
sed_inprogress_q <= sed_inprogress when rising_edge(CLK);
sed_error_q      <= sed_error when rising_edge(CLK);


---------------------------------------------------------------------------
-- Status / Control Register for internal data bus
---------------------------------------------------------------------------
proc_reg : process begin
  wait until rising_edge(CLK);
  BUS_TX.ack     <= '0';
  BUS_TX.nack    <= '0';
  BUS_TX.unknown <= '0';
  
  if BUS_RX.write = '1' then
    BUS_TX.ack <= '1';
    case BUS_RX.addr(1 downto 0) is
      when "00"   => control_i <= BUS_RX.data;
      when others => BUS_TX.ack <= '0'; BUS_TX.unknown <= '1';
    end case;
  elsif BUS_RX.read = '1' then
    BUS_TX.ack <= '1';
    case BUS_RX.addr(1 downto 0) is
      when "00"   => BUS_TX.data <= control_i;
      when "01"   => BUS_TX.data <= status_i;
      when others => BUS_TX.ack <= '0'; BUS_TX.unknown <= '1';
    end case;
  end if;
end process;

---------------------------------------------------------------------------
-- SED control state machine
---------------------------------------------------------------------------
proc_ctrl : process begin
  wait until rising_edge(CLK);
  timer <= timer + 1;
  case state is
    when IDLE =>
      sed_enable   <= '0';
      sed_start    <= '0';
      if control_i(0) = '1' then
        state      <= INIT_1;
        timer      <= "000001";
      end if;
    when INIT_1 =>
      sed_enable   <= '1';
      sed_start    <= '0';
      if timer = 0 then
        state      <= INIT_2;
      end if;
    when INIT_2 =>
      sed_enable   <= '1';
      sed_start    <= '0';
      if timer = 0 then
        state      <= INIT_3;
      end if;
    when INIT_3 =>
      sed_enable   <= '0';
      sed_start    <= '0';
      if timer = 0 then
        state      <= START_1;
      end if;
    when START_1 =>
      sed_enable   <= '1';
      sed_start    <= '0';
      if sed_edge = '1' then
        state      <= START_2;
      end if;
    when START_2 =>      
      sed_enable   <= '1';
      sed_start    <= '1';
      if sed_edge = '1' and sed_inprogress_q = '1' then
        state      <= WAITACTIVE;
      end if;
    when WAITACTIVE =>
      sed_enable   <= '1';
      sed_start    <= '0';
      if sed_edge = '1' and sed_done_q = '0' then
        state      <= WAITDONE;
      end if;
    when WAITDONE =>
      sed_enable   <= '1';
      sed_start    <= '0';
      if sed_edge = '1' and sed_inprogress_q = '0' and sed_done_q = '1' then
        state       <= INIT_1;
        run_counter <= run_counter + 1;
        if sed_error_q = '1' then
          error_counter <= error_counter + 1;
        end if;
      end if;
  end case;
  
  if control_i(0) = '0' then
    sed_enable <= '0';
    state      <= IDLE;
  end if;
  
end process;

---------------------------------------------------------------------------
-- Status Information
---------------------------------------------------------------------------
state_bits <= x"8" when state = IDLE else
              x"1" when state = INIT_1 else
              x"2" when state = INIT_2 else
              x"3" when state = INIT_3 else
              x"4" when state = START_1 else
              x"5" when state = START_2 else
              x"6" when state = WAITACTIVE else
              x"7" when state = WAITDONE else
--               x"9" when state = RESULT else
              x"F";

status_i(3 downto 0) <= state_bits;
status_i(4)          <= sed_clock_q;
status_i(5)          <= sed_enable;
status_i(6)          <= sed_start;
status_i(7)          <= sed_done_q;
status_i(8)          <= sed_inprogress_q;
status_i(9)          <= sed_error_q;
status_i(10)         <= sed_edge;
status_i(15 downto 11) <= (others => '0');
status_i(23 downto 16) <= std_logic_vector(run_counter)(7 downto 0);
status_i(31 downto 24) <= std_logic_vector(error_counter)(7 downto 0);
              
ERROR_OUT <= sed_error;              
DEBUG     <= status_i when rising_edge(CLK);

---------------------------------------------------------------------------
-- SED
---------------------------------------------------------------------------
THE_SED : SEDCA
  generic map(
      OSC_DIV      => 1,
      CHECKALWAYS  => "DISABLED",
      AUTORECONFIG => "OFF",
      MCCLK_FREQ   => "20",
      DEV_DENSITY  => "150K" 
      )
  port map(
    SEDENABLE => sed_enable,
    SEDSTART  => sed_start,
    SEDFRCERR => '0',
    SEDERR    => sed_error,
    SEDDONE   => sed_done,
    SEDINPROG => sed_inprogress,
    SEDCLKOUT => sed_clock
    );
    
    
end architecture; 
