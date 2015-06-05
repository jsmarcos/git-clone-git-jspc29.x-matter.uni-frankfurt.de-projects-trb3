library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.scaler_components.all;

entity nx_register_setup is
  port(
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;

    I2C_ONLINE_IN        : in  std_logic;
    I2C_COMMAND_OUT      : out std_logic_vector(31 downto 0);
    I2C_COMMAND_BUSY_IN  : in  std_logic;
    I2C_DATA_IN          : in  std_logic_vector(31 downto 0);
    I2C_DATA_BYTES_IN    : in  std_logic_vector(31 downto 0);
    I2C_LOCK_OUT         : out std_logic;
    I2C_REG_RESET_IN     : in  std_logic;
    
    SPI_COMMAND_OUT      : out std_logic_vector(31 downto 0);
    SPI_COMMAND_BUSY_IN  : in  std_logic;
    SPI_DATA_IN          : in  std_logic_vector(31 downto 0);
    SPI_LOCK_OUT         : out std_logic;

    -- Internal Register Read
    INT_READ_IN          : in  std_logic;
    INT_ADDR_IN          : in  std_logic_vector(15 downto 0);
    INT_ACK_OUT          : out std_logic;
    INT_DATA_OUT         : out std_logic_vector(31 downto 0);
    NX_CLOCK_ON_OUT      : out std_logic;
    
    -- Slave bus         
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;
    
    -- Debug Line
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_register_setup is

  -- I2C Command Multiplexer
  signal i2c_lock_0      : std_logic;
  signal i2c_lock_1      : std_logic;
  signal i2c_lock_2      : std_logic;
  signal i2c_lock_3      : std_logic;
  signal i2c_command     : std_logic_vector(31 downto 0);
  
  -- Send I2C Command
  type I2C_STATES is (I2C_IDLE,
                      I2C_WAIT_BUSY_HIGH,
                      I2C_WAIT_BUSY_LOW
                      );

  signal I2C_STATE : I2C_STATES;
  
  signal i2c_command_o           : std_logic_vector(31 downto 0);
  signal i2c_command_busy_o      : std_logic;
  signal i2c_command_done        : std_logic;
  signal i2c_error               : std_logic;
  signal i2c_data                : std_logic_vector(31 downto 0);
  signal i2c_data_bytes          : std_logic_vector(31 downto 0);
  
  -- I2C Register Ram
  type i2c_ram_t is array(0 to 45) of std_logic_vector(7 downto 0);
  signal i2c_ram                 : i2c_ram_t;
  
  type register_access_type_t is array(0 to 45) of std_logic_vector(1 downto 0);
  constant register_access_type : register_access_type_t :=
    ("11", "11", "11", "11", "11", "11", "11", "11",   --  0 ->  7
     "11", "11", "11", "11", "11", "11", "11", "11",   --  8 -> 15
     "11", "11", "11", "11", "11", "11", "11", "11",   -- 16 -> 23
     "11", "11", "11", "11", "11", "11", "00", "00",   -- 24 -> 31 
     "11", "11", "10", "10", "10", "10", "11", "11",   -- 32 -> 39
     "00", "00", "00", "11", "11", "11"                -- 40 -> 45
     );

  -- I2C RAM Handler
  signal ram_index_0             : integer;
  signal ram_index_1             : integer;
  signal ram_data_0              : std_logic_vector(7 downto 0);
  signal ram_data_1              : std_logic_vector(7 downto 0);
  signal ram_write_0             : std_logic;
  signal ram_write_1             : std_logic;
  signal do_write                : std_logic;

  -- DAC Trim FIFO RAM Handler
  type dac_ram_t is array(0 to 128) of std_logic_vector(5 downto 0);
  signal dac_ram                 : dac_ram_t;
  signal dac_ram_write_0         : std_logic;
  signal dac_ram_write_1         : std_logic;
  signal dac_ram_index_0         : integer;
  signal dac_ram_index_1         : integer;
  signal dac_ram_data_0          : std_logic_vector(5 downto 0);
  signal dac_ram_data_1          : std_logic_vector(5 downto 0);
  signal do_dac_write            : std_logic;

  -- ADC RAM Handler
  type adc_ram_t is array(0 to 3) of std_logic_vector(12 downto 0);
  signal adc_ram                 : adc_ram_t;
  
  -- Token Handler
  signal i2c_read_token          : std_logic_vector(45 downto 0);
  signal i2c_write_token         : std_logic_vector(45 downto 0);
  
  -- I2C Registers IO Handler
  type T_STATES is (T_IDLE_TOKEN,
                    T_WRITE_I2C_REGISTER,
                    T_WAIT_I2C_WRITE_DONE,
                    T_READ_I2C_REGISTER,
                    T_WAIT_I2C_READ_DONE,
                    T_READ_I2C_STORE_MEM,
                    T_NEXT_TOKEN
                    );

  signal T_STATE  : T_STATES;

  
  signal nx_i2c_command          : std_logic_vector(31 downto 0);
  signal token_ctr               : unsigned(5 downto 0);
  signal next_token              : std_logic;
  signal read_token_clear        : std_logic_vector(45 downto 0);
  signal write_token_clear       : std_logic_vector(45 downto 0);
  signal i2c_lock_0_clear        : std_logic;
  
  -- DAC Token Handler
  signal dac_read_token          : std_logic_vector(128 downto 0);
  signal dac_write_token         : std_logic_vector(128 downto 0);

  -- Read DAC I2C Registers
  type DR_STATES is (DR_IDLE,
                     DR_REGISTER,
                     DR_WRITE_BACK,
                     DR_NEXT_REGISTER,
                     DR_WAIT_DONE
                    );
  
  signal DR_STATE, DR_STATE_RETURN : DR_STATES;
  
  signal dac_read_i2c_command    : std_logic_vector(31 downto 0);
  signal r_fifo_ctr              : unsigned(7 downto 0);
  signal dac_read_token_clear    : std_logic_vector(128 downto 0);
  signal next_token_dac_r        : std_logic;
  signal i2c_lock_1_clear        : std_logic;

  -- Write DAC I2C Registers
  type DW_STATES is (DW_IDLE,
                     DW_REGISTER,
                     DW_WRITE_BACK,
                     DW_NEXT_REGISTER,
                     DW_WAIT_DONE
                     );
  signal DW_STATE, DW_STATE_RETURN : DW_STATES;

  signal dac_write_i2c_command   : std_logic_vector(31 downto 0);
  signal w_fifo_ctr              : unsigned(7 downto 0);
  signal dac_write_token_clear   : std_logic_vector(128 downto 0);
  signal next_token_dac_w        : std_logic;
  signal i2c_lock_2_clear        : std_logic;

  -- ADC Token Handler
  signal adc_read_token          : std_logic_vector(3 downto 0);

  -- Read ADC Registers
  type ADC_STATES is (ADC_IDLE_TOKEN,
                      ADC_READ_I2C_REGISTER,
                      ADC_WAIT_I2C_READ_DONE,
                      ADC_READ_I2C_STORE_MEM,
                      ADC_NEXT_TOKEN
                    );
  
  signal ADC_STATE : ADC_STATES;
  
  signal adc_i2c_command         : std_logic_vector(31 downto 0);
  signal adc_token_ctr           : unsigned(1 downto 0);
  signal adc_read_token_clear    : std_logic_vector(3 downto 0);
  signal next_token_adc          : std_logic;
  signal i2c_lock_3_clear        : std_logic;
  
  -- I2C Online Check
  type R_STATES is (R_TIMER_RESTART,
                    R_IDLE,
                    R_READ_DUMMY,
                    R_WAIT_DONE
                    );
  
  signal R_STATE : R_STATES;

  signal wait_timer_start        : std_logic;
  signal wait_timer_done         : std_logic;

  -- I2C Status
  signal i2c_online_t            : std_logic_vector(7 downto 0);
  signal i2c_update_memory_p     : std_logic;
  signal i2c_update_memory       : std_logic;
  signal i2c_disable_memory      : std_logic;
  signal i2c_reg_reset_in_s      : std_logic;
  signal i2c_reg_reset_clear     : std_logic;

  -- Internal Register Read
  signal int_data_o              : std_logic_vector(31 downto 0);
  signal int_ack_o               : std_logic;

  -- Status
  signal nx_clock_on_o           : std_logic;
  
  -- TRBNet Slave Bus
  signal slv_data_out_o          : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o      : std_logic;
  signal slv_unknown_addr_o      : std_logic;
  signal slv_ack_o               : std_logic;

  signal i2c_read_token_r        : std_logic_vector(45 downto 0);
  signal i2c_write_token_r       : std_logic_vector(45 downto 0);

  signal dac_read_token_r        : std_logic_vector(128 downto 0);
  signal dac_write_token_r       : std_logic_vector(128 downto 0);

  signal adc_read_token_r        : std_logic_vector(3 downto 0);
  
  signal nxyter_polarity         : std_logic_vector(1 downto 0);  -- 0: negative
  signal nxyter_testpulse        : std_logic_vector(1 downto 0);
  signal nxyter_testtrigger      : std_logic_vector(1 downto 0);
  signal nxyter_clock            : std_logic_vector(1 downto 0);
  signal nxyter_testchannels     : std_logic_vector(2 downto 0); 
  signal i2c_update_memory_r     : std_logic;

begin

  -----------------------------------------------------------------------------
  -- DEBUG
  -----------------------------------------------------------------------------

  DEBUG_OUT(0)            <= CLK_IN;
  DEBUG_OUT(1)            <= I2C_COMMAND_BUSY_IN;
  DEBUG_OUT(2)            <= i2c_command_busy_o;
  DEBUG_OUT(3)            <= i2c_disable_memory; --i2c_error;
  DEBUG_OUT(4)            <= i2c_command_done;
  DEBUG_OUT(5)            <= next_token_dac_r or
                             next_token_dac_w;
  DEBUG_OUT(6)            <= i2c_update_memory_r;
  DEBUG_OUT(7)            <= i2c_lock_0_clear;
  DEBUG_OUT(8)            <= i2c_lock_1_clear;
  DEBUG_OUT(9)            <= i2c_lock_2_clear;
  DEBUG_OUT(10)           <= i2c_lock_3_clear;
  DEBUG_OUT(11)           <= i2c_command(31);
  DEBUG_OUT(12)           <= i2c_lock_0;
  DEBUG_OUT(13)           <= i2c_lock_1;
  DEBUG_OUT(14)           <= i2c_lock_2;
  DEBUG_OUT(15)           <= i2c_lock_3;

  -----------------------------------------------------------------------------

  PROC_I2C_RAM: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        i2c_write_token_r   <= (others => '0');
        do_write            <= '0';
      else
        i2c_write_token_r   <= (others => '0');
        do_write            <= '0';
        
        if (ram_write_0 = '1' and
            register_access_type(ram_index_0)(0) = '1') then
          i2c_ram(ram_index_0)           <= ram_data_0;
          i2c_write_token_r(ram_index_0) <= '1';
          do_write                       <= '1';
        elsif (ram_write_1 = '1'                       and
               register_access_type(ram_index_1)(0) = '1' and
               i2c_write_token(ram_index_1) = '0') then
          i2c_ram(ram_index_1)           <= ram_data_1;
          do_write                       <= '1';
        elsif (nxyter_polarity(1) = '1') then
          i2c_ram(33)(2)                 <= nxyter_polarity(0);
          i2c_ram(32)(2)                 <= not nxyter_polarity(0);
          i2c_write_token_r(33)          <= '1';
          i2c_write_token_r(32)          <= '1';
          do_write                       <= '1';
        elsif (nxyter_clock(1) = '1') then
          i2c_ram(33)(3)                 <= nxyter_clock(0);  
          i2c_write_token_r(33)          <= '1';
          do_write                       <= '1';
        elsif (nxyter_testtrigger(1) = '1') then
          i2c_ram(32)(3)                 <= nxyter_testtrigger(0);  
          i2c_write_token_r(32)          <= '1';
          do_write                       <= '1';
        elsif (nxyter_testpulse(1) = '1') then
          i2c_ram(32)(0)                 <= nxyter_testpulse(0);  
          i2c_write_token_r(32)          <= '1';
          do_write                       <= '1';
        elsif (nxyter_testchannels(2) = '1') then
          i2c_ram(33)(1 downto 0)        <= nxyter_testchannels(1 downto 0);
          i2c_write_token_r(33)          <= '1';
          do_write                       <= '1';
        end if;
      end if;
    end if;
  end process PROC_I2C_RAM;

  PROC_DAC_RAM: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        dac_write_token_r   <= (others => '0');
        do_dac_write        <= '0';
      else
        dac_write_token_r   <= (others => '0');
        do_dac_write        <= '0';
        
        if (dac_ram_write_0 = '1') then
          dac_ram(dac_ram_index_0)           <= dac_ram_data_0;
          dac_write_token_r(dac_ram_index_0) <= '1';
          do_dac_write                       <= '1';
        elsif (dac_ram_write_1 = '1' and
               dac_write_token(dac_ram_index_1) = '0') then
          dac_ram(dac_ram_index_1)           <= dac_ram_data_1;
          do_dac_write                       <= '1';
        end if;
      end if;
    end if;
  end process PROC_DAC_RAM;

  -----------------------------------------------------------------------------

  PROC_I2C_COMMAND_MULTIPLEXER: process(CLK_IN)
    variable locks : std_logic_vector(3 downto 0) := (others => '0');
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        i2c_lock_0       <= '0';
        i2c_lock_1       <= '0';
        i2c_lock_2       <= '0';
        i2c_lock_3       <= '0';
        i2c_command      <= (others => '0');
      else
        i2c_command      <= (others => '0');
        locks            := i2c_lock_3 & i2c_lock_2 &
                            i2c_lock_1 & i2c_lock_0;
        
        -- Clear Locks
        if (i2c_lock_0_clear = '1') then
          i2c_lock_0          <= '0';
        end if;
        if (i2c_lock_1_clear = '1') then
          i2c_lock_1          <= '0';
        end if;
        if (i2c_lock_2_clear = '1') then
          i2c_lock_2          <= '0';
        end if;
        if (i2c_lock_3_clear = '1') then
          i2c_lock_3          <= '0';
        end if;

        if (i2c_command_busy_o = '0') then
          if (nx_i2c_command(31)   = '1'     and
              ((locks and "1110")  = "0000") and
              i2c_lock_0_clear     = '0') then
            i2c_command       <= nx_i2c_command;
            i2c_lock_0        <= '1';
          elsif (dac_write_i2c_command(31) = '1'     and
                 ((locks and "1011")       = "0000") and
                 i2c_lock_2_clear          = '0') then
            i2c_command       <= dac_write_i2c_command;
            i2c_lock_2        <= '1';
          elsif (dac_read_i2c_command(31) = '1'     and
                 ((locks and "1101")      = "0000") and
                 i2c_lock_1_clear         = '0') then
            i2c_command       <= dac_read_i2c_command;
            i2c_lock_1        <= '1';
          elsif (adc_i2c_command(31)  = '1'     and
                 ((locks and "0111")  = "0000") and
                 i2c_lock_3_clear     = '0') then
            i2c_command       <= adc_i2c_command;
            i2c_lock_3        <= '1';
          end if;
        end if;
      end if;
    end if;
  end process PROC_I2C_COMMAND_MULTIPLEXER;

  PROC_SEND_I2C_COMMAND: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        i2c_command_o       <= (others => '0');
        i2c_command_busy_o  <= '0';
        i2c_command_done    <= '0';
        i2c_error           <= '0';
        i2c_data            <= (others => '0');
        i2c_data_bytes      <= (others => '0');
        I2C_STATE           <= I2C_IDLE;
      else
        i2c_command_o       <= (others => '0');
        i2c_command_busy_o  <= '1';
        i2c_command_done    <= '0';
        i2c_error           <= '0';
        
        case I2C_STATE is

          when I2C_IDLE =>
            if (i2c_command(31) = '1') then
              i2c_command_o       <= i2c_command;
              I2C_STATE           <= I2C_WAIT_BUSY_HIGH;
            else
              i2c_command_busy_o  <= '0';
              I2C_STATE           <= I2C_IDLE;
            end if;

          when I2C_WAIT_BUSY_HIGH =>
            if (I2C_COMMAND_BUSY_IN = '0') then
              i2c_command_o       <= i2c_command_o;
              I2C_STATE           <= I2C_WAIT_BUSY_HIGH;
            else
              I2C_STATE           <= I2C_WAIT_BUSY_LOW;
            end if;

          when I2C_WAIT_BUSY_LOW =>
            if (I2C_COMMAND_BUSY_IN = '1') then
              I2C_STATE           <= I2C_WAIT_BUSY_LOW;
            else
              if (i2c_data(29 downto 24) ="000000") then
                i2c_error         <= '0';
              else
                i2c_error         <= '1';
              end if;
              i2c_data            <= I2C_DATA_IN;
              i2c_data_bytes      <= I2C_DATA_BYTES_IN;
              i2c_command_done    <= '1';
              I2C_STATE           <= I2C_IDLE;
            end if;
        end case;
        
      end if;
    end if;
  end process PROC_SEND_I2C_COMMAND;

  -----------------------------------------------------------------------------
  
  PROC_I2C_TOKEN_HANDLER: process(CLK_IN)
    variable read_token_mask : std_logic_vector(45 downto 0) := (others => '1');
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        i2c_read_token      <= (others => '0');
        i2c_write_token     <= (others => '0');
      else
        if (i2c_ram(32)(3) = '1') then
          read_token_mask(15 downto 0)  := (others => '0');
          read_token_mask(45 downto 16) := (others => '1');
        else
          read_token_mask               := (others => '1');
        end if;
        
        -- Write Token
        if (unsigned(i2c_write_token_r)    /= 0) then
          i2c_write_token   <= i2c_write_token or i2c_write_token_r;
        elsif (unsigned(write_token_clear) /= 0) then
          i2c_write_token   <= i2c_write_token and (not write_token_clear); 
        end if;

        -- Read Token
        if (i2c_update_memory = '1') then
          i2c_read_token    <= read_token_mask;
        elsif (unsigned(i2c_read_token_r) /= 0) then
          i2c_read_token    <= (i2c_read_token or i2c_read_token_r) and
                               read_token_mask;
        elsif (unsigned(read_token_clear) /= 0) then
          i2c_read_token    <= i2c_read_token and (not read_token_clear); 
        end if;
      end if;
    end if;
  end process PROC_I2C_TOKEN_HANDLER;

  PROC_DAC_TOKEN_HANDLER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        dac_read_token     <= (others => '0');
        dac_write_token    <= (others => '0');
      else
        -- Write Token
        if (unsigned(dac_write_token_r) /= 0) then
          dac_write_token   <= dac_write_token or dac_write_token_r;
        elsif (unsigned(dac_write_token_clear) /= 0) then
          dac_write_token   <= dac_write_token and (not dac_write_token_clear); 
        end if;

        -- Read Token
        if (i2c_update_memory = '1') then
          dac_read_token    <= (others => '1');
        elsif (unsigned(dac_read_token_r) /= 0) then
          dac_read_token    <= dac_read_token or dac_read_token_r;
        elsif (unsigned(dac_read_token_clear) /= 0) then
          dac_read_token    <= dac_read_token and (not dac_read_token_clear); 
        end if;
      end if;
    end if;
  end process PROC_DAC_TOKEN_HANDLER;


  PROC_ADC_TOKEN_HANDLER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        adc_read_token      <= (others => '0');
      else
        -- Read Token
        if (i2c_update_memory = '1') then
          adc_read_token    <= (others => '1');
        elsif (unsigned(adc_read_token_r) /= 0) then
          adc_read_token    <= (adc_read_token or adc_read_token_r);
        elsif (unsigned(adc_read_token_clear) /= 0) then
          adc_read_token    <= adc_read_token and (not adc_read_token_clear); 
        end if;
      end if;
    end if;
  end process PROC_ADC_TOKEN_HANDLER;
    
  -----------------------------------------------------------------------------
  
  PROC_I2C_REGISTERS_HANDLER: process(CLK_IN)
    variable index  : integer := 0;
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        nx_i2c_command           <= (others => '0');
        token_ctr                <= (others => '0');
        next_token               <= '0';
        read_token_clear         <= (others => '0');
        write_token_clear        <= (others => '0');
        ram_write_1              <= '0';
        i2c_lock_0_clear         <= '0';
        T_STATE                  <= T_IDLE_TOKEN;
      else
        index                    :=  to_integer(unsigned(token_ctr));
        nx_i2c_command           <= (others => '0');
        next_token               <= '0';
        read_token_clear         <= (others => '0');
        write_token_clear        <= (others => '0');
        ram_write_1              <= '0';
        i2c_lock_0_clear         <= '0';

        case T_STATE is
          
          when T_IDLE_TOKEN =>
            if (register_access_type(index)(0) = '1') then
              if (i2c_write_token(index) = '1') then 
                T_STATE                          <= T_WRITE_I2C_REGISTER;
              elsif (i2c_read_token(index) = '1') then
                T_STATE                          <= T_READ_I2C_REGISTER;
              else
                T_STATE                          <= T_NEXT_TOKEN;
              end if;
            else
              read_token_clear(index)            <= '1';
              write_token_clear(index)           <= '1';
              T_STATE                            <= T_NEXT_TOKEN;
            end if;

            -- Write I2C Register
          when T_WRITE_I2C_REGISTER =>
            nx_i2c_command(31 downto 16)         <= x"8008";
            nx_i2c_command(15 downto 14)         <= (others => '0');
            nx_i2c_command(13 downto  8)         <= token_ctr;
            nx_i2c_command( 7 downto  0)         <= i2c_ram(index);
            if (i2c_lock_0 = '0') then
              T_STATE                            <= T_WRITE_I2C_REGISTER;
            else
              write_token_clear(index)           <= '1';
              T_STATE                            <= T_WAIT_I2C_WRITE_DONE;
            end if;

          when T_WAIT_I2C_WRITE_DONE =>
            if (i2c_command_done = '0') then
              T_STATE                            <= T_WAIT_I2C_WRITE_DONE;
            else
              i2c_lock_0_clear                   <= '1';
              T_STATE                            <= T_NEXT_TOKEN;
            end if;

            -- Read I2C Register
          when T_READ_I2C_REGISTER =>
            nx_i2c_command(31 downto 16)         <= x"c108";
            nx_i2c_command(15 downto 14)         <= (others => '0');
            nx_i2c_command(13 downto  8)         <= token_ctr;
            nx_i2c_command( 7 downto  0)         <= (others => '0');
            if (i2c_lock_0 = '0') then
              T_STATE                            <= T_READ_I2C_REGISTER;
            else
              read_token_clear(index)            <= '1';
              T_STATE                            <= T_WAIT_I2C_READ_DONE;
            end if;

          when T_WAIT_I2C_READ_DONE =>
            if (i2c_command_done = '0') then
              T_STATE                            <= T_WAIT_I2C_READ_DONE;
            else
              T_STATE                            <= T_READ_I2C_STORE_MEM;
            end if;

          when T_READ_I2C_STORE_MEM =>
            ram_index_1                          <= index;
            ram_data_1                           <= i2c_data(7 downto 0);
            ram_write_1                          <= '1';
            i2c_lock_0_clear                     <= '1';
            T_STATE                              <= T_NEXT_TOKEN;
            
            -- Next Token
          when T_NEXT_TOKEN =>
            if (token_ctr < x"2e") then
              token_ctr                          <= token_ctr + 1;
            else
              token_ctr                          <= (others => '0');
            end if;
            next_token                           <= '1';
            T_STATE                              <= T_IDLE_TOKEN;
            
        end case;
      end if;
    end if;
  end process PROC_I2C_REGISTERS_HANDLER;

  -----------------------------------------------------------------------------

  PROC_READ_DAC_REGISTERS: process(CLK_IN)
    variable index : integer := 0;
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        dac_read_i2c_command   <= (others => '0');
        dac_ram_write_1        <= '0';
        dac_ram_index_1        <= 0;
        dac_ram_data_1         <= (others => '0');
        r_fifo_ctr             <= (others => '0');
        dac_read_token_clear   <= (others => '0');
        next_token_dac_r       <= '0';
        i2c_lock_1_clear       <= '0';
        DR_STATE_RETURN        <= DR_IDLE;
        DR_STATE               <= DR_IDLE;
      else
        dac_read_i2c_command   <= (others => '0');
        dac_ram_write_1        <= '0';
        dac_ram_index_1        <= 0;
        dac_ram_data_1         <= (others => '0');
        dac_read_token_clear   <= (others => '0');
        next_token_dac_r       <= '0';
        i2c_lock_1_clear       <= '0';
        index                  := to_integer(r_fifo_ctr);
        
        case DR_STATE is
          when DR_IDLE =>
            if (unsigned(dac_read_token) /= 0) then
              DR_STATE                           <= DR_REGISTER;
            else
              DR_STATE                           <= DR_IDLE;
            end if;
            r_fifo_ctr                           <= (others => '0');

          when DR_REGISTER =>
            dac_read_i2c_command(31 downto 16)   <= x"c108";
            dac_read_i2c_command(15 downto 8)    <= x"2a";  -- DAC Reg 42
            dac_read_i2c_command(7 downto 0)     <= (others => '0');
            if (i2c_lock_1 = '0') then
              DR_STATE                            <= DR_REGISTER;
            else
              dac_read_token_clear(index)         <= '1';
              DR_STATE_RETURN                     <= DR_WRITE_BACK;
              DR_STATE                            <= DR_WAIT_DONE;
            end if;
            
          when DR_WRITE_BACK =>
            -- Store FIFO Entry
            dac_ram_data_1                        <= i2c_data(5 downto 0);
            dac_ram_index_1                       <= index;
            dac_ram_write_1                       <= '1';
                                                  
            -- Write Data Back to FIFO            
            dac_read_i2c_command(31 downto 16)    <= x"8008";
            dac_read_i2c_command(15 downto 8)     <= x"2a";  -- DAC Reg 42
            dac_read_i2c_command(5 downto 0)      <= i2c_data(5 downto 0);
            dac_read_i2c_command(7 downto 6)      <= (others => '0');
            DR_STATE_RETURN                       <= DR_NEXT_REGISTER;
            DR_STATE                              <= DR_WAIT_DONE;
                                                  
          when DR_NEXT_REGISTER =>
            if (r_fifo_ctr < x"80") then          
              r_fifo_ctr                          <= r_fifo_ctr + 1;
              next_token_dac_r                    <= '1';
              DR_STATE                            <= DR_REGISTER;
            else                                  
              i2c_lock_1_clear                    <= '1';
              DR_STATE                            <= DR_IDLE;
            end if;                               
                                                  
          when DR_WAIT_DONE =>
            if (i2c_command_done = '0') then      
              DR_STATE                            <= DR_WAIT_DONE;
            else                                  
              DR_STATE                            <= DR_STATE_RETURN;
            end if;
        end case;

      end if;
    end if;
  end process PROC_READ_DAC_REGISTERS;

  PROC_WRITE_DAC_REGISTERS: process(CLK_IN)
    variable index : integer := 0;
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        dac_write_i2c_command  <= (others => '0');
        w_fifo_ctr             <= (others => '0');
        dac_write_token_clear  <= (others => '0');
        next_token_dac_w       <= '0';
        i2c_lock_2_clear       <= '0';
        DW_STATE_RETURN        <= DW_IDLE;
        DW_STATE               <= DW_IDLE;
      else
        dac_write_i2c_command  <= (others => '0');
        dac_write_token_clear  <= (others => '0');
        next_token_dac_w       <= '0';
        i2c_lock_2_clear       <= '0';
        
        index                  := to_integer(w_fifo_ctr);
        case DW_STATE is
          when DW_IDLE =>
            if (unsigned(dac_write_token) /= 0) then
              DW_STATE                            <= DW_REGISTER;
            else
              DW_STATE                            <= DW_IDLE;
            end if;
            w_fifo_ctr                            <= (others => '0');

          when DW_REGISTER =>
            dac_write_i2c_command(31 downto 16)   <= x"c108";
            dac_write_i2c_command(15 downto 8)    <= x"2a";  -- DAC Reg 42
            dac_write_i2c_command(7 downto 0)     <= (others => '0');
            dac_write_token_clear(index)          <= '1';
            if (i2c_lock_2 = '0') then
              DW_STATE                            <= DW_REGISTER;
            else
              dac_write_token_clear(index)        <= '1';
              DW_STATE_RETURN                     <= DW_WRITE_BACK;
              DW_STATE                            <= DW_WAIT_DONE;
            end if;
            
          when DW_WRITE_BACK =>
            -- Write Data Back to FIFO
            dac_write_i2c_command(31 downto 16)   <= x"8008";
            dac_write_i2c_command(15 downto 8)    <= x"2a";  -- DAC Reg 42
            dac_write_i2c_command(7 downto 6)     <= (others => '0');
            dac_write_i2c_command(5 downto 0)     <= dac_ram(index);
            DW_STATE_RETURN                       <= DW_NEXT_REGISTER;
            DW_STATE                              <= DW_WAIT_DONE;
                                                  
          when DW_NEXT_REGISTER =>                
            if (w_fifo_ctr < x"80") then          
              w_fifo_ctr                          <= w_fifo_ctr + 1;
              next_token_dac_w                    <= '1';
              DW_STATE                            <= DW_REGISTER;
            else                                  
              i2c_lock_2_clear                    <= '1';
              DW_STATE                            <= DW_IDLE;
            end if;                               
                                                  
          when DW_WAIT_DONE =>                    
            if (i2c_command_done = '0') then      
              DW_STATE                            <= DW_WAIT_DONE;
            else                                  
              DW_STATE                            <= DW_STATE_RETURN;
            end if;

        end case;
     end if;
    end if;
  end process PROC_WRITE_DAC_REGISTERS;

  -----------------------------------------------------------------------------

  PROC_ADC_REGISTERS_HANDLER: process(CLK_IN)
    variable index  : integer := 0;
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        adc_i2c_command          <= (others => '0');
        adc_token_ctr            <= (others => '0');
        next_token_adc           <= '0';
        adc_read_token_clear     <= (others => '0');
        i2c_lock_3_clear         <= '0';
        ADC_STATE                <= ADC_IDLE_TOKEN;
      else
        index                    := to_integer(unsigned(adc_token_ctr));
        adc_i2c_command          <= (others => '0');
        next_token_adc           <= '0';
        adc_read_token_clear     <= (others => '0');
        i2c_lock_3_clear         <= '0';

        case ADC_STATE is
          
          when ADC_IDLE_TOKEN =>
            if (adc_read_token(index) = '1') then
              ADC_STATE                          <= ADC_READ_I2C_REGISTER;
            else
              ADC_STATE                          <= ADC_NEXT_TOKEN;
            end if;
            
            -- Read I2C Register
          when ADC_READ_I2C_REGISTER =>
            adc_i2c_command(31 downto 16)        <= x"c229";
            case adc_token_ctr is
              when "00" => adc_i2c_command(15 downto  8) <= x"10";
              when "01" => adc_i2c_command(15 downto  8) <= x"20";
              when "10" => adc_i2c_command(15 downto  8) <= x"40";
              when "11" => adc_i2c_command(15 downto  8) <= x"80";
            end case;
            adc_i2c_command(7 downto  0)         <= (others => '0');
            if (i2c_lock_3 = '0') then
              ADC_STATE                          <= ADC_READ_I2C_REGISTER;
            else
              adc_read_token_clear(index)        <= '1';
              ADC_STATE                          <= ADC_WAIT_I2C_READ_DONE;
            end if;

          when ADC_WAIT_I2C_READ_DONE =>
            if (i2c_command_done = '0') then
              ADC_STATE                          <= ADC_WAIT_I2C_READ_DONE;
            else
              ADC_STATE                          <= ADC_READ_I2C_STORE_MEM;
            end if;

          when ADC_READ_I2C_STORE_MEM =>
            if (i2c_data_bytes(13 downto 12) =
                std_logic_vector(adc_token_ctr)) then
              adc_ram(index)(11 downto 0)        <= i2c_data_bytes(11 downto 0);
              adc_ram(index)(12)                 <= '0';
            else
              adc_ram(index)                     <= (others => '1');
            end if;
            i2c_lock_3_clear                     <= '1';
            ADC_STATE                            <= ADC_NEXT_TOKEN;
            
            -- Next Token
          when ADC_NEXT_TOKEN =>
            if (adc_token_ctr < "11") then
              adc_token_ctr                      <= adc_token_ctr + 1;
            else
              adc_token_ctr                      <= (others => '0');
            end if;
            next_token_adc                       <= '1';
            ADC_STATE                            <= ADC_IDLE_TOKEN;
            
        end case;
      end if;
    end if;
  end process PROC_ADC_REGISTERS_HANDLER;
  
  -----------------------------------------------------------------------------

  timer_static_1: timer_static
    generic map (
      CTR_WIDTH => 32,
      CTR_END   => 500000000    --5S
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => RESET_IN,
      TIMER_START_IN => wait_timer_start,
      TIMER_DONE_OUT => wait_timer_done
      );
    
  PROC_I2C_STATUS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        i2c_update_memory_p   <= '0';
        i2c_disable_memory    <= '0';
        i2c_online_t          <= (others => '0');
        i2c_reg_reset_clear   <= '0';
      else
        i2c_reg_reset_clear   <= '0';

        -- Shift Online
        i2c_online_t(0)       <= I2C_ONLINE_IN;
        for I  in 1 to 7 loop
          i2c_online_t(I)     <= i2c_online_t(I - 1);
        end loop;  
        
        if (i2c_update_memory_r = '1') then
          i2c_update_memory_p       <= '1';
          i2c_disable_memory        <= '0';
        else
          
          case i2c_online_t(7 downto 6) is
            
            when "00" =>
              i2c_update_memory_p   <= '0';
              i2c_disable_memory    <= '1';
              
            when "10" =>
              i2c_update_memory_p   <= '0';
              i2c_disable_memory    <= '1';
              
            when "01" =>
              i2c_update_memory_p   <= '1';
              i2c_disable_memory    <= '0';
              
            when "11" =>
              if (i2c_reg_reset_in_s = '1' and I2C_REG_RESET_IN = '0') then
                i2c_update_memory_p <= '1';
                i2c_reg_reset_clear <= '1';
              else
                i2c_update_memory_p <= '0';
              end if;
              i2c_disable_memory    <= '0';

          end case;
        end if;
      end if;
    end if;
  end process PROC_I2C_STATUS;

  pulse_delay_1: pulse_delay
    generic map (
      DELAY => 1000000
      )
    port map (
      CLK_IN    => CLK_IN,
      RESET_IN  => RESET_IN,
      PULSE_IN  => i2c_update_memory_p,
      PULSE_OUT => i2c_update_memory
      );
  
  PROC_REG_RESET: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        i2c_reg_reset_in_s    <= '0';
      else
        if (i2c_reg_reset_clear = '1') then
          i2c_reg_reset_in_s  <= '0';
        elsif(I2C_REG_RESET_IN = '1') then
          i2c_reg_reset_in_s  <= '1';
        end if;
      end if;
    end if;
  end process PROC_REG_RESET;

  -----------------------------------------------------------------------------

  PROC_INTERNAL_REG_READ: process(CLK_IN)
    variable index       : integer  := 0;
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        int_data_o          <= (others => '0');
        int_ack_o           <= '0';
      else
        int_data_o          <= (others => '0');
        int_ack_o           <= '0';

        if (INT_READ_IN = '1') then
          if (INT_ADDR_IN >= x"0000" and INT_ADDR_IN <= x"002d") then
            index := to_integer(unsigned(INT_ADDR_IN(5 downto 0)));
            if (i2c_disable_memory = '0') then
              int_data_o(7 downto 0)      <= i2c_ram(index);
              int_data_o(28 downto 8)     <= (others => '0');
              int_data_o(29)              <=
                not register_access_type(index)(0);
              int_data_o(30)              <= i2c_read_token(index);
              int_data_o(31)              <= i2c_write_token(index);
            else
              int_data_o(31 downto 0)     <= (others => '1');
            end if;
            int_ack_o                     <= '1';

          elsif (INT_ADDR_IN >= x"0100" and INT_ADDR_IN <= x"0180") then
            index := to_integer(unsigned(INT_ADDR_IN(7 downto 0)));
            if (i2c_disable_memory = '0') then
              int_data_o(5 downto 0)      <= dac_ram(index);
              int_data_o(29 downto 6)     <= (others => '0');
              int_data_o(30)              <= dac_read_token(index);
              int_data_o(31)              <= dac_write_token(index);
            else
              int_data_o(31 downto 0)     <= (others => '1');
            end if;  
            int_ack_o                     <= '1';

          elsif (INT_ADDR_IN >= x"0080" and INT_ADDR_IN <= x"0083") then
            index := to_integer(unsigned(INT_ADDR_IN(1 downto 0)));
            if (i2c_disable_memory = '0') then
              int_data_o(12 downto 0)     <= adc_ram(index);
              int_data_o(31 downto 13)    <= (others => '0');
            else
              int_data_o(31 downto 0)     <= (others => '1');
            end if;  
            int_ack_o                     <= '1';
          else
            case INT_ADDR_IN is
              when x"0050" =>
                -- Nxyter Clock
                if (i2c_disable_memory = '0') then
                  int_data_o(0)           <= i2c_ram(33)(3);
                  int_data_o(31 downto 1) <= (others => '0');
                else
                  int_data_o(31 downto 0) <= (others => '1');
                end if;
                int_ack_o                  <= '1';
                  
              when x"0051" =>
                -- Nxyter Polarity
                if (i2c_disable_memory = '0') then
                  int_data_o(0)           <= i2c_ram(33)(2);
                  int_data_o(31 downto 1) <= (others => '0');
                else
                  int_data_o(31 downto 0) <= (others => '1');
                end if;
                int_ack_o                 <= '1';  
        
              when x"0052" =>
                -- Nxyter Testpulse Polarity
                if (i2c_disable_memory = '0') then
                  int_data_o(0)           <= i2c_ram(32)(2);
                  int_data_o(31 downto 1) <= (others => '0');
                else
                  int_data_o(31 downto 0) <= (others => '1');
                end if;
                int_ack_o                 <= '1';
        
              when x"0053" =>
                -- Nxyter Testpulse
                if (i2c_disable_memory = '0') then
                  int_data_o(0)           <= i2c_ram(32)(0);
                  int_data_o(31 downto 1) <= (others => '0');
                else
                  int_data_o(31 downto 0) <= (others => '1');
                end if;
                int_ack_o                 <= '1';
        
              when x"0054" =>
                -- Nxyter Testtrigger
                if (i2c_disable_memory = '0') then
                  int_data_o(0)           <= i2c_ram(32)(3);
                  int_data_o(31 downto 1) <= (others => '0');
                else
                  int_data_o(31 downto 0) <= (others => '1');
                end if;
                int_ack_o                 <= '1';  
        
              when x"0055" =>
                -- Nxyter Testpulse Channels
                if (i2c_disable_memory = '0') then
                  int_data_o(1 downto 0)  <= i2c_ram(33)(1 downto 0);
                  int_data_o(31 downto 2) <= (others => '0');
                else
                  int_data_o(31 downto 0) <= (others => '1');
                end if;
                int_ack_o                 <= '1';
        
              when x"0056" =>
                -- I2C Online
                int_data_o(0)             <= I2C_ONLINE_IN;
                int_data_o(31 downto 2)   <= (others => '0');
                int_ack_o                 <= '1';
        
              when others =>
                int_data_o(31 downto 0)   <= (others => '1');
                int_ack_o                 <= '1';
            end case;  
          end if;
        end if;
      end if;
    end if;           
  end process PROC_INTERNAL_REG_READ;

  -----------------------------------------------------------------------------
  
  PROC_SLAVE_BUS: process(CLK_IN)
    variable index       : integer   := 0;
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o         <= (others => '0');
        slv_no_more_data_o     <= '0';
        slv_unknown_addr_o     <= '0';
        slv_ack_o              <= '0';

        ram_data_0             <= (others => '0');
        ram_index_0            <= 0;
        ram_write_0            <= '0';
        i2c_read_token_r       <= (others => '0');

        dac_ram_data_0         <= (others => '0');
        dac_ram_index_0        <= 0;
        dac_ram_write_0        <= '0';
        dac_read_token_r       <= (others => '0');
        adc_read_token_r       <= (others => '0');
        i2c_update_memory_r    <= '0';
        nxyter_clock           <= (others => '0');
        nxyter_polarity        <= (others => '0');
        nxyter_testtrigger     <= (others => '0');
        nxyter_testpulse       <= (others => '0');
        nxyter_testchannels    <= (others => '0');
      else                    
        slv_unknown_addr_o     <= '0';
        slv_no_more_data_o     <= '0';
        
        ram_data_0             <= (others => '0');
        ram_index_0            <= 0;
        ram_write_0            <= '0';
        i2c_read_token_r       <= (others => '0');
        
        dac_ram_data_0         <= (others => '0');
        dac_ram_index_0        <= 0;
        dac_ram_write_0        <= '0';
        dac_read_token_r       <= (others => '0');

        adc_read_token_r       <= (others => '0');
        
        i2c_update_memory_r    <= '0';
        nxyter_clock           <= (others => '0');
        nxyter_polarity        <= (others => '0');
        nxyter_testtrigger     <= (others => '0');
        nxyter_testpulse       <= (others => '0');
        nxyter_testchannels    <= (others => '0');
        
        if (SLV_WRITE_IN = '1') then
          if (SLV_ADDR_IN >= x"0000" and SLV_ADDR_IN <= x"002d") then
            index := to_integer(unsigned(SLV_ADDR_IN(5 downto 0)));
            if (i2c_disable_memory = '0') then
              ram_index_0                <= index;
              ram_data_0                 <= SLV_DATA_IN(7 downto 0);
              ram_write_0                <= '1';
            end if;
            slv_ack_o                    <= '1';
                      
          elsif (SLV_ADDR_IN >= x"0100" and SLV_ADDR_IN <= x"0180") then
            -- Write value to ram
            index   := to_integer(unsigned(SLV_ADDR_IN(7 downto 0)));
            if (index = 0) then
              index := 128;
            else
              index := index - 1;
            end if;
            
            if (i2c_disable_memory = '0') then
              dac_ram_index_0            <= index;
              dac_ram_data_0             <= SLV_DATA_IN(5 downto 0);
              dac_ram_write_0            <= '1';
            end if;
            slv_ack_o                    <= '1';

          else
            case SLV_ADDR_IN is
              when x"0050" =>
                -- Nxyter Clock
                if (i2c_disable_memory = '0') then
                  nxyter_clock(0)        <= SLV_DATA_IN(0);
                  nxyter_clock(1)        <= '1';
                end if;
                slv_ack_o                <= '1';
                  
              when x"0051" =>
                -- Nxyter Polarity
                if (i2c_disable_memory = '0') then
                  nxyter_polarity(0)     <= SLV_DATA_IN(0);
                  nxyter_polarity(1)     <= '1';
                end if;
                slv_ack_o                <= '1';  

              when x"0053" =>
                -- Nxyter Testpulse
                if (i2c_disable_memory = '0') then
                  nxyter_testpulse(0)    <= SLV_DATA_IN(0);
                  nxyter_testpulse(1)    <= '1';
                end if;
                slv_ack_o                <= '1';
                
              when x"0054" =>
                -- Nxyter Testtrigger
                if (i2c_disable_memory = '0') then
                  nxyter_testtrigger(0)  <= SLV_DATA_IN(0);
                  nxyter_testtrigger(1)  <= '1';
                end if;
                slv_ack_o                <= '1';  

              when x"0055" =>
                -- Nxyter Testtrigger
                if (i2c_disable_memory = '0') then
                  nxyter_testchannels(1 downto 0) <= SLV_DATA_IN(1 downto 0);
                  nxyter_testchannels(2) <= '1';
                end if;
                slv_ack_o                <= '1';
                
              when x"0060" =>
                if (i2c_disable_memory = '0') then
                  i2c_read_token_r       <= (others => '1');
                end if;
                slv_ack_o                <= '1';

              when x"0061" =>
                if (i2c_disable_memory = '0') then
                  dac_read_token_r       <= (others => '1');
                end if;
                slv_ack_o                <= '1';

              when x"0062" =>
                if (i2c_disable_memory = '0') then
                  i2c_update_memory_r    <= '1';
                end if;
                slv_ack_o                <= '1';
                
              when others =>          
                slv_unknown_addr_o       <= '1';
                slv_ack_o                <= '0';    
                                    
            end case;                     
          end if;

        elsif (SLV_READ_IN = '1') then
          if (SLV_ADDR_IN >= x"0000" and SLV_ADDR_IN <= x"002d") then
            index := to_integer(unsigned(SLV_ADDR_IN(5 downto 0)));
            if (i2c_disable_memory = '0') then
              slv_data_out_o(7 downto 0)      <= i2c_ram(index);
              slv_data_out_o(28 downto 8)     <= (others => '0');
              slv_data_out_o(29)              <=
                not register_access_type(index)(0);
              slv_data_out_o(30)              <= i2c_read_token(index);
              slv_data_out_o(31)              <= i2c_write_token(index);
            else
              slv_data_out_o(31 downto 0)     <= (others => '1');
            end if;
            slv_ack_o                         <= '1';

          elsif (SLV_ADDR_IN >= x"0100" and SLV_ADDR_IN <= x"0180") then
            index   := to_integer(unsigned(SLV_ADDR_IN(7 downto 0)));
            if (index = 0) then
              index := 128;
            else
              index := index - 1;
            end if;
            
            if (i2c_disable_memory = '0') then
              slv_data_out_o(5 downto 0)      <= dac_ram(index);
              slv_data_out_o(29 downto 6)     <= (others => '0');
              slv_data_out_o(30)              <= dac_read_token(index);
              slv_data_out_o(31)              <= dac_write_token(index);
            else
              slv_data_out_o(31 downto 0)     <= (others => '1');
            end if;  
            slv_ack_o                         <= '1';

          elsif (SLV_ADDR_IN >= x"0080" and SLV_ADDR_IN <= x"0083") then
            index := to_integer(unsigned(SLV_ADDR_IN(1 downto 0)));
            if (i2c_disable_memory = '0') then
              slv_data_out_o(12 downto 0)     <= adc_ram(index);
              slv_data_out_o(31 downto 13)    <= (others => '0');
              adc_read_token_r(index)         <= '1'; 
            else
              slv_data_out_o(31 downto 0)     <= (others => '1');
            end if;  
            slv_ack_o                         <= '1';
            
          else
            case SLV_ADDR_IN is
              when x"0050" =>
                -- Nxyter Clock ON
                if (i2c_disable_memory = '0') then
                  slv_data_out_o(0)           <= i2c_ram(33)(3);
                  slv_data_out_o(31 downto 1) <= (others => '0');
                else
                  slv_data_out_o(31 downto 0) <= (others => '1');
                end if;
                slv_ack_o                     <= '1';
                  
              when x"0051" =>
                -- Nxyter Polarity
                if (i2c_disable_memory = '0') then
                  slv_data_out_o(0)           <= i2c_ram(33)(2);
                  slv_data_out_o(31 downto 1) <= (others => '0');
                else
                  slv_data_out_o(31 downto 0) <= (others => '1');
                end if;
                slv_ack_o                     <= '1';  

              when x"0052" =>
                -- Nxyter Testpulse Polarity
                if (i2c_disable_memory = '0') then
                  slv_data_out_o(0)           <= i2c_ram(32)(2);
                  slv_data_out_o(31 downto 1) <= (others => '0');
                else
                  slv_data_out_o(31 downto 0) <= (others => '1');
                end if;
                slv_ack_o                     <= '1';

              when x"0053" =>
                -- Nxyter Testpulse
                if (i2c_disable_memory = '0') then
                  slv_data_out_o(0)           <= i2c_ram(32)(0);
                  slv_data_out_o(31 downto 1) <= (others => '0');
                else
                  slv_data_out_o(31 downto 0) <= (others => '1');
                end if;
                slv_ack_o                     <= '1';

              when x"0054" =>
                -- Nxyter Testtrigger
                if (i2c_disable_memory = '0') then
                  slv_data_out_o(0)           <= i2c_ram(32)(3);
                  slv_data_out_o(31 downto 1) <= (others => '0');
                else
                  slv_data_out_o(31 downto 0) <= (others => '1');
                end if;
                slv_ack_o                     <= '1';  

              when x"0055" =>
                -- Nxyter Testpulse Channels
                if (i2c_disable_memory = '0') then
                  slv_data_out_o(1 downto 0)  <= i2c_ram(33)(1 downto 0);
                  slv_data_out_o(31 downto 2) <= (others => '0');
                else
                  slv_data_out_o(31 downto 0) <= (others => '1');
                end if;
                slv_ack_o                     <= '1';

              when x"0056" =>
                -- I2C Online
                slv_data_out_o(0)             <= I2C_ONLINE_IN;
                slv_data_out_o(31 downto 2)   <= (others => '0');
                slv_ack_o                     <= '1';

              when x"0060" =>
                -- Update Register I2C Status
                if (unsigned(i2c_read_token) = 0) then
                  slv_data_out_o              <= (others => '0');
                else
                  slv_data_out_o              <= x"0000_0001";
                end if;
                slv_ack_o                     <= '1';

              when x"0061" =>
                -- Update Register DAC Status
                if (unsigned(dac_read_token) = 0) then
                  slv_data_out_o              <= (others => '0');
                else
                  slv_data_out_o              <= x"0000_0001";
                end if;
                slv_ack_o                     <= '1';
                
              when x"0062" =>
                -- Update Register I2C and DAC Status
                if (unsigned(i2c_read_token) = 0 and
                    unsigned(dac_read_token) = 0) then
                  slv_data_out_o              <= (others => '0');
                else
                  slv_data_out_o              <= x"0000_0001";
                end if;
                slv_ack_o                     <= '1';
                
              when x"0070" =>
                -- WriteToken
                slv_data_out_o                <= i2c_write_token(31 downto 0);
                slv_ack_o                     <= '1';
              when x"0071" =>
                -- WriteToken
                slv_data_out_o(13 downto 0)   <= i2c_write_token(45 downto 32);
                slv_data_out_o(31 downto 14)  <= (others => '0');
                slv_ack_o                     <= '1';

              when x"0072" =>
                -- ReadToken
                slv_data_out_o                <= i2c_read_token(31 downto 0);
                slv_ack_o                     <= '1';

              when x"0073" =>
                -- ReadToken
                slv_data_out_o(13 downto 0)   <= i2c_read_token(45 downto 32);
                slv_data_out_o(31 downto 14)  <= (others => '0');
                slv_ack_o                     <= '1';

              when x"0074" =>
                -- WriteTokenDAC
                slv_data_out_o                <= dac_write_token(31 downto 0);
                slv_ack_o                     <= '1';
              when x"0075" =>
                -- WriteTokenDAC
                slv_data_out_o                <= dac_write_token(63 downto 32);
                slv_ack_o                     <= '1';
              when x"0076" =>
                -- WriteTokenDAC
                slv_data_out_o                <= dac_write_token(95 downto 64);
                slv_ack_o                     <= '1';
              when x"0077" =>
                -- WriteTokenDAC
                slv_data_out_o                <= dac_write_token(127 downto 96);
                slv_ack_o                     <= '1';
              when x"0078" =>
                -- WriteTokenDAC
                slv_data_out_o(0)             <= dac_write_token(128);
                slv_data_out_o(31 downto 1)   <= (others => '0');
                slv_ack_o                     <= '1';

              when x"0079" =>
                -- ReadTokenDAC
                slv_data_out_o                <= dac_read_token(31 downto 0);
                slv_ack_o                     <= '1';
              when x"007a" =>
                -- ReadTokenDAC
                slv_data_out_o                <= dac_read_token(63 downto 32);
                slv_ack_o                     <= '1';
              when x"007b" =>
                -- ReadTokenDAC
                slv_data_out_o                <= dac_read_token(95 downto 64);
                slv_ack_o                     <= '1';
              when x"007c" =>
                -- ReadTokenDAC
                slv_data_out_o                <= dac_read_token(127 downto 96);
                slv_ack_o                     <= '1';
              when x"007d" =>
                -- ReadTokenDAC
                slv_data_out_o(0)             <= dac_read_token(128);
                slv_data_out_o(31 downto 1)   <= (others => '0');
                slv_ack_o                     <= '1';
                
              when others =>   
                slv_unknown_addr_o            <= '1';
                slv_ack_o                     <= '0';
            end case;  

          end if;
        else                        
          slv_ack_o                           <= '0';
        end if;
        
      end if;
    end if;           
  end process PROC_SLAVE_BUS;

  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------
  nx_clock_on_o           <= i2c_ram(33)(3) when rising_edge(CLK_IN);
  
  I2C_COMMAND_OUT         <= i2c_command_o;
  I2C_LOCK_OUT            <= i2c_command_busy_o;
                          
  SPI_COMMAND_OUT         <= (others => '0');
  SPI_LOCK_OUT            <= '0';
                          
  -- Internal Read        
  INT_ACK_OUT             <= int_ack_o;
  INT_DATA_OUT            <= int_data_o;

  NX_CLOCK_ON_OUT         <= nx_clock_on_o;
  
  -- Slave Bus            
  SLV_DATA_OUT            <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT    <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT    <= slv_unknown_addr_o;
  SLV_ACK_OUT             <= slv_ack_o; 

end Behavioral;
