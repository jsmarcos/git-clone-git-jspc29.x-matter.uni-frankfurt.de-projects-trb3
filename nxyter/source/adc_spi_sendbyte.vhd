library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;


entity adc_spi_sendbyte is
  generic (
    SPI_SPEED : unsigned(7 downto 0) := x"32"
    );
  port(
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;

    START_IN             : in  std_logic;
    BYTE_IN              : in  std_logic_vector(7 downto 0);
    SEQUENCE_DONE_OUT    : out std_logic;

    -- SPI connections
    SCLK_OUT             : out std_logic;
    SDIO_OUT             : out std_logic
    );
end entity;

architecture Behavioral of adc_spi_sendbyte is

  -- Send Byte  
  signal sclk_o            : std_logic;
  signal sdio_o            : std_logic;
  signal spi_start         : std_logic;

  signal sequence_done_o   : std_logic;
  signal spi_byte          : unsigned(7 downto 0);
  signal bit_ctr           : unsigned(3 downto 0);
  signal wait_timer_init   : unsigned(7 downto 0);

  signal sequence_done_o_x : std_logic;
  signal spi_byte_x        : unsigned(7 downto 0);
  signal bit_ctr_x         : unsigned(3 downto 0);
  signal wait_timer_init_x : unsigned(7 downto 0);
  
  type STATES is (S_IDLE,
                  S_SET_SDIO,
                  S_SET_SCLK,
                  S_NEXT_BIT,
                  S_DONE
                  );
  signal STATE, NEXT_STATE : STATES;
  
  -- Wait Timer
  signal wait_timer_done    : std_logic;

begin

  -- Timer
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


  PROC_SEND_BYTE_TRANSFER: process(CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        sequence_done_o  <= '0';
        bit_ctr          <= (others => '0');
        wait_timer_init  <= (others => '0');
        STATE            <= S_IDLE;
      else
        sequence_done_o  <= sequence_done_o_x;
        spi_byte         <= spi_byte_x;
        bit_ctr          <= bit_ctr_x;
        wait_timer_init  <= wait_timer_init_x;
        STATE            <= NEXT_STATE;
      end if;
    end if;
  end process PROC_SEND_BYTE_TRANSFER;  
  
  PROC_SEND_BYTE: process(STATE)
  begin 
    sdio_o             <= '0';
    sclk_o             <= '0';
    sequence_done_o_x  <= '0';
    spi_byte_x         <= spi_byte;
    bit_ctr_x          <= bit_ctr;       
    wait_timer_init_x  <= (others => '0');
    
    case STATE is
      when S_IDLE =>
        if (START_IN = '1') then
          spi_byte_x        <= BYTE_IN;
          bit_ctr_x         <= x"7";
          wait_timer_init_x <= SPI_SPEED srl 1;
          NEXT_STATE        <= S_SET_SDIO;
        else
          NEXT_STATE <= S_IDLE;
        end if;

      when S_SET_SDIO =>
        sdio_o <= spi_byte(7);
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_SET_SDIO;
        else
          wait_timer_init_x <= SPI_SPEED srl 1;
          NEXT_STATE <= S_SET_SCLK;
        end if;
      
      when S_SET_SCLK =>
        sdio_o <= spi_byte(7);
        sclk_o <= '1';
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_SET_SCLK;
        else
          NEXT_STATE        <= S_NEXT_BIT;
        end if;
        
      when S_NEXT_BIT =>
        sdio_o <= spi_byte(7);
        sclk_o <= '1';
        if (bit_ctr > 0) then
          bit_ctr_x          <= bit_ctr - 1;
          spi_byte_x         <= spi_byte sll 1;
          wait_timer_init_x  <= SPI_SPEED srl 1;
          NEXT_STATE         <= S_SET_SDIO;
        else
          NEXT_STATE         <= S_DONE;
        end if;

      when S_DONE =>
        sdio_o <= spi_byte(7);
        sclk_o <= '1';
        sequence_done_o_x <= '1';
        NEXT_STATE        <= S_IDLE;
        
    end case;
  end process PROC_SEND_BYTE;

  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  SEQUENCE_DONE_OUT <= sequence_done_o;
  
  -- SPI Outputs
  SDIO_OUT <= sdio_o;
  SCLK_OUT <= sclk_o;
  
end Behavioral;
