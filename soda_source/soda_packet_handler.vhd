library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
--use work.trb_net_std.all;
--use work.trb_net_components.all;
--use work.trb3_components.all;
--use work.med_sync_define.all;
--use work.version.all;

entity soda_packet_handler is
port(
	SYSCLK					: in	std_logic; -- fabric clock
	RESET						: in	std_logic; -- synchronous reset
	CLEAR						: in	std_logic; -- asynchronous reset
	CLK_EN					: in	std_logic;
	--Internal Connection
	RX_DLM_IN				: in std_logic;
	RX_DLM_WORD_IN			: in	std_logic_vector(7 downto 0) := (others => '0')
	);
end soda_packet_handler;

architecture Behavioral of soda_packet_handler is

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

	constant	c_K287						: std_logic_vector(7 downto 0) := x"FB";

	signal	clk_S							: std_logic;
	signal	rst_S							: std_logic;
	signal	rx_dlm_in_S					: std_logic;
	signal	rx_dlm_word_in_S			: std_logic_vector(7 downto 0) := (others => '0');
	signal	soda_cmd_strobe_S			: std_logic;
	signal	start_of_superburst_S	: std_logic;
	signal	super_burst_nr_S			: std_logic_vector(30 downto 0) := (others => '0');		-- from super-burst-nr-generator
	signal	soda_cmd_word_S			: std_logic_vector(30 downto 0) := (others => '0');		-- from slowcontrol
	signal	soda_pkt_word_S			: std_logic_vector(31 downto 0) := (others => '0');
	signal	soda_pkt_valid_S			: std_logic;
	
	type		packet_state_type is (	c_RST, c_IDLE, c_ERROR,
												c_SODA_PKT1, c_SODA_PKT2, c_SODA_PKT3, c_SODA_PKT4,
												c_SODA_PKT5, c_SODA_PKT6, c_SODA_PKT7, c_SODA_PKT8
											);
	signal	packet_state_S				:	packet_state_type := c_IDLE;

	signal	soc_S							: std_logic	:=	'1';
	signal	eoc_S							: std_logic	:= '0';
	signal	crc_data_valid_S			: std_logic	:= '0';
	signal	crc_datain_S				: std_logic_vector(7 downto 0)	:= (others => '0');
	signal	crc_tmp_S					: std_logic_vector(7 downto 0)	:= (others => '0');
	signal	crc_out_S					: std_logic_vector(7 downto 0)	:= (others => '0');
	signal	crc_valid_S					: std_logic	:= '0';

	signal	crc_check_S					: std_logic	:= '0';
	signal	crc_check_valid_S			: std_logic	:= '0';

begin

	rx_crc8: soda_d8crc8 
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
	
