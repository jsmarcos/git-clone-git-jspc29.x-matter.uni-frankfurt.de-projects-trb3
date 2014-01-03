library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity lcd is
  port(
    CLK : in std_logic;
    RESET : in std_logic;
    
    MOSI : out std_logic;
    SCK  : out std_logic;
    DC   : out std_logic;
    CS   : out std_logic;
    RST  : out std_logic;
    
    INPUT: in  std_logic_vector(255 downto 0);
    LED  : out std_logic_vector(3 downto 0)
    
    );
end entity;



architecture base of lcd is
--     Font size in bytes  : 2002
--     Font width          : 10
--     Font height         : 16
--     Font first char     : 0x20
--     Font last char      : 0x7E
type fontram_t is array (0 to 2047) of std_logic_vector(7 downto 0);
constant fontram : fontram_t := (    
    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
    x"00", x"00", x"00", x"00",
    x"00", x"00", x"00", x"00", x"00", x"00", x"FF", x"33", x"FF", x"33", x"FF", x"33", x"00", x"00", x"00", x"00", 
    x"00", x"00", x"00", x"00", x"00", x"00", x"1F", x"00", x"1F", x"00", x"1F", x"00", x"00", x"00", x"00", x"00", 
    x"1F", x"00", x"1F", x"00", x"1F", x"00", x"00", x"00", x"00", x"32", x"20", x"3F", x"F8", x"0F", x"FE", x"02", 
    x"26", x"32", x"A0", x"3F", x"F8", x"0F", x"7E", x"02", x"26", x"02", x"20", x"00", x"38", x"30", x"7C", x"70", 
    x"FE", x"60", x"C6", x"60", x"FF", x"FF", x"FF", x"FF", x"06", x"63", x"06", x"3F", x"04", x"1C", x"00", x"00", 
    x"3C", x"60", x"7E", x"38", x"42", x"1C", x"7E", x"0E", x"FE", x"3F", x"FC", x"7F", x"70", x"7E", x"38", x"42", 
    x"1C", x"7E", x"06", x"3C", x"00", x"1E", x"00", x"3F", x"BC", x"7F", x"FE", x"71", x"FE", x"63", x"E6", x"67", 
    x"3E", x"7F", x"1C", x"7C", x"00", x"7F", x"00", x"47", x"00", x"00", x"00", x"00", x"00", x"00", x"1F", x"00", 
    x"1F", x"00", x"1F", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"C0", x"03", 
    x"F0", x"0F", x"FC", x"3F", x"3E", x"7C", x"0E", x"70", x"07", x"E0", x"03", x"C0", x"03", x"C0", x"00", x"00", 
    x"00", x"00", x"03", x"C0", x"03", x"C0", x"07", x"E0", x"0E", x"70", x"3E", x"7C", x"FC", x"3F", x"F0", x"0F", 
    x"C0", x"03", x"00", x"00", x"18", x"00", x"98", x"00", x"D8", x"01", x"DE", x"01", x"4E", x"00", x"DE", x"01", 
    x"D8", x"01", x"98", x"00", x"18", x"00", x"00", x"00", x"00", x"00", x"00", x"03", x"00", x"03", x"00", x"03", 
    x"F0", x"3F", x"F0", x"3F", x"F0", x"3F", x"00", x"03", x"00", x"03", x"00", x"03", x"00", x"00", x"00", x"4E", 
    x"00", x"7E", x"00", x"7E", x"00", x"1E", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
    x"00", x"00", x"80", x"01", x"80", x"01", x"80", x"01", x"80", x"01", x"80", x"01", x"80", x"01", x"80", x"01", 
    x"80", x"01", x"00", x"00", x"00", x"00", x"00", x"38", x"00", x"38", x"00", x"38", x"00", x"38", x"00", x"00", 
    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"60", x"00", x"78", x"00", x"7F", 
    x"E0", x"1F", x"F8", x"07", x"FE", x"00", x"1E", x"00", x"06", x"00", x"00", x"00", x"F0", x"0F", x"F8", x"1F", 
    x"FC", x"3F", x"1E", x"78", x"06", x"60", x"06", x"60", x"1E", x"78", x"FC", x"3F", x"FC", x"1F", x"F0", x"0F", 
    x"00", x"60", x"18", x"60", x"1C", x"60", x"0C", x"60", x"FE", x"7F", x"FE", x"7F", x"FE", x"7F", x"00", x"60", 
    x"00", x"60", x"00", x"60", x"0C", x"70", x"0E", x"78", x"06", x"7C", x"06", x"6E", x"06", x"67", x"8E", x"63", 
    x"FE", x"61", x"FC", x"60", x"78", x"60", x"00", x"60", x"00", x"00", x"0C", x"60", x"CE", x"60", x"C6", x"60", 
    x"C6", x"60", x"E6", x"71", x"FE", x"7F", x"BE", x"3F", x"1C", x"1E", x"00", x"00", x"00", x"06", x"80", x"07", 
    x"C0", x"07", x"E0", x"06", x"78", x"06", x"1C", x"06", x"FE", x"7F", x"FE", x"7F", x"FE", x"7F", x"00", x"06", 
    x"00", x"00", x"FE", x"60", x"FE", x"60", x"FE", x"60", x"C6", x"60", x"C6", x"71", x"C6", x"7F", x"86", x"3F", 
    x"06", x"1F", x"06", x"0E", x"E0", x"0F", x"F8", x"3F", x"FC", x"3F", x"9E", x"71", x"CE", x"60", x"C6", x"60", 
    x"C6", x"71", x"C6", x"7F", x"84", x"3F", x"00", x"1F", x"06", x"00", x"06", x"60", x"06", x"7C", x"06", x"7F", 
    x"C6", x"1F", x"F6", x"03", x"FE", x"00", x"3E", x"00", x"0E", x"00", x"06", x"00", x"00", x"1E", x"3C", x"3F", 
    x"7C", x"7F", x"FE", x"71", x"E6", x"61", x"C6", x"61", x"FE", x"73", x"7E", x"7F", x"3C", x"3F", x"00", x"1E", 
    x"F8", x"00", x"FC", x"21", x"FE", x"63", x"8E", x"63", x"06", x"63", x"06", x"73", x"8E", x"79", x"FC", x"3F", 
    x"FC", x"1F", x"F0", x"07", x"00", x"00", x"00", x"00", x"00", x"00", x"38", x"1C", x"38", x"1C", x"38", x"1C", 
    x"38", x"1C", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"38", x"9C", x"38", x"FC", x"38", x"FC", 
    x"38", x"3C", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"01", x"80", x"01", 
    x"C0", x"03", x"E0", x"07", x"60", x"06", x"70", x"0E", x"30", x"0C", x"38", x"1C", x"18", x"18", x"18", x"18", 
    x"30", x"03", x"30", x"03", x"30", x"03", x"30", x"03", x"30", x"03", x"30", x"03", x"30", x"03", x"30", x"03", 
    x"30", x"03", x"30", x"03", x"18", x"18", x"18", x"18", x"38", x"1C", x"30", x"0C", x"70", x"0E", x"60", x"06", 
    x"E0", x"07", x"C0", x"03", x"80", x"01", x"80", x"01", x"0E", x"00", x"0E", x"00", x"06", x"00", x"06", x"66", 
    x"06", x"67", x"86", x"67", x"CE", x"01", x"FE", x"00", x"7C", x"00", x"3C", x"00", x"F0", x"0F", x"FC", x"3F", 
    x"1C", x"38", x"C6", x"67", x"E2", x"4F", x"32", x"4C", x"36", x"4C", x"3E", x"6C", x"FC", x"6F", x"F8", x"0F", 
    x"00", x"38", x"80", x"3F", x"E0", x"1F", x"FC", x"07", x"3C", x"06", x"3C", x"06", x"FC", x"07", x"E0", x"1F", 
    x"80", x"3F", x"00", x"38", x"FC", x"3F", x"FC", x"3F", x"FC", x"3F", x"8C", x"31", x"8C", x"31", x"8C", x"31", 
    x"CC", x"33", x"FC", x"3F", x"78", x"1F", x"78", x"1E", x"E0", x"07", x"F0", x"0F", x"F8", x"1F", x"38", x"1C", 
    x"1C", x"38", x"0C", x"30", x"0C", x"30", x"0C", x"30", x"1C", x"30", x"18", x"10", x"FC", x"3F", x"FC", x"3F", 
    x"FC", x"3F", x"0C", x"30", x"0C", x"30", x"1C", x"38", x"3C", x"3C", x"F8", x"1F", x"F8", x"0F", x"E0", x"07", 
    x"FC", x"3F", x"FC", x"3F", x"FC", x"3F", x"8C", x"31", x"8C", x"31", x"8C", x"31", x"8C", x"31", x"8C", x"31", 
    x"0C", x"30", x"0C", x"30", x"FC", x"3F", x"FC", x"3F", x"FC", x"3F", x"8C", x"01", x"8C", x"01", x"8C", x"01", 
    x"8C", x"01", x"8C", x"01", x"0C", x"00", x"0C", x"00", x"E0", x"07", x"F0", x"0F", x"F8", x"1F", x"38", x"1C", 
    x"1C", x"38", x"0C", x"30", x"8C", x"31", x"8C", x"31", x"9C", x"3F", x"98", x"1F", x"FC", x"3F", x"FC", x"3F", 
    x"FC", x"3F", x"80", x"01", x"80", x"01", x"80", x"01", x"80", x"01", x"FC", x"3F", x"FC", x"3F", x"FC", x"3F", 
    x"0C", x"30", x"0C", x"30", x"0C", x"30", x"FC", x"3F", x"FC", x"3F", x"FC", x"3F", x"0C", x"30", x"0C", x"30", 
    x"0C", x"30", x"00", x"00", x"00", x"00", x"00", x"30", x"0C", x"30", x"0C", x"30", x"0C", x"30", x"0C", x"38", 
    x"FC", x"3F", x"FC", x"1F", x"FC", x"0F", x"00", x"00", x"FC", x"3F", x"FC", x"3F", x"FC", x"3F", x"C0", x"03", 
    x"E0", x"07", x"78", x"0F", x"3C", x"1E", x"1C", x"3C", x"0C", x"38", x"04", x"30", x"FC", x"3F", x"FC", x"3F", 
    x"FC", x"3F", x"00", x"30", x"00", x"30", x"00", x"30", x"00", x"30", x"00", x"30", x"00", x"30", x"00", x"00", 
    x"FC", x"3F", x"FC", x"3F", x"FC", x"3F", x"F8", x"00", x"F0", x"07", x"C0", x"07", x"E0", x"07", x"F8", x"00", 
    x"FC", x"3F", x"FC", x"3F", x"FC", x"3F", x"FC", x"3F", x"FC", x"3F", x"F8", x"00", x"F0", x"03", x"C0", x"0F", 
    x"00", x"1F", x"FC", x"3F", x"FC", x"3F", x"FC", x"3F", x"E0", x"07", x"F8", x"1F", x"F8", x"1F", x"1C", x"38", 
    x"0C", x"30", x"0C", x"30", x"1C", x"38", x"F8", x"1F", x"F8", x"1F", x"E0", x"07", x"FC", x"3F", x"FC", x"3F", 
    x"FC", x"3F", x"8C", x"01", x"8C", x"01", x"8C", x"01", x"CC", x"01", x"FC", x"01", x"F8", x"00", x"78", x"00", 
    x"E0", x"07", x"F8", x"0F", x"F8", x"1F", x"1C", x"38", x"0C", x"30", x"0C", x"70", x"1C", x"F8", x"F8", x"DF", 
    x"F8", x"CF", x"E0", x"87", x"FC", x"3F", x"FC", x"3F", x"FC", x"3F", x"8C", x"01", x"8C", x"03", x"CC", x"07", 
    x"FC", x"1F", x"FC", x"3E", x"78", x"38", x"00", x"30", x"78", x"18", x"F8", x"38", x"FC", x"38", x"CC", x"30", 
    x"8C", x"31", x"8C", x"31", x"8C", x"33", x"1C", x"3F", x"18", x"1F", x"00", x"0E", x"00", x"00", x"0C", x"00", 
    x"0C", x"00", x"0C", x"00", x"FC", x"3F", x"FC", x"3F", x"FC", x"3F", x"0C", x"00", x"0C", x"00", x"0C", x"00", 
    x"FC", x"0F", x"FC", x"1F", x"FC", x"3F", x"00", x"38", x"00", x"30", x"00", x"30", x"00", x"38", x"FC", x"3F", 
    x"FC", x"1F", x"FC", x"0F", x"0C", x"00", x"FC", x"00", x"F8", x"03", x"E0", x"1F", x"80", x"3F", x"00", x"3C", 
    x"80", x"3F", x"E0", x"1F", x"FC", x"03", x"3C", x"00", x"00", x"00", x"FC", x"07", x"FC", x"1F", x"00", x"3F", 
    x"C0", x"1F", x"E0", x"07", x"C0", x"1F", x"00", x"3F", x"FC", x"1F", x"FC", x"07", x"00", x"00", x"0C", x"30", 
    x"1C", x"38", x"78", x"1E", x"E0", x"07", x"C0", x"03", x"E0", x"07", x"78", x"1E", x"1C", x"38", x"0C", x"30", 
    x"00", x"00", x"1C", x"00", x"7C", x"00", x"F0", x"00", x"E0", x"3F", x"80", x"3F", x"E0", x"3F", x"F0", x"00", 
    x"7C", x"00", x"1C", x"00", x"0C", x"38", x"0C", x"3C", x"0C", x"3E", x"0C", x"3F", x"8C", x"37", x"CC", x"33", 
    x"EC", x"31", x"FC", x"30", x"7C", x"30", x"1C", x"30", x"00", x"00", x"00", x"00", x"FF", x"FF", x"FF", x"FF", 
    x"FF", x"FF", x"03", x"C0", x"03", x"C0", x"03", x"C0", x"03", x"C0", x"00", x"00", x"00", x"00", x"07", x"00", 
    x"1F", x"00", x"FF", x"00", x"F8", x"07", x"E0", x"1F", x"00", x"FF", x"00", x"F8", x"00", x"E0", x"00", x"00", 
    x"00", x"00", x"03", x"C0", x"03", x"C0", x"03", x"C0", x"03", x"C0", x"FF", x"FF", x"FF", x"FF", x"FF", x"FF", 
    x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"01", x"E0", x"01", x"FC", x"00", x"1E", x"00", x"1E", x"00", 
    x"FC", x"00", x"E0", x"01", x"80", x"01", x"00", x"00", x"00", x"C0", x"00", x"C0", x"00", x"C0", x"00", x"C0", 
    x"00", x"C0", x"00", x"C0", x"00", x"C0", x"00", x"C0", x"00", x"C0", x"00", x"C0", x"00", x"00", x"00", x"00", 
    x"00", x"00", x"02", x"00", x"06", x"00", x"06", x"00", x"04", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
    x"00", x"1C", x"60", x"3E", x"70", x"3F", x"30", x"33", x"30", x"31", x"30", x"39", x"F0", x"1F", x"F0", x"3F", 
    x"E0", x"3F", x"00", x"30", x"FE", x"3F", x"FE", x"3F", x"FE", x"3F", x"60", x"38", x"30", x"30", x"30", x"30", 
    x"70", x"38", x"F0", x"3F", x"E0", x"1F", x"C0", x"07", x"80", x"07", x"E0", x"1F", x"E0", x"1F", x"70", x"38", 
    x"30", x"38", x"30", x"30", x"30", x"30", x"30", x"30", x"30", x"30", x"20", x"10", x"80", x"0F", x"E0", x"1F", 
    x"F0", x"3F", x"70", x"38", x"30", x"30", x"30", x"30", x"70", x"38", x"FE", x"3F", x"FE", x"3F", x"FE", x"3F", 
    x"80", x"0F", x"E0", x"1F", x"E0", x"1F", x"70", x"3B", x"30", x"33", x"30", x"33", x"70", x"33", x"F0", x"33", 
    x"E0", x"3B", x"C0", x"1B", x"60", x"00", x"60", x"00", x"60", x"00", x"FC", x"3F", x"FE", x"3F", x"FF", x"3F", 
    x"63", x"00", x"63", x"00", x"63", x"00", x"63", x"00", x"80", x"0F", x"E0", x"4F", x"F0", x"DF", x"70", x"DC", 
    x"30", x"D8", x"30", x"D8", x"70", x"D8", x"F0", x"FF", x"F0", x"FF", x"F0", x"7F", x"FE", x"3F", x"FE", x"3F", 
    x"FE", x"3F", x"60", x"00", x"70", x"00", x"30", x"00", x"30", x"00", x"F0", x"3F", x"F0", x"3F", x"E0", x"3F", 
    x"00", x"00", x"30", x"00", x"30", x"00", x"30", x"00", x"30", x"00", x"F3", x"3F", x"F3", x"3F", x"F3", x"3F", 
    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"60", x"30", x"E0", x"30", x"C0", x"30", x"C0", x"30", x"C0", 
    x"F3", x"FF", x"F3", x"7F", x"F3", x"3F", x"00", x"00", x"FE", x"3F", x"FE", x"3F", x"FE", x"3F", x"80", x"07", 
    x"E0", x"0F", x"F0", x"1F", x"70", x"3C", x"30", x"38", x"10", x"30", x"00", x"20", x"00", x"00", x"06", x"00", 
    x"06", x"00", x"06", x"00", x"06", x"00", x"FE", x"3F", x"FE", x"3F", x"FE", x"3F", x"00", x"00", x"00", x"00", 
    x"F0", x"3F", x"F0", x"3F", x"F0", x"3F", x"70", x"00", x"F0", x"3F", x"E0", x"3F", x"70", x"00", x"F0", x"3F", 
    x"F0", x"3F", x"E0", x"3F", x"F0", x"3F", x"F0", x"3F", x"F0", x"3F", x"60", x"00", x"70", x"00", x"30", x"00", 
    x"30", x"00", x"F0", x"3F", x"F0", x"3F", x"E0", x"3F", x"80", x"07", x"E0", x"1F", x"E0", x"1F", x"70", x"38", 
    x"30", x"30", x"30", x"30", x"70", x"38", x"E0", x"1F", x"E0", x"1F", x"80", x"07", x"F0", x"FF", x"F0", x"FF", 
    x"F0", x"FF", x"70", x"1C", x"30", x"18", x"30", x"18", x"70", x"1C", x"F0", x"1F", x"E0", x"0F", x"C0", x"07", 
    x"80", x"07", x"E0", x"0F", x"F0", x"1F", x"70", x"1C", x"30", x"18", x"30", x"18", x"70", x"1C", x"F0", x"FF", 
    x"F0", x"FF", x"F0", x"FF", x"00", x"00", x"F0", x"3F", x"F0", x"3F", x"F0", x"3F", x"70", x"00", x"30", x"00", 
    x"30", x"00", x"70", x"00", x"70", x"00", x"00", x"00", x"E0", x"18", x"F0", x"39", x"F0", x"31", x"B0", x"33", 
    x"30", x"33", x"30", x"33", x"30", x"3F", x"30", x"1E", x"00", x"1C", x"00", x"00", x"30", x"00", x"30", x"00", 
    x"30", x"00", x"FC", x"1F", x"FC", x"3F", x"FC", x"3F", x"30", x"30", x"30", x"30", x"30", x"30", x"30", x"30", 
    x"F0", x"1F", x"F0", x"3F", x"F0", x"3F", x"00", x"30", x"00", x"30", x"00", x"38", x"00", x"18", x"F0", x"3F", 
    x"F0", x"3F", x"F0", x"3F", x"10", x"00", x"F0", x"00", x"F0", x"03", x"E0", x"1F", x"00", x"3F", x"00", x"3C", 
    x"C0", x"3F", x"F0", x"0F", x"F0", x"01", x"30", x"00", x"30", x"00", x"F0", x"0F", x"E0", x"3F", x"00", x"1E", 
    x"C0", x"03", x"C0", x"03", x"00", x"1E", x"E0", x"3F", x"F0", x"0F", x"30", x"00", x"10", x"20", x"30", x"30", 
    x"F0", x"3C", x"F0", x"1F", x"C0", x"07", x"C0", x"0F", x"E0", x"3F", x"F0", x"3C", x"30", x"30", x"10", x"20", 
    x"10", x"00", x"F0", x"00", x"F0", x"C3", x"E0", x"CF", x"00", x"FF", x"00", x"7F", x"C0", x"0F", x"F0", x"01", 
    x"F0", x"00", x"10", x"00", x"30", x"30", x"30", x"38", x"30", x"3C", x"30", x"3E", x"30", x"37", x"B0", x"33", 
    x"F0", x"31", x"F0", x"30", x"70", x"30", x"30", x"30", x"00", x"00", x"80", x"01", x"80", x"01", x"FE", x"7F", 
    x"FF", x"FF", x"7F", x"FE", x"03", x"C0", x"03", x"C0", x"03", x"C0", x"00", x"00", x"00", x"00", x"00", x"00", 
    x"00", x"00", x"FF", x"FF", x"FF", x"FF", x"FF", x"FF", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
    x"00", x"00", x"03", x"C0", x"03", x"C0", x"03", x"C0", x"7F", x"FE", x"FF", x"FF", x"FE", x"7F", x"80", x"01", 
    x"80", x"01", x"00", x"00", x"00", x"03", x"80", x"03", x"80", x"01", x"80", x"01", x"80", x"03", x"80", x"03", 
    x"00", x"03", x"00", x"03", x"80", x"03", x"80", x"01", others => x"00");

  type initdc_t   is array (0 to 15) of std_logic;
  constant initdc   : initdc_t   := ('0','1','0','1','0','0','1','1','1','1','0','1','1','1','1','0');

  type data_t is array (0 to 1023) of std_logic_vector(7 downto 0);
  constant dataram : data_t := (
      x"36",x"48",x"3A",x"55",x"29",x"2A",x"00",x"00",
      x"00",x"EF",x"2B",x"00",x"00",x"01",x"3F",x"2C",
      x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
      x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",

      
 x"50", x"61", x"64", x"69", x"77", x"61", x"20", x"53", x"74", x"61", x"74", x"75", x"73", x"0a", 
 x"0a", 
 x"54", x"65", x"6d", x"70", x"65", x"72", x"61", x"74", x"75", x"72", x"65", x"20", x"20", x"20", x"20", x"20", x"20", x"84", x"0a", 
 x"55", x"49", x"44", x"20", x"20", x"83",                      x"82",                      x"81",                      x"80", x"0a",
 x"45", x"6e", x"61", x"62", x"6c", x"65", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"85", x"0a", 
 x"49", x"6e", x"76", x"65", x"72", x"74", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"86", x"0a",
 x"49", x"6e", x"70", x"75", x"74", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20",x"20",  x"87", x"0a",  
 x"0a",
 x"54", x"69", x"6d", x"65", x"72", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"8F",                      x"8E", x"0a",
 others => x"00");
    
    
  signal timer : unsigned(27 downto 0) := (others => '0');
  --2**16: 2.5ms
  --2**20: 40ms
  
  type state_t is (RSTIDLE, RSTRESET, RSTWAIT, RSTSELECT, 
                   RSTCONFIG1, RSTCONFIG2, RSTCONFIG3, RSTCONFIG4, 
                   RSTCONFIG5, RSTCLEAR, RSTCLEAR2, RSTFINISH, WAITSTART,
                   TSTART, WAITFONT, WRITEFONT, SETWINDOW,
                   WRITEWAIT, WRITESECONDBYTE, GETNIBBLE, 
                   GETHEX, NEXTCHAR);
  type spistate_t is (SPIIDLE, SPISEND1, SPISEND2, SPISEND3, SPISEND4);

  signal state     : state_t;
  signal spistate  : spistate_t;  

  signal cnt      : integer range 0 to 200000 := 0; --general purpose counter
  signal datapos  : integer range 0 to 1023;      --pointer in data ROM
  signal fontpos  : integer range 0 to 2047;      --pointer in font ROM
  
  signal spi_data : std_logic_vector(7 downto 0);
  signal spi_dc   : std_logic;
  signal spi_send : std_logic;
  signal spi_idle : std_logic;
  signal spi_busy : std_logic;
  signal spi_cnt  : integer range 0 to 7 := 0;
  signal spi_buf  : std_logic_vector(7 downto 0);
  
  signal poscol   : integer range 0 to 239 := 0;  --horizontal position
  signal posrow   : integer range 0 to 19 := 0;   --vertical position in 16px steps
  
  signal curdata  : std_logic_vector(7 downto 0); --current byte in data ROM
  signal curfont  : std_logic_vector(7 downto 0); --curent font byte
  signal nibble   : unsigned        (7 downto 0); --var. nibble to show
  signal varcnt   : integer range 0 to 4  := 0;   --position within variable
  
  signal pixcnt   : integer range 0 to 15 := 0;   --Pixel count when plotting fonts
  signal bytecnt  : integer range 0 to 1  := 0;   --high or low byte when plotting fonts
  signal colcnt   : integer range 0 to 15 := 0;   --number of cols in current char
  
