-------------------------------------------------------------------------------
-- Title      : Readout Header Entity
-- Project    : 
-------------------------------------------------------------------------------
-- File       : Readout_header.vhd
-- Author     : cugur@gsi.de
-- Created    : 2012-10-25
-- Last update: 2014-08-06
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2012 
-------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--library work;
--use work.trb_net_std.all;
--use work.trb_net_components.all;
--use work.trb3_components.all;

entity Readout_Header is
  port (
    RESET_100             : in  std_logic;
    CLK_100               : in  std_logic;
-- from the endpoint
    VALID_TIMING_TRG_IN   : in  std_logic;
    VALID_NOTIMING_TRG_IN : in  std_logic;
    INVALID_TRG_IN        : in  std_logic;
    TRG_CODE_IN           : in  std_logic_vector(7 downto 0);
    TRG_TYPE_IN           : in  std_logic_vector(3 downto 0);
-- to the endpoint
    TRG_RELEASE_OUT       : out std_logic;
    TRG_STATUSBIT_OUT     : out std_logic_vector(31 downto 0);
    DATA_OUT              : out std_logic_vector(31 downto 0);
    DATA_WRITE_OUT        : out std_logic;
    DATA_FINISHED_OUT     : out std_logic
    );
end entity Readout_Header;

architecture behavioral of Readout_Header is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

  -- readout fsm
  type FSM_READ is (IDLE, SEND_TRIG_RELEASE_A, SEND_TRIG_RELEASE_B, SEND_TRIG_RELEASE_C);
  signal RD_CURRENT : FSM_READ := IDLE;
  signal RD_NEXT    : FSM_READ;

  signal data_finished_fsm : std_logic;
  signal trig_release_fsm  : std_logic;
  signal wr_header_fsm     : std_logic;
  -- data mux
  signal wr_header         : std_logic;
  -- to endpoint
  signal data_out_reg      : std_logic_vector(31 downto 0);
  signal data_write        : std_logic;
  signal data_finished     : std_logic;
  signal trig_release      : std_logic;
  -- debug
  signal header_error_bits : std_logic_vector(15 downto 0);

begin  -- behavioral

-------------------------------------------------------------------------------
-- Readout
-------------------------------------------------------------------------------
-- Readout fsm
  RD_FSM_CLK : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' then
        RD_CURRENT <= IDLE;
      else
        RD_CURRENT    <= RD_NEXT;
        wr_header     <= wr_header_fsm;
        data_finished <= data_finished_fsm;
        trig_release  <= trig_release_fsm;
      end if;
    end if;
  end process RD_FSM_CLK;

  RD_FSM_PROC : process (RD_CURRENT, VALID_TIMING_TRG_IN, VALID_NOTIMING_TRG_IN, INVALID_TRG_IN,
                         TRG_TYPE_IN)
  begin

    RD_NEXT           <= RD_CURRENT;
    wr_header_fsm     <= '0';
    data_finished_fsm <= '0';
    trig_release_fsm  <= '0';

    case (RD_CURRENT) is
      when IDLE =>
        if VALID_TIMING_TRG_IN = '1' then
          RD_NEXT       <= SEND_TRIG_RELEASE_A;
          wr_header_fsm <= '1';
        elsif VALID_NOTIMING_TRG_IN = '1' then
          RD_NEXT <= SEND_TRIG_RELEASE_A;
          if TRG_TYPE_IN = x"E" or TRG_TYPE_IN = x"D" then
            wr_header_fsm <= '1';
          end if;
        elsif INVALID_TRG_IN = '1' then
          RD_NEXT <= SEND_TRIG_RELEASE_A;
        end if;

      when SEND_TRIG_RELEASE_A =>
        RD_NEXT <= SEND_TRIG_RELEASE_B;

      when SEND_TRIG_RELEASE_B =>
        RD_NEXT           <= SEND_TRIG_RELEASE_C;
        data_finished_fsm <= '1';

      when SEND_TRIG_RELEASE_C =>
        RD_NEXT          <= IDLE;
        trig_release_fsm <= '1';

      when others =>
        RD_NEXT <= IDLE;
    end case;
  end process RD_FSM_PROC;

-------------------------------------------------------------------------------
-- Data out mux
-------------------------------------------------------------------------------

  Data_Out_MUX : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if wr_header = '1' then
        data_out_reg <= "001" & "0" & TRG_TYPE_IN & TRG_CODE_IN & header_error_bits;
      else
        data_out_reg <= (others => '1');
      end if;
      data_write <= wr_header;
    end if;
  end process Data_Out_MUX;

  DATA_OUT          <= data_out_reg;
  DATA_WRITE_OUT    <= data_write;
  DATA_FINISHED_OUT <= data_finished;
  TRG_RELEASE_OUT   <= trig_release;
  TRG_STATUSBIT_OUT <= (others => '0');

  -- Error, warning bits set in the header
  header_error_bits <= (others => '0');

end behavioral;
