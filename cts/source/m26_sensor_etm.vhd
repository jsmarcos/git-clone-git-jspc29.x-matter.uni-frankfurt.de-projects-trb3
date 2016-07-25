
--m26_sensor_etm
--To check the busy status of the CTS
--Qiyan 06072016


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.All;

library work;
--use work.trb_net_std.all;
--use work.trb3_components.all;


entity m26_sensor_etm is
	port(
		CLK						: in std_logic;	-- system clk 100 MHz!
		RESET_IN					: in std_logic;	-- system reset
				
		Busy_IN              : in std_logic;   -- status of trb data transfer.
		BUFFER_WARNING_IN    : in std_logic;   
		
		Trigger_OUT          : out std_logic;  -- trigger for TRB depends on the Busy_in;
		DISCARD_OUT          : out std_logic;
		
		--data output for read-out
		TRIGGER_IN           : in	std_logic;
		DATA_OUT			      : out std_logic_vector(31 downto 0);
		WRITE_OUT			   : out std_logic;
		STATUSBIT_OUT        : out std_logic_vector(31 downto 0);
		FINISHED_OUT	      : out std_logic;

		--Registers / Debug		 
		CONTROL_REG_IN       : in  std_logic_vector(31 downto 0);
		STATUS_REG_OUT       : out std_logic_vector(31 downto 0) := (others => '0');
		DEBUG					   : out std_logic_vector(31 downto 0)
		);
end entity;



architecture arch1 of m26_sensor_etm is
		
	type   state_trigger is (IDLE, WAIT_PULSE,CHECK_BUSY,WAIT_BUSY,SEND_TRIGGER);
	signal state : state_trigger := IDLE;
	
	type   state_readout is (RDO_IDLE, RDO_WRITE1, RDO_WRITE2, RDO_WRITE3, RDO_WRITE4, RDO_FINISH);
	signal rdostate : state_readout := RDO_IDLE;
	
   signal pulserCNT: integer range 0 to 65535;
   signal waitBusyCNT: integer range 0 to 65535;
   signal bufWaringCNT: integer range 0 to 1023;
   signal config_checkbusy_disable_IN: std_logic;
   signal config_discard_disable_IN:std_logic;
   signal config_rdo_disable_IN:std_logic;
   signal busy_delayCLK: integer range 0 to 1023;
   signal bufferWarning_NUM:integer range 0 to 1023;
	
begin

	
	PROC_FSM : process
	begin
		wait until rising_edge(CLK);
      if RESET_IN = '1' then
         state <= IDLE;
         waitBusyCNT <= 0;
         pulserCNT <= 0;
         bufWaringCNT <= 0;
         Trigger_OUT <= '0';
         DISCARD_OUT <= '0';
      else
         Trigger_OUT <= '0';
         DISCARD_OUT <= '0';
         pulserCNT <= pulserCNT + 1;
         if(pulserCNT = 11520)then
            pulserCNT <= 0;
         end if;
         case state is
            when IDLE => 
               waitBusyCNT <= 0;
               DISCARD_OUT <= '0'; 
               bufWaringCNT <= 0;
               if(config_checkbusy_disable_IN = '0') then
                  state <= WAIT_PULSE;
               else
                  if(pulserCNT = 11520)then
                     Trigger_OUT <= '1';
                  end if;
               end if;               
				when WAIT_PULSE =>
               if(pulserCNT = 11519) then
                  state <= CHECK_BUSY;
               end if; 
            when CHECK_BUSY =>
               if(Busy_IN = '0')then
                  if(BUFFER_WARNING_IN = '1')then
                     bufWaringCNT <= bufWaringCNT + 1;
                  else
                     bufWaringCNT <= 0;
                  end if;
                  state <= SEND_TRIGGER;
               else
                  state <= WAIT_BUSY;
               end if;
            when WAIT_BUSY =>
               waitBusyCNT <= waitBusyCNT + 1;--how many clk should it wait?
               if(Busy_IN = '0')then
                  state <= SEND_TRIGGER;
                  if(BUFFER_WARNING_IN = '1')then
                     bufWaringCNT <= bufWaringCNT + 1;
                  else
                     bufWaringCNT <= 0;
                  end if;
               end if;
            when SEND_TRIGGER =>
               Trigger_OUT <= '1';               
               if(waitBusyCNT > busy_delayCLK or bufWaringCNT > bufferWarning_NUM)then
                  if(config_discard_disable_IN = '0')then
                     DISCARD_OUT <= '1';
                  end if;
               end if;
               waitBusyCNT <= 0;
               bufWaringCNT <= 0;
               state <= WAIT_PULSE;
         end case;
      end if;		
	end process;
	
	
	


	PROC_RDO : process
	begin
		wait until rising_edge(CLK);
		WRITE_OUT			<= '0';
		FINISHED_OUT	<= config_rdo_disable_IN;
		STATUSBIT_OUT <= (others => '0');--(23 => data_status_reg(0), others => '0');
		DATA_OUT <= x"00000000";
		case rdostate is
			when RDO_IDLE =>
				DATA_OUT <= x"00000000";
				if TRIGGER_IN = '1' and config_rdo_disable_IN = '0' then
               rdostate <= RDO_WRITE1;
				end if;
			when RDO_WRITE1 =>
				rdostate	<= RDO_WRITE2;
				DATA_OUT	<= x"55555555";
				WRITE_OUT <= '1';
			when RDO_WRITE2 =>
				rdostate	<= RDO_WRITE3;
				DATA_OUT	<= x"AAAAAAAA";
				WRITE_OUT <= '1';
			when RDO_WRITE3 =>
				rdostate	<= RDO_WRITE4;
				DATA_OUT	<= x"deadbeef";
				WRITE_OUT <= '1';
			when RDO_WRITE4 =>
				rdostate	<= RDO_FINISH;
				DATA_OUT	<= x"deadbeef";
				WRITE_OUT <= '1';
			when RDO_FINISH =>
				FINISHED_OUT <= '1';
				rdostate		 <= RDO_IDLE;
		end case;
	end process;

	config_rdo_disable_IN <= CONTROL_REG_IN(0);
	config_discard_disable_IN <= CONTROL_REG_IN(1);
	config_checkbusy_disable_IN <= CONTROL_REG_IN(2);
	busy_delayCLK <= to_integer(unsigned(CONTROL_REG_IN(14 downto 5)));
   bufferWarning_NUM <= to_integer(unsigned(CONTROL_REG_IN(24 downto 15)));
   
	STATUS_REG_OUT <= std_logic_vector(to_unsigned(pulserCNT,16)) & std_logic_vector(to_unsigned(waitBusyCNT,16));
	DEBUG					 <= x"00000000";	

end architecture;