begin

spi_idle <= not spi_busy and not spi_send;


spi_fsm : process begin
  wait until rising_edge(CLK);
  case spistate is
    when SPIIDLE =>
      MOSI <= '0';
      SCK  <= '0';
      spi_busy <= '0';
      if spi_send = '1' then
        spistate <= SPISEND1;
        spi_buf  <= spi_data;
        spi_busy <= '1';
        spi_cnt  <= 7;
        DC       <= spi_dc;
      end if;
    when SPISEND1 =>  
      spistate <= SPISEND2;
      SCK      <= '0';
      MOSI     <= spi_buf(spi_cnt);
    when SPISEND2 =>  
      spistate <= SPISEND3;
      SCK      <= '0';
      MOSI     <= spi_buf(spi_cnt);
    when SPISEND3 =>  
      spistate <= SPISEND4;
      SCK      <= '1';
      MOSI     <= spi_buf(spi_cnt);
    when SPISEND4 =>  
      SCK      <= '1';
      MOSI     <= spi_buf(spi_cnt);
      if spi_cnt = 0 then
        spistate <= SPIIDLE;
      else
        spistate <= SPISEND1;
        spi_cnt  <= spi_cnt - 1;
      end if;
  end case;
  if RESET = '1' then
    spistate <= SPIIDLE;
  end if;
