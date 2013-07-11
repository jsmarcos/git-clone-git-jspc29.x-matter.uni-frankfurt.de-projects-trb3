library ieee;
USE IEEE.std_logic_1164.ALL;
use ieee.numeric_std.all;
use work.trb_net_std.all;

package config is


------------------------------------------------------------------------------
--Begin of configuration
------------------------------------------------------------------------------

--include TDC for all four trigger input lines
    constant INCLUDE_TDC : integer range c_NO to c_YES := c_NO;
    
--use all four SFP (1-4) as downlink to other boards.     
    constant USE_4_SFP   : integer range c_NO to c_YES := c_NO;

    
--Run wih 125 MHz instead of 100 MHz     
    constant USE_125_MHZ : integer range c_NO to c_YES := c_NO;    

--Which external trigger module (ETM) to use?
    type ETM_CHOICE_type is (ETM_CHOICE_MBS_VULOM, ETM_CHOICE_MAINZ_A2);
    constant ETM_CHOICE : ETM_CHOICE_type := ETM_CHOICE_MBS_VULOM;
    
------------------------------------------------------------------------------
--End of configuration
------------------------------------------------------------------------------



   
--Ports:
--        LVL1/IPU       SCtrl
--  0     FPGA 1         FPGA 1
--  1     FPGA 2         FPGA 2
--  2     FPGA 3         FPGA 3
--  3     FPGA 4         FPGA 4
--  4     opt. link      opt. link
--  5-7   SFP 2-4
--  5(8)  CTS read-out   internal         0 1 -   X X O   --downlink only
--  6(9)  CTS TRG        Sctrl GbE        2 3 4   X X X   --uplink only


    
 
 
------------------------------------------------------------------------------
--Hub configuration 
------------------------------------------------------------------------------
    type hub_mii_t is array(0 to 1) of integer;    
    type hub_ct    is array(0 to 16) of integer;
    type hub_cfg_t is array(0 to 1) of hub_ct;    
    type hw_info_t is array(0 to 1) of std_logic_vector(31 downto 0);
    
  --this is used to select the proper configuration in the main code    
    constant CFG_MODE : integer;
    
    
  --first entry is normal CTS with one optical output, second one is with four optical outputs
  --slow-control is accepted on SFP1 only, triggers are sent to all used SFP
    constant INTERNAL_NUM_ARR     : hub_mii_t := (5,5);
    constant INTERFACE_NUM_ARR    : hub_mii_t := (5,8);
    constant IS_UPLINK_ARR        : hub_cfg_t := ((0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0),
                                                  (0,0,0,0,0,0,0,0,1,0,1,0,0,0,0,0,0));
    constant IS_DOWNLINK_ARR      : hub_cfg_t := ((1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0),
                                                  (1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0));
    constant IS_UPLINK_ONLY_ARR   : hub_cfg_t := ((0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0),
                                                  (0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0)); 
    constant HARDWARE_INFO_ARR    : hw_info_t := (x"9000CEE0",x"9000CEE2");
                          
    constant INTERNAL_NUM         : integer;
    constant INTERFACE_NUM        : integer;
    constant IS_UPLINK            : hub_ct;
    constant IS_DOWNLINK          : hub_ct;
    constant IS_UPLINK_ONLY       : hub_ct;
    constant HARDWARE_INFO        : std_logic_vector(31 downto 0);
    
    -- MII_NUMBER        => 5, --(8)
    -- INT_NUMBER        => 5,
    -- INT_CHANNELS      => (0,1,0,1,3),

    -- No trigger / sctrl sent to optical link, slow control receiving possible
    -- MII_IS_UPLINK        => (0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0);
    -- MII_IS_DOWNLINK      => (1,1,1,1,0,1,0,0,0,0,0,0,0,0,0,0,0);
    -- MII_IS_UPLINK_ONLY   => (0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0);

    -- Trigger / sctrl sent to optical link, slow control receiving possible
    -- MII_IS_UPLINK        => (0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0);
    -- MII_IS_DOWNLINK      => (1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0);
    -- MII_IS_UPLINK_ONLY   => (0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0);
    -- & disable port 4 in c0 and c1 -- no triggers from/to optical link

    -- Trigger / sctrl sent to 4 optical links
    -- MII_IS_UPLINK        => (0,0,0,0,0,0,0,0,1,0,1,0,0,0,0,0,0);
    -- MII_IS_DOWNLINK      => (1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0);
    -- MII_IS_UPLINK_ONLY   => (0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0);
    -- & disable port 4 in c0 and c1 -- no triggers from/to optical link

------------------------------------------------------------------------------
--CTS configuration
------------------------------------------------------------------------------
    constant cts_rdo_additional_ports : integer;

end;

package body config is
--compute correct configuration mode
  constant CFG_MODE : integer := USE_4_SFP;
  constant cts_rdo_additional_ports : integer := 1 + INCLUDE_TDC;

  constant HARDWARE_INFO        : std_logic_vector (31 downto 0) := HARDWARE_INFO_ARR(INCLUDE_TDC);
  constant INTERNAL_NUM         : integer := INTERNAL_NUM_ARR(CFG_MODE);
  constant INTERFACE_NUM        : integer := INTERFACE_NUM_ARR(CFG_MODE);
  constant IS_UPLINK            : hub_ct  := IS_UPLINK_ARR(CFG_MODE);
  constant IS_DOWNLINK          : hub_ct  := IS_DOWNLINK_ARR(CFG_MODE);
  constant IS_UPLINK_ONLY       : hub_ct  := IS_UPLINK_ONLY_ARR(CFG_MODE); 
  
  
end package body;
