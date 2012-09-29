library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

entity CTS_TRG_PSEUDORAND_PULSER is
   generic (
      DATA_XOR     : std_logic_vector(31 downto 0) := (others => '0')
   );
   port (
      clk_in       : in  std_logic;
      threshold_in : in  std_logic_vector(31 downto 0); 
      trigger_out  : out std_logic
   );
end CTS_TRG_PSEUDORAND_PULSER;

architecture behave of CTS_TRG_PSEUDORAND_PULSER is
   SIGNAL crc_i      : std_logic_vector(31 DOWNTO 0);
   SIGNAL crc_tmp_i  : std_logic_vector(31 DOWNTO 0);
   constant DATA     : std_logic_vector(31 downto 0) := X"6ED9EBA1" xor DATA_XOR; -- 2**30 * sqrt(3)
begin
-- comparator
   comp_proc: process(clk_in) is
   begin
      if rising_edge(clk_in) then
         if to_integer(unsigned(crc_i)) < to_integer(unsigned(threshold_in)) then
            trigger_out <= '1';
         else
            trigger_out <= '0';
         end if;
      end if;
   end process;
         
-- CRC generator created usign http://www.electronicdesignworks.com/utilities/crc_generator/crc_generator.htm
-- based on polynomial x32 + x26 + x23 + x22 + x16 + x12 + x11 + x10 + x8 + x7 + x5 + x4 + x2 + x1 + 1
   crc_tmp_i(0) <= DATA(0) XOR DATA(6) XOR DATA(9) XOR DATA(10) XOR DATA(24) XOR crc_i(0) XOR crc_i(24) XOR DATA(29) XOR crc_i(29) XOR DATA(28) XOR crc_i(28) XOR crc_i(10) XOR DATA(26) XOR crc_i(26) XOR crc_i(9) XOR DATA(25) XOR crc_i(25) XOR DATA(12) XOR DATA(16) XOR DATA(30) XOR crc_i(6) XOR crc_i(30) XOR crc_i(16) XOR DATA(31) XOR crc_i(31) XOR crc_i(12); 
   crc_tmp_i(1) <= DATA(0) XOR DATA(1) XOR DATA(7) XOR DATA(11) XOR crc_i(1) XOR crc_i(11) XOR DATA(27) XOR crc_i(27) XOR DATA(13) XOR DATA(17) XOR crc_i(7) XOR crc_i(17) XOR crc_i(13) XOR DATA(6) XOR DATA(9) XOR DATA(24) XOR crc_i(0) XOR crc_i(24) XOR DATA(28) XOR crc_i(28) XOR crc_i(9) XOR DATA(12) XOR DATA(16) XOR crc_i(6) XOR crc_i(16) XOR crc_i(12); 
   crc_tmp_i(2) <= DATA(0) XOR DATA(1) XOR DATA(2) XOR DATA(8) XOR crc_i(2) XOR DATA(14) XOR DATA(18) XOR crc_i(8) XOR crc_i(18) XOR crc_i(14) XOR DATA(7) XOR crc_i(1) XOR DATA(13) XOR DATA(17) XOR crc_i(7) XOR crc_i(17) XOR crc_i(13) XOR DATA(6) XOR DATA(9) XOR DATA(24) XOR crc_i(0) XOR crc_i(24) XOR DATA(26) XOR crc_i(26) XOR crc_i(9) XOR DATA(16) XOR DATA(30) XOR crc_i(6) XOR crc_i(30) XOR crc_i(16) XOR DATA(31) XOR crc_i(31); 
   crc_tmp_i(3) <= DATA(1) XOR DATA(2) XOR DATA(3) XOR DATA(9) XOR crc_i(3) XOR DATA(15) XOR DATA(19) XOR crc_i(9) XOR crc_i(19) XOR crc_i(15) XOR DATA(8) XOR crc_i(2) XOR DATA(14) XOR DATA(18) XOR crc_i(8) XOR crc_i(18) XOR crc_i(14) XOR DATA(7) XOR DATA(10) XOR DATA(25) XOR crc_i(1) XOR crc_i(25) XOR DATA(27) XOR crc_i(27) XOR crc_i(10) XOR DATA(17) XOR DATA(31) XOR crc_i(7) XOR crc_i(31) XOR crc_i(17); 
   crc_tmp_i(4) <= DATA(0) XOR DATA(2) XOR DATA(3) XOR DATA(4) XOR crc_i(4) XOR DATA(20) XOR crc_i(20) XOR crc_i(3) XOR DATA(15) XOR DATA(19) XOR crc_i(19) XOR crc_i(15) XOR DATA(8) XOR DATA(11) XOR crc_i(2) XOR crc_i(11) XOR DATA(18) XOR crc_i(8) XOR crc_i(18) XOR DATA(6) XOR DATA(24) XOR crc_i(0) XOR crc_i(24) XOR DATA(29) XOR crc_i(29) XOR DATA(25) XOR crc_i(25) XOR DATA(12) XOR DATA(30) XOR crc_i(6) XOR crc_i(30) XOR DATA(31) XOR crc_i(31) XOR crc_i(12); 
   crc_tmp_i(5) <= DATA(0) XOR DATA(1) XOR DATA(3) XOR DATA(4) XOR DATA(5) XOR crc_i(5) XOR DATA(21) XOR crc_i(21) XOR crc_i(4) XOR DATA(20) XOR crc_i(20) XOR crc_i(3) XOR DATA(19) XOR crc_i(19) XOR DATA(7) XOR crc_i(1) XOR DATA(13) XOR crc_i(7) XOR crc_i(13) XOR DATA(6) XOR DATA(10) XOR DATA(24) XOR crc_i(0) XOR crc_i(24) XOR DATA(29) XOR crc_i(29) XOR DATA(28) XOR crc_i(28) XOR crc_i(10) XOR crc_i(6); 
   crc_tmp_i(6) <= DATA(1) XOR DATA(2) XOR DATA(4) XOR DATA(5) XOR DATA(6) XOR crc_i(6) XOR DATA(22) XOR crc_i(22) XOR crc_i(5) XOR DATA(21) XOR crc_i(21) XOR crc_i(4) XOR DATA(20) XOR crc_i(20) XOR DATA(8) XOR crc_i(2) XOR DATA(14) XOR crc_i(8) XOR crc_i(14) XOR DATA(7) XOR DATA(11) XOR DATA(25) XOR crc_i(1) XOR crc_i(25) XOR DATA(30) XOR crc_i(30) XOR DATA(29) XOR crc_i(29) XOR crc_i(11) XOR crc_i(7); 
   crc_tmp_i(7) <= DATA(0) XOR DATA(2) XOR DATA(3) XOR DATA(5) XOR DATA(7) XOR crc_i(7) XOR DATA(23) XOR crc_i(23) XOR DATA(22) XOR crc_i(22) XOR crc_i(5) XOR DATA(21) XOR crc_i(21) XOR crc_i(3) XOR DATA(15) XOR crc_i(15) XOR DATA(8) XOR crc_i(2) XOR crc_i(8) XOR DATA(10) XOR DATA(24) XOR crc_i(0) XOR crc_i(24) XOR DATA(29) XOR crc_i(29) XOR DATA(28) XOR crc_i(28) XOR crc_i(10) XOR DATA(25) XOR crc_i(25) XOR DATA(16) XOR crc_i(16); 
   crc_tmp_i(8) <= DATA(0) XOR DATA(1) XOR DATA(3) XOR DATA(4) XOR DATA(8) XOR crc_i(8) XOR DATA(23) XOR crc_i(23) XOR DATA(22) XOR crc_i(22) XOR crc_i(4) XOR crc_i(3) XOR DATA(11) XOR crc_i(1) XOR crc_i(11) XOR DATA(17) XOR crc_i(17) XOR DATA(10) XOR crc_i(0) XOR DATA(28) XOR crc_i(28) XOR crc_i(10) XOR DATA(12) XOR DATA(31) XOR crc_i(31) XOR crc_i(12); 
   crc_tmp_i(9) <= DATA(1) XOR DATA(2) XOR DATA(4) XOR DATA(5) XOR DATA(9) XOR crc_i(9) XOR DATA(24) XOR crc_i(24) XOR DATA(23) XOR crc_i(23) XOR crc_i(5) XOR crc_i(4) XOR DATA(12) XOR crc_i(2) XOR crc_i(12) XOR DATA(18) XOR crc_i(18) XOR DATA(11) XOR crc_i(1) XOR DATA(29) XOR crc_i(29) XOR crc_i(11) XOR DATA(13) XOR crc_i(13); 
   crc_tmp_i(10) <= DATA(0) XOR DATA(2) XOR DATA(3) XOR DATA(5) XOR crc_i(5) XOR DATA(13) XOR crc_i(3) XOR crc_i(13) XOR DATA(19) XOR crc_i(19) XOR crc_i(2) XOR DATA(14) XOR crc_i(14) XOR DATA(9) XOR crc_i(0) XOR DATA(29) XOR crc_i(29) XOR DATA(28) XOR crc_i(28) XOR DATA(26) XOR crc_i(26) XOR crc_i(9) XOR DATA(16) XOR crc_i(16) XOR DATA(31) XOR crc_i(31); 
   crc_tmp_i(11) <= DATA(0) XOR DATA(1) XOR DATA(3) XOR DATA(4) XOR DATA(14) XOR crc_i(4) XOR crc_i(14) XOR DATA(20) XOR crc_i(20) XOR crc_i(3) XOR DATA(15) XOR crc_i(15) XOR crc_i(1) XOR DATA(27) XOR crc_i(27) XOR DATA(17) XOR crc_i(17) XOR DATA(9) XOR DATA(24) XOR crc_i(0) XOR crc_i(24) XOR DATA(28) XOR crc_i(28) XOR DATA(26) XOR crc_i(26) XOR crc_i(9) XOR DATA(25) XOR crc_i(25) XOR DATA(12) XOR DATA(16) XOR crc_i(16) XOR DATA(31) XOR crc_i(31) XOR crc_i(12); 
   crc_tmp_i(12) <= DATA(0) XOR DATA(1) XOR DATA(2) XOR DATA(4) XOR DATA(5) XOR DATA(15) XOR crc_i(5) XOR crc_i(15) XOR DATA(21) XOR crc_i(21) XOR crc_i(4) XOR crc_i(2) XOR DATA(18) XOR crc_i(18) XOR crc_i(1) XOR DATA(27) XOR crc_i(27) XOR DATA(13) XOR DATA(17) XOR crc_i(17) XOR crc_i(13) XOR DATA(6) XOR DATA(9) XOR DATA(24) XOR crc_i(0) XOR crc_i(24) XOR crc_i(9) XOR DATA(12) XOR DATA(30) XOR crc_i(6) XOR crc_i(30) XOR DATA(31) XOR crc_i(31) XOR crc_i(12); 
   crc_tmp_i(13) <= DATA(1) XOR DATA(2) XOR DATA(3) XOR DATA(5) XOR DATA(6) XOR DATA(16) XOR crc_i(6) XOR crc_i(16) XOR DATA(22) XOR crc_i(22) XOR crc_i(5) XOR crc_i(3) XOR DATA(19) XOR crc_i(19) XOR crc_i(2) XOR DATA(28) XOR crc_i(28) XOR DATA(14) XOR DATA(18) XOR crc_i(18) XOR crc_i(14) XOR DATA(7) XOR DATA(10) XOR DATA(25) XOR crc_i(1) XOR crc_i(25) XOR crc_i(10) XOR DATA(13) XOR DATA(31) XOR crc_i(7) XOR crc_i(31) XOR crc_i(13); 
   crc_tmp_i(14) <= DATA(2) XOR DATA(3) XOR DATA(4) XOR DATA(6) XOR DATA(7) XOR DATA(17) XOR crc_i(7) XOR crc_i(17) XOR DATA(23) XOR crc_i(23) XOR crc_i(6) XOR crc_i(4) XOR DATA(20) XOR crc_i(20) XOR crc_i(3) XOR DATA(29) XOR crc_i(29) XOR DATA(15) XOR DATA(19) XOR crc_i(19) XOR crc_i(15) XOR DATA(8) XOR DATA(11) XOR DATA(26) XOR crc_i(2) XOR crc_i(26) XOR crc_i(11) XOR DATA(14) XOR crc_i(8) XOR crc_i(14); 
   crc_tmp_i(15) <= DATA(3) XOR DATA(4) XOR DATA(5) XOR DATA(7) XOR DATA(8) XOR DATA(18) XOR crc_i(8) XOR crc_i(18) XOR DATA(24) XOR crc_i(24) XOR crc_i(7) XOR crc_i(5) XOR DATA(21) XOR crc_i(21) XOR crc_i(4) XOR DATA(30) XOR crc_i(30) XOR DATA(16) XOR DATA(20) XOR crc_i(20) XOR crc_i(16) XOR DATA(9) XOR DATA(12) XOR DATA(27) XOR crc_i(3) XOR crc_i(27) XOR crc_i(12) XOR DATA(15) XOR crc_i(9) XOR crc_i(15); 
   crc_tmp_i(16) <= DATA(0) XOR DATA(4) XOR DATA(5) XOR DATA(8) XOR DATA(19) XOR crc_i(19) XOR crc_i(8) XOR DATA(22) XOR crc_i(22) XOR crc_i(5) XOR DATA(17) XOR DATA(21) XOR crc_i(21) XOR crc_i(17) XOR DATA(13) XOR crc_i(4) XOR crc_i(13) XOR DATA(24) XOR crc_i(0) XOR crc_i(24) XOR DATA(29) XOR crc_i(29) XOR DATA(26) XOR crc_i(26) XOR DATA(12) XOR DATA(30) XOR crc_i(30) XOR crc_i(12); 
   crc_tmp_i(17) <= DATA(1) XOR DATA(5) XOR DATA(6) XOR DATA(9) XOR DATA(20) XOR crc_i(20) XOR crc_i(9) XOR DATA(23) XOR crc_i(23) XOR crc_i(6) XOR DATA(18) XOR DATA(22) XOR crc_i(22) XOR crc_i(18) XOR DATA(14) XOR crc_i(5) XOR crc_i(14) XOR DATA(25) XOR crc_i(1) XOR crc_i(25) XOR DATA(30) XOR crc_i(30) XOR DATA(27) XOR crc_i(27) XOR DATA(13) XOR DATA(31) XOR crc_i(31) XOR crc_i(13); 
   crc_tmp_i(18) <= DATA(2) XOR DATA(6) XOR DATA(7) XOR DATA(10) XOR DATA(21) XOR crc_i(21) XOR crc_i(10) XOR DATA(24) XOR crc_i(24) XOR crc_i(7) XOR DATA(19) XOR DATA(23) XOR crc_i(23) XOR crc_i(19) XOR DATA(15) XOR crc_i(6) XOR crc_i(15) XOR DATA(26) XOR crc_i(2) XOR crc_i(26) XOR DATA(31) XOR crc_i(31) XOR DATA(28) XOR crc_i(28) XOR DATA(14) XOR crc_i(14); 
   crc_tmp_i(19) <= DATA(3) XOR DATA(7) XOR DATA(8) XOR DATA(11) XOR DATA(22) XOR crc_i(22) XOR crc_i(11) XOR DATA(25) XOR crc_i(25) XOR crc_i(8) XOR DATA(20) XOR DATA(24) XOR crc_i(24) XOR crc_i(20) XOR DATA(16) XOR crc_i(7) XOR crc_i(16) XOR DATA(27) XOR crc_i(3) XOR crc_i(27) XOR DATA(29) XOR crc_i(29) XOR DATA(15) XOR crc_i(15); 
   crc_tmp_i(20) <= DATA(4) XOR DATA(8) XOR DATA(9) XOR DATA(12) XOR DATA(23) XOR crc_i(23) XOR crc_i(12) XOR DATA(26) XOR crc_i(26) XOR crc_i(9) XOR DATA(21) XOR DATA(25) XOR crc_i(25) XOR crc_i(21) XOR DATA(17) XOR crc_i(8) XOR crc_i(17) XOR DATA(28) XOR crc_i(4) XOR crc_i(28) XOR DATA(30) XOR crc_i(30) XOR DATA(16) XOR crc_i(16); 
   crc_tmp_i(21) <= DATA(5) XOR DATA(9) XOR DATA(10) XOR DATA(13) XOR DATA(24) XOR crc_i(24) XOR crc_i(13) XOR DATA(27) XOR crc_i(27) XOR crc_i(10) XOR DATA(22) XOR DATA(26) XOR crc_i(26) XOR crc_i(22) XOR DATA(18) XOR crc_i(9) XOR crc_i(18) XOR DATA(29) XOR crc_i(5) XOR crc_i(29) XOR DATA(31) XOR crc_i(31) XOR DATA(17) XOR crc_i(17); 
   crc_tmp_i(22) <= DATA(0) XOR DATA(11) XOR DATA(14) XOR crc_i(14) XOR crc_i(11) XOR DATA(23) XOR DATA(27) XOR crc_i(27) XOR crc_i(23) XOR DATA(19) XOR crc_i(19) XOR DATA(18) XOR crc_i(18) XOR DATA(9) XOR DATA(24) XOR crc_i(0) XOR crc_i(24) XOR DATA(29) XOR crc_i(29) XOR DATA(26) XOR crc_i(26) XOR crc_i(9) XOR DATA(12) XOR DATA(16) XOR crc_i(16) XOR DATA(31) XOR crc_i(31) XOR crc_i(12); 
   crc_tmp_i(23) <= DATA(0) XOR DATA(1) XOR DATA(15) XOR crc_i(15) XOR DATA(20) XOR crc_i(20) XOR DATA(19) XOR crc_i(19) XOR crc_i(1) XOR DATA(27) XOR crc_i(27) XOR DATA(13) XOR DATA(17) XOR crc_i(17) XOR crc_i(13) XOR DATA(6) XOR DATA(9) XOR crc_i(0) XOR DATA(29) XOR crc_i(29) XOR DATA(26) XOR crc_i(26) XOR crc_i(9) XOR DATA(16) XOR crc_i(6) XOR crc_i(16) XOR DATA(31) XOR crc_i(31); 
   crc_tmp_i(24) <= DATA(1) XOR DATA(2) XOR DATA(16) XOR crc_i(16) XOR DATA(21) XOR crc_i(21) XOR DATA(20) XOR crc_i(20) XOR crc_i(2) XOR DATA(28) XOR crc_i(28) XOR DATA(14) XOR DATA(18) XOR crc_i(18) XOR crc_i(14) XOR DATA(7) XOR DATA(10) XOR crc_i(1) XOR DATA(30) XOR crc_i(30) XOR DATA(27) XOR crc_i(27) XOR crc_i(10) XOR DATA(17) XOR crc_i(7) XOR crc_i(17); 
   crc_tmp_i(25) <= DATA(2) XOR DATA(3) XOR DATA(17) XOR crc_i(17) XOR DATA(22) XOR crc_i(22) XOR DATA(21) XOR crc_i(21) XOR crc_i(3) XOR DATA(29) XOR crc_i(29) XOR DATA(15) XOR DATA(19) XOR crc_i(19) XOR crc_i(15) XOR DATA(8) XOR DATA(11) XOR crc_i(2) XOR DATA(31) XOR crc_i(31) XOR DATA(28) XOR crc_i(28) XOR crc_i(11) XOR DATA(18) XOR crc_i(8) XOR crc_i(18); 
   crc_tmp_i(26) <= DATA(0) XOR DATA(3) XOR DATA(4) XOR DATA(18) XOR crc_i(18) XOR DATA(23) XOR crc_i(23) XOR DATA(22) XOR crc_i(22) XOR crc_i(4) XOR DATA(20) XOR crc_i(20) XOR crc_i(3) XOR DATA(19) XOR crc_i(19) XOR DATA(6) XOR DATA(10) XOR DATA(24) XOR crc_i(0) XOR crc_i(24) XOR DATA(28) XOR crc_i(28) XOR crc_i(10) XOR DATA(26) XOR crc_i(26) XOR DATA(25) XOR crc_i(25) XOR crc_i(6) XOR DATA(31) XOR crc_i(31); 
   crc_tmp_i(27) <= DATA(1) XOR DATA(4) XOR DATA(5) XOR DATA(19) XOR crc_i(19) XOR DATA(24) XOR crc_i(24) XOR DATA(23) XOR crc_i(23) XOR crc_i(5) XOR DATA(21) XOR crc_i(21) XOR crc_i(4) XOR DATA(20) XOR crc_i(20) XOR DATA(7) XOR DATA(11) XOR DATA(25) XOR crc_i(1) XOR crc_i(25) XOR DATA(29) XOR crc_i(29) XOR crc_i(11) XOR DATA(27) XOR crc_i(27) XOR DATA(26) XOR crc_i(26) XOR crc_i(7); 
   crc_tmp_i(28) <= DATA(2) XOR DATA(5) XOR DATA(6) XOR DATA(20) XOR crc_i(20) XOR DATA(25) XOR crc_i(25) XOR DATA(24) XOR crc_i(24) XOR crc_i(6) XOR DATA(22) XOR crc_i(22) XOR crc_i(5) XOR DATA(21) XOR crc_i(21) XOR DATA(8) XOR DATA(12) XOR DATA(26) XOR crc_i(2) XOR crc_i(26) XOR DATA(30) XOR crc_i(30) XOR crc_i(12) XOR DATA(28) XOR crc_i(28) XOR DATA(27) XOR crc_i(27) XOR crc_i(8); 
   crc_tmp_i(29) <= DATA(3) XOR DATA(6) XOR DATA(7) XOR DATA(21) XOR crc_i(21) XOR DATA(26) XOR crc_i(26) XOR DATA(25) XOR crc_i(25) XOR crc_i(7) XOR DATA(23) XOR crc_i(23) XOR crc_i(6) XOR DATA(22) XOR crc_i(22) XOR DATA(9) XOR DATA(13) XOR DATA(27) XOR crc_i(3) XOR crc_i(27) XOR DATA(31) XOR crc_i(31) XOR crc_i(13) XOR DATA(29) XOR crc_i(29) XOR DATA(28) XOR crc_i(28) XOR crc_i(9); 
   crc_tmp_i(30) <= DATA(4) XOR DATA(7) XOR DATA(8) XOR DATA(22) XOR crc_i(22) XOR DATA(27) XOR crc_i(27) XOR DATA(26) XOR crc_i(26) XOR crc_i(8) XOR DATA(24) XOR crc_i(24) XOR crc_i(7) XOR DATA(23) XOR crc_i(23) XOR DATA(10) XOR DATA(14) XOR DATA(28) XOR crc_i(4) XOR crc_i(28) XOR crc_i(14) XOR DATA(30) XOR crc_i(30) XOR DATA(29) XOR crc_i(29) XOR crc_i(10); 
   crc_tmp_i(31) <= DATA(5) XOR DATA(8) XOR DATA(9) XOR DATA(23) XOR crc_i(23) XOR DATA(28) XOR crc_i(28) XOR DATA(27) XOR crc_i(27) XOR crc_i(9) XOR DATA(25) XOR crc_i(25) XOR crc_i(8) XOR DATA(24) XOR crc_i(24) XOR DATA(11) XOR DATA(15) XOR DATA(29) XOR crc_i(5) XOR crc_i(29) XOR crc_i(15) XOR DATA(31) XOR crc_i(31) XOR DATA(30) XOR crc_i(30) XOR crc_i(11); 

   crc_proc: process(clk_in) is
   begin
      if rising_edge(clk_in) then
         crc_i <= crc_tmp_i;
      end if;
   end process;
end behave;