end process;


fsm : process begin
  wait until rising_edge(CLK);
  timer    <= timer + 1;
  RST      <= '1';
  CS       <= '0';
  spi_send <= '0';
  LED(0)   <= '1';
  case state is
--------------------------------------------------------------      
--  Reset sequence
--------------------------------------------------------------   
    when RSTIDLE =>
      RST <= '1';
      CS  <= '1';
      if timer = x"4000000" then --2500ms
        state <= RSTRESET;
        timer <= (others => '0');
      end if;  
    when RSTRESET =>
      RST <= '0';
      CS  <= '1';
      if timer = x"0300000" then --120ms
        state <= RSTWAIT;
        timer <= (others => '0');
      end if;  
    when RSTWAIT =>
      RST <= '1';
      CS  <= '1';
      if timer = x"0300000" then  --120ms
        state <= RSTSELECT;
        timer <= (others => '0');
      end if;  
    when RSTSELECT =>
      if timer = x"000000F" then  --short...
        state <= RSTCONFIG1;
        spi_data <= x"11";
        spi_dc   <= '0';
        spi_send <= '1';
        timer <= (others => '0');
      end if;
    when RSTCONFIG1 =>
      if timer = x"0200000" then --80ms
        state <= RSTCONFIG2;
        timer <= (others => '0');
        datapos   <= 0;
      end if;
