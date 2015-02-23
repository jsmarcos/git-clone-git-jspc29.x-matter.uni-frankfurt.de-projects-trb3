library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

entity cbmnet_readout_tx_fifo is
   port (
      CLK_IN : in std_logic;
      RESET_IN : in std_logic;
      EMPTY_IN : in std_logic;   -- identical to reset_in
      

      DATA_IN  : in  std_logic_vector(15 downto 0);
      DATA_OUT : out std_logic_vector(15 downto 0);
      
      ENQUEUE_IN : in std_logic;
      DEQUEUE_IN : in std_logic;
      
      LAST_OUT : out std_logic;
      
      FILLED_IN : in std_logic;
      FILLED_OUT : out std_logic
   );
end entity;

architecture RTL of cbmnet_readout_tx_fifo is
   type MEM_T is array(0 to 31) of std_logic_vector(15 downto 0);
   signal mem_i : MEM_T;
   
   signal raddr_i, waddr_i : unsigned(5 downto 0);
   signal filled_i : std_logic;
begin

   WPROC: process is
   begin
      wait until rising_edge(CLK_IN);
      
      if RESET_IN='1' or EMPTY_IN='1' then
         waddr_i <= (others => '0');
      elsif ENQUEUE_IN='1' then
         mem_i(to_integer(waddr_i(4 downto 0))) <= DATA_IN;
         if waddr_i /= "100000" then
            waddr_i <= waddr_i + 1;
         end if;
      end if;
   end process;
   
   RPROC: process is
   begin
      wait until rising_edge(CLK_IN);
      
      if RESET_IN='1' or EMPTY_IN='1' then
         raddr_i <= (others => '0');
      elsif DEQUEUE_IN='1' then
         raddr_i <= raddr_i + 1;
      end if;
   end process;
   
   LAST_OUT <= '1' when raddr_i+1 >= waddr_i else '0';
   DATA_OUT <= mem_i(to_integer(raddr_i(4 downto 0)));
   
   filled_i <= not(RESET_IN or EMPTY_IN) and (filled_i or FILLED_IN) when rising_edge(CLK_IN);
   FILLED_OUT <= filled_i;
end architecture;