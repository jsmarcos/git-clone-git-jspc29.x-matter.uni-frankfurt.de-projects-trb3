library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.trb_net_std.all;


entity input_to_trigger_logic is
  generic(
    INPUTS     : integer range 1 to 32 := 24;
    OUTPUTS    : integer range 1 to 16 := 4
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
signal invert : std_logic_vector(INPUTS-1 downto 0);

signal stretch_inp : std_logic_vector(INPUTS-1 downto 0);


signal inp_inv      : std_logic_vector(INPUTS-1 downto 0);  
signal inp_long     : std_logic_vector(INPUTS-1 downto 0);  
signal inp_long_reg : std_logic_vector(INPUTS-1 downto 0);  

signal output_i: std_logic_vector(OUTPUTS-1 downto 0);

signal inp_reg : std_logic_vector(INPUTS-1 downto 0);
signal out_reg : std_logic_vector(OUTPUTS-1 downto 0);

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
      case ADDR_IN(2 downto 0) is
        when "000"   => DATA_OUT(INPUTS-1 downto 0)  <= inp_reg;     DATA_OUT(31 downto INPUTS)  <= (others => '0');
        when "001"   => DATA_OUT(OUTPUTS-1 downto 0) <= out_reg;     DATA_OUT(31 downto OUTPUTS) <= (others => '0');
        when "010"   => DATA_OUT(INPUTS-1 downto 0)  <= stretch_inp; DATA_OUT(31 downto INPUTS) <= (others => '0');
        when "100"   => DATA_OUT(INPUTS-1 downto 0)  <= invert;      DATA_OUT(31 downto INPUTS) <= (others => '0');
        when others => NACK_OUT <= '1'; ACK_OUT <= '0';
      end case;
    else
      NACK_OUT <= '1'; 
      ACK_OUT  <= '0';
    end if;

  end if;

  
  end process;

  
inp_inv           <= INPUT xor invert;
inp_long          <= (inp_inv or inp_long) and not inp_long_reg;
inp_long_reg      <= inp_long when rising_edge(CLK);

  
gen_outs : for i in 0 to OUTPUTS-1 generate
  output_i(i) <= or_all((((inp_long or inp_long_reg) and stretch_inp) or (inp_inv and not stretch_inp)) and enable(i)(INPUTS-1 downto 0));
end generate;

inp_reg <= INPUT when rising_edge(CLK);
out_reg <= output_i when rising_edge(CLK);

OUTPUT  <= output_i;

end architecture;