--------------------------------------------------------------      
--  Load config & clear display
--------------------------------------------------------------       
    when RSTCONFIG2 =>
      if spi_idle = '1' then
        if datapos = 15 then
          state <= RSTCLEAR;
          datapos <= 0;
        else
          datapos <= datapos + 1;
        end if;
        spi_data <= curdata;
        spi_dc   <= initdc(datapos);
        spi_send <= '1';
      end if;
    when RSTCLEAR =>
      if spi_idle = '1' then
        cnt <= cnt + 1;
        spi_data <= x"20";
        spi_dc   <= '1';
        spi_send <= '1';
        state   <= RSTCLEAR2;
        if cnt = 320*240*2-1 then
          state <= RSTFINISH;
        end if;
      end if;
    when RSTCLEAR2 =>
      if spi_idle = '1' then
        cnt <= cnt + 1;
        spi_data <= x"8B";
        spi_dc   <= '1';
        spi_send <= '1';
        state   <= RSTCLEAR;
        if cnt = 320*240*2-1 then
          state <= RSTFINISH;
        end if;
      end if;
    when RSTFINISH =>
      LED(0)  <= '0';
      poscol  <= 0;
      posrow  <= 0;
      datapos <= 32; --start of text section
      varcnt  <= 4;  --no nibble active
      state   <= WAITSTART;
      
