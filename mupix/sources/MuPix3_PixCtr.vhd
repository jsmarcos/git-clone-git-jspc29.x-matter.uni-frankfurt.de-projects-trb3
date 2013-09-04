-------------------------------------------------------------------------------
--Controll of MuPix DACs and Pixel Tune DACs
--T. Weber, Mainz Univesity
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

entity PixCtr is
  
  port (
    clk                  : in  std_logic;
    sout_c_from_mupix    : in  std_logic;
    sout_d_from_mupix    : in  std_logic;
    ck_d_to_mupix        : out std_logic;
    ck_c_to_mupix        : out std_logic;
    ld_c_to_mupix        : out std_logic;
    sin_to_mupix         : out std_logic;
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic);
end PixCtr;

architecture Behavioral of PixCtr is
  

  signal sout_from_mupix     : std_logic_vector(31 downto 0);
  signal slowcontrol_reg_new : std_logic_vector(31 downto 0);
  signal slowcontrol_reg_old : std_logic_vector(31 downto 0);
  signal start_write_mupix   : std_logic;
  signal done_write_mupix    : std_logic;
  signal busy_write_mupix    : std_logic;

  type   delay_type is (idle, delay1, done);
  signal delay_fsm : delay_type := idle;

begin  -- Behavioral

  Delay : process (clk)
  begin  -- process Delay
    if rising_edge(clk) then
      done_write_mupix <= '0';
      case delay_fsm is
        when idle =>
          if start_write_mupix = '1' then
            delay_fsm <= delay1;
          end if;
        when delay1 =>
          delay_fsm <= done;
        when done =>
          done_write_mupix    <= '1';
          sout_from_mupix     <= sout_from_mupix(29 downto 0) & sout_c_from_mupix & sout_d_from_mupix;
          slowcontrol_reg_old <= slowcontrol_reg_new;
          delay_fsm <= idle;
      end case;
    end if;
  end process Delay;

  sin_to_mupix  <= slowcontrol_reg_old(0);
  ck_c_to_mupix <= slowcontrol_reg_old(1);
  ck_d_to_mupix <= slowcontrol_reg_old(2);
  ld_c_to_mupix <= slowcontrol_reg_old(3);

  -----------------------------------------------------------------------------
  --x0080: Register for SlowControl
  --x0081: Output of MuPix SlowControl Pins
  -----------------------------------------------------------------------------

  SLV_BUS : process (clk)
  begin  -- process SLV_BUS
    if rising_edge(clk) then
      
      SLV_DATA_OUT         <= (others => '0');
      SLV_UNKNOWN_ADDR_OUT <= '0';
      SLV_NO_MORE_DATA_OUT <= '0';
      SLV_ACK_OUT          <= '0';
      start_write_mupix    <= '0';


      if busy_write_mupix = '1' then
        if done_write_mupix = '0'then
          busy_write_mupix <= '1';
        else
          busy_write_mupix <= '0';
          SLV_ACK_OUT      <= '1';
        end if;
        
        
      elsif SLV_WRITE_IN = '1' then
        case SLV_ADDR_IN is
          when x"0080" =>
            slowcontrol_reg_new <= SLV_DATA_IN;
            start_write_mupix   <= '1';
            busy_write_mupix    <= '1';
          when others =>
            SLV_UNKNOWN_ADDR_OUT <= '1';
        end case;
        
      elsif SLV_READ_IN = '1' then
        case SLV_ADDR_IN is
          when x"0080" =>
            SLV_DATA_OUT <= slowcontrol_reg_old;
            SLV_ACK_OUT  <= '1';
          when x"0081" =>
            SLV_DATA_OUT <= sout_from_mupix;
            SLV_ACK_OUT  <= '1';
          when others =>
            SLV_UNKNOWN_ADDR_OUT <= '1';
        end case;
      end if;
    end if;
  end process SLV_BUS;
  
end Behavioral;


