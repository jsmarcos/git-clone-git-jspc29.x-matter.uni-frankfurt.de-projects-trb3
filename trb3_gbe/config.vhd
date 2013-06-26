library ieee;
USE IEEE.std_logic_1164.ALL;
use ieee.numeric_std.all;
use work.trb_net_std.all;

use work.trb_net16_hub_func.all;

package config is


------------------------------------------------------------------------------
--Begin of design configuration
------------------------------------------------------------------------------

--use all four SFP, 1 as uplink, 2-4 as downlink to other boards.     
--    constant USE_4_SFP   : integer range c_NO to c_YES := c_NO;


--Include GbE logic     
    constant USE_ETHERNET           : integer := c_YES;    
    
--Run wih 125 MHz instead of 100 MHz     
    constant USE_125_MHZ            : integer := c_NO;    
   
--Only slow-control, no trigger or read-out
    constant USE_SCTRL_ONLY         : integer := c_NO;    

--Use sync mode, RX clock for all parts of the FPGA
    constant USE_RXCLOCK            : integer := c_NO;
    
   
--Address settings   
    constant INIT_ENDPOINT_ID       : std_logic_vector := x"0005";
    constant INIT_ADDRESS           : std_logic_vector := x"F305";
    constant BROADCAST_SPECIAL_ADDR : std_logic_vector := x"40";
   
------------------------------------------------------------------------------
--End of design configuration
------------------------------------------------------------------------------




-- Be careful when setting the MII_NUMBER and MII_IS_* generics!

--With GbE:
-- for MII_NUMBER=5 (4 downlinks, 1 uplink):
-- port 0,1,2,3: downlinks to other FPGA
-- port 4: LVL1/Data channel on uplink to CTS, but internal endpoint on SCTRL
-- port 5: SCTRL channel on uplink to CTS
-- port 6: SCTRL channel from GbE interface

--Not implemented currently:
--optical link SFP1 is uplink on TRG & IPU and downlink on sctrl  (e.g. connect a CTS, sctrl via GbE)
--     MII_IS_UPLINK       => (0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0),
--     MII_IS_DOWNLINK     => (1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0),
--     MII_IS_UPLINK_ONLY  => (0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0),
 
 
------------------------------------------------------------------------------
--Hub configuration 
------------------------------------------------------------------------------
    type hub_mii_t is array(0 to 1) of integer;    
--     type hub_ct    is array(0 to 16) of integer;
    type hub_cfg_t is array(0 to 1) of hub_mii_config_t;  
    type hw_info_t is array(0 to 7) of std_logic_vector(31 downto 0);
--     type hub_ch_t  is array(0 to 3) of integer;    
    type hub_chn_t is array(0 to 1) of hub_channel_config_t;

  --this is used to select the proper configuration in the main code    
    constant CFG_MODE : integer;

    --    --optical link SFP1 is uplink on all channels  (e.g. connect a Hub)


    constant INTERNAL_NUM_ARR     : hub_mii_t := (0,0);
    constant INTERFACE_NUM_ARR    : hub_mii_t := (5,5);
    constant IS_UPLINK_ARR        : hub_cfg_t := ((0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0),
                                                  (0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0));
    constant IS_DOWNLINK_ARR      : hub_cfg_t := ((1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1),
                                                  (1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0));
    constant IS_UPLINK_ONLY_ARR   : hub_cfg_t := ((0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0),
                                                  (0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0)); 
    constant INTERNAL_CHANNEL_ARR : hub_cfg_t := ((0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),                                                  
                                                  (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0));
    constant HARDWARE_INFO_ARR    : hw_info_t := (x"90000030",x"90000E30",x"90008030",x"90008E30",
                                                  x"90000020",x"90000E20",x"90008020",x"90008E20");
    constant USED_CHANNELS_ARR    : hub_chn_t := ((1,1,0,1),(0,0,0,1));
    constant CLOCK_FREQUENCY_ARR  : hub_mii_t := (100,125);
    constant MEDIA_FREQUENCY_ARR  : hub_mii_t := (200,125);
                          
  --declare constants, filled in body                          
    constant INTERNAL_NUM         : integer;
    constant INTERFACE_NUM        : integer;
    constant IS_UPLINK            : hub_mii_config_t;
    constant IS_DOWNLINK          : hub_mii_config_t;
    constant IS_UPLINK_ONLY       : hub_mii_config_t;
    constant INTERNAL_CHANNELS    : hub_mii_config_t;
    constant HARDWARE_INFO        : std_logic_vector(31 downto 0);
    constant USED_CHANNELS        : hub_channel_config_t;
    constant CLOCK_FREQUENCY      : integer;
    constant MEDIA_FREQUENCY      : integer;

end;

package body config is
--compute correct configuration mode
  constant CFG_MODE : integer := USE_ETHERNET;
  constant HW_INFO_MODE : integer := USE_ETHERNET + 2 * USE_RXCLOCK + 4 * USE_SCTRL_ONLY;

  constant INTERNAL_NUM         : integer := INTERNAL_NUM_ARR(CFG_MODE);
  constant INTERFACE_NUM        : integer := INTERFACE_NUM_ARR(CFG_MODE);
  constant IS_UPLINK            : hub_mii_config_t  := IS_UPLINK_ARR(CFG_MODE);
  constant IS_DOWNLINK          : hub_mii_config_t  := IS_DOWNLINK_ARR(CFG_MODE);
  constant IS_UPLINK_ONLY       : hub_mii_config_t  := IS_UPLINK_ONLY_ARR(CFG_MODE); 
  constant INTERNAL_CHANNELS    : hub_mii_config_t  := INTERNAL_CHANNEL_ARR(CFG_MODE); 
  constant HARDWARE_INFO        : std_logic_vector(31 downto 0) := HARDWARE_INFO_ARR(HW_INFO_MODE);
  constant USED_CHANNELS        : hub_channel_config_t := USED_CHANNELS_ARR(USE_SCTRL_ONLY);
  constant CLOCK_FREQUENCY      : integer := CLOCK_FREQUENCY_ARR(USE_125_MHZ);
  constant MEDIA_FREQUENCY      : integer := MEDIA_FREQUENCY_ARR(USE_125_MHZ);
  
end package body;