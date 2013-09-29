library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;

entity nx_setup is
  port(
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;

    I2C_COMMAND_OUT      : out std_logic_vector(31 downto 0);
    I2C_COMMAND_BUSY_IN  : in  std_logic;
    I2C_DATA_IN          : in  std_logic_vector(31 downto 0);
    I2C_LOCK             : out std_logic;

    SPI_COMMAND_OUT      : out std_logic_vector(31 downto 0);
    SPI_COMMAND_BUSY_IN  : in  std_logic;
    SPI_DATA_IN          : in  std_logic_vector(31 downto 0);
    SPI_LOCK             : out std_logic;
    
    -- Slave bus         
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;
    
    -- Debug Line
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_setup is

  -- Send I2C Command
  type I2C_STATES is (I2C_IDLE,
                      I2C_WAIT_BUSY_HIGH,
                      I2C_WAIT_BUSY_LOW
                      );

  signal I2C_STATE : I2C_STATES;
  
  signal spi_command_o : std_logic_vector(31 downto 0);
  signal i2c_lock_o              : std_logic;
  signal i2c_command_o           : std_logic_vector(31 downto 0);
  signal i2c_command             : std_logic_vector(31 downto 0);
  signal i2c_command_busy        : std_logic;
  signal i2c_command_done        : std_logic;
  signal i2c_data                : std_logic_vector(31 downto 0);

  -- Read I2C Registers
  type R_STATES is (R_IDLE,
                    R_REGISTER,
                    R_REGISTER_STORE,
                    R_NEXT_REGISTER,
                    R_WAIT_DONE
                    );
  
  signal R_STATE, R_STATE_RETURN : R_STATES;

  signal nx_read_i2c_command     : std_logic_vector(31 downto 0);
  signal nx_read_i2c_lock        : std_logic;        
  signal r_register_ctr          : unsigned(5 downto 0);

  -- Write I2C Registers
  type W_STATES is (W_IDLE,
                    W_REGISTER,
                    W_NEXT_REGISTER,
                    W_WAIT_DONE
                    );

  signal W_STATE, W_STATE_RETURN : W_STATES;

  
  signal nx_write_i2c_command    : std_logic_vector(31 downto 0);
  signal nx_write_i2c_lock       : std_logic;        
  signal w_register_ctr          : unsigned(5 downto 0);
  
  
  -- Read DAC I2C Registers
  type DR_STATES is (DR_IDLE,
                     DR_REGISTER,
                     DR_WRITE_BACK,
                     DR_NEXT_REGISTER,
                     DR_WAIT_DONE
                    );
  
  signal DR_STATE, DR_STATE_RETURN : DR_STATES;
  

  signal dac_read_i2c_command    : std_logic_vector(31 downto 0);
  signal dac_read_i2c_lock       : std_logic;        
  signal r_fifo_ctr              : unsigned(7 downto 0);

  -- Write DAC I2C Registers
  type DW_STATES is (DW_IDLE,
                     DW_REGISTER,
                     DW_WRITE_BACK,
                     DW_NEXT_REGISTER,
                     DW_WAIT_DONE
                     );
  signal DW_STATE, DW_STATE_RETURN : DW_STATES;

  signal dac_write_i2c_command   : std_logic_vector(31 downto 0);
  signal dac_write_i2c_lock      : std_logic;        
  signal w_fifo_ctr              : unsigned(7 downto 0);

  
  -- TRBNet Slave Bus
  signal slv_data_out_o          : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o      : std_logic;
  signal slv_unknown_addr_o      : std_logic;
  signal slv_ack_o               : std_logic;

  signal read_nx_i2c_all_start   : std_logic;
  signal write_nx_i2c_all_start  : std_logic;
  
  signal read_dac_all_start      : std_logic;
  signal write_dac_all_start     : std_logic;

  -- I2C Register Ram
  type i2c_ram_t is array(0 to 45) of std_logic_vector(7 downto 0);
  signal i2c_ram                 : i2c_ram_t;
  signal i2c_ram_write_0         : std_logic;
  signal i2c_ram_write_1         : std_logic;
  signal i2c_ram_input_addr_0    : unsigned(5 downto 0);
  signal i2c_ram_input_addr_1    : unsigned(5 downto 0);
  signal i2c_ram_input_0         : std_logic_vector(7 downto 0);
  signal i2c_ram_input_1         : std_logic_vector(7 downto 0);
  
  type register_access_type_t is array(0 to 45) of std_logic;
  constant register_access_type : register_access_type_t :=
    ('1', '1', '1', '1', '1', '1', '1', '1',   --  0 ->  7
     '1', '1', '1', '1', '1', '1', '1', '1',   --  8 -> 15
     '1', '1', '1', '1', '1', '1', '1', '1',   -- 16 -> 23
     '1', '1', '1', '1', '1', '1', '0', '0',   -- 24 -> 31 
     '1', '1', '0', '0', '0', '0', '1', '1',   -- 32 -> 39
     '0', '0', '0', '1', '1', '1'              -- 40 -> 45
     );
  
  -- DAC Trim FIFO RAM
  type dac_ram_t is array(0 to 130) of std_logic_vector(5 downto 0);
  signal dac_ram                 : dac_ram_t;
  signal dac_ram_write_0         : std_logic;
  signal dac_ram_write_1         : std_logic;
  signal dac_ram_input_addr_0    : unsigned(7 downto 0);
  signal dac_ram_input_addr_1    : unsigned(7 downto 0);
  signal dac_ram_input_0         : std_logic_vector(5 downto 0);
  signal dac_ram_input_1         : std_logic_vector(5 downto 0);

  signal ctr                     : std_logic_vector(5 downto 0);
  signal i2c_ram_write_d         : std_logic;
  signal dac_ram_write_d         : std_logic;
begin

  -----------------------------------------------------------------------------
  -- DEBUG
  -----------------------------------------------------------------------------

  DEBUG_OUT(0)            <= CLK_IN;
  DEBUG_OUT(1)            <= read_nx_i2c_all_start;
  DEBUG_OUT(2)            <= write_nx_i2c_all_start;
  DEBUG_OUT(3)            <= read_dac_all_start;
  DEBUG_OUT(4)            <= write_dac_all_start;

  DEBUG_OUT(5)            <= i2c_lock_o;
  DEBUG_OUT(6)            <= i2c_command_busy;
  DEBUG_OUT(7)            <= i2c_command_done;
  DEBUG_OUT(8)            <= I2C_COMMAND_BUSY_IN;
  
  DEBUG_OUT(9)            <= i2c_ram_write_d;
  DEBUG_OUT(10)           <= i2c_ram_write_0;
  DEBUG_OUT(11)           <= i2c_ram_write_1;
  DEBUG_OUT(12)           <= dac_ram_write_d;
  DEBUG_OUT(13)           <= dac_ram_write_0;
  DEBUG_OUT(14)           <= dac_ram_write_1;
  DEBUG_OUT(15)           <= '0';

  --DEBUG_OUT(14 downto 9)  <= ctr;
  ctr <= std_logic_vector(r_register_ctr) or std_logic_vector(w_register_ctr);
  
  -----------------------------------------------------------------------------

  PROC_I2C_RAM_WRITE_HANDLER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        i2c_ram_write_d <= '0';
      else
        i2c_ram_write_d <= '0';
        if (i2c_ram_write_0 = '1') then
          i2c_ram(to_integer(i2c_ram_input_addr_0)) <= i2c_ram_input_0;
          i2c_ram_write_d                           <= '1';
        elsif (i2c_ram_write_1 = '1') then
          i2c_ram(to_integer(i2c_ram_input_addr_1)) <= i2c_ram_input_1;
          i2c_ram_write_d                           <= '1';
        end if;
      end if;
    end if;
  end process PROC_I2C_RAM_WRITE_HANDLER;

  PROC_DAC_RAM_WRITE_HANDLER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        dac_ram_write_d <= '0';
      else
        dac_ram_write_d <= '0';
        if (dac_ram_write_0 = '1') then
          dac_ram(to_integer(dac_ram_input_addr_0)) <= dac_ram_input_0;
          dac_ram_write_d                           <= '1';
        elsif (dac_ram_write_1 = '1') then
          dac_ram(to_integer(dac_ram_input_addr_1)) <= dac_ram_input_1;
          dac_ram_write_d                           <= '1';
        end if;
      end if;
    end if;
  end process PROC_DAC_RAM_WRITE_HANDLER;
        
  -----------------------------------------------------------------------------

  i2c_lock_o    <= nx_write_i2c_lock or
                   nx_read_i2c_lock or
                   dac_read_i2c_lock or
                   dac_write_i2c_lock;
  i2c_command   <= nx_write_i2c_command or
                   nx_read_i2c_command or
                   dac_read_i2c_command or
                   dac_write_i2c_command;

  PROC_SEND_I2C_COMMAND: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        i2c_command_o    <= (others => '0');
        i2c_command_busy <= '0';
        i2c_command_done <= '0';
        i2c_data         <= (others => '0');
        I2C_STATE        <= I2C_IDLE;
      else
        i2c_command_o    <= (others => '0');
        i2c_command_busy <= '0';
        i2c_command_done <= '0';
        
        case I2C_STATE is

          when I2C_IDLE =>
            if (i2c_command(31) = '1') then
              i2c_command_o    <= i2c_command;
              i2c_command_busy <= '1';
              I2C_STATE        <= I2C_WAIT_BUSY_HIGH;
            else
              I2C_STATE        <= I2C_IDLE;
            end if;

          when I2C_WAIT_BUSY_HIGH =>
            if (I2C_COMMAND_BUSY_IN = '0') then
              i2c_command_o    <= i2c_command_o;
              i2c_command_busy <= '1';
              I2C_STATE        <= I2C_WAIT_BUSY_HIGH;
            else
              i2c_command_busy <= '1';
              I2C_STATE        <= I2C_WAIT_BUSY_LOW;
            end if;

          when I2C_WAIT_BUSY_LOW =>
            if (I2C_COMMAND_BUSY_IN = '1') then
              i2c_command_busy <= '1';
              I2C_STATE        <= I2C_WAIT_BUSY_LOW;
            else
              i2c_data         <= I2C_DATA_IN;
              i2c_command_done <= '1';
              i2c_command_busy <= '1';
              I2C_STATE        <= I2C_IDLE;
            end if;
        end case;
        
      end if;
    end if;
  end process PROC_SEND_I2C_COMMAND;

  -----------------------------------------------------------------------------
  
  PROC_READ_NX_REGISTERS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        nx_read_i2c_command    <= (others => '0');
        nx_read_i2c_lock       <= '0';
        i2c_ram_input_0        <= (others => '0');
        i2c_ram_input_addr_0   <= (others => '0');
        i2c_ram_write_0        <= '0';
        r_register_ctr         <= (others => '0');
        
        R_STATE_RETURN         <= R_IDLE;
        R_STATE                <= R_IDLE;
      else
        nx_read_i2c_command    <= (others => '0');
        nx_read_i2c_lock       <= '1';
        i2c_ram_input_0        <= (others => '0');
        i2c_ram_input_addr_0   <= (others => '0');
        i2c_ram_write_0        <= '0';

        case R_STATE is
          when R_IDLE =>
            if (read_nx_i2c_all_start = '1') then
              R_STATE                           <= R_REGISTER;
            else
              nx_read_i2c_lock                  <= '0';
              R_STATE                           <= R_IDLE;
            end if;
            r_register_ctr                      <= (others => '0');

          when R_REGISTER =>
           if (register_access_type(to_integer(r_register_ctr)) = '1') then
             nx_read_i2c_command(31 downto 16)  <= x"ff08";
             nx_read_i2c_command(15 downto 14)  <= (others => '0');
             nx_read_i2c_command(13 downto  8)  <= r_register_ctr;
             nx_read_i2c_command( 7 downto  0)  <= (others => '0');
             R_STATE_RETURN                     <= R_REGISTER_STORE;
             R_STATE                            <= R_WAIT_DONE;
           else
             R_STATE                            <= R_REGISTER_STORE;
           end if;

          when R_REGISTER_STORE =>
            if (register_access_type(to_integer(r_register_ctr)) = '1') then
              i2c_ram_input_0                   <= i2c_data(7 downto 0);
            else
              i2c_ram_input_0                   <= x"be";
            end if;
            i2c_ram_input_addr_0                <= r_register_ctr;
            i2c_ram_write_0                     <= '1';
            r_register_ctr                      <= r_register_ctr + 1;
            R_STATE                             <= R_NEXT_REGISTER;
            
          when R_NEXT_REGISTER =>
            if (r_register_ctr < x"2e") then
              R_STATE                           <= R_REGISTER;
            else
              R_STATE                           <= R_IDLE;
            end if;
            
          when R_WAIT_DONE =>
            if (i2c_command_done = '0') then
              R_STATE                           <= R_WAIT_DONE;
            else
              R_STATE                           <= R_STATE_RETURN;
            end if;

        end case;
     end if;
    end if;
  end process PROC_READ_NX_REGISTERS;

  PROC_WRITE_NX_REGISTERS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        nx_write_i2c_lock        <= '0';
        nx_write_i2c_command     <= (others => '0');
        w_register_ctr           <= (others => '0');
        
        W_STATE_RETURN           <= W_IDLE;
        W_STATE                  <= W_IDLE;
      else
        nx_write_i2c_command     <= (others => '0');
        nx_write_i2c_lock        <= '1';
        
        case W_STATE is

          when W_IDLE =>
            if (write_nx_i2c_all_start = '1') then
              W_STATE                            <= W_REGISTER;
            else
              nx_write_i2c_lock                  <= '0';
              W_STATE                            <= W_IDLE;
            end if;
            w_register_ctr                       <= (others => '0');
            
          when W_REGISTER =>
            if (register_access_type(
              to_integer(unsigned(w_register_ctr))) = '1') 
            then
              nx_write_i2c_command(31 downto 16) <= x"bf08";
              nx_write_i2c_command(15 downto 14) <= (others => '0');
              nx_write_i2c_command(13 downto  8) <= w_register_ctr;
              nx_write_i2c_command( 7 downto  0) <=
                i2c_ram(to_integer(unsigned(w_register_ctr)));
              W_STATE_RETURN                     <= W_NEXT_REGISTER;
              W_STATE                            <= W_WAIT_DONE;
            else
              W_STATE                            <= W_NEXT_REGISTER;
            end if;
            w_register_ctr                       <= w_register_ctr + 1;

          when W_NEXT_REGISTER =>
            if (w_register_ctr < x"2e") then
              W_STATE                            <= W_REGISTER;
            else
              W_STATE                            <= W_IDLE;
            end if;

          when W_WAIT_DONE =>
            if (i2c_command_done = '0') then
              W_STATE                            <= W_WAIT_DONE;
            else
              W_STATE                            <= W_STATE_RETURN;
            end if;

        end case;
      end if;
    end if;
  end process PROC_WRITE_NX_REGISTERS;

  -----------------------------------------------------------------------------

  PROC_READ_DAC_REGISTERS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        dac_read_i2c_command   <= (others => '0');
        dac_read_i2c_lock      <= '0';
        dac_ram_write_0        <= '0';
        dac_ram_input_addr_0   <= (others => '0');
        dac_ram_input_0        <= (others => '0');
        r_fifo_ctr             <= (others => '0');

        DR_STATE_RETURN        <= DR_IDLE;
        DR_STATE               <= DR_IDLE;
      else
        dac_read_i2c_command   <= (others => '0');
        dac_read_i2c_lock      <= '1';
        dac_ram_write_0        <= '0';
        dac_ram_input_addr_0   <= (others => '0');
        dac_ram_input_0        <= (others => '0');
        
        case DR_STATE is
          when DR_IDLE =>
            if (read_dac_all_start = '1') then
              DR_STATE                          <= DR_REGISTER;
            else
              dac_read_i2c_lock                 <= '0';
              DR_STATE                          <= DR_IDLE;
            end if;
            r_fifo_ctr                          <= (others => '0');

          when DR_REGISTER =>
            dac_read_i2c_command(31 downto 16)  <= x"ff08";
            dac_read_i2c_command(15 downto 8)   <= x"2a";  -- DAC Reg 42
            dac_read_i2c_command(7 downto 0)    <= (others => '0');
            DR_STATE_RETURN                     <= DR_WRITE_BACK;
            DR_STATE                            <= DR_WAIT_DONE;

          when DR_WRITE_BACK =>
            -- Store FIFO Entry
            dac_ram_input_0                     <= i2c_data(5 downto 0);
            dac_ram_input_addr_0                <= r_fifo_ctr;
            dac_ram_write_0                     <= '1';
            
            -- Write Data Back to FIFO
            dac_read_i2c_command(31 downto 16)  <= x"bf08";
            dac_read_i2c_command(15 downto 8)   <= x"2a";  -- DAC Reg 42
            dac_read_i2c_command(5 downto 0)    <= i2c_data(5 downto 0);
            dac_read_i2c_command(7 downto 6)    <= (others => '0');
              r_fifo_ctr                        <= r_fifo_ctr + 1;
            DR_STATE_RETURN                     <= DR_NEXT_REGISTER;
            DR_STATE                            <= DR_WAIT_DONE;
           
          when DR_NEXT_REGISTER =>
            if (r_fifo_ctr < x"81") then
              DR_STATE                          <= DR_REGISTER;
            else
              DR_STATE                          <= DR_IDLE;
            end if;
            
          when DR_WAIT_DONE =>
            if (i2c_command_done = '0') then
              DR_STATE                          <= DR_WAIT_DONE;
            else
              DR_STATE                          <= DR_STATE_RETURN;
            end if;

        end case;
     end if;
    end if;
  end process PROC_READ_DAC_REGISTERS;

  PROC_WRITE_DAC_REGISTERS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        dac_write_i2c_command  <= (others => '0');
        dac_write_i2c_lock     <= '0';
        w_fifo_ctr             <= (others => '0');

        DW_STATE_RETURN        <= DW_IDLE;
        DW_STATE               <= DW_IDLE;
      else
        dac_write_i2c_command  <= (others => '0');
        dac_write_i2c_lock     <= '1';
        
        case DW_STATE is
          when DW_IDLE =>
            if (write_dac_all_start = '1') then
              DW_STATE                          <= DW_REGISTER;
            else
              dac_write_i2c_lock                <= '0';
              DW_STATE                          <= DW_IDLE;
            end if;
            w_fifo_ctr                          <= (others => '0');

          when DW_REGISTER =>
            dac_write_i2c_command(31 downto 16) <= x"ff08";
            dac_write_i2c_command(15 downto 8)  <= x"2a";  -- DAC Reg 42
            dac_write_i2c_command(7 downto 0)   <= (others => '0');
            DW_STATE_RETURN                     <= DW_WRITE_BACK;
            DW_STATE                            <= DW_WAIT_DONE;
            
          when DW_WRITE_BACK =>
            -- Write Data Back to FIFO
            dac_write_i2c_command(31 downto 16) <= x"bf08";
            dac_write_i2c_command(15 downto 8)  <= x"2a";  -- DAC Reg 42
            dac_write_i2c_command(7 downto 6)   <= (others => '0');
            dac_write_i2c_command(5 downto 0)   <=
              dac_ram(to_integer(w_fifo_ctr));
            w_fifo_ctr                        <= w_fifo_ctr + 1;
            DW_STATE_RETURN                     <= DW_NEXT_REGISTER;
            DW_STATE                            <= DW_WAIT_DONE;
           
          when DW_NEXT_REGISTER =>
            if (w_fifo_ctr < x"81") then
              DW_STATE                          <= DW_REGISTER;
            else
              DW_STATE                          <= DW_IDLE;
            end if;
            
          when DW_WAIT_DONE =>
            if (i2c_command_done = '0') then
              DW_STATE                          <= DW_WAIT_DONE;
            else
              DW_STATE                          <= DW_STATE_RETURN;
            end if;

        end case;
     end if;
    end if;
  end process PROC_WRITE_DAC_REGISTERS;
  
  -----------------------------------------------------------------------------
  
  PROC_SLAVE_BUS: process(CLK_IN)
    variable mem_address : unsigned(7 downto 0) := x"00";

  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o         <= (others => '0');
        slv_no_more_data_o     <= '0';
        slv_unknown_addr_o     <= '0';
        slv_ack_o              <= '0';

        read_nx_i2c_all_start  <= '0';
        write_nx_i2c_all_start <= '0';
        read_dac_all_start     <= '0';
        write_dac_all_start    <= '0';

        i2c_ram_input_1        <= (others => '0');
        i2c_ram_input_addr_1   <= (others => '0');
        i2c_ram_write_1        <= '0';
        dac_ram_input_1        <= (others => '0');
        dac_ram_input_addr_1   <= (others => '0');
        dac_ram_write_1        <= '0';
      else                    
        slv_data_out_o         <= (others => '0');
        slv_unknown_addr_o     <= '0';
        slv_no_more_data_o     <= '0';

        read_nx_i2c_all_start  <= '0';
        write_nx_i2c_all_start <= '0';
        read_dac_all_start     <= '0';
        write_dac_all_start    <= '0';

        i2c_ram_input_1        <= (others => '0');
        i2c_ram_input_addr_1   <= (others => '0');
        i2c_ram_write_1        <= '0';
        dac_ram_input_1        <= (others => '0');
        dac_ram_input_addr_1   <= (others => '0');
        dac_ram_write_1        <= '0';
        
        if (SLV_WRITE_IN  = '1') then
          if (SLV_ADDR_IN >= x"0000" and SLV_ADDR_IN <= x"002d") then
            if (i2c_lock_o = '1') then
              slv_no_more_data_o       <= '1';
              slv_ack_o                <= '0';
            else
              if (register_access_type(
                to_integer(unsigned(SLV_ADDR_IN(5 downto 0)))) = '1')
              then
                -- Write value to ram
                i2c_ram_input_1        <= SLV_DATA_IN(7 downto 0);
                i2c_ram_input_addr_1   <= unsigned(SLV_ADDR_IN(5 downto 0));
                i2c_ram_write_1        <= '1';
                slv_ack_o              <= '1';
              end if;
              slv_ack_o                <= '1';
            end if;

          elsif (SLV_ADDR_IN >= x"0060" and SLV_ADDR_IN <= x"00e0") then
            if (i2c_lock_o = '1') then
              slv_no_more_data_o       <= '1';
              slv_ack_o                <= '0';
            else
              -- Write value to ram
              mem_address := unsigned(SLV_ADDR_IN(7 downto 0)) - x"60";
              dac_ram_input_1          <= SLV_DATA_IN(5 downto 0);
              dac_ram_input_addr_1     <= mem_address;
              dac_ram_write_1          <= '1';
              slv_ack_o                <= '1';
            end if;

          else
            case SLV_ADDR_IN is
              when x"0040" =>
                read_nx_i2c_all_start  <= '1';
                slv_ack_o              <= '1';

              when x"0041" =>
                write_nx_i2c_all_start <= '1';
                slv_ack_o              <= '1';

              when x"0042" =>
                read_dac_all_start     <= '1';
                slv_ack_o              <= '1';

              when x"0043" =>
                write_dac_all_start    <= '1';
                slv_ack_o              <= '1';
                              
              when others =>          
                slv_unknown_addr_o     <= '1';
                slv_ack_o              <= '0';    
                                    
            end case;                     
          end if;

        elsif (SLV_READ_IN = '1') then
          if (SLV_ADDR_IN >= x"0000" and SLV_ADDR_IN <= x"002d") then
            slv_data_out_o(7 downto 0)  <= 
              i2c_ram(to_integer(unsigned(SLV_ADDR_IN(5 downto 0))));
            slv_data_out_o(31 downto 8) <= (others => '0');
            slv_ack_o                   <= '1';
          elsif (SLV_ADDR_IN >= x"0060" and SLV_ADDR_IN <= x"00e0") then
            mem_address := unsigned(SLV_ADDR_IN(7 downto 0)) - x"60";
            slv_data_out_o(5 downto 0)  <= dac_ram(to_integer(mem_address));
            slv_data_out_o(31 downto 6) <= (others => '0');
            slv_ack_o                   <= '1';
          else
            slv_unknown_addr_o          <= '1';
            slv_ack_o                   <= '0';
          end if;
        else                        
          slv_ack_o                     <= '0';
        end if;
        
      end if;
    end if;           
  end process PROC_SLAVE_BUS;

  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------
  
  I2C_COMMAND_OUT  <= i2c_command_o;
  I2C_LOCK         <= i2c_lock_o;
  
  SPI_COMMAND_OUT  <= spi_command_o;
  spi_command_o    <= (others => '0');

  -- Slave Bus
  SLV_DATA_OUT         <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT <= slv_unknown_addr_o;
  SLV_ACK_OUT          <= slv_ack_o; 

end Behavioral;
