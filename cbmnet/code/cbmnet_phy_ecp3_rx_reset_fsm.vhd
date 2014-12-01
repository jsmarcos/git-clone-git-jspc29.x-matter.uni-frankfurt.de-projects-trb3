--Media interface RX state machine
-- initial version by lattice tempte
-- adopted by Jan Michel for sync. TrbNet
-- adopted by Manuel Penschuck for CbmNet phy


LIBRARY IEEE;
   USE IEEE.std_logic_1164.ALL;
   USE IEEE.numeric_std.all;
   use work.trb_net_std.all;



entity cbmnet_phy_ecp3_rx_reset_fsm is
   generic (
      IS_SIMULATED : integer range 0 to 1 := c_NO
   );
   port (
      RST_N             : in std_logic;
      RX_REFCLK         : in std_logic;
      TX_PLL_LOL_QD_S   : in std_logic;
      RX_CDR_LOL_CH_S   : in std_logic;
      RX_LOS_LOW_CH_S   : in std_logic;

      RM_RESET_IN          : in std_logic := '0';
      PROPER_BYTE_ALIGN_IN : in std_logic := '1';
      PROPER_WORD_ALIGN_IN : in std_logic := '1';

      RX_SERDES_RST_CH_C: out std_logic;
      RX_PCS_RST_CH_C   : out std_logic;
      STATE_OUT         : out std_logic_vector(3 downto 0)
   );
end entity ;
                                                                                              
architecture rx_reset_fsm_arch of cbmnet_phy_ecp3_rx_reset_fsm is
   constant count_index : integer := 19;
   type statetype is (WAIT_FOR_PLOL, RX_SERDES_RESET, WAIT_FOR_timer1, CHECK_LOL_LOS, WAIT_FOR_timer2, NORMAL);
                                                                                                
   signal   cs:      statetype;  -- current state of lsm
   signal   ns:      statetype;  -- next state of lsm
                                                                                                
   signal   tx_pll_lol_qd_s_int: std_logic;
   signal   rx_los_low_int:         std_logic;
   signal   rx_lol_los  :  std_logic;
   signal   rx_lol_los_int:      std_logic;
   signal   rx_lol_los_del:      std_logic;
   signal   rx_pcs_rst_ch_c_int: std_logic;
   signal   rx_serdes_rst_ch_c_int: std_logic;
                                                                                                
   signal   reset_timer2:  std_logic;
                                                                                                
   signal   counter2: unsigned(19 downto 0);
   signal   timer2   : std_logic;
                                        
   signal rm_reset_i          : std_logic;
   signal proper_byte_align_i : std_logic;
   signal proper_word_align_i : std_logic;                                        
begin
                                                                                              
   rx_lol_los <= rx_cdr_lol_ch_s or rx_los_low_ch_s ;
                                                                                                
   proc_fsm_sync: process(RX_REFCLK)
   begin
   if rising_edge(RX_REFCLK) then
      if RST_N = '0' then
         cs <= WAIT_FOR_PLOL;
         rx_lol_los_int <= '1';
         rx_lol_los_del <= '1';
         tx_pll_lol_qd_s_int <= '1';
         RX_PCS_RST_CH_C <= '1';
         RX_SERDES_RST_CH_C <= '0';
         rx_los_low_int <= '1';
      else
         cs <= ns;
         rx_lol_los_del <= rx_lol_los;
         rx_lol_los_int <= rx_lol_los_del;
         
         tx_pll_lol_qd_s_int <= tx_pll_lol_qd_s;
         
         RX_PCS_RST_CH_C <= rx_pcs_rst_ch_c_int;
         RX_SERDES_RST_CH_C <= rx_serdes_rst_ch_c_int;
         rx_los_low_int <= rx_los_low_ch_s;
         
         rm_reset_i <= RM_RESET_IN;
         proper_byte_align_i <= PROPER_BYTE_ALIGN_IN;
         proper_word_align_i <= PROPER_WORD_ALIGN_IN;
      end if;
   end if;
   end process;
                                                                                             
                                                                                              
--timer2 = 400,000 Refclk cycles or 200,000 REFCLKDIV2 cycles
--An 18 bit counter ([17:0]) counts 262144 cycles, so a 19 bit ([18:0]) counter will do if we set timer2 = bit[18]
  proc_timer2: process begin
    wait until rising_edge(RX_REFCLK);
    if reset_timer2 = '1' then
      counter2 <= "00000000000000000000";
      timer2 <= '0';
    else
      if counter2(count_index) = '1' or (IS_SIMULATED = c_YES and counter2(5) = '1') then
        timer2 <='1';
      else
        timer2 <='0';
        counter2 <= counter2 + 1 ;
      end if;
    end if;
   end process;
                                                                                              
                                                                                              
   proc_fsm_trans: process(cs, tx_pll_lol_qd_s_int, rx_los_low_int, rx_lol_los_int, rx_lol_los_del,
                           timer2, proper_word_align_i, proper_byte_align_i, rx_lol_los_int, rm_reset_i)
   begin
      reset_timer2 <= '0';
      STATE_OUT <= x"F";                                                                                              
      case cs is
         when WAIT_FOR_PLOL =>
            rx_pcs_rst_ch_c_int <= '1';
            rx_serdes_rst_ch_c_int <= '0';
            if (tx_pll_lol_qd_s_int = '1' or rx_los_low_int = '1') then  --Also make sure A Signal
               ns <= WAIT_FOR_PLOL;             --is Present prior to moving to the next
            else
               ns <= RX_SERDES_RESET;
            end if;
            STATE_OUT <= x"1";
                                                                                                
         when RX_SERDES_RESET =>
            rx_pcs_rst_ch_c_int <= '1';
            rx_serdes_rst_ch_c_int <= '1';
            ns <= WAIT_FOR_timer1;
            STATE_OUT <= x"2";
                                                                                                
                                                                                                
         when WAIT_FOR_timer1 =>
            rx_pcs_rst_ch_c_int <= '1';
            rx_serdes_rst_ch_c_int <= '1';
            ns <= CHECK_LOL_LOS;
            STATE_OUT <= x"3";

         when CHECK_LOL_LOS =>
            rx_pcs_rst_ch_c_int <= '1';
            rx_serdes_rst_ch_c_int <= '0';
            reset_timer2 <= '1';
            ns <= WAIT_FOR_timer2;
            STATE_OUT <= x"4";

         when WAIT_FOR_timer2 =>
            rx_pcs_rst_ch_c_int <= '1';
            rx_serdes_rst_ch_c_int <= '0';
            if rx_lol_los_int = rx_lol_los_del then   --NO RISING OR FALLING EDGES
               if timer2 = '1' then
                  if rx_lol_los_int = '1' then
                     ns <= WAIT_FOR_PLOL;
                  else
                     ns <= NORMAL;
                  end if;
               else
                  ns <= WAIT_FOR_timer2;
               end if;
            else
               ns <= CHECK_LOL_LOS;    --RESET timer2
            end if;
            STATE_OUT <= x"5";

                                                                                                
         when NORMAL =>
            rx_pcs_rst_ch_c_int <= '0';
            rx_serdes_rst_ch_c_int <= '0';
            if rx_lol_los_int = '1' or proper_byte_align_i = '0' or proper_word_align_i = '0' or rm_reset_i = '1' then
               ns <= WAIT_FOR_PLOL;
            else
               ns <= NORMAL;
            end if;
            STATE_OUT <= x"6";
                                                                                                
         when others =>
            ns <= WAIT_FOR_PLOL;
                                                                                             
      end case;
   end process;
                                                                                              
end architecture;