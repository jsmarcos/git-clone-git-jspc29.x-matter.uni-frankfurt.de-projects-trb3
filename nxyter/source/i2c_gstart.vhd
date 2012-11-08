library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.adcmv3_components.all;

entity I2C_GSTART is
  port(
    CLK_IN          : in    std_logic;
    RESET_IN        : in    std_logic;
    START_IN        : in    std_logic;
    DOSTART_IN      : in    std_logic;
    I2C_SPEED_IN    : in    std_logic_vector(8 downto 0);
    SDONE_OUT       : out   std_logic;
    SOK_OUT         : out   std_logic;
    SDA_IN          : in    std_logic;
    SCL_IN          : in    std_logic;
    R_SCL_OUT       : out   std_logic;
    S_SCL_OUT       : out   std_logic;
    R_SDA_OUT       : out   std_logic;
    S_SDA_OUT       : out   std_logic;
    BSM_OUT         : out   std_logic_vector(3 downto 0)
    );
end entity;

architecture Behavioral of I2C_GSTART is

-- Signals
  type STATES is (SLEEP,
                  P_SCL,
                  WCTR0,
                  P_SDA,
                  WCTR1,
                  P_CHK,
                  S_CHK0,
                  RS_SDA,
                  S_CHK1,
                  ERROR,
                  DONE);
  signal CURRENT_STATE, NEXT_STATE: STATES;

  signal bsm          : std_logic_vector(3 downto 0);
  signal cctr         : unsigned(8 downto 0); -- counter for bit length

  signal cycdone_x    : std_logic;
  signal cycdone      : std_logic; -- one counter period done

  signal load_cyc_x   : std_logic;
  signal load_cyc     : std_logic;
  signal dec_cyc_x    : std_logic;
  signal dec_cyc      : std_logic;
  signal sdone_x      : std_logic;
  signal sdone        : std_logic; -- Start/Stop done
  signal sok_x        : std_logic;
  signal sok          : std_logic; -- Start/Stop OK

  signal r_scl        : std_logic;
  signal s_scl        : std_logic;
  signal r_sda        : std_logic;
  signal s_sda        : std_logic;

-- Moduls

begin

-- Countdown for one half of SCL (adjustable clock width)
  THE_CYC_CTR_PROC: process( clk_in )
  begin
    if( rising_edge(clk_in) ) then
      if( reset_in = '1' ) then
        cctr <= (others => '0');
      elsif( load_cyc = '1' ) then
        cctr <= i2c_speed_in;
      elsif( dec_cyc = '1' ) then
        cctr <= cctr - 1;
      end if;
    end if;
  end process THE_CYC_CTR_PROC;

-- end of cycle recognition
  cycdone_x <= '1' when (cctr = 0) else '0';

-- The main state machine
-- State memory process
  STATE_MEM: process( clk_in )
  begin
    if ( rising_edge(clk_in) ) then
      if( reset_in = '1' ) then
        CURRENT_STATE <= SLEEP;
        load_cyc      <= '0';
        dec_cyc       <= '0';
        sdone         <= '0';
        sok           <= '0';
        cycdone       <= '0';
      else
        CURRENT_STATE <= NEXT_STATE;
        load_cyc      <= load_cyc_x;
        dec_cyc       <= dec_cyc_x;
        sdone         <= sdone_x;
        sok           <= sok_x;
        cycdone       <= cycdone_x;
      end if;
    end if;
  end process STATE_MEM;

