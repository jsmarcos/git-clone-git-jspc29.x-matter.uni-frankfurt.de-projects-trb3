library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb3_components.all;


entity mbs_vulom_recv is
  port(
    CLK        : in std_logic;  -- e.g. 100 MHz
    RESET_IN   : in std_logic;  -- could be used after busy_release to make sure entity is in correct state

    --Module inputs
    MBS_IN     : in std_logic;  -- raw input
    CLK_200    : in std_logic;  -- internal sampling clock
    
    --trigger outputs
    TRG_ASYNC_OUT  : out std_logic;  -- asynchronous rising edge, length varying, here: approx. 110 ns
    TRG_SYNC_OUT   : out std_logic;  -- sync. to CLK

    --data output for read-out
    TRIGGER_IN   : in  std_logic;
    DATA_OUT     : out std_logic_vector(31 downto 0);
    WRITE_OUT    : out std_logic;
    STATUSBIT_OUT: out std_logic_vector(31 downto 0);
    FINISHED_OUT : out std_logic;
    
    --Registers / Debug    
    CONTROL_REG_IN : in  std_logic_vector(31 downto 0);
    STATUS_REG_OUT : out std_logic_vector(31 downto 0) := (others => '0');
    HEADER_REG_OUT : out std_logic_vector(1 downto 0);
    DEBUG          : out std_logic_vector(31 downto 0)    
    );

    attribute syn_useioff : boolean;
    --no IO-FF for MBS input
    attribute syn_useioff of MBS_IN    : signal is false;


end entity;

--MBS format
--Startbit    (0): “0“
--Preamb. (1): “1010“
--Trig.nr.  (2) :24bit
--Status  (3): unused (2 bits)
--Paritybit   (4): “0“ or “1“ (positive?)
--Postam. (5):“1010“
--Stopbit   (0): “1“
--Parity check over counter & status bit

--Data Format: 
-- Bit 23 -  0 : Trigger Number
-- Bit 30 - 29 : Status
-- Bit 31      : Error flag

--statusbit 23 will be set in case of a data error from MBS

architecture mbs_vulom_recv_arch of mbs_vulom_recv is


signal bitcnt : integer range 0 to 37;
signal shift_reg : std_logic_vector(36 downto 0);

signal first_bits_fast : std_logic;
signal first_bits_slow : std_logic;
signal reg_MBS_IN      : std_logic;
signal done            : std_logic;
signal done_slow       : std_logic;

signal number_reg      : std_logic_vector(23 downto 0);
signal status_reg      : std_logic_vector(1 downto 0);
signal error_reg       : std_logic;

signal trg_async       : std_logic;
signal trg_sync        : std_logic;

type state_t is (IDLE, WAIT1,WAIT2,WAIT3,WAIT4, FINISH);
signal state           : state_t;

type rdo_state_t is (RDO_IDLE, RDO_WAIT, RDO_WRITE, RDO_FINISH);
signal rdostate        : rdo_state_t;

signal config_rdo_disable_i : std_logic;

begin

-- we tell the CTS that we send one word of over DATA_OUT
HEADER_REG_OUT <= b"01"; 

reg_MBS_IN <= MBS_IN when rising_edge(CLK_200);

PROC_FIRST_BITS : process begin
  wait until rising_edge(CLK_200);
  if bitcnt > 32 and RESET_IN = '0' then
    first_bits_fast <= '1';
  else
    first_bits_fast <= '0';
  end if;
end process;
  
first_bits_slow <= first_bits_fast when rising_edge(CLK);

trg_async     <= (not MBS_IN or trg_async) when first_bits_fast = '1' else '0';
trg_sync      <= (not reg_MBS_IN or trg_sync) and first_bits_slow when rising_edge(CLK);

TRG_ASYNC_OUT <= trg_async;
TRG_SYNC_OUT  <= trg_sync when rising_edge(CLK);

PROC_FSM: process begin
  wait until rising_edge(CLK_200);

  case state is
    when IDLE =>
      bitcnt <= 37;
      done <= '1';
      if reg_MBS_IN = '0' then
        done  <= '0';
        state <= WAIT1;
      end if;
      
    when WAIT1 =>
      state <= WAIT2;
      
    when WAIT2 =>
      bitcnt <= bitcnt - 1;
      shift_reg <= shift_reg(shift_reg'high - 1 downto 0) & reg_MBS_IN;
      state <= WAIT3;
      
    when WAIT3 =>
      if bitcnt = 0 then
        state <= FINISH;
      else
        state <= WAIT4;
      end if;
      
    when WAIT4 =>
      state <= WAIT1;
      
    when FINISH =>
      if reg_MBS_IN = '1' then
        state <= IDLE;
      end if;
      done <= '1';
  end case;
  if RESET_IN = '1' then
    state <= IDLE;
    done <= '0';
  end if;
end process;

done_slow <= done when rising_edge(CLK);

PROC_REG_INFO : process begin
  wait until rising_edge(CLK);
  if done_slow = '1' then
    number_reg <= shift_reg(31 downto 8);
    status_reg <= shift_reg(7 downto 6);

    if shift_reg(36 downto 32) = "01010" and shift_reg(4 downto 0) = "10101" and xor_all(shift_reg(31 downto 5)) = '0' then
      error_reg <= '0';
    else
      error_reg <= '1';
    end if;
  end if;
end process;


PROC_RDO : process begin
  wait until rising_edge(CLK);
  WRITE_OUT     <= '0';
  FINISHED_OUT  <= config_rdo_disable_i;
  STATUSBIT_OUT <= (23 => error_reg, others => '0');
  case rdostate is
    when RDO_IDLE =>
      if TRIGGER_IN = '1' and config_rdo_disable_i = '0' then
        if done_slow = '0' then
          rdostate <= RDO_WAIT;
        else
          rdostate <= RDO_WRITE;
        end if;
      end if;
    when RDO_WAIT =>
      if done_slow = '1' then
        rdostate <= RDO_WRITE;
      end if;
    when RDO_WRITE =>
      rdostate <= RDO_FINISH;
      DATA_OUT <= error_reg & status_reg & "00000" & number_reg;
      WRITE_OUT <= '1';
    
    when RDO_FINISH =>
      FINISHED_OUT <= '1';
      rdostate     <= RDO_IDLE;
  end case;
end process;

config_rdo_disable_i <= CONTROL_REG_IN(0);

STATUS_REG_OUT <= error_reg & '0' & std_logic_vector(to_unsigned(bitcnt,6)) & number_reg;
DEBUG <= x"00000000"; -- & done & '0' & shift_reg(13 downto 0);

end architecture;
