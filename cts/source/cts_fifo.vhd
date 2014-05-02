library IEEE;
   use IEEE.STD_LOGIC_1164.ALL;
   use IEEE.NUMERIC_STD.ALL;

entity CTS_FIFO is
   generic (
      ADDR_WIDTH : integer range 1 to 32;
      WIDTH : positive
   );
   
   port (
      CLK         : in std_logic;
      RESET       : in std_logic;
      
      DATA_IN     : in  std_logic_vector(WIDTH-1 downto 0);
      DATA_OUT    : out std_logic_vector(WIDTH-1 downto 0);
      
      WORDS_IN_FIFO_OUT : out std_logic_vector(ADDR_WIDTH downto 0);
      
      ENQUEUE_IN  : in std_logic;
      DEQUEUE_IN  : in std_logic;
      
      FULL_OUT    : out std_logic;
      EMPTY_OUT   : out std_logic
   );
end entity;

architecture RTL of CTS_FIFO is
   constant DEPTH : integer := 2**ADDR_WIDTH;
   
   attribute syn_ramstyle : string;
   
   type memory_t is array(0 to DEPTH-1) of std_logic_vector(WIDTH-1 downto 0);
   signal memory_i : memory_t;   
   attribute syn_ramstyle of memory_i : signal is "block_ram";
   
   signal index_read_i, index_write_i : integer range 0 to DEPTH - 1 := 0;
   signal full_i, empty_i : std_logic;
   
   signal words_in_fifo_i : integer range 0 to DEPTH;
begin
   proc: process(CLK) is
      variable next_read_v, next_write_v : integer range 0 to DEPTH - 1 := 0;
   begin
      if rising_edge(CLK) then
      -- compute next addresses (might be used later !)
         if index_read_i = DEPTH - 1 then
            next_read_v := 0;
         else
            next_read_v := index_read_i + 1;
         end if;

         if index_write_i = DEPTH - 1 then
            next_write_v := 0;
         else
            next_write_v := index_write_i + 1;
         end if;

      -- do the job
         if RESET = '1' then
            index_read_i <= 0;
            index_write_i <= 0;
            full_i <= '0';
            empty_i <= '1';
            words_in_fifo_i <= 0;
         else
            if ENQUEUE_IN = '1' and DEQUEUE_IN = '1' and empty_i = '0' then
               memory_i(index_write_i) <= DATA_IN;
               index_write_i <= next_write_v;
               index_read_i <= next_read_v;
               
            elsif ENQUEUE_IN = '1' and full_i = '0' then
               memory_i(index_write_i) <= DATA_IN;
               index_write_i <= next_write_v;
               empty_i <= '0';

               if words_in_fifo_i = DEPTH - 1 then
                  full_i <= '1';
               end if;

               words_in_fifo_i <= words_in_fifo_i + 1;               
               
            elsif DEQUEUE_IN = '1' and empty_i = '0' then
               index_read_i <= next_read_v;
               full_i <= '0';
               
               if words_in_fifo_i = 1 then
                  empty_i <= '1';
               end if;
            
               words_in_fifo_i <= words_in_fifo_i - 1;
            end if;
         end if;
      end if;
   end process;
   
   DATA_OUT <= memory_i(index_read_i);
   WORDS_IN_FIFO_OUT <= STD_LOGIC_VECTOR(TO_UNSIGNED(words_in_fifo_i, WORDS_IN_FIFO_OUT'length));
   EMPTY_OUT <= empty_i;
   FULL_OUT <= full_i;   
end architecture;