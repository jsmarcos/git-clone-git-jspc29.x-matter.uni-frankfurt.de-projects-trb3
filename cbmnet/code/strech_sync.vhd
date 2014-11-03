entity POS_EDGE_STRECH_SYNC is
   generic (
      LENGTH : positive := 2
   );
   port (
      IN_CLK_IN : std_logic;
      DATA_IN : std_logic;
      OUT_CLK_IN : std_logic;
      DATA_OUT : std_logic
   )
end entity;

architecture RTL of STRECH_SYNC is
   signal in_buffer_i : std_logic_vector(LENGTH - 1 downto 0);
   signal in_buffer_aggr_i : std_logic;
   signal out_buffer_i : std_logic;
begin
   in_buffer_i <= in_buffer_i(LENGTH-2 downto 0) & DATA_IN when rising_edge(OUT_CLK_IN);
   in_buffer_aggr_i <= OR_ALL(in_buffer_i);
   
   out_buffer_i <= not out_buffer_i and in_buffer_aggr_i when rising_edge(OUT_CLK_IN);
end architecture;