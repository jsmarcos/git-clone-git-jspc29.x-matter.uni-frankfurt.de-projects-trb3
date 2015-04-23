library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
USE ieee.math_real.ALL;

use work.adc_package.all;

use std.textio.all;

use work.txt_util.all;

entity dqsinput_dummy is
  generic(
    stim_file : string := "adcsim.dat"
  );
  port(
    eclk : in  std_logic;
    sclk : out std_logic;
    q_0  : out std_logic_vector(19 downto 0)
  );
end entity dqsinput_dummy;

architecture arch of dqsinput_dummy is
  signal sclk_int : std_logic                     := '0';
  signal q        : std_logic_vector(19 downto 0) := (others => '0');
  
  signal start_read, read_done : std_logic;
  signal readwords : integer;
  
  type word_t is array (0 to CHANNELS-1) of std_logic_vector(9 downto 0);

  type word_arr_t is array (1 to 2) of word_t; 
  signal words : word_arr_t;

  constant randrange : real := 0.0;
  
begin
  sclk <= sclk_int;
  clkdiv : process is
  begin
    wait until rising_edge(eclk);
    sclk_int <= not sclk_int;
  end process clkdiv;

  gen_data_mapping : for j in 0 to CHANNELS generate
    -- reverse weird bit mapping of dqs
    gen_data_mapping_bits : for k in 0 to 3 generate
      q_0(k * (CHANNELS + 1) + j) <= q(j * 4 + 3 - k);
    end generate;
  end generate;

  datareader : process is
    variable seed1, seed2                       : positive;
    variable rand                               : real;
    variable random1, random2, random3, random4 : unsigned(9 downto 0);
    variable l                                  : line;
    variable s                                  : std_logic_vector(47 downto 0);
    variable t1, t2, t3, t4                     : integer;
    variable s1, s2, s3, s4                     : std_logic_vector(9 downto 0);
    file stimulus : TEXT;
  begin
    file_open(stimulus, stim_file, read_mode);
    while not endfile(stimulus) loop
      readline(stimulus, l);
      hread(l, s);

      UNIFORM(seed1, seed2, rand);
      random1 := to_unsigned(INTEGER(TRUNC(rand * randrange * 2.0)), 10);
      UNIFORM(seed1, seed2, rand);
      random2 := to_unsigned(INTEGER(TRUNC(rand * randrange * 2.0)), 10);
      UNIFORM(seed1, seed2, rand);
      random3 := to_unsigned(INTEGER(TRUNC(rand * randrange * 2.0)), 10);
      UNIFORM(seed1, seed2, rand);
      random4 := to_unsigned(INTEGER(TRUNC(rand * randrange * 2.0)), 10);

      t1 := 1024 - to_integer(unsigned(s(9 downto 0)));
      t2 := 1024 - to_integer(unsigned(s(21 downto 12)));
      t3 := 1024 - to_integer(unsigned(s(33 downto 24)));
      t4 := 1024 - to_integer(unsigned(s(45 downto 36)));

      s1 := std_logic_vector(to_unsigned(t1, 10) + random1 - to_unsigned(integer(randrange), 10));
      s2 := std_logic_vector(to_unsigned(t2, 10) + random2 - to_unsigned(integer(randrange), 10));
      s3 := std_logic_vector(to_unsigned(t3, 10) + random3 - to_unsigned(integer(randrange), 10));
      s4 := std_logic_vector(to_unsigned(t4, 10) + random4 - to_unsigned(integer(randrange), 10));

      wait until start_read = '1';
            
      words(readwords)(0) <= s1;
      words(readwords)(1) <= s2;
      words(readwords)(2) <= s3;
      words(readwords)(3) <= s4; 
      read_done <= '1';
      wait until start_read = '0';
      read_done <= '0';
      
    end loop;
    file_close(stimulus);
  end process datareader;

  dataoutput : process is
  begin
    -- fill the words signal
    readwords <= 1;
    start_read <= '1';
    wait until read_done = '1';
    start_read <= '0';
    wait until read_done = '0';
    
    readwords <= 2;
    start_read <= '1';
    wait until read_done = '1';
    start_read <= '0';
    wait until read_done = '0'; 
    
    wait until rising_edge(sclk_int);
    q(3  downto  0) <= words(1)(0)(9 downto 6);
    q(7  downto  4) <= words(1)(1)(9 downto 6);
    q(11 downto  8) <= words(1)(2)(9 downto 6);
    q(15 downto 12) <= words(1)(3)(9 downto 6);
    q(19 downto 16) <= "0000";
    

    wait until rising_edge(sclk_int);
    q(3  downto  0) <= words(1)(0)(5 downto 2);
    q(7  downto  4) <= words(1)(1)(5 downto 2);
    q(11 downto  8) <= words(1)(2)(5 downto 2);
    q(15 downto 12) <= words(1)(3)(5 downto 2);
    q(19 downto 16) <= "0000";
    
    wait until rising_edge(sclk_int);
    q(3  downto  2) <= words(1)(0)(1 downto 0);
    q(7  downto  6) <= words(1)(1)(1 downto 0);
    q(11 downto 10) <= words(1)(2)(1 downto 0);
    q(15 downto 14) <= words(1)(3)(1 downto 0);
    q(1  downto  0) <= words(2)(0)(9 downto 8);
    q(5  downto  4) <= words(2)(1)(9 downto 8);
    q(9 downto   8) <= words(2)(2)(9 downto 8);
    q(13 downto 12) <= words(2)(3)(9 downto 8);
    q(19 downto 16) <= "0011";
    
    wait until rising_edge(sclk_int);
    q(3  downto  0) <= words(2)(0)(7 downto 4);
    q(7  downto  4) <= words(2)(1)(7 downto 4);
    q(11 downto  8) <= words(2)(2)(7 downto 4);
    q(15 downto 12) <= words(2)(3)(7 downto 4);
    q(19 downto 16) <= "1111";
    
    wait until rising_edge(sclk_int);
    q(3  downto  0) <= words(2)(0)(3 downto 0);
    q(7  downto  4) <= words(2)(1)(3 downto 0);
    q(11 downto  8) <= words(2)(2)(3 downto 0);
    q(15 downto 12) <= words(2)(3)(3 downto 0);
    q(19 downto 16) <= "1111";   
    
  end process dataoutput;
end architecture arch;

