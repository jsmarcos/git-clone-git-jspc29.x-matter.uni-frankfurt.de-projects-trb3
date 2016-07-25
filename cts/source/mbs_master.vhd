library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.All;

library work;
use work.trb_net_std.all;


entity mbs_master is
	port(
		CLK						: in std_logic;	-- system clk 100 MHz!
		RESET_IN					: in std_logic;	-- system reset
				
		MBS_CLOCK_OUT        : out std_logic; 
		MBS_DATA_OUT         : out std_logic;   
		
		--data output for read-out
		TRIGGER_IN           : in	std_logic;
		TRIGGER_NUMBER_IN    : in  std_logic_vector(15 downto 0);
		DATA_OUT			      : out std_logic_vector(31 downto 0);
		WRITE_OUT			   : out std_logic;
      FINISHED_OUT         : out std_logic;
		STATUSBIT_OUT        : out std_logic_vector(31 downto 0)
		);
end entity;



architecture arch1 of mbs_master is
		
	type   state_trigger is (IDLE, MAKEWORD, SETUP, CLOCKWAIT, MBS_FINISHED);
	signal state : state_trigger := IDLE;
	
	type   state_readout is (RDO_IDLE, RDO_WRITE1, RDO_FINISH);
	signal rdostate : state_readout := RDO_IDLE;
	
	signal mbs_trigger_counter : std_logic_vector(23 downto 0);
	signal mbs_word            : std_logic_vector(36 downto 0);
	signal mbs_clock_i         : std_logic;
	signal mbs_data_i          : std_logic;
	signal bitcounter          : unsigned(6 downto 0);
	signal last_TRIGGER_IN     : std_logic;

begin
MBS_CLOCK_OUT <= mbs_clock_i;
MBS_DATA_OUT  <= mbs_data_i;

last_TRIGGER_IN <= TRIGGER_IN when rising_edge(CLK);

	PROC_FSM : process
	begin
		wait until rising_edge(CLK);
      if RESET_IN = '1' then
         state <= IDLE;
         mbs_trigger_counter <= 0;
      else
         case state is
            when IDLE => 
               mbs_clock_i <= '0';
               mbs_data_i  <= '1';
               if TRIGGER_IN = '1' and last_TRIGGER_IN = '0' then
                 mbs_trigger_counter(15 downto 0) <= TRIGGER_NUMBER_IN;
                 if mbs_trigger_counter(15 downto 0) = x"ffff" then
                   mbs_trigger_counter(23 downto 16) <= std_logic_vector(unsigned(mbs_trigger_counter(23 downto 16)) + 1);
                 end if;
                 state <= MAKEWORD;
               end if;
            when MAKEWORD =>
               mbs_word(36 downto 32) <= "01010";
               mbs_word(31 downto 8)  <= std_logic_vector(mbs_trigger_counter);
               mbs_word(7 downto 6)   <= "00";
               mbs_word(5)            <= xor_all(std_logic_vector(mbs_trigger_counter));
               mbs_word(4 downto 0)   <= "10101";
               bitcounter             <= 10#36#;
               state <= SETUP;
            when SETUP =>
               mbs_clock_i <= '1';
               mbs_data_i  <= mbs_word(36);
               mbs_word <= mbs_word(35 downto 0) & '1';
               bitcounter <= bitcounter - 1;
               state <= CLOCKWAIT;
            when CLOCKWAIT =>
               mbs_clock_i <= '0';
               if bitcounter = 0 then
                  state <= MBS_FINISHED;
               else
                  state <= SETUP;
               end if;
            when MBS_FINISHED =>
               state <= IDLE;
         end case;
      end if;		
	end process;
	


	PROC_RDO : process
	begin
		wait until rising_edge(CLK);
		WRITE_OUT			<= '0';
		FINISHED_OUT      <= '0';
		STATUSBIT_OUT     <= (others => '0');
		DATA_OUT          <= x"00000000";
		case rdostate is
			when RDO_IDLE =>
				if TRIGGER_IN = '1' and last_TRIGGER_IN = '0'  then
               rdostate <= RDO_WRITE1;
				end if;
			when RDO_WRITE1 =>
			   if state = MBS_FINISHED then
               rdostate	<= RDO_FINISH;
               DATA_OUT	<= x"b5" & std_logic_vector(mbs_trigger_counter);
               WRITE_OUT <= '1';
            end if;   
			when RDO_FINISH =>
				FINISHED_OUT <= '1';
				rdostate		 <= RDO_IDLE;
		end case;
		if RESET_IN = '1' then
         rdostate <= RDO_IDLE;
		end if;
	end process;

end architecture;
