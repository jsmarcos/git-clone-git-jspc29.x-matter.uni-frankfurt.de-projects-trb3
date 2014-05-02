library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.trb_net_std.all;


entity input_statistics is
  generic(
    INPUTS     : integer range 1 to 32 := 16
    );
  port(
    CLK        : in std_logic;
    
    INPUT      : in  std_logic_vector(INPUTS-1 downto 0);

    DATA_IN    : in  std_logic_vector(31 downto 0) := (others => '0');
    DATA_OUT   : out std_logic_vector(31 downto 0);
    WRITE_IN   : in  std_logic := '0';
    READ_IN    : in  std_logic := '0';
    ACK_OUT    : out std_logic;
    NACK_OUT   : out std_logic;
    ADDR_IN    : in  std_logic_vector(15 downto 0) := (others => '0')
    
    );
end entity;


architecture input_statistics_arch of input_statistics is

signal inp_reg      : std_logic_vector(INPUTS-1 downto 0);
signal inp_reg_last : std_logic_vector(INPUTS-1 downto 0);

signal trigger_fifo : std_logic;
signal reset_cnt    : std_logic;
signal timer_rst    : std_logic;

signal enable : std_logic_vector(31 downto 0);
signal invert : std_logic_vector(31 downto 0);
signal rate   : unsigned(31 downto 0);

signal fifo_read   : std_logic_vector(31 downto 0);
signal fifo_wait,fifo_wait2,fifo_wait3   : std_logic;
signal fifo_empty  : std_logic_vector(31 downto 0);
signal fifo_write  : std_logic;
signal fifo_select : integer range 0 to 31;

type cnt_t is array(0 to 31) of unsigned(23 downto 0);
signal cnt : cnt_t;

type dout_t is array(0 to 31) of std_logic_vector(17 downto 0);
signal fifo_dout : dout_t;

type fifo_count_t is array(0 to 31) of std_logic_vector(10 downto 0);
signal fifo_count : fifo_count_t;

signal timer    : unsigned(31 downto 0);
signal word_cnt : unsigned(11 downto 0);

type state_t is (IDLE,RUN,CHECK);
signal state : state_t;

signal status_reg : std_logic_vector(31 downto 0);

begin


THE_CONTROL : process 
  variable tmp : integer range 0 to 31;
begin
  wait until rising_edge(CLK);
  ACK_OUT  <= '0';
  NACK_OUT <= '0';
  trigger_fifo  <= '0';
  reset_cnt     <= '0';
  timer_rst     <= '0';
  fifo_read     <= (others => '0');
  fifo_wait     <= '0';
  tmp := to_integer(unsigned(ADDR_IN(4 downto 0)));
  if WRITE_IN = '1' then
    if ADDR_IN(6 downto 4) = "000" and tmp < INPUTS then
      ACK_OUT <= '1';
      case ADDR_IN(3 downto 0) is
        when x"0"   => enable <= DATA_IN;
        when x"1"   => invert <= DATA_IN;
        when x"2"   => rate   <= unsigned(DATA_IN);
                       timer_rst    <= '1';
        when x"f"   => trigger_fifo <= DATA_IN(0);
                       reset_cnt    <= DATA_IN(1);
        when others => NACK_OUT <= '1'; ACK_OUT <= '0';
      end case;
    else 
      NACK_OUT <= '1';
    end if;
  elsif READ_IN = '1' then
    if ADDR_IN(6 downto 4) = "000" and tmp < INPUTS then
      ACK_OUT <= '1';
      case ADDR_IN(3 downto 0) is
        when x"0"   => DATA_OUT <= enable;
        when x"1"   => DATA_OUT <= invert;
        when x"2"   => DATA_OUT <= std_logic_vector(rate);
        when x"3"   => DATA_OUT <= timer;
        when x"4"   => DATA_OUT <= status_reg;
        when x"e"   => DATA_OUT(INPUTS-1 downto 0)  <= inp_reg; DATA_OUT(31 downto INPUTS) <= (others => '0');
        when others => DATA_OUT <= (others => '0');
      end case;
    elsif ADDR_IN(6 downto 5) = "01" and tmp < INPUTS then
      fifo_read(to_integer(unsigned(ADDR_IN(4 downto 0)))) <= '1';
      fifo_select <= to_integer(unsigned(ADDR_IN(4 downto 0)));
      fifo_wait <= '1';
    elsif ADDR_IN(6 downto 5) = "10" and tmp < INPUTS then
      DATA_OUT(23 downto 0) <= cnt(to_integer(unsigned(ADDR_IN(4 downto 0))));
      ACK_OUT               <= '1';
    else
      NACK_OUT              <= '1';
    end if;
  elsif fifo_wait3 = '1' then
    DATA_OUT(17 downto 0) <= fifo_dout(fifo_select);
    DATA_OUT(31)          <= fifo_empty(fifo_select);
    DATA_OUT(30 downto 18)<= (others => '0');
    ACK_OUT <= '1';
  end if;
end process;

fifo_wait2 <= fifo_wait when rising_edge(CLK);
fifo_wait3 <= fifo_wait2 when rising_edge(CLK);

inp_reg <= INPUT when rising_edge(CLK);
inp_reg_last <= inp_reg when rising_edge(CLK);

gen_counters : for i in 0 to INPUTS-1 generate
  process begin
    wait until rising_edge(CLK);
    if reset_cnt = '1' then
      cnt(i) <= (others => '0');
    elsif inp_reg(i) = not invert(i) and inp_reg_last(i) = invert(i) and enable(i) = '1' then
      cnt(i) <= cnt(i) + 1;
    end if;
  end process;
end generate;


proc_ctrl : process begin
  wait until rising_edge(CLK);
  fifo_write <= '0';
  case state is 
    when IDLE =>
      if trigger_fifo = '1' then
        state <= RUN;
        word_cnt <= (others => '0');
      end if;
    when RUN =>
      timer <= timer + 1;
      if timer = rate then
        fifo_write <= '1';
        word_cnt   <= word_cnt + 1;
        timer      <= (others => '0');
        state      <= CHECK;
      end if;
    
    when CHECK =>
      if word_cnt = x"400" then
        state <= IDLE;
      else
        state <= RUN;
      end if;
  end case;
  if timer_rst = '1' then
    timer <= (others => '0');
  end if;
end process;

gen_fifos : for i in 0 to INPUTS-1 generate
  THE_FIFO : entity work.fifo_18x1k_oreg
    port map (
      Data               => std_logic_vector(cnt(i)(17 downto 0)),
      Clock              => CLK, 
      WrEn               => fifo_write,
      RdEn               => fifo_read(i),
      Reset              => trigger_fifo,
      AmFullThresh       => "1000000000",
      Q                  => fifo_dout(i),
      WCNT               => fifo_count(i),
      Empty              => fifo_empty(i), 
      Full               => open,
      AlmostFull         => open
      );
end generate;

status_reg(10 downto 0) <= fifo_count(0);
status_reg(11)          <= fifo_write;
status_reg(15 downto 12)<= (others => '0');
status_reg(27 downto 16)<= word_cnt;
status_reg(31 downto 28)<= (others => '0');


end architecture;