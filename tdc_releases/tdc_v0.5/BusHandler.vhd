library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.version.all;

entity BusHandler is
  generic (
    CHANNEL_NUMBER : integer range 0 to 64 := 2);
  port (
    RESET            : in  std_logic;
    CLK              : in  std_logic;
--
    DATA_IN          : in  std_logic_vector_array_32(0 to CHANNEL_NUMBER);
    READ_EN_IN       : in  std_logic;
    WRITE_EN_IN      : in  std_logic;
    ADDR_IN          : in  std_logic_vector(6 downto 0);
    DATA_OUT         : out std_logic_vector(31 downto 0);
    DATAREADY_OUT    : out std_logic;
    UNKNOWN_ADDR_OUT : out std_logic);
end BusHandler;

architecture Behavioral of BusHandler is

  --Output signals
  signal data_out_reg     : std_logic_vector(31 downto 0);
  signal data_ready_reg   : std_logic;
  signal unknown_addr_reg : std_logic;

  --FSM signals
  type   FSM is (IDLE, READ_A, WRITE_A);
  signal FSM_CURRENT, FSM_NEXT : FSM;
  signal fsm_data_out          : std_logic_vector(31 downto 0);
  signal fsm_data_ready        : std_logic;
  signal fsm_unknown_addr      : std_logic;
  
begin

  READ_WRITE_RESPONSE : process (CLK, RESET)
  begin
    if rising_edge(CLK) then
      if RESET = '1' then
        data_out_reg     <= (others => '0');
        data_ready_reg   <= '0';
        unknown_addr_reg <= '0';
      elsif READ_EN_IN = '1' then
        if to_integer(unsigned(ADDR_IN)) > CHANNEL_NUMBER then  -- if bigger than 64
          data_out_reg     <= (others => '0');
          data_ready_reg   <= '0';
          unknown_addr_reg <= '1';
        else
          data_out_reg     <= DATA_IN(to_integer(unsigned(ADDR_IN)));
          data_ready_reg   <= '1';
          unknown_addr_reg <= '0';
        end if;
      elsif WRITE_EN_IN = '1' then
        data_out_reg     <= (others => '0');
        data_ready_reg   <= '0';
        unknown_addr_reg <= '1';
      else
        data_out_reg     <= (others => '0');
        data_ready_reg   <= '0';
        unknown_addr_reg <= '0';
      end if;
    end if;
  end process READ_WRITE_RESPONSE;


  --FifoWriteSignal : process (CLK)
  --begin
  --  if rising_edge(CLK) then
  --    if RESET = '1' then
  --      unknown_addr_reg <= '0';
  --    else
  --      unknown_addr_reg <= '1';
  --    end if;
  --  end if;
  --end process FifoWriteSignal;
                            

        

  DATA_OUT         <= data_out_reg;
  DATAREADY_OUT    <= data_ready_reg;
  UNKNOWN_ADDR_OUT <= unknown_addr_reg;

end Behavioral;

