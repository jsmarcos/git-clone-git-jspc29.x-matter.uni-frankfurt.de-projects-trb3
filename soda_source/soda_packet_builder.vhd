library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
--use work.trb_net_std.all;
--use work.trb_net_components.all;
--use work.trb3_components.all;
--use work.med_sync_define.all;
--use work.version.all;

entity soda_packet_builder is
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
end soda_packet_builder;

architecture Behavioral of soda_packet_builder is

component soda_d8crc8
	port( 
		clock			: in std_logic; 
		reset			: in std_logic; 
		soc			: in std_logic; 
		data			: in std_logic_vector(7 downto 0); 
		data_valid	: in std_logic; 
		eoc			: in std_logic; 
		crc			: out std_logic_vector(7 downto 0); 
		crc_valid	: out std_logic 
	);
end component;

--	constant	c_K287						: std_logic_vector(7 downto 0) := x"FB";

	signal	clk_S							: std_logic;
	signal	rst_S							: std_logic;
	signal	soda_cmd_strobe_S			: std_logic;
	signal	start_of_superburst_S	: std_logic;
	signal	super_burst_nr_S			: std_logic_vector(30 downto 0)	:= (others => '0');		-- from super-burst-nr-generator
	signal	soda_cmd_word_S			: std_logic_vector(31 downto 0)	:= (others => '0');		-- from slowcontrol
	signal	soda_pkt_word_S			: std_logic_vector(7 downto 0)	:= (others => '0');
	signal	soda_pkt_valid_S			: std_logic;

	signal	soc_S							: std_logic;
	signal	eoc_S							: std_logic;
	signal	crc_data_valid_S			: std_logic;
	signal	crc_datain_S				: std_logic_vector(7 downto 0)	:= (others => '0');
	signal	crc_tmp_S					: std_logic_vector(7 downto 0)	:= (others => '0');
	signal	crc_out_S					: std_logic_vector(7 downto 0)	:= (others => '0');
	signal	crc_valid_S					: std_logic;
	
	type		packet_state_type is 	(	c_RST, c_IDLE, c_ERROR,
													c_STD1, c_STD2, c_STD3, c_STD4, c_STD5, c_STD6, c_STD7, c_STD8,
													c_CMD1, c_CMD2, c_CMD3, c_CMD4, c_CMD5, c_CMD6, c_CMD7, c_CMD8
												);
	signal	packet_state_S				:	packet_state_type := c_IDLE;
--	signal	packet_state_S				:	packet_state_type := c_IDLE;

begin

	tx_crc8: soda_d8crc8 
		port map(
			clock			=> clk_S,
			reset			=> rst_S,
			soc			=> soc_S,
			data			=> crc_datain_S,
			data_valid	=> crc_data_valid_S,
			eoc			=> eoc_S,
			crc			=> crc_out_S,
			crc_valid	=> crc_valid_S
		);

	clk_S							<= SYSCLK;
	rst_S							<= RESET;
	soda_cmd_strobe_S			<=	SODA_CMD_STROBE_IN;
	soda_cmd_word_S			<= SODA_CMD_WORD_IN;
	start_of_superburst_S	<= START_OF_SUPERBURST;
	super_burst_nr_S			<=	SUPER_BURST_NR_IN;
	
	TX_DLM_WORD_OUT			<=	soda_pkt_word_S;
	TX_DLM_OUT					<=	soda_pkt_valid_S;
	
