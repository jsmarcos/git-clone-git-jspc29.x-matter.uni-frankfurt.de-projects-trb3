----------------------------------------------------------------------------
-- SPI IF
-- Interface to the SPI bus controlling the three DACs on the mupix test board
--
-- Niklaus Berger, Heidelberg University
-- nberger@physi.uni-heidelberg.de
--
-- 
--
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.mupix_comp.all;

entity spi_if is
  port(
    clk            : in  std_logic;
    reset_n        : in  std_logic;
    threshold_reg  : in  std_logic_vector(15 downto 0);
    injection1_reg : in  std_logic_vector(15 downto 0);
    injection2_reg : in  std_logic_vector(15 downto 0);
    wren           : in  std_logic;
    spi_data       : out std_logic;
    spi_clk        : out std_logic;
    spi_ld         : out std_logic
    );          
end entity spi_if;



architecture rtl of spi_if is

  type   state_type is (waiting, writing, loading);
  signal state : state_type;

  signal shiftregister : std_logic_vector(47 downto 0);
  signal write_again   : std_logic;

  signal ckdiv : std_logic_vector(4 downto 0);



  signal cyclecounter : std_logic_vector(7 downto 0);

begin


  process(clk, reset_n)

  begin
    if(reset_n = '0') then
      ckdiv        <= (others => '0');
      cyclecounter <= (others => '0');
      spi_data     <= '0';
      spi_clk      <= '0';
      spi_ld       <= '0';
      state        <= waiting;
    elsif(clk'event and clk = '1') then
      case state is
        when waiting =>
          ckdiv        <= (others => '0');
          cyclecounter <= (others => '0');
          spi_data     <= '0';
          spi_clk      <= '0';
          spi_ld       <= '0';
          state        <= waiting;

          if(wren = '1' or write_again = '1') then
            shiftregister <= injection2_reg & injection1_reg & threshold_reg;
            state         <= writing;
            write_again   <= '0';
          end if;
        when writing =>
          if(wren = '1') then
            write_again <= '1';
          end if;

          ckdiv <= ckdiv + '1';
          if(ckdiv = "00000") then
            cyclecounter <= cyclecounter + '1';
            if(cyclecounter(0) = '0') then  -- even cycles: push data, clock at '0'
              spi_data                   <= shiftregister(47);
              shiftregister(47 downto 1) <= shiftregister(46 downto 0);
              shiftregister(0)           <= '0';
              spi_clk                    <= '0';
            end if;
            if(cyclecounter(0) = '1') then  --odd cycles: 
              spi_clk <= '1';
            end if;
            if(cyclecounter = "01100000") then  -- we are done...
              state        <= loading;
              spi_clk      <= '1';
              cyclecounter <= "00000000";
            end if;
          end if;
        when loading =>
          if(wren = '1') then
            write_again <= '1';
          end if;
          ckdiv <= ckdiv + '1';
          if(ckdiv = "00000") then
            cyclecounter <= cyclecounter + '1';
            if(cyclecounter = "00000000") then
              spi_ld <= '1';
            elsif(cyclecounter = "00000001") then
              spi_clk <= '0';
            elsif(cyclecounter = "00000010") then
              spi_ld <= '0';
              state  <= waiting;
            end if;
          end if;
      end case;
    end if;
  end process;

end rtl;
