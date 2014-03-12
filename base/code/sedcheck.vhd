library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity sedcheck is
  port(
    CLK        : in std_logic;
    ERROR_OUT  : out std_logic;
    
    DATA_IN    : in  std_logic_vector(31 downto 0) := (others => '0');
    DATA_OUT   : out std_logic_vector(31 downto 0);
    WRITE_IN   : in  std_logic := '0';
    READ_IN    : in  std_logic := '0';
    ACK_OUT    : out std_logic;
    NACK_OUT   : out std_logic;
    ADDR_IN    : in  std_logic_vector(15 downto 0) := (others => '0')    
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
 
  type state_t is (IDLE, INIT_1, INIT_2, INIT_3, START_1, START_2, WAITACTIVE, WAITDONE, RESULT);
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
  signal sed_done_reg       : std_logic;
  signal sed_error_reg      : std_logic;
  signal sed_inprogress_reg : std_logic;

  signal control_i      : std_logic_vector(31 downto 0) := (others => '0');
  signal status_i       : std_logic_vector(31 downto 0);
  
  signal run_counter    : unsigned(7 downto 0) := (others => '0');
  signal error_counter  : unsigned(7 downto 0) := (others => '0');
  signal timer          : unsigned(5 downto 0);
  
begin

sed_clock_last <= sed_clock_q when rising_edge(CLK);
sed_edge       <= not sed_clock_q and sed_clock_last;

sed_clock_q      <= sed_clock when rising_edge(CLK);

sed_done_q       <= sed_done_reg when rising_edge(CLK);
sed_inprogress_q <= sed_inprogress_reg when rising_edge(CLK);
sed_error_q      <= sed_error_reg when rising_edge(CLK);

sed_error_reg      <= sed_error when falling_edge(sed_clock);
sed_done_reg       <= sed_done when falling_edge(sed_clock);
sed_inprogress_reg <= sed_inprogress when falling_edge(sed_clock);

---------------------------------------------------------------------------
-- Status / Control Register for internal data bus
---------------------------------------------------------------------------
proc_reg : process begin
  wait until rising_edge(CLK);
  ACK_OUT  <= '0';
  NACK_OUT <= '0';
  if WRITE_IN = '1' then
    ACK_OUT <= '1';
    case ADDR_IN(1 downto 0) is
      when "00"   => control_i <= DATA_IN;
      when others => ACK_OUT <= '0'; NACK_OUT <= '1';
    end case;
  elsif READ_IN = '1' then
    ACK_OUT <= '1';
    case ADDR_IN(1 downto 0) is
      when "00"   => DATA_OUT <= control_i;
      when "01"   => DATA_OUT <= status_i;
      when others => ACK_OUT <= '0'; NACK_OUT <= '1';
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
          state   <= INIT_1;
          timer   <= "000001";
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
      if sed_edge = '1' then
        state      <= WAITACTIVE;
      end if;
    when WAITACTIVE =>
      sed_enable   <= '1';
      sed_start    <= '0';
      if sed_edge = '1' and sed_done_q = '0' then
        state      <= WAITDONE;
      end if;
    when WAITDONE =>
      if sed_edge = '1' and sed_inprogress_q = '0' and sed_done_q = '1' then
        state       <= RESULT;
        timer   <= "000001";
      end if;
    when RESULT =>
--       if timer = 0 then
        state       <= IDLE;
        run_counter <= run_counter + 1;
        if sed_error_q = '1' then
          error_counter <= error_counter + 1;
        end if;
--       end if;
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
              x"9" when state = RESULT else
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