--	packet_state_S	<= packet_state_S;
	
	packet_fsm_proc : process(clk_S, rst_S, packet_state_S, crc_valid_S, start_of_superburst_S, soda_cmd_strobe_S)
	begin
		if rising_edge(clk_S) then
			if (rst_S='1') then
				packet_state_S	<=	c_RST;
			else
				case packet_state_S is
					when c_RST	=>
						if (start_of_superburst_S='1') then
							packet_state_S	<= c_STD1;
						elsif (soda_cmd_strobe_S='1') then
							packet_state_S	<= c_CMD1;
						else
							packet_state_S	<=	c_IDLE;
						end if;
					when c_IDLE	=>
						if (start_of_superburst_S='1') then
							packet_state_S	<= c_STD1;
						elsif (soda_cmd_strobe_S='1') then
							packet_state_S	<= c_CMD1;
						end if;
					when c_STD1	=>
						packet_state_S	<= c_STD2;
					when c_STD2	=>
						packet_state_S	<= c_STD3;
					when c_STD3	=>
						packet_state_S	<= c_STD4;
					when c_STD4	=>
						packet_state_S	<= c_STD5;
					when c_STD5	=>
						packet_state_S	<= c_STD6;
					when c_STD6	=>
						packet_state_S	<= c_STD7;
					when c_STD7	=>
						packet_state_S	<= c_STD8;
					when c_STD8	=>
						if (soda_cmd_strobe_S='0') then
							packet_state_S	<= c_IDLE;
						else
							packet_state_S	<= c_CMD1;
						end if;
					when c_CMD1	=>
							packet_state_S	<= c_CMD2;
					when c_CMD2	=>
							packet_state_S	<= c_CMD3;
					when c_CMD3	=>
							packet_state_S	<= c_CMD4;
					when c_CMD4	=>
							packet_state_S	<= c_CMD5;
					when c_CMD5	=>
							packet_state_S	<= c_CMD6;
					when c_CMD6	=>
							packet_state_S	<= c_CMD7;
					when c_CMD7	=>
						if (crc_valid_S = '0') then
							packet_state_S	<= c_ERROR;
						else
							packet_state_S	<= c_CMD8;
						end if;
					when c_CMD8	=>
						packet_state_S		<= c_IDLE;
					when c_ERROR	=>
						packet_state_S		<= c_IDLE;
					when others	=>
						packet_state_S		<= c_IDLE;
				end case;
			end if;
		end if;
	end process;

	soda_packet_fill_proc : process(clk_S, packet_state_S)
	begin
		if rising_edge(clk_S) then
			case packet_state_S is
					when c_IDLE	=>
						soda_pkt_valid_S	<= '0';
						soda_pkt_word_S	<= (others=>'0');
					when c_STD1	=>
						soda_pkt_valid_S	<= '1';
						soda_pkt_word_S	<= '1' & super_burst_nr_S(30 downto 24);
					when c_STD2	=>
						soda_pkt_valid_S	<= '0';
					when c_STD3	=>
						soda_pkt_valid_S	<= '1';
						soda_pkt_word_S	<= super_burst_nr_S(23 downto 16);
					when c_STD4	=>
						soda_pkt_valid_S	<= '0';
					when c_STD5	=>
						soda_pkt_valid_S	<= '1';
						soda_pkt_word_S	<= super_burst_nr_S(15 downto 8);
					when c_STD6	=>
						soda_pkt_valid_S	<= '0';
					when c_STD7	=>
						soda_pkt_valid_S	<= '1';
						soda_pkt_word_S	<= super_burst_nr_S(7 downto 0);
					when c_STD8	=>
						soda_pkt_valid_S	<= '0';
					when c_CMD1	=>
						soda_pkt_valid_S	<= '1';
						soda_pkt_word_S	<= '0' & soda_cmd_word_S(30 downto 24);
					when c_CMD2	=>
						soda_pkt_valid_S	<= '0';
					when c_CMD3	=>
						soda_pkt_valid_S	<= '1';
						soda_pkt_word_S	<= soda_cmd_word_S(23 downto 16);
					when c_CMD4	=>
						soda_pkt_valid_S	<= '0';
					when c_CMD5	=>
						soda_pkt_valid_S	<= '1';
						soda_pkt_word_S	<= soda_cmd_word_S(15 downto 8);
					when c_CMD6	=>
						soda_pkt_valid_S	<= '0';
					when c_CMD7	=>
						soda_pkt_valid_S	<= '1';
						soda_pkt_word_S	<= crc_out_S;
					when c_CMD8	=>
							soda_pkt_valid_S	<= '0';
					when others	=>
						soda_pkt_valid_S	<= '0';
						soda_pkt_word_S	<= (others=>'0');
			end case;		
		end if;
	end process;


	crc_gen_proc : process(clk_S, packet_state_S)
	begin
		if rising_edge(clk_S) then
			case packet_state_S is
					when c_IDLE	=>
						crc_data_valid_S	<= '0';
						crc_datain_S		<= (others=>'0');
						soc_S					<= '1';
						eoc_S					<= '0';
					when c_CMD1	=>
						crc_data_valid_S	<= '1';
						crc_datain_S		<= '0' & soda_cmd_word_S(30 downto 24);
						soc_S					<= '0';
						eoc_S					<= '0';
					when c_CMD2	=>
						crc_data_valid_S	<= '0';
						crc_datain_S		<= (others=>'0');
						soc_S					<= '0';
						eoc_S					<= '0';
					when c_CMD3	=>
						crc_data_valid_S	<= '1';
						crc_datain_S		<= soda_cmd_word_S(23 downto 16);
						soc_S					<= '0';
						eoc_S					<= '0';
					when c_CMD4	=>
						crc_data_valid_S	<= '0';
						crc_datain_S		<= (others=>'0');
						soc_S					<= '0';
						eoc_S					<= '0';
					when c_CMD5	=>
						crc_data_valid_S	<= '1';
						crc_datain_S	<= soda_cmd_word_S(15 downto 8);
						soc_S					<= '0';
						eoc_S					<= '1';
					when c_CMD6	=>
						crc_data_valid_S	<= '0';
						crc_datain_S		<= (others=>'0');
						soc_S					<= '0';
						eoc_S					<= '0';
					when c_CMD7	=>
						crc_data_valid_S	<= '0';
						crc_datain_S		<= (others=>'0');
						soc_S					<= '0';
						eoc_S					<= '0';
					when c_CMD8	=>
						crc_data_valid_S	<= '0';
						crc_datain_S		<= (others=>'0');
						soc_S					<= '0';
						eoc_S					<= '0';
					when others	=>
						crc_data_valid_S	<= '0';
						crc_datain_S		<= (others=>'0');
						soc_S					<= '0';
						eoc_S					<= '0';
			end case;		
		end if;
	end process;
	
end architecture;