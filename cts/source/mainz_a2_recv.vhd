library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb3_components.all;


entity mainz_a2_recv is
  port(
    CLK      : in std_logic;    -- must be 100 MHz!
    RESET_IN : in std_logic;  	-- could be used after busy_release to make sure entity is in correct state

    --Module inputs
    SERIAL_IN  : in std_logic;             -- serial raw in, externally clock'ed at 12.5 MHz
    EXT_TRG_IN : in std_logic;           		-- external trigger in, ~10us later
																						-- the external trigger id is sent on SERIAL_IN

    --trigger outputs
    TRG_ASYNC_OUT : out std_logic;  -- asynchronous rising edge, length varying, here: approx. 110 ns
    TRG_SYNC_OUT  : out std_logic;      -- sync. to CLK

    --data output for read-out
    TRIGGER_IN    : in  std_logic;
    DATA_OUT      : out std_logic_vector(31 downto 0);
    WRITE_OUT     : out std_logic;
    STATUSBIT_OUT : out std_logic_vector(31 downto 0);
    FINISHED_OUT  : out std_logic;

    --Registers / Debug    
    CONTROL_REG_IN : in  std_logic_vector(31 downto 0);
    STATUS_REG_OUT : out std_logic_vector(31 downto 0) := (others => '0');
    DEBUG          : out std_logic_vector(31 downto 0)
    );
end entity;

--A2 trigger format of SERIAL_IN
--Startbit    : "1"
--Trig.nr.    : 32bit (but only ~20bit used at the moment)
--Paritybit   : "0" or "1" 
--Stopbit/Controlbit: "1"
--Parity check over trig Nr and parity bit

--Data Format of DATA_OUT (goes into DAQ stream)
-- Bit 30 -  0 : Trigger Number (Bit 32 is cut off and used for error flag)
-- Bit 31      : Error flag (either parity wrong or no stop/control bit seen)

--statusbit 23 of STATUSBIT_OUT is equal to Bit 31 of DATA_OUT

architecture arch1 of mainz_a2_recv is

	constant timeoutcnt_Max : integer := 2000000; -- x 10 ns = 20us maximum
	                                             -- time until trigger id can
	                                             -- be received;
	signal timeoutcnt : integer range 0 to timeoutcnt_Max := timeoutcnt_Max;
	
	signal shift_reg : std_logic_vector(34 downto 0);
	signal bitcnt    : integer range 0 to shift_reg'length;
	
  

  --signal first_bits_fast : std_logic;
  --signal first_bits_slow : std_logic;
  signal reg_SERIAL_IN      : std_logic;
  signal done            : std_logic;
  --signal done_slow       : std_logic;

  signal number_reg : std_logic_vector(30 downto 0);
  --signal status_reg : std_logic_vector(1 downto 0);
  signal error_reg  : std_logic;

  signal trg_async : std_logic;
  signal trg_sync  : std_logic;

  type state_t is (IDLE, WAIT_FOR_STARTBIT, WAIT1, WAIT2, WAIT3, READ_BIT,
                   WAIT5, WAIT6, WAIT7, WAIT8, NO_TRG_ID_RECV, FINISH);
  signal state : state_t := IDLE;

  type rdo_state_t is (RDO_IDLE, RDO_WAIT, RDO_WRITE, RDO_FINISH);
  signal rdostate : rdo_state_t := RDO_IDLE;

  signal config_rdo_disable_i : std_logic;

