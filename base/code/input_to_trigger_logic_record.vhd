library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.trb_net_std.all;


entity input_to_trigger_logic_record is
  generic(
    INPUTS      : integer range 1 to 96 := 24;
    OUTPUTS     : integer range 1 to 8  := 4
    );
  port(
    CLK        : in std_logic;
    
    INPUT      : in  std_logic_vector(INPUTS-1 downto 0);
    OUTPUT     : out std_logic_vector(OUTPUTS-1 downto 0);

    BUS_RX     : in  CTRLBUS_RX;
    BUS_TX     : out CTRLBUS_TX
    );
end entity;


architecture input_to_trigger_logic_arch of input_to_trigger_logic_record is
constant register_bits : integer := (INPUTS-1)/32*32+32-1;
type reg_t is array(0 to OUTPUTS-1) of std_logic_vector(register_bits downto 0);
signal enable : reg_t := (others => (others => '0'));
signal invert       : std_logic_vector(register_bits downto 0) := (others => '0');
signal coincidence1 : std_logic_vector(register_bits downto 0) := (others => '0');
signal coincidence2 : std_logic_vector(register_bits downto 0) := (others => '0');
signal coin_in_1    : std_logic;
signal coin_in_2    : std_logic;
signal stretch_inp  : std_logic_vector(register_bits downto 0) := (others => '0');

type inp_t is array(0 to 4) of std_logic_vector(INPUTS-1 downto 0);
signal inp_shift    : inp_t := (others => (others => '0'));

signal inp_inv      : std_logic_vector(INPUTS-1 downto 0) := (others => '0');  
signal inp_long     : std_logic_vector(INPUTS-1 downto 0) := (others => '0');  
signal inp_verylong : std_logic_vector(INPUTS-1 downto 0) := (others => '0');  

signal output_i     : std_logic_vector(OUTPUTS-1 downto 0) := (others => '0');
signal out_reg      : std_logic_vector(OUTPUTS-1 downto 0) := (others => '0');
signal got_coincidence : std_logic;
signal coin_enable  : std_logic  := '0';
signal current_multiplicity, set_multiplicity : unsigned(7 downto 0);
signal multiplicity_trigger : std_logic := '0';

begin
THE_CONTROL : process 
  variable outchan : integer range 0 to 7;
  variable slice : integer range 0 to 3;
begin
  wait until rising_edge(CLK);
  BUS_TX.ack  <= '0';
  BUS_TX.nack <= '0';
  BUS_TX.unknown <= '0';
  outchan := to_integer(unsigned(BUS_RX.addr(4 downto 2)));
  slice   := to_integer(unsigned(BUS_RX.addr(1 downto 0)));
  
  if BUS_RX.write = '1' then
    BUS_TX.ack <= '1';
    if BUS_RX.addr(5) = '0' and outchan < OUTPUTS then
      if    slice=0                 then enable(outchan)(31 downto  0)  <= BUS_RX.data;
      elsif slice=1 and INPUTS > 32 then enable(outchan)(63 downto 32)  <= BUS_RX.data;
      elsif slice=2 and INPUTS > 64 then enable(outchan)(95 downto 64)  <= BUS_RX.data;
      end if;
    elsif BUS_RX.addr(5 downto 4) = "10" then
      if    slice=0                 then 
        case BUS_RX.addr(3 downto 2) is
          when "00"   =>  stretch_inp(31 downto 0) <= BUS_RX.data;
          when "01"   =>  invert(31 downto 0)      <= BUS_RX.data;
          when "10"   =>  coincidence1(31 downto 0)<= BUS_RX.data;
          when "11"   =>  coincidence2(31 downto 0)<= BUS_RX.data;
          when others => null;
        end case;
      elsif slice=1 and INPUTS > 32 then 
        case BUS_RX.addr(3 downto 2) is
          when "00"   =>  stretch_inp(63 downto 32) <= BUS_RX.data;
          when "01"   =>  invert(63 downto 32)      <= BUS_RX.data;
          when "10"   =>  coincidence1(63 downto 32)<= BUS_RX.data;
          when "11"   =>  coincidence2(63 downto 32)<= BUS_RX.data;
          when others => null;
        end case;      
      elsif slice=2 and INPUTS > 64 then 
        case BUS_RX.addr(3 downto 2) is
          when "00"   =>  stretch_inp(95 downto 64) <= BUS_RX.data;
          when "01"   =>  invert(95 downto 64)      <= BUS_RX.data;
          when "10"   =>  coincidence1(95 downto 64)<= BUS_RX.data;
          when "11"   =>  coincidence2(95 downto 64)<= BUS_RX.data;
          when others => null;
        end case;          
      end if;  
    elsif BUS_RX.addr(5 downto 0) = "110010" then
      set_multiplicity <= unsigned(BUS_RX.data(23 downto 16));
    else
      BUS_TX.nack <= '1'; 
      BUS_TX.ack  <= '0';
    end if;  
  end if;
  if BUS_RX.read = '1' then
    BUS_TX.ack <= '1';
    if BUS_RX.addr(5) = '0' and outchan < OUTPUTS then
      if    slice=0                 then BUS_TX.data <= enable(outchan)(31 downto  0);
      elsif slice=1 and INPUTS > 32 then BUS_TX.data <= enable(outchan)(63 downto 32);
      elsif slice=2 and INPUTS > 64 then BUS_TX.data <= enable(outchan)(95 downto 64);
      else                               BUS_TX.data <= (others => '0');
      end if;
    elsif BUS_RX.addr(5 downto 4) = "10" then  
      if    slice=0                 then 
        case BUS_RX.addr(3 downto 2) is
          when "00"   =>  BUS_TX.data <= stretch_inp(31 downto 0) ;
          when "01"   =>  BUS_TX.data <= invert(31 downto 0)      ;
          when "10"   =>  BUS_TX.data <= coincidence1(31 downto 0);
          when "11"   =>  BUS_TX.data <= coincidence2(31 downto 0);
          when others => null;
        end case;
      elsif slice=1 and INPUTS > 32 then 
        case BUS_RX.addr(3 downto 2) is
          when "00"   =>  BUS_TX.data <= stretch_inp(63 downto 32) ;
          when "01"   =>  BUS_TX.data <= invert(63 downto 32)      ;
          when "10"   =>  BUS_TX.data <= coincidence1(63 downto 32);
          when "11"   =>  BUS_TX.data <= coincidence2(63 downto 32);
          when others => null;
        end case;      
      elsif slice=2 and INPUTS > 64 then 
        case BUS_RX.addr(3 downto 2) is
          when "00"   =>  BUS_TX.data <= stretch_inp(95 downto 64) ;
          when "01"   =>  BUS_TX.data <= invert(95 downto 64)      ;
          when "10"   =>  BUS_TX.data <= coincidence1(95 downto 64);
          when "11"   =>  BUS_TX.data <= coincidence2(95 downto 64);
          when others => null;
        end case; 
      else                BUS_TX.data <= (others => '0');  
      end if;  
    elsif BUS_RX.addr(5 downto 0) = "110000" then
      BUS_TX.data(OUTPUTS-1 downto 0) <= out_reg;
      BUS_TX.data(31 downto OUTPUTS)  <= (others => '0');
    elsif BUS_RX.addr(5 downto 0) = "110001" then
      BUS_TX.data                 <= (others => '0');
      BUS_TX.data( 6 downto  0)   <= std_logic_vector(to_unsigned(INPUTS,7));
      BUS_TX.data(11 downto  8)   <= std_logic_vector(to_unsigned(OUTPUTS,4));      
    elsif BUS_RX.addr(5 downto 0) = "110010" then
      BUS_TX.data                 <= x"00" & std_logic_vector(set_multiplicity) & x"00" & std_logic_vector(current_multiplicity);
    else  
      BUS_TX.nack <= '1'; 
      BUS_TX.ack  <= '0';
    end if;
  end if;
  