-- Transition matrix
  TRANSFORM: process(CURRENT_STATE, dostart_in, start_in, sda_in, scl_in, cycdone)
  begin
    NEXT_STATE <= SLEEP;
    load_cyc_x <= '0';
    dec_cyc_x  <= '0';
    sdone_x    <= '0';
    sok_x      <= '1';
    case CURRENT_STATE is
      when SLEEP  =>  if   ( (dostart_in = '1') and (start_in = '1') ) then
                        NEXT_STATE <= S_CHK0; -- generate a start condition
                        load_cyc_x <= '1';
                      elsif( (dostart_in = '1') and (start_in = '0') ) then
                        NEXT_STATE <= P_SCL; -- generate a stop condition
                        load_cyc_x <= '1';
                      else
                        NEXT_STATE <= SLEEP;
                      end if;
      when P_SCL  =>  NEXT_STATE <= WCTR0;
                      dec_cyc_x  <= '1';
      when S_CHK0 =>  if( (sda_in = '1') and (scl_in = '1') ) then
                        NEXT_STATE <= RS_SDA;
                      else
                        NEXT_STATE <= ERROR;
                        sok_x      <= '0';
                      end if;
      when RS_SDA =>  NEXT_STATE <= WCTR0;
                      dec_cyc_x  <= '1';
      when WCTR0  =>  if   ( (cycdone = '1') and (start_in = '1') ) then
                        NEXT_STATE <= S_CHK1;
                      elsif( (cycdone = '1') and (start_in = '0') ) then
                        NEXT_STATE <= P_SDA;
                        load_cyc_x <= '1';
                      else
                        NEXT_STATE <= WCTR0;
                        dec_cyc_x  <= '1';
                      end if;
      when S_CHK1 =>  if( (sda_in = '0') and (scl_in = '1') ) then
                        NEXT_STATE <= DONE;
                      else
                        NEXT_STATE <= ERROR;
                        sok_x      <= '0';
                      end if;
      when P_SDA  =>  NEXT_STATE <= WCTR1;
                      dec_cyc_x  <= '1';
      when WCTR1  =>  if( (cycdone = '1') ) then
                        NEXT_STATE <= P_CHK;
                      else
                        NEXT_STATE <= WCTR1;
                        dec_cyc_x  <= '1';
                      end if;
      when P_CHK  =>  if( (sda_in = '1') and (scl_in = '1') ) then
                        NEXT_STATE <= DONE;
                        sdone_x    <= '1';
                      else
                        NEXT_STATE <= ERROR;
                        sok_x      <= '0';
                      end if;
      when ERROR  =>  if( dostart_in = '0' ) then
                        NEXT_STATE <= SLEEP;
                      else
                        NEXT_STATE <= ERROR;
                        sdone_x    <= '1';
                        sok_x      <= '0';
                      end if;
      when DONE   =>  if( dostart_in = '0' ) then
                        NEXT_STATE <= SLEEP;
                      else
                        NEXT_STATE <= DONE;
                        sdone_x    <= '1';
                      end if;
      when others =>  NEXT_STATE <= SLEEP;
    end case;
  end process TRANSFORM;

-- Output decoding
  DECODE: process(CURRENT_STATE)
  begin
    case CURRENT_STATE is
      when SLEEP  =>  bsm <= x"0";
      when S_CHK0 =>  bsm <= x"1";
      when RS_SDA =>  bsm <= x"2";
      when P_SCL  =>  bsm <= x"3";
      when WCTR0  =>  bsm <= x"4";
      when S_CHK1 =>  bsm <= x"5";
      when P_SDA  =>  bsm <= x"6";
      when WCTR1  =>  bsm <= x"7";
      when P_CHK  =>  bsm <= x"8";
      when DONE   =>  bsm <= x"9";
      when ERROR  =>  bsm <= x"e";
      when others =>  bsm <= x"f";
    end case;
  end process DECODE;

  S_R_GEN: process(CURRENT_STATE)
  begin
    if   ( CURRENT_STATE = P_SCL ) then
      r_scl <= '0';
      s_scl <= '1';
      r_sda <= '0';
      s_sda <= '0';
    elsif( CURRENT_STATE = RS_SDA ) then
      r_scl <= '0';
      s_scl <= '0';
      r_sda <= '1';
      s_sda <= '0';
    elsif( CURRENT_STATE = P_SDA ) then
      r_scl <= '0';
      s_scl <= '0';
      r_sda <= '0';
      s_sda <= '1';
    else
      r_scl <= '0';
      s_scl <= '0';
      r_sda <= '0';
      s_sda <= '0';
    end if;
  end process S_R_GEN;

-- Outputs
  r_scl_out <= r_scl;
  s_scl_out <= s_scl;
  r_sda_out <= r_sda;
  s_sda_out <= s_sda;
  sdone_out <= sdone;
  sok_out   <= sok;

-- Debug
  bsm_out <= bsm;

end Behavioral;
