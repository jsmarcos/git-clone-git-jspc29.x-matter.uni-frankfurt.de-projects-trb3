library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.adcmv3_components.all;

entity slv_ped_thr_mem is
  port(
    CLK_IN          : in    std_logic;
    RESET_IN        : in    std_logic;

    -- Slave bus
    SLV_ADDR_IN     : in    std_logic_vector(10 downto 0);
    SLV_READ_IN     : in    std_logic;
    SLV_WRITE_IN    : in    std_logic;
    SLV_ACK_OUT     : out   std_logic;
    SLV_DATA_IN     : in    std_logic_vector(31 downto 0);
    SLV_DATA_OUT    : out   std_logic_vector(31 downto 0);

    -- I/O to the backend
    MEM_CLK_IN      : in    std_logic;
    MEM_ADDR_IN     : in    std_logic_vector(6 downto 0);
    MEM_0_D_OUT     : out   std_logic_vector(17 downto 0);

    -- Status lines
    STAT            : out   std_logic_vector(31 downto 0) -- DEBUG
    );
end entity;

architecture Behavioral of slv_ped_thr_mem is

-- Signals
  type STATES is (SLEEP,
                  RD_RDY,
                  RD_DEL0,
                  RD_DEL1,
                  WR_DEL0,
                  WR_DEL1,
                  WR_RDY,
                  RD_ACK,
                  WR_ACK,
                  DONE);
  signal CURRENT_STATE, NEXT_STATE: STATES;

-- statemachine signals
  signal slv_ack_x        : std_logic;
  signal slv_ack          : std_logic;
  signal store_wr_x       : std_logic;
  signal store_wr         : std_logic;
  signal store_rd_x       : std_logic;
  signal store_rd         : std_logic;

  signal block_addr       : std_logic_vector(3 downto 0);

  signal ped_data             : std_logic_vector(17 downto 0);
  signal mem_data             : std_logic_vector(17 downto 0);

  signal mem_wr_x             : std_logic;
  signal mem_wr               : std_logic;
  signal mem_sel              : std_logic;

  signal rdback_data          : std_logic_vector(17 downto 0);

begin

---------------------------------------------------------
-- Mapping of backplanes                               --
---------------------------------------------------------
--  THE_APV_ADC_MAP_MEM: apv_adc_map_mem
--    port map (
--      ADDRESS(6 downto 4) => backplane_in,
--      ADDRESS(3 downto 0) => slv_addr_in(10 downto 7),
--      Q                   => block_addr
--      );
--
  THE_MEM_SEL_PROC: process( clk_in )
  begin
    if( rising_edge(clk_in) ) then
      mem_sel     <= '1';
      rdback_data <= mem_data;
    end if;
  end process THE_MEM_SEL_PROC;

---------------------------------------------------------
-- Statemachine                                        --
---------------------------------------------------------
-- State memory process
  STATE_MEM: process( clk_in )
  begin
    if( rising_edge(clk_in) ) then
      if( reset_in = '1' ) then
        CURRENT_STATE <= SLEEP;
        slv_ack       <= '0';
        store_wr      <= '0';
        store_rd      <= '0';
      else
        CURRENT_STATE <= NEXT_STATE;
        slv_ack       <= slv_ack_x;
        store_wr      <= store_wr_x;
        store_rd      <= store_rd_x;
      end if;
    end if;
  end process STATE_MEM;

-- Transition matrix
  TRANSFORM: process( CURRENT_STATE, slv_read_in, slv_write_in )
  begin
    NEXT_STATE <= SLEEP;
    slv_ack_x  <= '0';
    store_wr_x <= '0';
    store_rd_x <= '0';
    case CURRENT_STATE is
      when SLEEP      =>  if   ( slv_read_in = '1' ) then
                            NEXT_STATE <= RD_DEL0;
                            store_rd_x <= '1';
                          elsif( slv_write_in = '1' ) then
                            NEXT_STATE <= WR_DEL0;
                            store_wr_x <= '1';
                          else
                            NEXT_STATE <= SLEEP;
                          end if;
      when RD_DEL0    =>  NEXT_STATE <= RD_DEL1;
      when RD_DEL1    =>  NEXT_STATE <= RD_RDY;
      when RD_RDY     =>  NEXT_STATE <= RD_ACK;
      when RD_ACK     =>  if( slv_read_in = '0' ) then
                            NEXT_STATE <= DONE;
                            slv_ack_x  <= '1';
                          else
                            NEXT_STATE <= RD_ACK;
                            slv_ack_x  <= '1';
                          end if;
      when WR_DEL0    =>  NEXT_STATE <= WR_DEL1;
      when WR_DEL1    =>  NEXT_STATE <= WR_RDY;
      when WR_RDY     =>  NEXT_STATE <= WR_ACK;
      when WR_ACK     =>  if( slv_write_in = '0' ) then
                            NEXT_STATE <= DONE;
                            slv_ack_x  <= '1';
                          else
                            NEXT_STATE <= WR_ACK;
                            slv_ack_x  <= '1';
                          end if;
      when DONE       =>  NEXT_STATE <= SLEEP;

      when others     =>  NEXT_STATE <= SLEEP;
    end case;
  end process TRANSFORM;

---------------------------------------------------------
-- block memories                                      --
---------------------------------------------------------
  -- Port A: SLV_BUS
  -- Port B: state machine
  THE_PED_MEM: ped_thr_true
    port map(
      DATAINA     => slv_data_in(17 downto 0),
      DATAINB     => b"00_0000_0000_0000_0000",
      ADDRESSA    => slv_addr_in(6 downto 0),
      ADDRESSB    => mem_addr_in,
      CLOCKA      => clk_in,
      CLOCKB      => mem_clk_in,
      CLOCKENA    => '1',
      CLOCKENB    => '1',
      WRA         => mem_wr, -- BUGBUGBUG
      WRB         => '0', -- state machine never writes!
      RESETA      => reset_in,
      RESETB      => reset_in,
      QA          => mem_data,
      QB          => ped_data
      );
-- Write signals
  mem_wr_x <= '1' when ( (mem_sel = '1') and (store_wr = '1') ) else '0';


-- Synchronize
  THE_SYNC_PROC: process(clk_in)
  begin
    if( rising_edge(clk_in) ) then
      mem_wr <= mem_wr_x;
    end if;
  end process THE_SYNC_PROC;

---------------------------------------------------------
-- output signals                                      --
---------------------------------------------------------
  slv_ack_out  <= slv_ack;
  slv_data_out <= b"0000_0000_0000_00" & rdback_data;

  mem_0_d_out  <= ped_data;

  stat(31 downto 20) <= (others => '0');
  stat(19 downto 16) <= block_addr;
  stat(15 downto 1)  <= (others => '0');
  stat(0)            <= mem_sel;

end Behavioral;
