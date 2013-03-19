library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.med_sync_define.all;
use work.version.all;

entity soda_packet_builder is
--	generic(
--	INTERCEPT_MODE : integer range 0 to 1 := c_NO   --use the RX clock for internal logic and transmission. Should be NO for soda tests!
--	);
port(
	SYSCLK					: in	std_logic; -- fabric clock
	RESET						: in	std_logic; -- synchronous reset
	CLEAR						: in	std_logic; -- asynchronous reset
	CLK_EN					: in	std_logic;
	--Internal Connection
	START_OF_BURST			: in	std_logic := '0';
	SUPER_BURST_NR_OUT	: out	std_logic_vector(30 downto 0) := (others => '0');
	SUPER_BURST_NR_VALID	: out std_logic
	START_OF_SUPERBURST	: out std_logic
	);
end soda_packet_builder;

architecture Behavioral of soda_packet_builder is
	constant	c_K287						: std_logic_vector(7 downto 0) := x"FB";

	signal	clk_S							: std_logic;
	signal	rst_S							: std_logic;
	signal	soda_cmd_strobe_S			: std_logic;
	signal	start_of_burst_S			: std_logic;
	signal	start_of_superburst_S	: std_logic;
	signal	super_burst_nr_S			: std_logic_vector(30 downto 0) := (others => '0');		-- from super-burst-nr-generator
	signal	superburst_nr_valid_S	: std_logic;
	
	signal	burst_count_S				: std_logic_vector(3 downto 0)	:= (others => '0');

begin

	clk_S								<= SYSCLK;
	rst_S								<= RESET;
	start_of_burst_S				<= START_OF_BURST;
	
	SUPER_BURST_NR_OUT			<=	soda_pkt_word_S;
	SUPER_BURST_NR_VALID			<=	soda_pkt_valid_S;
	START_OF_SUPERBURST			<= start_of_burst_S;
	
	

end architecture;