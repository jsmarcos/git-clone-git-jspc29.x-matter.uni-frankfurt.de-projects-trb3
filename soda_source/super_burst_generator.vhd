library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_signed.all;

--library work;
--use work.trb_net_std.all;
--use work.trb_net_components.all;
--use work.trb3_components.all;
--use work.med_sync_define.all;
--use work.version.all;

entity super_burst_generator is
	generic(
		BURST_COUNT : natural range 1 to 256 := 16   -- number of bursts to be counted between super-bursts
		);
	port(
		SYSCLK					: in	std_logic; -- fabric clock
		RESET						: in	std_logic; -- synchronous reset
		CLEAR						: in	std_logic; -- asynchronous reset
		CLK_EN					: in	std_logic;
		--Internal Connection
		SODA_BURST_PULSE_IN	: in	std_logic := '0';	-- 
		START_OF_SUPERBURST	: out	std_logic := '0';
		SUPER_BURST_NR_OUT	: out	std_logic_vector(30 downto 0) := (others => '0')
		);
end super_burst_generator;

architecture Behavioral of super_burst_generator is

	constant	cBURST_COUNT				: std_logic_vector(7 downto 0)	:= conv_std_logic_vector(BURST_COUNT - 1,8);

	signal	clk_S							: std_logic;
	signal	rst_S							: std_logic;
	signal	soda_burst_pulse_S		: std_logic	:= '0';
	signal	start_of_superburst_S	: std_logic	:= '0';
	signal	super_burst_nr_S			: std_logic_vector(30 downto 0)	:= (others => '0');		-- from super-burst-nr-generator
	signal	burst_counter_S			: std_logic_vector(7 downto 0)	:= (others => '0');		-- from super-burst-nr-generator
	

begin

	clk_S							<= SYSCLK;
	rst_S							<= RESET;
	START_OF_SUPERBURST		<= start_of_superburst_S;
	SUPER_BURST_NR_OUT		<=	super_burst_nr_S;
	
	burst_pulse_edge_proc : process(clk_S, rst_S, SODA_BURST_PULSE_IN, soda_burst_pulse_S, burst_counter_S)
	begin
		if rising_edge(clk_S) then
			soda_burst_pulse_S <= SODA_BURST_PULSE_IN;
			if (rst_S='1') then
				burst_counter_S	<= cBURST_COUNT;
				start_of_superburst_S	<= '0';
				super_burst_nr_S			<= (others => '0');
			elsif ((SODA_BURST_PULSE_IN = '1') and (soda_burst_pulse_S = '0')) then
				if (burst_counter_S = x"00") then
					start_of_superburst_S	<= '1';
					super_burst_nr_S			<= super_burst_nr_S + 1;
					burst_counter_S	<= cBURST_COUNT;
				else
					start_of_superburst_S	<= '0';
					burst_counter_s	<=	burst_counter_s - 1;
				end if;
			else
				start_of_superburst_S		<= '0';
			end if;
		end if;
	end process;
	

end Behavioral;