--	packet_state_S	<= packet_state_S;
	
			rx_dlm_in_S					<=	RX_DLM_IN;
			rx_dlm_word_in_S			<=	RX_DLM_WORD_IN;
	
	packet_fsm_proc : process(clk_S)
	begin
		if rising_edge(clk_S) then
			if (rst_S='1') then
				packet_state_S	<=	c_RST;
			else
				case packet_state_S is
					when c_RST	=>
						if (rx_dlm_in_S='1') then						-- received K27.7 #1
							packet_state_S	<= c_SODA_PKT1;
						else
							packet_state_S	<= c_IDLE;
						end if;
					when c_IDLE	=>
						if (rx_dlm_in_S='1') then						-- received K27.7 #1
							packet_state_S	<= c_SODA_PKT1;
						else
							packet_state_S	<= c_IDLE;
						end if;
					when c_SODA_PKT1	=>
						if (rx_dlm_in_S='0') then						-- possibly received data-byte
							packet_state_S	<= c_SODA_PKT2;
						else
							packet_state_S	<= c_ERROR;
						end if;
					when c_SODA_PKT2	=>
						if (rx_dlm_in_S='1') then						-- received K27.7 #2
							packet_state_S	<= c_SODA_PKT3;
						else
							packet_state_S	<= c_ERROR;
						end if;
					when c_SODA_PKT3	=>
						if (rx_dlm_in_S='0') then						-- possibly received data-byte
							packet_state_S	<= c_SODA_PKT4;
						else
							packet_state_S	<= c_ERROR;
						end if;
					when c_SODA_PKT4	=>
						if (rx_dlm_in_S='1') then						-- received K27.7 #3
							packet_state_S	<= c_SODA_PKT5;
						else
							packet_state_S	<= c_ERROR;
						end if;
					when c_SODA_PKT5	=>
						if (rx_dlm_in_S='0') then						-- possibly received data-byte
							packet_state_S	<= c_SODA_PKT6;
						else
							packet_state_S	<= c_ERROR;
						end if;
					when c_SODA_PKT6	=>
						if (rx_dlm_in_S='1') then						-- received K27.7 #4
							packet_state_S	<= c_SODA_PKT7;
						else
							packet_state_S	<= c_ERROR;
						-- else do nothing
						end if;
					when c_SODA_PKT7	=>
						if (rx_dlm_in_S='1') or (crc_valid_S = '0') or not(crc_out_S = RX_DLM_WORD_IN) then
							packet_state_S	<= c_ERROR;	-- if there's an unexpected K27.7 or no valid CRC-output or the CRC-check doesn't match
						else
							packet_state_S	<= c_SODA_PKT8;
						end if;
					when c_SODA_PKT8	=>
						if (rx_dlm_in_S='1') then						-- received K27.7 #4+1... must be another packet coming in....
							packet_state_S	<= c_SODA_PKT1;
						else
							packet_state_S	<= c_IDLE;
						end if;
					when c_ERROR	=>
							packet_state_S	<= c_IDLE;				-- TODO: Insert ERROR_HANDLER
					when others	=>
							packet_state_S	<= c_IDLE;
				end case;
			end if;
		end if;
	end process;

	soda_packet_collector_proc : process(clk_S, packet_state_S)
	begin
		if rising_edge(clk_S) then
			case packet_state_S is
					when c_RST	=>
						soda_pkt_valid_S	<= '0';
						soda_pkt_word_S						<= (others=>'0');
					when c_IDLE	=>
						soda_pkt_valid_S	<= '0';
						soda_pkt_word_S						<= (others=>'0');
					when c_SODA_PKT1 	=>
						soda_pkt_word_S(31 downto 24)		<=	RX_DLM_WORD_IN;
					when c_SODA_PKT2	=>
						-- do nothing -- disregard k27.7
					when c_SODA_PKT3	=>
						soda_pkt_word_S(23 downto 16)		<=	RX_DLM_WORD_IN;
					when c_SODA_PKT4	=>
						-- do nothing -- disregard k27.7
					when c_SODA_PKT5	=>
						soda_pkt_word_S(15 downto 8)		<=	RX_DLM_WORD_IN;
					when c_SODA_PKT6	=>
						-- do nothing -- disregard k27.7
					when c_SODA_PKT7	=>
						soda_pkt_word_S(7 downto 0)		<=	RX_DLM_WORD_IN;	-- get transmitted CRC
					when c_SODA_PKT8	=>
					when others	=>
						soda_pkt_valid_S						<= '0';
						soda_pkt_word_S						<= (others=>'0');
			end case;
			
			if (soda_pkt_valid_S ='1') then
				if (soda_pkt_word_S(31) = '1') then
					super_burst_nr_S							<= soda_pkt_word_S(30 downto 0);
					start_of_superburst_S					<= '1';
				else
					soda_cmd_word_S							<= soda_pkt_word_S(30 downto 0);
					soda_cmd_strobe_S							<= '1';
				end if;
			else
				start_of_superburst_S						<= '0';
				soda_cmd_strobe_S								<= '0';
			end if;
		end if;
	end process;

	crc_check_proc : process(clk_S, packet_state_S)
	begin
		if rising_edge(clk_S) then
			case packet_state_S is
					when c_RST	=>
						soc_S										<= '1';
						eoc_S										<= '0';
						crc_check_valid_S						<= '0';
					when c_IDLE	=>
						crc_data_valid_S						<= '0';
						crc_datain_S							<= (others=>'0');
						soc_S										<= '1';
						eoc_S										<= '0';
					when c_SODA_PKT1	=>
						crc_data_valid_S						<= '1';
						crc_datain_S							<=	RX_DLM_WORD_IN;
						soc_S										<= '0';
					when c_SODA_PKT2	=>
						crc_data_valid_S						<= '0';
						crc_datain_S							<= (others=>'0');
					when c_SODA_PKT3	=>
						crc_data_valid_S						<= '1';
						crc_datain_S							<= RX_DLM_WORD_IN;
					when c_SODA_PKT4	=>
						crc_data_valid_S						<= '0';
						crc_datain_S							<= (others=>'0');
					when c_SODA_PKT5	=>
						crc_data_valid_S						<= '1';
						crc_datain_S							<= RX_DLM_WORD_IN;
						eoc_S										<= '1';
					when c_SODA_PKT6	=>
						crc_data_valid_S						<= '0';
						crc_datain_S							<= (others=>'0');
						eoc_S										<= '0';
					when c_SODA_PKT7	=>
						crc_data_valid_S						<= '0';
						crc_datain_S							<= (others=>'0');
						if ((crc_valid_S = '1') and (crc_out_S = RX_DLM_WORD_IN)) then
							crc_check_S							<= '1';
						else
							crc_check_S							<= '0';
						end if;
						crc_check_valid_S						<= '1';
					when c_SODA_PKT8	=>
						crc_data_valid_S						<= '0';
						crc_datain_S							<= (others=>'0');
						soc_S										<= '0';
						eoc_S										<= '0';
						crc_check_S								<= '0';
						crc_check_valid_S						<= '0';
					when others	=>
						crc_data_valid_S						<= '0';
						crc_datain_S							<= (others=>'0');
						soc_S										<= '0';
						eoc_S										<= '0';
						crc_check_valid_S						<= '0';
			end case;		
		end if;
	end process;

end architecture;