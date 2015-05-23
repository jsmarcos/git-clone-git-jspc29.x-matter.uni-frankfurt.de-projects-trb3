library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity fifo_44_data_delay_my is
    port (
        Data          : in   std_logic_vector(43 downto 0); 
        Clock         : in   std_logic; 
        WrEn          : in   std_logic; 
        RdEn          : in   std_logic; 
        Reset         : in   std_logic; 
        AmEmptyThresh : in   std_logic_vector(7 downto 0); 
        Q             : out  std_logic_vector(43 downto 0); 
        Empty         : out  std_logic; 
        Full          : out  std_logic; 
        AlmostEmpty   : out  std_logic;
        DEBUG_OUT     : out std_logic_vector(15 downto 0)
        );
end entity;

architecture Behavioral of fifo_44_data_delay_my is
  constant BUS_WIDTH      : integer := 8;
  constant DATA_WIDTH     : integer := 44;
  constant FULL_LEVEL     : unsigned(BUS_WIDTH - 1 downto 0) := (others => '1');
                          
  signal write_address    : std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal write_data       : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal write_enable     : std_logic;
  signal write_ctr        : unsigned(BUS_WIDTH - 1 downto 0);
  signal write_ctr_x      : unsigned(BUS_WIDTH - 1 downto 0);
  signal full_o           : std_logic;
                          
  signal read_address     : std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal read_enable      : std_logic;
  signal read_enable_last : std_logic;
  signal read_ctr         : unsigned(BUS_WIDTH - 1 downto 0);
  signal read_ctr_x       : unsigned(BUS_WIDTH - 1 downto 0);
  signal read_data        : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal empty_o          : std_logic;
  signal empty_o_x        : std_logic;
  signal almost_empty_o   : std_logic;
  signal almost_empty_o_x : std_logic;

  signal Q_o              : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal Q_o_x            : std_logic_vector(DATA_WIDTH - 1 downto 0);
    
begin

  -----------------------------------------------------------------------------

  DEBUG_OUT(0)              <= Clock;
  DEBUG_OUT(1)              <= WrEn;
  DEBUG_OUT(2)              <= write_enable;
  DEBUG_OUT(3)              <= RdEn;
  DEBUG_OUT(4)              <= read_enable;
  DEBUG_OUT(5)              <= read_enable_last;
  DEBUG_OUT(6)              <= full_o;
  DEBUG_OUT(7)              <= empty_o;
  DEBUG_OUT(8)              <= almost_empty_o;
  DEBUG_OUT(9)              <= Reset;
  DEBUG_OUT(15 downto 10)    <=
    std_logic_vector(write_ctr - read_ctr)(5 downto 0);
  
  -----------------------------------------------------------------------------
  
  ram_fifo_delay_256x44_1: entity work.ram_fifo_delay_256x44
    port map (
      WrAddress => write_address,
      RdAddress => read_address, 
      Data      => write_data,   
      WE        => not Reset, 
      RdClock   => Clock,       
      RdClockEn => read_enable,  
      Reset     => Reset,
      WrClock   => Clock,
      WrClockEn => write_enable, 
      Q         => read_data     
      );
  
  -----------------------------------------------------------------------------
  -- RAM Handler
  -----------------------------------------------------------------------------
  PROC_MEM_WRITE_TRANSFER: process(Clock)
  begin
    if( rising_edge(Clock) ) then
      if( Reset = '1' ) then
        write_ctr            <= (others => '0');
        read_ctr             <= (others => '0');
        read_enable_last     <= '0';
        Q_o                  <= (others => '0');
      else
        write_ctr            <= write_ctr_x;
        read_ctr             <= read_ctr_x;
        read_enable_last     <= read_enable;
        Q_o                  <= Q_o_x;
      end if;
    end if;
  end process PROC_MEM_WRITE_TRANSFER;

  PROC_MEM_WRITE: process(WrEn,
                          RdEn,
                          Data,
                          write_ctr,
                          read_ctr,
                          read_data,
                          read_enable_last,  
                          full_o,
                          empty_o,
                          AmEmptyThresh
                          )
    variable delta_ctr      : unsigned(BUS_WIDTH - 1 downto 0);
    variable full           : std_logic;
    variable empty          : std_logic;
    variable almost_empty   : std_logic;
    
  begin

    -- Fill Level
    delta_ctr               := write_ctr - read_ctr;

    -- Empty
    if (delta_ctr = 0) then
      empty              := '1';
    else
      empty              := '0';
    end if;

    -- Almost Empty
    if (delta_ctr < unsigned(AmEmptyThresh)) then
      almost_empty       := '1';
    else
      almost_empty       := '0';
    end if;

    -- Full
    if (delta_ctr = FULL_LEVEL) then
      full               := '1';
    else
      full               := '0';
    end if;   

    full_o         <= full;
    empty_o        <= empty;
    almost_empty_o <= almost_empty;
    
    -- FIFO Writes
    if (WrEn = '1' and full = '0') then
      write_address          <= write_ctr;
      write_data             <= Data;
      write_enable           <= '1';
      write_ctr_x            <= write_ctr + 1;
    else                  
      write_address          <= (others => '0');
      write_data             <= (others => '0');
      write_enable           <= '0';
      write_ctr_x            <= write_ctr;
    end if;               

    -- FIFO Reads
    if (RdEn = '1' and empty = '0') then
      read_address           <= read_ctr;
      read_enable            <= '1';
      read_ctr_x             <= read_ctr + 1;
    else                  
      read_address           <= (others => '0');
      read_enable            <= '0';
      read_ctr_x             <= read_ctr;
    end if;               
    
    if (read_enable_last = '1') then
      Q_o_x                  <= read_data;
    else
      Q_o_x                  <= (others => '0');
    end if;
    
  end process PROC_MEM_WRITE;

  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  Q              <= Q_o;
  Empty          <= empty_o;
  Full           <= full_o;
  AlmostEmpty    <= almost_empty_o;
  
end Behavioral;