end process;  


  inp_shift(0)      <= (inp_inv or inp_shift(0)) and not (inp_shift(1) and not inp_inv); 
gen_shift: for i in 1 to 4 generate
  inp_shift(i)      <= inp_shift(i-1) when rising_edge(CLK);
end generate;

coin_enable <= or_all(coincidence1) when rising_edge(CLK);

inp_inv           <= INPUT xor invert(INPUTS-1 downto 0);
inp_long          <= inp_shift(0) or inp_shift(1);
inp_verylong      <= inp_shift(1) or inp_shift(2) or inp_shift(3) or inp_shift(4) when rising_edge(CLK);

coin_in_1         <= or_all(coincidence1(INPUTS-1 downto 0) and inp_verylong)   when rising_edge(CLK);
coin_in_2         <= or_all(coincidence2(INPUTS-1 downto 0) and inp_verylong)   when rising_edge(CLK);
got_coincidence   <= coin_in_1 and coin_in_2 and coin_enable when rising_edge(CLK);
  
gen_outs : for i in 0 to OUTPUTS-1 generate
  gen_first : if i = 0 generate
    output_i(i) <= or_all(((inp_long and stretch_inp(INPUTS-1 downto 0)) or (inp_inv(INPUTS-1 downto 0) and not stretch_inp(INPUTS-1 downto 0))) and enable(i)(INPUTS-1 downto 0)) or got_coincidence;
  end generate;
  gen_second : if i = 1 generate
    output_i(i) <= or_all(((inp_long and stretch_inp(INPUTS-1 downto 0)) or (inp_inv(INPUTS-1 downto 0) and not stretch_inp(INPUTS-1 downto 0))) and enable(i)(INPUTS-1 downto 0)) or multiplicity_trigger;
  end generate;
  gen_rest : if i > 1 generate 
    output_i(i) <= or_all(((inp_long and stretch_inp(INPUTS-1 downto 0)) or (inp_inv(INPUTS-1 downto 0) and not stretch_inp(INPUTS-1 downto 0))) and enable(i)(INPUTS-1 downto 0));
  end generate;
end generate;

gen_mult : if OUTPUTS >= 2 generate
  PROC_MULT : process 
    variable m : integer range 0 to INPUTS-1;
  begin
    wait until rising_edge(CLK);
    m := 0;
    for i in 0 to INPUTS-1 loop
      if inp_verylong(i) = '1' and enable(0)(i) = '1' then
        m := m + 1;
      end if;  
    end loop;
    current_multiplicity <= to_unsigned(m,8);
    
    if current_multiplicity >= set_multiplicity and set_multiplicity > 0 then
      multiplicity_trigger <= '1';
    else
      multiplicity_trigger <= '0';
    end if;
  end process;
end generate;  
gen_no_mult : if OUTPUTS < 2 generate 
  multiplicity_trigger <= '0';
end generate;


out_reg <= output_i when rising_edge(CLK);

OUTPUT  <= output_i;

end architecture;