library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.scaler_components.all;


entity adc_spi_readbyte is
  generic (
    SPI_SPEED : unsigned(7 downto 0) := x"32"
    );
  port(
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;

    START_IN             : in  std_logic;
    BYTE_OUT             : out std_logic_vector(7 downto 0);
    SEQUENCE_DONE_OUT    : out std_logic;

    -- SPI connections
    SDIO_IN              : in   std_logic;
    SCLK_OUT             : out std_logic
    );
end entity;

architecture Behavioral of adc_spi_readbyte is

  -- Send Byte  
  signal sclk_o             : std_logic;
  signal spi_start          : std_logic;

  signal sequence_done_o    : std_logic;
  signal spi_byte           : unsigned(7 downto 0);
  signal bit_ctr            : unsigned(3 downto 0);
  signal spi_ack_o          : std_logic;
  signal wait_timer_start   : std_logic;

  signal sequence_done_o_x  : std_logic;
  signal spi_byte_x         : unsigned(7 downto 0);
  signal bit_ctr_x          : unsigned(3 downto 0);
  signal spi_ack_o_x        : std_logic;
  signal wait_timer_start_x : std_logic;

  type STATES is (S_IDLE,
                  S_UNSET_SCKL,
                  S_UNSET_SCKL_HOLD,
                  S_GET_BIT,
                  S_SET_SCKL,
                  S_NEXT_BIT,
                  S_DONE
                  );
  signal STATE, NEXT_STATE : STATES;
  
  -- Wait Timer
  signal wait_timer_done    : std_logic;

begin

  -- Timer
  timer_static_1: timer_static
    generic map(
      CTR_WIDTH => 8,
      CTR_END   => to_integer(SPI_SPEED srl 1)
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => RESET_IN,
      TIMER_START_IN => wait_timer_start,
      TIMER_DONE_OUT => wait_timer_done
      );

  PROC_READ_BYTE_TRANSFER: process(CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        sequence_done_o  <= '0';
        bit_ctr          <= (others => '0');
        spi_ack_o        <= '0';
        wait_timer_start <= '0';
        STATE            <= S_IDLE;
      else
        sequence_done_o  <= sequence_done_o_x;
        spi_byte         <= spi_byte_x;
        bit_ctr          <= bit_ctr_x;
        spi_ack_o        <= spi_ack_o_x;
        wait_timer_start <= wait_timer_start_x;
        STATE            <= NEXT_STATE;
      end if;
    end if;
  end process PROC_READ_BYTE_TRANSFER;  
  
  PROC_READ_BYTE: process(STATE,
                          START_IN,
                          wait_timer_done,
                          bit_ctr
                          )
  begin 
    sclk_o             <= '0';
    sequence_done_o_x  <= '0';
    spi_byte_x         <= spi_byte;
    bit_ctr_x          <= bit_ctr;       
    spi_ack_o_x        <= spi_ack_o;
    wait_timer_start_x <= '0';
    
    case STATE is
      when S_IDLE =>
        if (START_IN = '1') then
          spi_byte_x         <= (others => '0');
          bit_ctr_x          <= x"7";
          wait_timer_start_x <= '1';
          NEXT_STATE         <= S_UNSET_SCKL;
        else
          NEXT_STATE         <= S_IDLE;
        end if;

        -- SPI Read byte
      when S_UNSET_SCKL =>
        wait_timer_start_x   <= '1';
        NEXT_STATE           <= S_UNSET_SCKL_HOLD;

      when S_UNSET_SCKL_HOLD =>
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_UNSET_SCKL_HOLD;
        else
          NEXT_STATE <= S_GET_BIT;
        end if;
        
      when S_GET_BIT =>
        spi_byte_x(0)        <= SDIO_IN;
        wait_timer_start_x   <= '1';
        NEXT_STATE           <= S_SET_SCKL;

      when S_SET_SCKL =>
        sclk_o  <= '1';
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_SET_SCKL;
        else
          wait_timer_start_x <= '1';
          NEXT_STATE         <= S_NEXT_BIT;
        end if;
        
      when S_NEXT_BIT =>
        sclk_o  <= '1';
        if (bit_ctr > 0) then
          bit_ctr_x          <= bit_ctr - 1;
          spi_byte_x         <= spi_byte sll 1;
          wait_timer_start_x <= '1';
          NEXT_STATE         <= S_UNSET_SCKL;
        else
          NEXT_STATE         <= S_DONE;
        end if;

      when S_DONE =>
        sclk_o  <= '1';
        sequence_done_o_x <= '1';
        NEXT_STATE        <= S_IDLE;

    end case;
  end process PROC_READ_BYTE;

  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  SEQUENCE_DONE_OUT <= sequence_done_o;
  BYTE_OUT          <= spi_byte;
  
  -- I2c Outputs
  SCLK_OUT <= sclk_o;
  
end Behavioral;
