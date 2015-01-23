library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
USE ieee.math_real.ALL;
use ieee.numeric_std.all;

library std;
use std.textio.all;

library work;
use work.txt_util.all;

entity dummyADC is
    generic(
              stim_file: string :="adcsim.dat"
            );
    port(
          CLK    : in  std_logic;
          DATA   : out std_logic_vector(39 downto 0) := (others => '0');
          VALID  : out std_logic
        );
end entity;



architecture dummyADC_arch of dummyADC is

constant randrange : real := 0.0;

begin
receive_data: process
variable seed1, seed2   : positive;
variable rand           : real;
variable random1, random2, random3, random4         : unsigned(9 downto 0);
variable l              : line;
variable s              : std_logic_vector(47 downto 0);
variable toggle         : std_logic := '0';
variable s1, s2, s3, s4 : std_logic_vector(9 downto 0);
variable cnt : unsigned(9 downto 0) := (others => '0');
 file stimulus: TEXT;   
begin                                       

   file_open(stimulus, stim_file, read_mode);
   while not endfile(stimulus) loop
     readline(stimulus, l);
     hread(l, s);
     
     UNIFORM(seed1, seed2, rand);
     random1 := to_unsigned(INTEGER(TRUNC(rand*randrange*2.0)),10); 
     UNIFORM(seed1, seed2, rand);
     random2 := to_unsigned(INTEGER(TRUNC(rand*randrange*2.0)),10); 
     UNIFORM(seed1, seed2, rand);
     random3 := to_unsigned(INTEGER(TRUNC(rand*randrange*2.0)),10); 
     UNIFORM(seed1, seed2, rand);
     random4 := to_unsigned(INTEGER(TRUNC(rand*randrange*2.0)),10); 

     s1 := std_logic_vector(unsigned(s( 9 downto  0))+random1-to_unsigned(integer(randrange),10));
     s2 := std_logic_vector(unsigned(s(21 downto 12))+random2-to_unsigned(integer(randrange),10));
     s3 := std_logic_vector(unsigned(s(33 downto 24))+random3-to_unsigned(integer(randrange),10));
     s4 := std_logic_vector(unsigned(s(45 downto 36))+random4-to_unsigned(integer(randrange),10));
     
     s1 := std_logic_vector(cnt);
     cnt := cnt + 1;
     
     DATA <= s4 & s3 & s2 & s1;
     VALID <= '1';
     wait until CLK = '1'; wait for 0.5 ns;
     VALID <= '0';
     wait until CLK = '1'; wait for 0.5 ns;
     if toggle = '0' then
       wait until CLK = '1'; wait for 0.5 ns;
       toggle := '1';
     else 
       toggle := '0';
     end if;  
     
   end loop;
   file_close(stimulus);

 end process receive_data;
end architecture;