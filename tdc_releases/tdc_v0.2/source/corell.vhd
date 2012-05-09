-------------------------------------------------------------------------------
-- Title      : Corell_Entity
-- Project    : 
-------------------------------------------------------------------------------
-- File       : corell.vhd
-- Author     :   <cugur@>
-- Company    : 
-- Created    : 2012-02-20
-- Last update: 2012-02-21
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Entity created for Oliver Corell
-------------------------------------------------------------------------------
-- Copyright (c) 2012 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2012-02-20  1.0      cugur   Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity corell is
  
  port (
    CLK        : in  std_logic;         -- clock 100 MHz
--
    DATA_IN    : in  std_logic_vector(95 downto 0);  -- data in from slow control
    CONTROL_IN : in  std_logic_vector(3 downto 0);   -- control reg in from SC 
    MOSI_OUT   : out std_logic;         -- master out slave in
    SCK_OUT    : out std_logic;         -- clock
    CS_OUT     : out std_logic_vector(3 downto 0)    -- chip select (inverted)
    );

end corell;

architecture behavioral of corell is

-------------------------------------------------------------------------------
-- Component Declerations
-------------------------------------------------------------------------------
  component pll_100_in_5_out
    port (
      CLK   : in  std_logic;
      CLKOP : out std_logic;
      LOCK  : out std_logic);
  end component;
--
  component signal_sync
    generic (
      WIDTH : integer;
      DEPTH : integer);
    port (
      RESET : in  std_logic;
      CLK0  : in  std_logic;
      CLK1  : in  std_logic;
      D_IN  : in  std_logic_vector(WIDTH-1 downto 0);
      D_OUT : out std_logic_vector(WIDTH-1 downto 0));
  end component;
--
  component bit_sync
    generic (
      DEPTH : integer);
    port (
      RESET : in  std_logic;
      CLK0  : in  std_logic;
      CLK1  : in  std_logic;
      D_IN  : in  std_logic;
      D_OUT : out std_logic);
  end component;
-------------------------------------------------------------------------------
-- Signal Declerations
-------------------------------------------------------------------------------
  signal clk_100_i             : std_logic;
  signal clk_5_i               : std_logic;
  signal lock_i                : std_logic;
  signal rst_i                 : std_logic;
--
  signal data_100_i            : std_logic_vector(95 downto 0);
  signal control_100_i         : std_logic_vector(3 downto 0);
  signal data_5_i              : std_logic_vector(95 downto 0);
  signal control_5_i           : std_logic_vector(3 downto 0);
--
  signal mosi_i                : std_logic;
  signal cs_i                  : std_logic_vector(3 downto 0);
  signal sck_i                 : std_logic;
--
  type   FSM is (IDLE, SEND);
  signal FSM_CURRENT, FSM_NEXT : FSM;
  signal mosi_fsm              : std_logic;
  signal cs_fsm                : std_logic_vector(3 downto 0);
  signal clk_en_fsm            : std_logic;
  signal clk_en_i              : std_logic;
  signal i_fsm                 : integer;
  signal i                     : integer;
--
  signal new_command_reg       : std_logic;
  signal new_command_i         : std_logic_vector(3 downto 0);
  signal send_reg              : std_logic;
  signal control_5_reg         : std_logic_vector(3 downto 0);
  signal cs_nr                 : integer := 0;

-------------------------------------------------------------------------------
  
begin  -- behavioral

  clk_100_i     <= CLK;
  data_100_i    <= DATA_IN;
  control_100_i <= CONTROL_IN;
  rst_i         <= not lock_i;

-------------------------------------------------------------------------------
  -- clock settings and clock domain crossings

  pll_100_in_5_out_1 : pll_100_in_5_out
    port map (
      CLK   => clk_100_i,
      CLKOP => clk_5_i,
      LOCK  => lock_i);

  signal_sync_1 : signal_sync
    generic map (
      WIDTH => 96,
      DEPTH => 3)
    port map (
      RESET => rst_i,
      CLK0  => clk_100_i,
      CLK1  => clk_5_i,
      D_IN  => data_100_i,
      D_OUT => data_5_i);

  signal_sync_2 : signal_sync
    generic map (
      WIDTH => 4,
      DEPTH => 3)
    port map (
      RESET => rst_i,
      CLK0  => clk_100_i,
      CLK1  => clk_5_i,
      D_IN  => control_100_i,
      D_OUT => control_5_i);
-------------------------------------------------------------------------------

  --purpose: FSM
  FSM_CLK : process (clk_5_i)
  begin
    if rising_edge(clk_5_i) then
      if lock_i = '0' then
        FSM_CURRENT <= IDLE;
        clk_en_i    <= '0';
        mosi_i      <= '0';
        cs_i        <= x"F";
        i           <= 0;
      else
        FSM_CURRENT <= FSM_NEXT;
        clk_en_i    <= clk_en_fsm;
        mosi_i      <= mosi_fsm;
        cs_i        <= cs_fsm;
        i           <= i_fsm;
      end if;
    end if;
  end process FSM_CLK;

  FSM_PROC : process (FSM_CURRENT, new_command_reg, send_reg, i, data_5_i)
  begin

    clk_en_fsm <= '0';
    mosi_fsm   <= '0';
    cs_fsm     <= x"F";
    i_fsm      <= 95;

    case (FSM_CURRENT) is
      when IDLE =>
        if new_command_reg = '1' and send_reg = '1' then
          FSM_NEXT   <= SEND;
          clk_en_fsm <= '1';
        else
          FSM_NEXT <= IDLE;
        end if;
--
      when SEND =>
        if i = 0 then
          FSM_NEXT <= IDLE;
        else
          FSM_NEXT <= SEND;
        end if;
        clk_en_fsm    <= '1';
        mosi_fsm      <= data_5_i(i);
        cs_fsm(cs_nr) <= '0';
        i_fsm         <= i - 1;
--      
      when others =>
        FSM_NEXT <= IDLE;
    end case;
  end process FSM_PROC;

  CLK_en : process (clk_5_i)
  begin
    if rising_edge(clk_5_i) or falling_edge(clk_5_i) then
      if clk_en_i = '1' then
        sck_i <= clk_5_i;
      else
        sck_i <= '0';
      end if;
    end if;
  end process CLK_en;

  MOSI_OUT <= mosi_i;
  SCK_OUT  <= sck_i;
  CS_OUT   <= cs_i;

  --purpose: Register the control signal
  Registering : process (clk_5_i)
  begin
    if rising_edge(clk_5_i) then
      if lock_i = '0' then
        control_5_reg   <= (others => '0');
        new_command_reg <= '0';
      else
        control_5_reg   <= control_5_i;
        new_command_reg <= new_command_i(0) or new_command_i(1) or new_command_i(2) or new_command_i(3);
      end if;
    end if;
  end process Registering;

  New_Command : for j in 0 to 3 generate
    new_command_i(j) <= control_5_reg(j) xor control_5_i(j);
  end generate New_Command;

  send_reg <= control_5_reg(3);
  cs_nr    <= to_integer(unsigned(control_5_reg(1 downto 0)));

end behavioral;
