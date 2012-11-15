library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.nxyter_components.all;

entity nxyter_registers is
  port(
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    
    -- Slave bus         
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;

    -- Signals
    I2C_SM_RESET_OUT     : out std_logic;
    I2C_REG_RESET_OUT    : out std_logic;
    NX_TS_RESET_OUT      : out std_logic;
    
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nxyter_registers is

  signal slv_data_out_o     : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o : std_logic;
  signal slv_unknown_addr_o : std_logic;
  signal slv_ack_o          : std_logic;


  -- I2C Reset
  signal i2c_sm_reset_start  : std_logic;
  signal i2c_reg_reset_start : std_logic;
  signal nx_ts_reset_start   : std_logic;
  
  signal i2c_sm_reset_o      : std_logic;
  signal i2c_reg_reset_o     : std_logic;
  signal nx_ts_reset_o       : std_logic;
  signal wait_timer_init_x   : unsigned(7 downto 0);

  type STATES is (S_IDLE,
                  S_I2C_SM_RESET,
                  S_I2C_SM_RESET_WAIT,
                  S_I2C_REG_RESET,
                  S_I2C_REG_RESET_WAIT,
                  S_NX_TS_RESET,
                  S_NX_TS_RESET_WAIT
                  );
  
  signal STATE, NEXT_STATE : STATES;
  
  -- Wait Timer
  signal wait_timer_init    : unsigned(7 downto 0);
  signal wait_timer_done    : std_logic;
  
  type reg_32bit_t is array (0 to 7) of std_logic_vector(31 downto 0);
  signal reg_data   : reg_32bit_t;
  
begin

  DEBUG_OUT(0) <=  I2C_SM_RESET_OUT ;
  DEBUG_OUT(1) <=  I2C_REG_RESET_OUT;
  DEBUG_OUT(2) <=  NX_TS_RESET_OUT;

  DEBUG_OUT(15 downto 3) <= (others => '0');
  
  nx_timer_1: nx_timer
    generic map (
      CTR_WIDTH => 8
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => RESET_IN,
      TIMER_START_IN => wait_timer_init,
      TIMER_DONE_OUT => wait_timer_done
      );
  
  -----------------------------------------------------------------------------
  -- I2C SM Reset
  -----------------------------------------------------------------------------

  PROC_I2C_SM_RESET_TRANSFER: process(CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        wait_timer_init  <= (others => '0');
        STATE            <= S_IDLE;
      else
        wait_timer_init  <= wait_timer_init_x;
        STATE            <= NEXT_STATE;
      end if;
    end if;
  end process PROC_I2C_SM_RESET_TRANSFER;

  PROC_I2C_SM_RESET: process(STATE)
  begin
    i2c_sm_reset_o     <= '0';
    i2c_reg_reset_o    <= '0';
    nx_ts_reset_o      <= '0';
    wait_timer_init_x  <= (others => '0');
    
    case STATE is
      when S_IDLE =>
        if (i2c_sm_reset_start = '1') then
          NEXT_STATE       <= S_I2C_SM_RESET;
        elsif (i2c_reg_reset_start = '1') then
          NEXT_STATE       <= S_I2C_REG_RESET;
        elsif (nx_ts_reset_start = '1') then
          NEXT_STATE       <= S_NX_TS_RESET;
        else
          NEXT_STATE       <= S_IDLE;
        end if;
        
      when S_I2C_SM_RESET =>
        i2c_sm_reset_o     <= '1';
        wait_timer_init_x  <= x"8f";
        NEXT_STATE         <= S_I2C_SM_RESET_WAIT;

      when S_I2C_SM_RESET_WAIT =>
        i2c_sm_reset_o    <= '1';
        if (wait_timer_done = '0') then
          NEXT_STATE       <= S_I2C_SM_RESET_WAIT;
        else
          NEXT_STATE       <= S_IDLE;
        end if;

      when S_I2C_REG_RESET =>
        i2c_reg_reset_o    <= '1';
        wait_timer_init_x  <= x"8f";
        NEXT_STATE         <= S_I2C_REG_RESET_WAIT;

      when S_I2C_REG_RESET_WAIT =>
        i2c_reg_reset_o    <= '1';
        if (wait_timer_done = '0') then
          NEXT_STATE       <= S_I2C_REG_RESET_WAIT;
        else
          NEXT_STATE       <= S_IDLE;
        end if;

      when S_NX_TS_RESET =>
        nx_ts_reset_o      <= '1';
        wait_timer_init_x  <= x"8f";
        NEXT_STATE         <= S_NX_TS_RESET_WAIT;

      when S_NX_TS_RESET_WAIT =>
        nx_ts_reset_o      <= '1';
        if (wait_timer_done = '0') then
          NEXT_STATE       <= S_NX_TS_RESET_WAIT;
        else
          NEXT_STATE       <= S_IDLE;
        end if;

        
    end case;
  end process PROC_I2C_SM_RESET;

  -----------------------------------------------------------------------------
  -- Slave Bus
  -----------------------------------------------------------------------------
  
  PROC_NX_REGISTERS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        reg_data(0)         <= x"babe_0000";
        reg_data(1)         <= x"babe_0001";
        reg_data(2)         <= x"babe_0002";
        reg_data(3)         <= x"babe_0003";
        reg_data(4)         <= x"babe_0004";
        reg_data(5)         <= x"babe_0005";
        reg_data(6)         <= x"babe_0006";
        reg_data(7)         <= x"babe_0007";

        slv_data_out_o      <= (others => '0');
        slv_no_more_data_o  <= '0';
        slv_unknown_addr_o  <= '0';
        slv_ack_o           <= '0';
        
        i2c_sm_reset_start  <= '0';
        i2c_reg_reset_start <= '0';
        nx_ts_reset_start   <= '0';
      else
        slv_ack_o <= '1';
        slv_unknown_addr_o  <= '0';
        slv_no_more_data_o  <= '0';
        slv_data_out_o      <= (others => '0');    
        i2c_sm_reset_start  <= '0';
        i2c_reg_reset_start <= '0';
        nx_ts_reset_start   <= '0';

        if (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" => i2c_sm_reset_start  <= '1';
            when x"0001" => i2c_reg_reset_start <= '1';
            when x"0002" => nx_ts_reset_start   <= '1';
            when x"0003" => reg_data(3) <= SLV_DATA_IN;
            when x"0004" => reg_data(4) <= SLV_DATA_IN;
            when x"0005" => reg_data(5) <= SLV_DATA_IN;
            when x"0006" => reg_data(6) <= SLV_DATA_IN;
            when x"0007" => reg_data(7) <= SLV_DATA_IN;
            when others => slv_unknown_addr_o <= '1';
                           slv_ack_o <= '0';
          end case;
          
        elsif (SLV_READ_IN = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>  slv_data_out_o <= reg_data(0);
            when x"0001" =>  slv_data_out_o <= reg_data(1);
            when x"0002" =>  slv_data_out_o <= reg_data(2);
            when x"0003" =>  slv_data_out_o <= reg_data(3);
            when x"0004" =>  slv_data_out_o <= reg_data(4);
            when x"0005" =>  slv_data_out_o <= reg_data(5);
            when x"0006" =>  slv_data_out_o <= reg_data(6);
            when x"0007" =>  slv_data_out_o <= reg_data(7);
            when others => slv_unknown_addr_o <= '1';
                           slv_ack_o <= '0';
          end case;

        else
          slv_ack_o <= '0';
        end if;
      end if;
    end if;           
  end process PROC_NX_REGISTERS;

-- Output Signals
  SLV_DATA_OUT         <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT <= slv_unknown_addr_o;
  SLV_ACK_OUT          <= slv_ack_o;          

  I2C_SM_RESET_OUT     <= i2c_sm_reset_o;
  I2C_REG_RESET_OUT    <= i2c_reg_reset_o;
  NX_TS_RESET_OUT      <= nx_ts_reset_o;

end Behavioral;
