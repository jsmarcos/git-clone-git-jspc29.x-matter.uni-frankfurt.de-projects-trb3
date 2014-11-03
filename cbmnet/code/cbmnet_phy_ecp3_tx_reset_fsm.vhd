--Media interface TX state machine


LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.all;
   use work.trb_net_std.all;


entity cbmnet_phy_ecp3_tx_reset_fsm is
   generic (
      IS_SIMULATED : integer range 0 to 1 := c_NO
   );
   port (
      RST_N           : in std_logic;
      TX_REFCLK       : in std_logic;   
      TX_PLL_LOL_QD_S : in std_logic;
      RST_QD_C        : out std_logic;
      TX_PCS_RST_CH_C : out std_logic;
      STATE_OUT       : out std_logic_vector(3 downto 0)

   );
end entity;
                                                                                              
architecture tx_reset_fsm_arch of cbmnet_phy_ecp3_tx_reset_fsm is
   constant count_index : integer := 19;                                                                                            
   type statetype is (QUAD_RESET, WAIT_FOR_TIMER1, CHECK_PLOL, WAIT_FOR_TIMER2, NORMAL);
                                                                                                
   signal   cs:      statetype;  -- current state of lsm
   signal   ns:      statetype;  -- next state of lsm
                                                                                                
   signal   tx_pll_lol_qd_s_int  : std_logic;
   signal   tx_pcs_rst_ch_c_int  : std_logic;
   signal   RST_QD_C_int      : std_logic;
                                                                                                
   signal   reset_timer1:  std_logic;
   signal   reset_timer2:  std_logic;
                                                                                                
   signal   counter1:      unsigned(2 downto 0);
   signal   TIMER1:        std_logic;
                                                                                                
   signal   counter2:      unsigned(19 downto 0);
   signal   TIMER2:        std_logic;

begin
                                                                                              
process (TX_REFCLK, RST_N)
begin
  if RST_N = '0' then
      cs <= QUAD_RESET;
      tx_pll_lol_qd_s_int <= '1';
      tx_pcs_rst_ch_c <= '1';
      RST_QD_C <= '1';
  else if rising_edge(TX_REFCLK) then
      cs <= ns;
      tx_pll_lol_qd_s_int <= tx_pll_lol_qd_s;
      tx_pcs_rst_ch_c <= tx_pcs_rst_ch_c_int;
      RST_QD_C <= RST_QD_C_int;
  end if;
  end if;
end process;
--TIMER1 = 20ns;
--Fastest REFLCK =312 MHZ, or 3 ns. We need 8 REFCLK cycles or 4 REFCLKDIV2 cycles
-- A 2 bit counter ([1:0]) counts 4 cycles, so a 3 bit ([2:0]) counter will do if we set TIMER1 = bit[2]
                                                                                              
                                                                                              
process (TX_REFCLK)
begin
  if rising_edge(TX_REFCLK) then
      if reset_timer1 = '1' then
        counter1 <= "000";
        TIMER1 <= '0';
      else
        if counter1(2) = '1' then
            TIMER1 <= '1';
        else
            TIMER1 <='0';
            counter1 <= counter1 + 1 ;
        end if;
      end if;
  end if;
end process;
                                                                                              
                                                                                              
--TIMER2 = 1,400,000 UI;
--WORST CASE CYCLES is with smallest multipier factor.
-- This would be with X8 clock multiplier in DIV2 mode
-- IN this casse, 1 UI = 2/8 REFCLK  CYCLES = 1/8 REFCLKDIV2 CYCLES
-- SO 1,400,000 UI =1,400,000/8 = 175,000 REFCLKDIV2 CYCLES
-- An 18 bit counter ([17:0]) counts 262144 cycles, so a 19 bit ([18:0]) counter will do if we set TIMER2 = bit[18]
                                                                                              
                                                                                              
process(TX_REFCLK, reset_timer2)
begin
  if rising_edge(TX_REFCLK) then
      if reset_timer2 = '1' then
        counter2 <= "00000000000000000000";
        TIMER2 <= '0';
      else
        if counter2(count_index) = '1' or (IS_SIMULATED = c_YES and counter2(5) = '1') then
            TIMER2 <='1';
        else
            TIMER2 <='0';
            counter2 <= counter2 + 1 ;
        end if;
      end if;
  end if;
end process;
                                                                                              
process(cs, TIMER1, TIMER2, tx_pll_lol_qd_s_int)
begin
   reset_timer1 <= '0';
   reset_timer2 <= '0';
   STATE_OUT <= x"F";
                                                                                             
   case cs is
      when QUAD_RESET   =>
         STATE_OUT <= x"1";
         tx_pcs_rst_ch_c_int <= '1';
         RST_QD_C_int <= '1';
         reset_timer1 <= '1';
         ns <= WAIT_FOR_TIMER1;
                                                                        
      when WAIT_FOR_TIMER1 =>
         STATE_OUT <= x"2";
         tx_pcs_rst_ch_c_int <= '1';
         RST_QD_C_int <= '1';
         if TIMER1 = '1' then
            ns <= CHECK_PLOL;
         else
            ns <= WAIT_FOR_TIMER1;
         end if;
                                                                        
      when CHECK_PLOL   =>
         STATE_OUT <= x"3";
         tx_pcs_rst_ch_c_int <= '1';
         RST_QD_C_int <= '0';
         reset_timer2 <= '1';
         ns <= WAIT_FOR_TIMER2;
                                                                        
      when WAIT_FOR_TIMER2 =>
         STATE_OUT <= x"4";
         tx_pcs_rst_ch_c_int <= '1';
         RST_QD_C_int <= '0';
         if TIMER2 = '1' then
            if tx_pll_lol_qd_s_int = '1' then
               ns <= QUAD_RESET;
            else
               ns <= NORMAL;
            end if;
         else
            ns <= WAIT_FOR_TIMER2;
         end if;
                                                                        
      when NORMAL =>
         STATE_OUT <= x"5";
         tx_pcs_rst_ch_c_int <= '0';
         RST_QD_C_int <= '0';
         if tx_pll_lol_qd_s_int = '1' then
            ns <= QUAD_RESET;
         else
            ns <= NORMAL;
         end if;
                                                                        
      when others =>
         ns <=    QUAD_RESET;
                                                                                             
   end case;
end process;
                                                                                              
end architecture;