begin


  reg_SERIAL_IN <= SERIAL_IN when rising_edge(CLK);

  --PROC_FIRST_BITS : process
  --begin
  --  wait until rising_edge(CLK_200);
  --  if bitcnt > 32 and RESET_IN = '0' then
  --    first_bits_fast <= '1';
  --  else
  --    first_bits_fast <= '0';
  --  end if;
  --end process;

  --first_bits_slow <= first_bits_fast when rising_edge(CLK);

  --trg_async <= (not MBS_IN or trg_async)                        when first_bits_fast = '1' else '0';
  --trg_sync  <= (not reg_MBS_IN or trg_sync) and first_bits_slow when rising_edge(CLK);
  trg_async <= EXT_TRG_IN;
  trg_sync <= EXT_TRG_IN when rising_edge(CLK); -- do we need another register
																								-- here?
  
  TRG_ASYNC_OUT <= trg_async;
  TRG_SYNC_OUT  <= trg_sync when rising_edge(CLK);

  -- since CLK runs at 100MHz, we sample at 12.5MHz due to 8 WAIT states
  PROC_FSM : process
  begin
    wait until rising_edge(CLK);
    case state is

	    when IDLE =>
		    done   <= '1';
		    if trg_sync = '1' then
			    done <= '0';
			    timeoutcnt <= timeoutcnt_Max;
			    state <= WAIT_FOR_STARTBIT;
		    end if;	
		    
      when WAIT_FOR_STARTBIT =>
        
        if reg_SERIAL_IN = '1' then
	        bitcnt <= shift_reg'length;
	        state <= WAIT1;
        elsif timeoutcnt = 0 then
	        state <= NO_TRG_ID_RECV;
        else 
	        timeoutcnt <= timeoutcnt-1;     
        end if;

        
      when WAIT1 =>
        state <= WAIT2;
	    when WAIT2 =>
	      state <= WAIT3;
	    when WAIT3 =>
	      state <= READ_BIT;
	      
	      
      when READ_BIT => -- actually WAIT4, but we read here, in the middle of
											 -- the serial line communication
        bitcnt    <= bitcnt - 1;
        -- we fill the shift_reg LSB first since this way the trg id arrives
        shift_reg <= reg_SERIAL_IN & shift_reg(shift_reg'high downto 1);
        state     <= WAIT5;
        
      when WAIT5 =>
	      -- check if we're done reading
        if bitcnt = 0 then
          state <= FINISH;
        else
          state <= WAIT6;
        end if;
        
      when WAIT6 =>
	      state <= WAIT7;
	    when WAIT7 =>
	      state <= WAIT8;	      
	    when WAIT8 =>
	      state <= WAIT1;	      	      

	    when NO_TRG_ID_RECV =>
		    -- we received no id after a trigger within the timeout, so
		    -- set bogus trigger id and no control bit (forces error flag set!)
		    shift_reg <= b"00" & x"ffffffff" & b"1"; 
		    state <= FINISH;
		    
      when FINISH =>
	      -- wait until serial line is idle again
        if reg_SERIAL_IN = '0' then
          state <= IDLE;
        end if;
        done <= '1';
    end case;
    
    if RESET_IN = '1' then
      state <= IDLE;
      done  <= '0';
    end if;
  end process;

  --done_slow <= done when rising_edge(CLK);

  PROC_REG_INFO : process
  begin
    wait until rising_edge(CLK);
    if done = '1' then
	    -- here we cut off the highest bit of the received trigger id
	    -- so shift_reg(32) is discarded (but used for checksum)
      number_reg <= shift_reg(31 downto 1);
      --status_reg <= shift_reg(7 downto 6);

      -- check if start and control bit is 1 and parity is okay
      if shift_reg(34) = '1' and shift_reg(0) = '1'
	      and xor_all(shift_reg(33 downto 1)) = '0' then
        error_reg <= '0';
      else
        error_reg <= '1';
      end if;
    end if;
  end process;


  PROC_RDO : process
  begin
    wait until rising_edge(CLK);
    WRITE_OUT     <= '0';
    FINISHED_OUT  <= config_rdo_disable_i;
    STATUSBIT_OUT <= (23 => error_reg, others => '0');
    case rdostate is
      when RDO_IDLE =>
        if TRIGGER_IN = '1' and config_rdo_disable_i = '0' then
          if done = '0' then
            rdostate <= RDO_WAIT;
          else
            rdostate <= RDO_WRITE;
          end if;
        end if;
      when RDO_WAIT =>
        if done = '1' then
          rdostate <= RDO_WRITE;
        end if;
      when RDO_WRITE =>
        rdostate  <= RDO_FINISH;
        DATA_OUT  <= error_reg & number_reg;
        WRITE_OUT <= '1';
        
      when RDO_FINISH =>
        FINISHED_OUT <= '1';
        rdostate     <= RDO_IDLE;
    end case;
  end process;

  config_rdo_disable_i <= CONTROL_REG_IN(0);

  STATUS_REG_OUT <= error_reg & std_logic_vector(to_unsigned(bitcnt, 6)) & number_reg(24 downto 0);
  DEBUG          <= x"00000000";  -- & done & '0' & shift_reg(13 downto 0);

end architecture;
