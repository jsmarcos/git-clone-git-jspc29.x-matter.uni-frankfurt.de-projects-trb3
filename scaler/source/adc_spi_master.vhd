library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.scaler_components.all;

entity adc_spi_master is
  generic (
    SPI_SPEED : unsigned(7 downto 0) := x"32"
    );
  port(
    CLK_IN                 : in    std_logic;
    RESET_IN               : in    std_logic;
                           
    -- SPI connections     
    SCLK_OUT               : out   std_logic;
    SDIO_INOUT             : inout std_logic;
    CSB_OUT                : out   std_logic;
                           
    -- Internal Interface  
    INTERNAL_COMMAND_IN    : in    std_logic_vector(31 downto 0);
    COMMAND_ACK_OUT        : out   std_logic;
    SPI_DATA_OUT           : out   std_logic_vector(31 downto 0);
    SPI_LOCK_IN            : in    std_logic;
                           
    -- Slave bus           
    SLV_READ_IN            : in    std_logic;
    SLV_WRITE_IN           : in    std_logic;
    SLV_DATA_OUT           : out   std_logic_vector(31 downto 0);
    SLV_DATA_IN            : in    std_logic_vector(31 downto 0);
    SLV_ACK_OUT            : out   std_logic;
    SLV_NO_MORE_DATA_OUT   : out   std_logic;
    SLV_UNKNOWN_ADDR_OUT   : out   std_logic;
                           
    -- Debug Line          
    DEBUG_OUT              : out   std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of adc_spi_master is

  signal sdio_i        : std_logic;
  signal sdio_x        : std_logic;
  signal sdio          : std_logic;

  signal sclk_o        : std_logic;
  signal command_ack_o : std_logic;

  -- SPI Master
  signal csb_o                 : std_logic;
  signal spi_start             : std_logic;

  signal spi_busy              : std_logic;
  signal takeover_sdio         : std_logic;
  signal wait_timer_start      : std_logic;
  signal sendbyte_seq_start    : std_logic;
  signal readbyte_seq_start    : std_logic;
  signal sendbyte_byte         : std_logic_vector(7 downto 0);
  signal read_seq_ctr          : std_logic;
  signal reg_data              : std_logic_vector(31 downto 0);

  signal spi_busy_x            : std_logic;
  signal wait_timer_start_x    : std_logic;
  signal sendbyte_seq_start_x  : std_logic;
  signal sendbyte_byte_x       : std_logic_vector(7 downto 0);
  signal readbyte_seq_start_x  : std_logic;
  signal read_seq_ctr_x        : std_logic;
  signal reg_data_x            : std_logic_vector(31 downto 0);
  
  signal sdio_sendbyte         : std_logic;
  signal sclk_sendbyte         : std_logic;
  signal sendbyte_done         : std_logic;
  
  signal sclk_readbyte         : std_logic;
  signal readbyte_byte         : std_logic_vector(7 downto 0);
  signal readbyte_done         : std_logic;
  
  type STATES is (S_RESET,
                  S_IDLE,
                  S_START,
                  S_START_WAIT,
                  
                  S_SEND_CMD_A,
                  S_SEND_CMD_A_WAIT,
                  S_SEND_CMD_B,
                  S_SEND_CMD_B_WAIT,

                  S_SEND_DATA,
                  S_SEND_DATA_WAIT,
                  S_GET_DATA,
                  S_GET_DATA_WAIT,

                  S_STOP,
                  S_STOP_WAIT
                  );
  signal STATE, NEXT_STATE : STATES;
  
  -- SPI Timer
  signal wait_timer_done         : std_logic;
                                 
  -- TRBNet Slave Bus            
  signal slv_data_out_o          : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o      : std_logic;
  signal slv_unknown_addr_o      : std_logic;
  signal slv_ack_o               : std_logic;
  signal spi_chipid              : std_logic_vector(6 downto 0);
  signal spi_rw_bit              : std_logic;
  signal spi_registerid          : std_logic_vector(12 downto 0);
  signal spi_register_data       : std_logic_vector(7 downto 0);
  signal spi_register_value_read : std_logic_vector(7 downto 0);

begin
  -----------------------------------------------------------------------------
  -- Debug Line
  -----------------------------------------------------------------------------
  DEBUG_OUT(0)            <= CLK_IN;
  DEBUG_OUT(1)            <= sclk_o;
  DEBUG_OUT(2)            <= SDIO_INOUT;
  DEBUG_OUT(3)            <= csb_o;
  DEBUG_OUT(4)            <= spi_busy;
  DEBUG_OUT(5)            <= wait_timer_done;
  DEBUG_OUT(6)            <= sendbyte_seq_start;
  DEBUG_OUT(7)            <= sendbyte_done;
  DEBUG_OUT(8)            <= sclk_sendbyte;
  DEBUG_OUT(9)            <= sdio_sendbyte;
  DEBUG_OUT(10)           <= sclk_readbyte;
  DEBUG_OUT(11)           <= takeover_sdio;
  DEBUG_OUT(15 downto 12) <= (others => '0');

  -----------------------------------------------------------------------------
  
  -- Timer
  timer_static_1: timer_static
    generic map (
      CTR_WIDTH => 8,
      CTR_END   => to_integer(SPI_SPEED srl 2)
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => RESET_IN,
      TIMER_START_IN => wait_timer_start,
      TIMER_DONE_OUT => wait_timer_done
      );
  
  adc_spi_sendbyte_1: adc_spi_sendbyte
    generic map (
      SPI_SPEED => SPI_SPEED
      )
    port map (
      CLK_IN             => CLK_IN,
      RESET_IN           => RESET_IN,
      START_IN           => sendbyte_seq_start,
      BYTE_IN            => sendbyte_byte,
      SEQUENCE_DONE_OUT  => sendbyte_done,
      SDIO_OUT           => sdio_sendbyte,
      SCLK_OUT           => sclk_sendbyte
      );

  adc_spi_readbyte_1: adc_spi_readbyte
    generic map (
      SPI_SPEED => SPI_SPEED
      )
    port map (
      CLK_IN            => CLK_IN,
      RESET_IN          => RESET_IN,
      START_IN          => readbyte_seq_start,
      BYTE_OUT          => readbyte_byte,
      SEQUENCE_DONE_OUT => readbyte_done,
      SDIO_IN           => sdio,
      SCLK_OUT          => sclk_readbyte
      );
  
  -- Sync SPI SDIO Line
  sdio_i <= SDIO_INOUT;

  PROC_I2C_LINES_SYNC: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        sdio_x <= '1';
        sdio   <= '1';
      else
        sdio_x <= sdio_i;
        sdio   <= sdio_x;
      end if;
    end if;
  end process PROC_I2C_LINES_SYNC;

  PROC_I2C_MASTER_TRANSFER: process(CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        spi_busy              <= '1';
        sendbyte_seq_start    <= '0';
        readbyte_seq_start    <= '0';
        sendbyte_byte         <= (others => '0');
        wait_timer_start      <= '0';
        reg_data              <= (others => '0');
        read_seq_ctr          <= '0';
        STATE                 <= S_RESET;
      else
        spi_busy              <= spi_busy_x;
        sendbyte_seq_start    <= sendbyte_seq_start_x;
        readbyte_seq_start    <= readbyte_seq_start_x;
        sendbyte_byte         <= sendbyte_byte_x;
        wait_timer_start      <= wait_timer_start_x;
        reg_data              <= reg_data_x;
        read_seq_ctr          <= read_seq_ctr_x;
        STATE                 <= NEXT_STATE;
      end if;
    end if;
  end process PROC_I2C_MASTER_TRANSFER;
  
        
  PROC_I2C_MASTER: process(STATE,
                           spi_start,
                           wait_timer_done,
                           sendbyte_done,
                           readbyte_done
                           )

  begin
    -- Defaults
    takeover_sdio           <= '0';
    sclk_o                  <= '0';
    csb_o                   <= '0';
    spi_busy_x              <= '1';
    sendbyte_seq_start_x    <= '0';
    sendbyte_byte_x         <= (others => '0');
    readbyte_seq_start_x    <= '0';
    wait_timer_start_x      <= '0';
    reg_data_x              <= reg_data;
    read_seq_ctr_x          <= read_seq_ctr;
    
    case STATE is

      when S_RESET =>
        reg_data_x <= (others => '0');
        NEXT_STATE <= S_IDLE;
        
      when S_IDLE =>
        csb_o        <= '1';
        if (spi_start = '1') then
          reg_data_x <= x"8000_0000";  -- Set Running , clear all other bits 
          NEXT_STATE <= S_START;
        else
          spi_busy_x     <= '0';
          reg_data_x     <= reg_data and x"7fff_ffff";  -- clear running bit;
          read_seq_ctr_x <= '0';
          NEXT_STATE     <= S_IDLE;
        end if;
            
        -- SPI START Sequence 
      when S_START =>
        wait_timer_start_x <= '1';
        NEXT_STATE         <= S_START_WAIT;
        
      when S_START_WAIT =>
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_START_WAIT;
        else
          takeover_sdio <= '1';
          NEXT_STATE    <= S_SEND_CMD_A;
        end if;
                   
        -- I2C SEND CMD Part1
      when S_SEND_CMD_A =>
        takeover_sdio               <= '1';
        sendbyte_byte_x(7)          <= spi_rw_bit;
        sendbyte_byte_x(6 downto 5) <= "00";
        sendbyte_byte_x(4 downto 0) <= spi_registerid(12 downto 8);
        sendbyte_seq_start_x        <= '1';
        NEXT_STATE                  <= S_SEND_CMD_A_WAIT;
        
      when S_SEND_CMD_A_WAIT =>
        takeover_sdio <= '1';
        if (sendbyte_done = '0') then
          NEXT_STATE <= S_SEND_CMD_A_WAIT;
        else
          NEXT_STATE <= S_SEND_CMD_B;
        end if;
        
        -- I2C SEND CMD Part1
      when S_SEND_CMD_B =>
        takeover_sdio               <= '1';
        sendbyte_byte_x(7 downto 0) <= spi_registerid(7 downto 0);
        sendbyte_seq_start_x        <= '1';
        NEXT_STATE                  <= S_SEND_CMD_B_WAIT;
        
      when S_SEND_CMD_B_WAIT =>
        takeover_sdio <= '1';
        if (sendbyte_done = '0') then
          NEXT_STATE <= S_SEND_CMD_B_WAIT;
        else
          if (spi_rw_bit = '1') then
            NEXT_STATE        <= S_GET_DATA;
          else
            NEXT_STATE        <= S_SEND_DATA;
          end if;
        end if;

        -- I2C SEND DataWord
      when S_SEND_DATA =>
        takeover_sdio          <= '1';
        sendbyte_byte_x        <= spi_register_data;
        sendbyte_seq_start_x   <= '1';
        NEXT_STATE             <= S_SEND_DATA_WAIT;
        
      when S_SEND_DATA_WAIT =>
        takeover_sdio <= '1';
        if (sendbyte_done = '0') then
          NEXT_STATE <= S_SEND_DATA_WAIT;
        else
          NEXT_STATE <= S_STOP;
        end if;

        -- I2C GET DataWord
      when S_GET_DATA =>
        readbyte_seq_start_x   <= '1';
        NEXT_STATE             <= S_GET_DATA_WAIT;
        
      when S_GET_DATA_WAIT =>
        if (readbyte_done = '0') then
          NEXT_STATE <= S_GET_DATA_WAIT;
        else
          reg_data_x(7 downto 0) <= readbyte_byte; 
          NEXT_STATE             <= S_STOP;
        end if;
        
        -- SPI STOP Sequence 
      when S_STOP =>
        wait_timer_start_x    <= '1';
        NEXT_STATE            <= S_STOP_WAIT;
        
      when S_STOP_WAIT =>
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_STOP_WAIT;
        else
          reg_data_x <= reg_data or x"4000_0000"; -- Set DONE Bit
          NEXT_STATE <= S_IDLE;
        end if;
        
    end case;
  end process PROC_I2C_MASTER;

  -----------------------------------------------------------------------------
  -- TRBNet Slave Bus
  -----------------------------------------------------------------------------
  --
  --   Write bit definition
  --   ====================
  -- 
  --   D[31]    SPI_GO          0 => don't do anything on SPI,
  --                            1 => start SPI access
  --   D[30]    SPI_ACTION      0 => write byte, 1 => read byte
  --   D[20:8]  SPI_CMD         SPI Register Id
  --   D[7:0]   SPI_DATA        data to be written
  --   
  --   Read bit definition
  --   ===================
  --   
  --   D[31]    RUNNING         whatever
  --   D[30]    SPI_DONE        whatever
  --   D[29:21] reserved        reserved
  --   D[20:16] debug           subject to change, don't use
  --   D[15:8]  reserved        reserved
  --   D[7:0]   SPI_DATA        result of SPI read operation
  --
  
  PROC_SLAVE_BUS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o     <= (others => '0');
        slv_no_more_data_o <= '0';
        slv_unknown_addr_o <= '0';
        slv_ack_o          <= '0';
        spi_start          <= '0';
        command_ack_o      <= '0';
        
        spi_chipid              <= (others => '0');    
        spi_rw_bit              <= '0';    
        spi_registerid          <= (others => '0');    
        spi_register_data       <= (others => '0');    
        spi_register_value_read <= (others => '0');
            
      else
        slv_data_out_o     <= (others => '0');
        slv_unknown_addr_o <= '0';
        slv_no_more_data_o <= '0';

        spi_start          <= '0';
        command_ack_o      <= '0';

        --if (spi_busy = '0' and INTERNAL_COMMAND_IN(31) = '1') then
        --  spi_rw_bit         <= INTERNAL_COMMAND_IN(30);
        --  spi_registerid     <= INTERNAL_COMMAND_IN(20 downto 8);
        --  spi_register_data  <= INTERNAL_COMMAND_IN(7 downto 0); 
        --  spi_start          <= '1';
        --  command_ack_o      <= '1';
        --  slv_ack_o          <= '1';
        --
        --elsif (SLV_WRITE_IN  = '1') then
        if (SLV_WRITE_IN  = '1') then
          if (spi_busy = '0' and SLV_DATA_IN(31) = '1') then
            spi_rw_bit        <= SLV_DATA_IN(30);
            spi_registerid    <= SLV_DATA_IN(20 downto 8);
            spi_register_data <= SLV_DATA_IN(7 downto 0); 
            spi_start         <= '1';
            slv_ack_o         <= '1';
          else
            slv_ack_o         <= '1';
          end if;
          
        elsif (SLV_READ_IN = '1') then
          if (spi_busy = '1') then
            slv_no_more_data_o <= '1';
            slv_ack_o          <= '0';
          else
            slv_data_out_o     <= reg_data;
            slv_ack_o          <= '1';
          end if;

        else
          slv_ack_o            <= '0';
        end if;
        
      end if;
    end if;           
  end process PROC_SLAVE_BUS;


  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------
  
  -- SPI Outputs
  SDIO_INOUT      <= sdio_sendbyte when (takeover_sdio = '1')
                     else 'Z';
  
  SCLK_OUT        <= sclk_o or
                     sclk_sendbyte or
                     sclk_readbyte;

  CSB_OUT         <= csb_o;
  COMMAND_ACK_OUT <= command_ack_o;
    
  -- Slave Bus
  SLV_DATA_OUT         <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT <= slv_unknown_addr_o;
  SLV_ACK_OUT          <= slv_ack_o; 

end Behavioral;
