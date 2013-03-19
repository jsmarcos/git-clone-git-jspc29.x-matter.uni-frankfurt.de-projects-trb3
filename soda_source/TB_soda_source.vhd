library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--library work;
--use work.trb_net_std.all;
--use work.trb_net_components.all;
--use work.trb3_components.all;
--use work.med_sync_define.all;
--use work.version.all;

entity TB_soda_source is
end entity;

architecture TestBench of TB_soda_source is

   -- Clock period definitions
   constant clk_period          : time          := 4ns;


component super_burst_generator
	generic(
		BURST_COUNT : integer range 1 to 64 := 16   -- number of bursts to be counted between super-bursts
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
end component;

component soda_packet_builder
	port(
		SYSCLK					: in	std_logic; -- fabric clock
		RESET						: in	std_logic; -- synchronous reset
		CLEAR						: in	std_logic; -- asynchronous reset
		CLK_EN					: in	std_logic;
		--Internal Connection
		SODA_CMD_STROBE_IN	: in	std_logic := '0';	-- 
		START_OF_SUPERBURST	: in	std_logic := '0';
		SUPER_BURST_NR_IN		: in	std_logic_vector(30 downto 0) := (others => '0');
		SODA_CMD_WORD_IN		: in	std_logic_vector(31 downto 0) := (others => '0');		--REGIO_CTRL_REG in trbnet handler is 32 bit
		TX_DLM_OUT				: out	std_logic := '0';	-- 
		TX_DLM_WORD_OUT		: out	std_logic_vector(7 downto 0) := (others => '0')
	);
end component;

component soda_packet_handler
port(
	SYSCLK						: in	std_logic; -- fabric clock
	RESET							: in	std_logic; -- synchronous reset
	CLEAR							: in	std_logic; -- asynchronous reset
	CLK_EN						: in	std_logic;
	--Internal Connection
	RX_DLM_WORD_IN				: in	std_logic_vector(7 downto 0) := (others => '0');
	RX_DLM_IN					: in std_logic
	);
end component;

--Inputs
	signal rst_S							: std_logic;
	signal clk_S							: std_logic;
	signal enable_S						: std_logic := '0';
	signal soda_cmd_word_S				: std_logic_vector(31 downto 0)	:= (others => '0');
	signal soda_cmd_strobe_S			: std_logic := '0';
	signal SOS_S							: std_logic := '0';
	signal super_burst_nr_S				: std_logic_vector(30 downto 0)	:= (others => '0');		-- from super-burst-nr-generator
	signal SOB_S							: std_logic := '0';
	signal dlm_word_S						: std_logic_vector(7 downto 0)	:= (others => '0');
	signal dlm_valid_S					: std_logic;

begin

	superburst_gen :  super_burst_generator
		generic map(BURST_COUNT		=> 16)
		port map(
			SYSCLK					=>	clk_S,
			RESET						=> rst_S,
			CLEAR						=>	'0',
			CLK_EN					=>	'0',
			--Internal Connection
			SODA_BURST_PULSE_IN	=>	SOB_S,
			START_OF_SUPERBURST	=>	SOS_S,
			SUPER_BURST_NR_OUT	=>	super_burst_nr_S
		);

	packet_builder : soda_packet_builder
		port map(
			SYSCLK					=>	clk_S,
			RESET						=> rst_S,
			CLEAR						=>	'0',
			CLK_EN					=> '0',
			--Internal Connection
			SODA_CMD_STROBE_IN	=> soda_cmd_strobe_S,
			START_OF_SUPERBURST	=> SOS_S,
			SUPER_BURST_NR_IN		=> super_burst_nr_S,
			SODA_CMD_WORD_IN		=> soda_cmd_word_S,
			TX_DLM_OUT				=> dlm_valid_S,
			TX_DLM_WORD_OUT		=> dlm_word_S
		
			);

	packet_handler : soda_packet_handler
	port map(
		SYSCLK						=>	clk_S,
		RESET							=> rst_S,
		CLEAR							=>	'0',
		CLK_EN						=>	'0',
		--Internal Connection
		RX_DLM_IN					=> dlm_valid_S,
		RX_DLM_WORD_IN				=> dlm_word_S
		);

------------------------------------------------------------------------------------------------------------
   -- SODA command packet
------------------------------------------------------------------------------------------------------------
	cmd_proc	:process
	begin
      wait for 2us;
		soda_cmd_word_S	<= x"40000000";
		soda_cmd_strobe_S	<= '1';
      wait for clk_period;
		soda_cmd_strobe_S	<= '0';
      wait;
	end process;

------------------------------------------------------------------------------------------------------------
   -- Clock process definitions
------------------------------------------------------------------------------------------------------------
   clk_proc :process
   begin
		clk_S <= '0';
		wait for clk_period/2;
		clk_S <= '1';
		wait for clk_period/2;
   end process; 

   -- reset process
   reset_proc: process
   begin
                rst_S <= '1';
      wait for clk_period * 5; 
                rst_S <= '0';
      wait;
   end process;

   burst_proc :process
   begin
                SOB_S <= '0';
                wait for 2.35us;
                SOB_S <= '1';
                wait for 50ns;
   end process; 


end TestBench;

