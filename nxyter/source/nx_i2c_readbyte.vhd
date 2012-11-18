library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;


entity nx_i2c_readbyte is
  generic (
    I2C_SPEED : unsigned(11 downto 0) := x"3e8"
    );
  port(
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;

    START_IN             : in  std_logic;
    BYTE_OUT             : out std_logic_vector(7 downto 0);
    SEQUENCE_DONE_OUT    : out std_logic;

    -- I2C connections
    SDA_OUT              : out std_logic;
    SCL_OUT              : out std_logic;
    SDA_IN               : in  std_logic
    );
end entity;

architecture Behavioral of nx_i2c_readbyte is

  -- Send Byte  
  signal sda_o             : std_logic;
  signal scl_o             : std_logic;
  signal i2c_start         : std_logic;

  signal sequence_done_o   : std_logic;
  signal i2c_byte          : unsigned(7 downto 0);
  signal bit_ctr           : unsigned(3 downto 0);
  signal i2c_ack_o         : std_logic;
  signal wait_timer_init   : unsigned(11 downto 0);

  signal sequence_done_o_x : std_logic;
  signal i2c_byte_x        : unsigned(7 downto 0);
  signal bit_ctr_x         : unsigned(3 downto 0);
  signal i2c_ack_o_x       : std_logic;
  signal wait_timer_init_x : unsigned(11 downto 0);
  
  type STATES is (S_IDLE,
                  S_INIT,
                  S_INIT_WAIT,

                  S_READ_BYTE,
                  S_UNSET_SCL1,
                  S_SET_SCL1,
                  s_GET_BIT,
                  S_SET_SCL2,
                  S_UNSET_SCL2,
                  S_NEXT_BIT,

                  S_SET_ACK,
                  S_ACK_SET_SCL,
                  S_ACK_UNSET_SCL
                  );
  signal STATE, NEXT_STATE : STATES;
  
  -- Wait Timer
  signal wait_timer_done    : std_logic;

begin

  -- Timer
  nx_timer_1: nx_timer
    generic map(
      CTR_WIDTH => 12
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => RESET_IN,
      TIMER_START_IN => wait_timer_init,
      TIMER_DONE_OUT => wait_timer_done
      );


  PROC_READ_BYTE_TRANSFER: process(CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        sequence_done_o  <= '0';
        bit_ctr          <= (others => '0');
        i2c_ack_o        <= '0';
        wait_timer_init  <= (others => '0');
        STATE            <= S_IDLE;
      else
        sequence_done_o  <= sequence_done_o_x;
        i2c_byte         <= i2c_byte_x;
        bit_ctr          <= bit_ctr_x;
        i2c_ack_o        <= i2c_ack_o_x;
        wait_timer_init  <= wait_timer_init_x;
        STATE            <= NEXT_STATE;
      end if;
    end if;
  end process PROC_READ_BYTE_TRANSFER;  
  
  PROC_READ_BYTE: process(STATE)
  begin 
    sda_o              <= '1';
    scl_o              <= '1';
    sequence_done_o_x  <= '0';
    i2c_byte_x         <= i2c_byte;
    bit_ctr_x          <= bit_ctr;       
    i2c_ack_o_x        <= i2c_ack_o;
    wait_timer_init_x  <= (others => '0');
    
    case STATE is
      when S_IDLE =>
        if (START_IN = '1') then
          sda_o       <= '0';
          scl_o       <= '0';
          i2c_byte_x  <= (others => '0');
          NEXT_STATE  <= S_INIT;
        else
          NEXT_STATE <= S_IDLE;
        end if;

        -- INIT
      when S_INIT =>
        sda_o              <= '0';
        scl_o              <= '0';
        wait_timer_init_x  <= I2C_SPEED srl 1;
        NEXT_STATE <= S_INIT_WAIT;

      when S_INIT_WAIT =>
        sda_o              <= '0';
        scl_o              <= '0';
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_INIT_WAIT;
        else
          NEXT_STATE <= S_READ_BYTE;
        end if;
        
        -- I2C Read byte
      when S_READ_BYTE =>
        scl_o             <= '0';
        bit_ctr_x         <= x"7";
        wait_timer_init_x <= I2C_SPEED srl 2;
        NEXT_STATE        <= S_UNSET_SCL1;

      when S_UNSET_SCL1 =>
        scl_o <= '0';
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_UNSET_SCL1;
        else
          wait_timer_init_x <= I2C_SPEED srl 2;
          NEXT_STATE <= S_SET_SCL1;
        end if;

      when S_SET_SCL1 =>
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_SET_SCL1;
        else
          wait_timer_init_x <= I2C_SPEED srl 2;
          NEXT_STATE        <= S_GET_BIT;
        end if;

      when S_GET_BIT =>
        i2c_byte_x(0)   <= SDA_IN;
        NEXT_STATE      <= S_SET_SCL2;
                
      when S_SET_SCL2 =>
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_SET_SCL2;
        else
          wait_timer_init_x <= I2C_SPEED srl 2;
          NEXT_STATE        <= S_UNSET_SCL2;
        end if;
        
      when S_UNSET_SCL2 =>
        scl_o <= '0';
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_UNSET_SCL2;
        else
          NEXT_STATE <= S_NEXT_BIT;
        end if;
        
      when S_NEXT_BIT =>
        scl_o <= '0';
        if (bit_ctr > 0) then
          bit_ctr_x          <= bit_ctr - 1;
          i2c_byte_x         <= i2c_byte sll 1;
          wait_timer_init_x  <= I2C_SPEED srl 2;
          NEXT_STATE         <= S_UNSET_SCL1;
        else
          wait_timer_init_x  <= I2C_SPEED srl 2;
          NEXT_STATE         <= S_SET_ACK;
        end if;

        -- I2C Send ACK Sequence (doesn't work, so just send a clock)
      when S_SET_ACK =>
        --sda_o <= '0';
        scl_o <= '0';
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_SET_ACK;
        else
          wait_timer_init_x <= I2C_SPEED srl 1;
          NEXT_STATE        <= S_ACK_SET_SCL;
        end if;

      when S_ACK_SET_SCL =>
        -- sda_o <= '0';
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_ACK_SET_SCL;
        else
          wait_timer_init_x <= I2C_SPEED srl 2;
          NEXT_STATE        <= S_ACK_UNSET_SCL;
        end if; 
        
      when S_ACK_UNSET_SCL =>
        --sda_o <= '0';
        scl_o <= '0';
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_ACK_UNSET_SCL;
        else
          sequence_done_o_x <= '1';
          NEXT_STATE        <= S_IDLE;
        end if;

    end case;
  end process PROC_READ_BYTE;

  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  SEQUENCE_DONE_OUT <= sequence_done_o;
  BYTE_OUT          <= i2c_byte;
  
  -- I2c Outputs
  SDA_OUT <= sda_o;
  SCL_OUT <= scl_o;
  
end Behavioral;
