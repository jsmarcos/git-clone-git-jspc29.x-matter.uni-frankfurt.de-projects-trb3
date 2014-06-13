library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.trb_net_std.all;


entity input_to_trigger_logic is
  generic(
    INPUTS      : integer range 1 to 32 := 24;
    OUTPUTS     : integer range 1 to 16 := 4
    );
  port(
    CLK        : in std_logic;
    
    INPUT      : in  std_logic_vector(INPUTS-1 downto 0);
    OUTPUT     : out std_logic_vector(OUTPUTS-1 downto 0);

    DATA_IN    : in  std_logic_vector(31 downto 0) := (others => '0');
    DATA_OUT   : out std_logic_vector(31 downto 0);
    WRITE_IN   : in  std_logic := '0';
    READ_IN    : in  std_logic := '0';
    ACK_OUT    : out std_logic;
    NACK_OUT   : out std_logic;
    ADDR_IN    : in  std_logic_vector(15 downto 0) := (others => '0')
    
    );
end entity;


architecture input_to_trigger_logic_arch of input_to_trigger_logic is

type reg_t is array(0 to OUTPUTS-1) of std_logic_vector(31 downto 0);
signal enable : reg_t;
signal invert       : std_logic_vector(INPUTS-1 downto 0);
signal coincidence1 : std_logic_vector(INPUTS-1 downto 0);
signal coincidence2 : std_logic_vector(INPUTS-1 downto 0);
signal coin_in_1    : std_logic;
signal coin_in_2    : std_logic;
signal stretch_inp  : std_logic_vector(INPUTS-1 downto 0);

type inp_t is array(0 to 4) of std_logic_vector(INPUTS-1 downto 0);
signal inp_shift    : inp_t;

signal inp_inv      : std_logic_vector(INPUTS-1 downto 0);  
signal inp_long     : std_logic_vector(INPUTS-1 downto 0);  
signal inp_verylong : std_logic_vector(INPUTS-1 downto 0);  

signal output_i     : std_logic_vector(OUTPUTS-1 downto 0);
signal out_reg      : std_logic_vector(OUTPUTS-1 downto 0);
signal got_coincidence : std_logic;

begin


THE_CONTROL : process 
  variable tmp : integer range 0 to 16;
begin
  wait until rising_edge(CLK);
  ACK_OUT  <= '0';
  NACK_OUT <= '0';
  tmp := to_integer(unsigned(ADDR_IN(4 downto 1)));
  if WRITE_IN = '1' then
    ACK_OUT <= '1';
    if ADDR_IN(5) = '0' and ADDR_IN(0) = '0' and tmp < OUTPUTS then
      enable(tmp) <= DATA_IN;
    elsif ADDR_IN(5) = '1' then
      case ADDR_IN(2 downto 0) is
        when "010"   =>  stretch_inp <= DATA_IN(INPUTS-1 downto 0);
        when "100"   =>  invert      <= DATA_IN(INPUTS-1 downto 0);
        when "101"   =>  coincidence1<= DATA_IN(INPUTS-1 downto 0);
        when "110"   =>  coincidence2<= DATA_IN(INPUTS-1 downto 0);
      end case;
    else
      NACK_OUT <= '1'; 
      ACK_OUT <= '0';
    end if;
  elsif READ_IN = '1' then
    ACK_OUT <= '1';
    if ADDR_IN(5) = '0' and ADDR_IN(0) = '0' and tmp < OUTPUTS then
      DATA_OUT <= enable(tmp);
    elsif ADDR_IN(5) = '1' then
      DATA_OUT <= (others => '0');
      case ADDR_IN(2 downto 0) is
        when "000"   => DATA_OUT(INPUTS-1 downto 0)  <= inp_shift(1);     
        when "001"   => DATA_OUT(OUTPUTS-1 downto 0) <= out_reg;     
        when "010"   => DATA_OUT(INPUTS-1 downto 0)  <= stretch_inp; 
        when "100"   => DATA_OUT(INPUTS-1 downto 0)  <= invert;     
        when "101"   => DATA_OUT(INPUTS-1 downto 0)  <= coincidence1; 
        when "110"   => DATA_OUT(INPUTS-1 downto 0)  <= coincidence2; 
        when "111"   => DATA_OUT( 5 downto  0)   <= std_logic_vector(to_unsigned(INPUTS,6));
                        DATA_OUT(11 downto  8)   <= std_logic_vector(to_unsigned(OUTPUTS,4));
        when others => NACK_OUT <= '1'; ACK_OUT <= '0';
      end case;
    else
      NACK_OUT <= '1'; 
      ACK_OUT  <= '0';
    end if;

  end if;

  
  end process;

  inp_shift(0)      <= (inp_inv or inp_shift(0)) and not (inp_shift(1) and not inp_inv); 
gen_shift: for i in 1 to 4 generate
  inp_shift(i)      <= inp_shift(i-1) when rising_edge(CLK);
end generate;
  
inp_inv           <= INPUT xor invert;
inp_long          <= inp_shift(0) or inp_shift(1);
inp_verylong      <= inp_shift(1) or inp_shift(2) or inp_shift(3) or inp_shift(4) when rising_edge(CLK);

coin_in_1         <= or_all(coincidence1 and inp_verylong) when rising_edge(CLK);
coin_in_2         <= or_all(coincidence2 and inp_verylong) when rising_edge(CLK);
got_coincidence   <= coin_in_1 and coin_in_2               when rising_edge(CLK);
  
gen_outs : for i in 0 to OUTPUTS-1 generate
  output_i(i) <= or_all(((inp_long and stretch_inp) or (inp_inv and not stretch_inp)) and enable(i)(INPUTS-1 downto 0)) or (got_coincidence and enable(i)(INPUTS));
end generate;


out_reg <= output_i when rising_edge(CLK);

OUTPUT  <= output_i;

end architecture;