--------------------------------------------------------------      
--  Write text from memory
--------------------------------------------------------------     
    when NEXTCHAR =>
      state <= WAITSTART;
      if varcnt = 0 or varcnt = 4 then
        datapos <= datapos + 1;
        varcnt  <= 4;
      end if;
      
    when WAITSTART =>
      state <= TSTART;
    when TSTART =>
      if curdata >= x"20" and curdata <= x"7E" then  --plain text
        state   <= SETWINDOW;
        cnt     <= 0;
        colcnt  <= 0;
        bytecnt <= 0;
        varcnt  <= 4; 
        fontpos <= (to_integer(unsigned(curdata)) - 32)*20;
      elsif curdata(7 downto 4) = x"8" then  --show a variable
        state   <= GETNIBBLE;
        varcnt  <= varcnt - 1;               --here: range 4..1
        nibble  <= x"0" & unsigned(INPUT(to_integer(unsigned(curdata(3 downto 0)))*16+varcnt*4-1 downto 
                                         to_integer(unsigned(curdata(3 downto 0)))*16+varcnt*4-4));
      elsif curdata = x"0a" then   --line break
        poscol  <= 0;
        posrow  <= posrow + 1;
        datapos <= datapos + 1;
        state <= WAITSTART;
      elsif curdata = x"00" then   --end of string
        state <= RSTFINISH;
      else                         --error, skip
        datapos <= datapos + 1;
      end if;
    
    when GETNIBBLE =>
      state <= GETHEX;
      if nibble < x"0a" then
        nibble <= nibble + x"30";
      else
        nibble <= nibble + x"57";
      end if;
      
    when GETHEX =>
      state   <= SETWINDOW;
      cnt     <= 0;
      colcnt  <= 0;
      bytecnt <= 0;
      fontpos <= (to_integer(nibble) - 32)*20;
    
    when SETWINDOW =>
      if cnt < 11 then
        if spi_idle = '1' then
          cnt <= cnt + 1;
          spi_send <= '1';
          case cnt is
            when 0 => spi_dc <= '0'; spi_data <= x"2A";
            when 1 => spi_dc <= '1'; spi_data <= x"00";
            when 2 => spi_dc <= '1'; spi_data <= std_logic_vector(to_unsigned(poscol,8));
            when 3 => spi_dc <= '1'; spi_data <= x"00";
            when 4 => spi_dc <= '1'; spi_data <= std_logic_vector(to_unsigned(poscol,8));
            when 5 => spi_dc <= '0'; spi_data <= x"2B";
            when 6 => spi_dc <= '1'; spi_data <= std_logic_vector(to_unsigned(posrow/16,8));
            when 7 => spi_dc <= '1'; spi_data <= std_logic_vector(to_unsigned(posrow*16,8));
            when 8 => spi_dc <= '1'; spi_data <= std_logic_vector(to_unsigned((posrow*16+15)/256,8));
            when 9 => spi_dc <= '1'; spi_data <= std_logic_vector(to_unsigned(posrow*16+15,8));
            when 10=> spi_dc <= '0'; spi_data <= x"2C";
          end case;
        end if;
      else
        state  <= WRITEFONT;
        spi_dc <= '1';
        bytecnt<= 0;
        pixcnt <= 0;
      end if;

    when WRITEWAIT =>
      state <= WRITEFONT;
    when WRITEFONT =>
      if pixcnt = 8 and bytecnt = 1 and colcnt < 10 then --end of column
        state   <= SETWINDOW;
        cnt     <= 0;
        poscol  <= poscol + 1;
        colcnt  <= colcnt + 1;
        fontpos <= fontpos + 1;
      elsif pixcnt = 8 and bytecnt = 1 and colcnt = 10 then --end of character
        state   <= NEXTCHAR;
        poscol  <= poscol + 1;
      elsif spi_idle = '1' then
        if pixcnt < 8 then
          state <= WRITESECONDBYTE;
          if colcnt < 10 and curfont(pixcnt) = '1' then
            if varcnt = 4 then
              spi_data <= x"FD";
            else
              spi_data <= x"FF";
            end if;
          else
            spi_data <= x"20";
          end if;
          spi_send <= '1';
        else
          state   <= WRITEWAIT;
          fontpos <= fontpos + 1;
          pixcnt  <= 0;
          bytecnt <= 1;  
        end if;
      end if;
    when WRITESECONDBYTE =>
      if spi_idle = '1' then
        spi_send <= '1';
        if colcnt < 10 and curfont(pixcnt) = '1' then
          if varcnt = 4 then
            spi_data <= x"40";
          else
            spi_data <= x"FF";
          end if;
        else
          spi_data <= x"8B";
        end if;
        state   <= WRITEFONT;
        pixcnt  <= pixcnt + 1;
      end if;
      
      
  end case;
  if RESET = '1' then
    state <= RSTIDLE;
    datapos <= 0;
  end if;
end process;

ram : process begin
  wait until rising_edge(CLK);
  curdata <= dataram(datapos);
  curfont <= fontram(fontpos);
end process;

LED(1) <= spi_idle;
LED(2) <= not spi_dc;
LED(3) <= not spi_send;

  
end architecture;
