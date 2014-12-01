-- Hardware Independent CBMNet Bridge components 

library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   
library work;
   use work.trb_net_std.all;

package cbmnet_interface_pkg is
   component cbmnet_bridge is
      port (
      -- clock and reset
         CLK125_IN : in std_logic;
         ASYNC_RESET_IN : in std_logic;         
         TRB_CLK_IN : in std_logic;
         TRB_RESET_IN : in std_logic;
         
         CBM_CLK_OUT : out std_logic;
         CBM_RESET_OUT: out std_logic;
         
         REBOOT_FPGA_OUT: out std_logic;
         
      -- Media Interface
         SD_RXD_P_IN        : in  std_logic := '0';
         SD_RXD_N_IN        : in  std_logic := '0';
         SD_TXD_P_OUT       : out std_logic := '0';
         SD_TXD_N_OUT       : out std_logic := '0';

         SD_PRSNT_N_IN      : in  std_logic;  -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
         SD_LOS_IN          : in  std_logic;  -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
         SD_TXDIS_OUT       : out  std_logic := '0'; -- SFP disable

         LED_RX_OUT         : out std_logic;
         LED_TX_OUT         : out std_logic;
         LED_OK_OUT         : out std_logic;
         
      -- Status and strobes   
         CBM_LINK_ACTIVE_OUT     : out std_logic;
         CBM_DLM_OUT             : out std_logic;
         CBM_TIMING_TRIGGER_OUT  : out std_logic;
         CBM_SYNC_PULSER_OUT     : out std_logic;

      -- TRBNet Terminal
         --data output for read-out
         TRB_TRIGGER_IN       : in  std_logic;
         TRB_RDO_VALID_DATA_TRG_IN  : in  std_logic;
         TRB_RDO_VALID_NO_TIMING_IN : in  std_logic;
         TRB_RDO_DATA_OUT     : out std_logic_vector(31 downto 0);
         TRB_RDO_WRITE_OUT    : out std_logic;
         TRB_RDO_STATUSBIT_OUT: out std_logic_vector(31 downto 0);
         TRB_RDO_FINISHED_OUT : out std_logic;
         
         TRB_TRIGGER_OUT : out std_logic;
      
         -- connect to hub
         HUB_CTS_NUMBER_IN              : in  std_logic_vector (15 downto 0);
         HUB_CTS_CODE_IN                : in  std_logic_vector (7  downto 0);
         HUB_CTS_INFORMATION_IN         : in  std_logic_vector (7  downto 0);
         HUB_CTS_READOUT_TYPE_IN        : in  std_logic_vector (3  downto 0);
         HUB_CTS_START_READOUT_IN       : in  std_logic;
         HUB_CTS_READOUT_FINISHED_OUT   : out std_logic;  --no more data, end transfer, send TRM
         HUB_CTS_STATUS_BITS_OUT        : out std_logic_vector (31 downto 0);
         HUB_FEE_DATA_IN                : in  std_logic_vector (15 downto 0);
         HUB_FEE_DATAREADY_IN           : in  std_logic;
         HUB_FEE_READ_OUT               : out std_logic;  --must be high when idle, otherwise you will never get a dataready
         HUB_FEE_STATUS_BITS_IN         : in  std_logic_vector (31 downto 0);
         HUB_FEE_BUSY_IN                : in  std_logic;   

         -- connect to GbE
         GBE_CTS_NUMBER_OUT             : out std_logic_vector (15 downto 0);
         GBE_CTS_CODE_OUT               : out std_logic_vector (7  downto 0);
         GBE_CTS_INFORMATION_OUT        : out std_logic_vector (7  downto 0);
         GBE_CTS_READOUT_TYPE_OUT       : out std_logic_vector (3  downto 0);
         GBE_CTS_START_READOUT_OUT      : out std_logic;
         GBE_CTS_READOUT_FINISHED_IN    : in  std_logic;      --no more data, end transfer, send TRM
         GBE_CTS_STATUS_BITS_IN         : in  std_logic_vector (31 downto 0);
         GBE_FEE_DATA_OUT               : out std_logic_vector (15 downto 0);
         GBE_FEE_DATAREADY_OUT          : out std_logic;
         GBE_FEE_READ_IN                : in  std_logic;  --must be high when idle, otherwise you will never get a dataready
         GBE_FEE_STATUS_BITS_OUT        : out std_logic_vector (31 downto 0);
         GBE_FEE_BUSY_OUT               : out std_logic;

         -- reg io
         -- reg io
         REGIO_ADDR_IN                  : in  std_logic_vector(15 downto 0);
         REGIO_DATA_IN                  : in  std_logic_vector(31 downto 0);
         REGIO_READ_ENABLE_IN           : in  std_logic;
         REGIO_WRITE_ENABLE_IN          : in  std_logic;
         REGIO_TIMEOUT_IN               : in  std_logic;
         REGIO_DATA_OUT                 : out std_logic_vector(31 downto 0);
         REGIO_DATAREADY_OUT            : out std_logic;
         REGIO_WRITE_ACK_OUT            : out std_logic;
         REGIO_NO_MORE_DATA_OUT         : out std_logic;
         REGIO_UNKNOWN_ADDR_OUT         : out std_logic;
         
         DEBUG_OUT : out std_logic_vector(31 downto 0)
      );
   end component;
   
   component trbnet_rdo_pattern_generator is
      port (
         CLK_IN : in std_logic;
         RESET_IN : in std_logic;
      
         HUB_CTS_NUMBER_OUT          : out  std_logic_vector (15 downto 0);
         HUB_CTS_CODE_OUT            : out  std_logic_vector (7  downto 0);
         HUB_CTS_OUTFORMATION_OUT    : out  std_logic_vector (7  downto 0);
         HUB_CTS_READOUT_TYPE_OUT    : out  std_logic_vector (3  downto 0);
         HUB_CTS_START_READOUT_OUT   : out  std_logic;
         HUB_CTS_READOUT_FINISHED_IN : in std_logic;  --no more data, end transfer, send TRM
         HUB_CTS_STATUS_BITS_IN      : in std_logic_vector (31 downto 0);
         HUB_FEE_DATA_OUT            : out  std_logic_vector (15 downto 0);
         HUB_FEE_DATAREADY_OUT       : out  std_logic;
         HUB_FEE_READ_IN             : in std_logic;  --must be high when idle, otherwise you will never get a dataready
         HUB_FEE_STATUS_BITS_OUT     : out  std_logic_vector (31 downto 0);
         HUB_FEE_BUSY_OUT            : out  std_logic;      


         REGIO_READ_ENABLE_IN   : in  std_logic; 
         REGIO_WRITE_ENABLE_IN  : in  std_logic; 
         REGIO_DATA_IN          : in  std_logic_vector (31 downto 0);
         REGIO_ADDR_IN          : in  std_logic_vector (15 downto 0);
         REGIO_TIMEOUT_IN       : in  std_logic; 
         REGIO_DATA_OUT         : out  std_logic_vector (31 downto 0);
         REGIO_DATAREADY_OUT    : out  std_logic; 
         REGIO_WRITE_ACK_OUT    : out  std_logic; 
         REGIO_NO_MORE_DATA_OUT : out  std_logic; 
         REGIO_UNKNOWN_ADDR_OUT : out  std_logic
      );
   end component;
   


   constant K280 : std_logic_vector(7 downto 0) := "00011100";
   constant K281 : std_logic_vector(7 downto 0) := "00111100";
   constant K282 : std_logic_vector(7 downto 0) := "01011100";
   constant K283 : std_logic_vector(7 downto 0) := "01111100";
   constant K284 : std_logic_vector(7 downto 0) := "10011100";
   constant K285 : std_logic_vector(7 downto 0) := "10111100";
   constant K286 : std_logic_vector(7 downto 0) := "11011100";
   constant K287 : std_logic_vector(7 downto 0) := "11111100";
   constant K237 : std_logic_vector(7 downto 0) := "11111110";
   constant K277 : std_logic_vector(7 downto 0) := "11111011";
   constant K297 : std_logic_vector(7 downto 0) := "11111101";
   constant K307 : std_logic_vector(7 downto 0) := "11111110";
   
   constant CBMNET_READY_CHAR0 : std_logic_vector(7 downto 0) :=  K284;
   constant CBMNET_READY_CHAR1 : std_logic_vector(7 downto 0) :=  K287;
   constant CBMNET_ALIGN_CHAR  : std_logic_vector(7 downto 0) :=  K285;
   
   component cn_rx_pcs_wrapper is
      generic (
         SIMULATION     : integer range 0 to 1 := 0;
         
         READY_CHAR0    : std_logic_vector(7 downto 0) :=  K284;
         READY_CHAR1    : std_logic_vector(7 downto 0) :=  K287;
         ALIGN_CHAR     : std_logic_vector(7 downto 0)  :=  K285;
         
         USE_BS         : integer range 0 to 1 := 1;  -- Use barrel-shifter, otherwise reset rx CDR
         SYNC_SIGNALS   : integer range 0 to 1 := 1; -- Sync input signals to rx clock domain

         INCL_8B10B_DEC : integer range 0 to 1 := 1
      );
      port (   
         rx_clk                  : in std_logic;
         res_n_rx                : in std_logic;
         rxpcs_reinit            : in std_logic;                     -- Reinit RXPCS 
         rxdata_in               : in std_logic_vector(19 downto 0);
         reset_rx_cdr            : out std_logic;                    -- Reset RX CDR to align
         rxpcs_almost_ready      : out std_logic;                    -- Ready1 detected, only waiting for break
         rxpcs_ready             : out std_logic;                    -- RXPCS initialization done
         see_reinit              : out std_logic;                    -- Initialization pattern detected although ready
         bs_position             : out std_logic_vector(4 downto 0); -- Number of bit-shifts necessary for word-alignment
         rxdata_out              : out std_logic_vector(17 downto 0);
         ebtb_detect             : out std_logic;                    -- Depends on the FSM state, alignment done
         wait_for_ready1         : out std_logic;
         
         --diagnostics
         ebtb_code_err_cntr_clr  : in std_logic;
         ebtb_disp_err_cntr_clr  : in std_logic;
         ebtb_code_err_cntr      : out std_logic_vector(15 downto 0); -- Counts for code errors if ebtb_detect is true
         ebtb_disp_err_cntr      : out std_logic_vector(15 downto 0); -- Counts for disparity errors if ebtb_detect is true
         ebtb_code_err_cntr_flag : out std_logic;
         ebtb_disp_err_cntr_flag : out std_logic
      );
   end component;


   component cn_tx_pcs_wrapper is
      generic (
         SIMULATION     : integer range 0 to 1 := 0;
      
         READY_CHAR0    : std_logic_vector( 7 downto 0) :=  K284;
         READY_CHAR1    : std_logic_vector( 7 downto 0) :=  K287;
         ALIGN_CHAR     : std_logic_vector( 7 downto 0) :=  K285;
         PMA_INIT_CHAR  : std_logic_vector(19 downto 0) := x"aaaaa";
         
         REVERSE_OUTPUT : integer range 0 to 1 := 1;
         LINK_MASTER    : integer range 0 to 1 := 1;
         SYNC_SIGNALS   : integer range 0 to 1 := 1;

         INCL_8B10B_ENC : integer range 0 to 1 := 1
      );
      port (
         tx_clk                 : in std_logic;
         res_n_tx               : in std_logic;
         pcs_restart            : in std_logic;          -- restart pcs layer
         pma_ready              : in std_logic;
         ebtb_detect            : in std_logic;            -- alignment done and valid 8b10b stream detected
         see_reinit             : in std_logic;
         rx_wait_for_ready1     : in std_logic;
         rxpcs_almost_ready     : in std_logic;
         txdata_in              : in std_logic_vector(17 downto 0);
         
         
         rx_bitdelay_done       : in std_logic;

         txpcs_ready            : out std_logic;
         link_lost              : out std_logic;
         reset_out              : out std_logic;
         rxpcs_reinit           : out std_logic;           -- Reinit the RXPCS FSM
         txdata_out             : out std_logic_vector(17 downto 0);             -- tx data to transceiver
         txdata_out_coded       : out std_logic_vector(19 downto 0);       -- tx data to transceiver already 8b10b coded
         
         --diagnostics
         pcs_startup_cntr_clr   : in std_logic;
         pcs_startup_cntr       : out std_logic_vector(15 downto 0);       -- Counts for link startups
         pcs_startup_cntr_flag  : out std_logic
      );
   end component;

   component cn_lp_top is
      port (
         clk          : in std_logic; --  Main clock
         res_n        : in std_logic; --  Active low reset, can be changed by define
         serdes_ready : in std_logic; --  signalize when PHY ready
         link_active  : out std_logic; --  link is active and can send and receive data

         -- send
         data2send_start : in std_logic; --  send data interface
         data2send_end   : in std_logic; 
         data2send       : in std_logic_vector(15 downto 0); 
         data2send_stop  : out std_logic; 

         ctrl2send_start : in std_logic; --  send control interface
         ctrl2send_end   : in std_logic; 
         ctrl2send       : in std_logic_vector(15 downto 0); 
         ctrl2send_stop  : out std_logic; 

         dlm2send    : in std_logic_vector(3 downto 0); -- // send dlm interface
         dlm2send_va : in std_logic; 

         -- receive
         data_rec_start : out std_logic; --  receive data interface 
         data_rec_end   : out std_logic; 
         data_rec       : out std_logic_vector(15 downto 0); 
         data_rec_stop  : in std_logic; 

         ctrl_rec_start : out std_logic; --  receive control interface   
         ctrl_rec_end   : out std_logic; 
         ctrl_rec       : out std_logic_vector(15 downto 0); 
         ctrl_rec_stop  : in  std_logic; 

         dlm_rec    : out std_logic_vector(3 downto 0); --receive dlm interface
         dlm_rec_va : out std_logic; 

         crc_error_cntr_flag : out std_logic;
         crc_error_cntr : out std_logic_vector(15 downto 0);
         crc_error_cntr_clr : in std_logic;
         
         -- link signals   
         data_from_link : in  std_logic_vector(17 downto 0); -- interface from the PHY
         data2link      : out std_logic_vector(17 downto 0) -- interface to the PHY   
      );
   end component;
   
   
   component lp_top is 
      generic (
         NUM_LANES : integer := 1;  -- Number of data lanes
         TX_SLAVE  : integer := 0   -- If set; module will act as TX slave; otherwise as RX slave
                                   -- If only one lane is used; parameter does not matter
      );
      port (
         clk               : in  std_logic; -- Main clock
         res_n             : in  std_logic; -- Active low reset; can be changed by define
         link_active       : out std_logic; -- link is active and can send and receive data

         ctrl2send_stop    : out std_logic; -- send control interface
         ctrl2send_start   : in  std_logic;
         ctrl2send_end     : in  std_logic;
         ctrl2send         : in  std_logic_vector(15 downto 0);

         data2send_stop    : out std_logic_vector(NUM_LANES-1 downto 0); -- send data interface
         data2send_start   : in  std_logic_vector(NUM_LANES-1 downto 0);
         data2send_end     : in  std_logic_vector(NUM_LANES-1 downto 0);
         data2send         : in  std_logic_vector((16*NUM_LANES)-1 downto 0);

         dlm2send_va       : in  std_logic;                      -- send dlm interface
         dlm2send          : in  std_logic_vector(3 downto 0);

         dlm_rec_type      : out std_logic_vector(3 downto 0);   -- receive dlm interface
         dlm_rec_va        : out std_logic;

         data_rec          : out std_logic_vector((16*NUM_LANES)-1 downto 0);   -- receive data interface
         data_rec_start    : out std_logic_vector(NUM_LANES-1 downto 0);
         data_rec_end      : out std_logic_vector(NUM_LANES-1 downto 0);         
         data_rec_stop     : in  std_logic_vector(NUM_LANES-1 downto 0);  
                     
         ctrl_rec          : out std_logic_vector(15 downto 0);       -- receive control interface
         ctrl_rec_start    : out std_logic;
         ctrl_rec_end      : out std_logic;                 
         ctrl_rec_stop     : in  std_logic;
                     
         data_from_link    : in  std_logic_vector((18*NUM_LANES)-1 downto 0);   -- interface from the PHY
         data2link         : out std_logic_vector((18*NUM_LANES)-1 downto 0);   -- interface to the PHY

         link_activeovr    : in  std_logic; -- Overrides; set 0 by default
         link_readyovr     : in  std_logic;

         SERDES_ready      : in  std_logic; -- signalize when PHY ready
               
         -- diagnostics Lane0
         crc_error_cntr_flag     : out std_logic_vector(NUM_LANES-1 downto 0);
         retrans_cntr_flag       : out std_logic_vector(NUM_LANES-1 downto 0);
         retrans_error_cntr_flag : out std_logic_vector(NUM_LANES-1 downto 0);
         crc_error_cntr          : out std_logic_vector(16*NUM_LANES-1 downto 0);
         retrans_cntr            : out std_logic_vector(16*NUM_LANES-1 downto 0);
         retrans_error_cntr      : out std_logic_vector(16*NUM_LANES-1 downto 0);
         crc_error_cntr_clr      : in  std_logic_vector(NUM_LANES-1 downto 0);
         retrans_cntr_clr        : in  std_logic_vector(NUM_LANES-1 downto 0);
         retrans_error_cntr_clr  : in  std_logic_vector(NUM_LANES-1 downto 0)
      );
   end component;

   component dlm_reflect is 
   port
   (
      clk            : in std_logic;
      res_n          : in std_logic;
      dlm_rec_in     : in std_logic_vector(3 downto 0);
      dlm_rec_va_in  : in std_logic;
      dlm_rec_out    : out std_logic_vector(3 downto 0);
      dlm_rec_va_out : out std_logic;
      dlm2send_va    : out std_logic;
      dlm2send       : out std_logic_vector(3 downto 0)
   );
   end component;
   
   component link_tester_be is
      generic (
         MIN_CTRL_PACKET_SIZE : integer := 12;
         MAX_CTRL_PACKET_SIZE : integer := 60;

         DATAWIDTH  : integer := 16;
         SINGLE_DEST : integer := 1;        
         DATA_PADDING : integer := 0;
         CTRL_PADDING : integer := 16#A5A5#

    -- cannot use X's here, as the synplify seems to not support this for
    -- multi-language projects
    --     ROC_ADDR : std_logic_vector(15 downto 0) := "00000000XXXXXXXX";
    --     OWN_ADDR : std_logic_vector(15 downto 0) := "1000000000000000"
      );
      port (
         clk : in std_logic;
         res_n : in std_logic;
         link_active : in std_logic;

         ctrl_en : in std_logic;              --enable ctrl packet generation
         dlm_en : in std_logic;               --enable dlm generation        
         force_rec_data_stop : in std_logic;  --force data flow to stop
         force_rec_ctrl_stop : in std_logic;  --force ctrl flow to stop

         ctrl2send_stop : in std_logic;
         ctrl2send_start : out std_logic;
         ctrl2send_end : out std_logic;
         ctrl2send : out std_logic_vector(15 downto 0);


         dlm2send_valid : out std_logic;
         dlm2send : out std_logic_vector(3 downto 0);

         dlm_rec : in std_logic_vector(3 downto 0);
         dlm_rec_valid : in std_logic;

         data_rec_start : in std_logic;
         data_rec_end : in std_logic;
         data_rec : in std_logic_vector(DATAWIDTH-1 downto 0);
         data_rec_stop : out std_logic;

         ctrl_rec_start : in std_logic;
         ctrl_rec_end : in std_logic;
         ctrl_rec : in std_logic_vector(15 downto 0);
         ctrl_rec_stop : out std_logic;

         data_valid : out std_logic;
         ctrl_valid : out std_logic;
         dlm_valid : out std_logic
      );
   end component;

   component link_tester_fe 
      generic (
         MIN_PACKET_SIZE : integer := 8;
         MAX_PACKET_SIZE : integer := 64;
         PACKET_GRAN : integer := 2;
         MIN_CTRL_PACKET_SIZE : integer := 12;
         MAX_CTRL_PACKET_SIZE : integer := 60;


         CTRL_PADDING : integer := 16#A5A5#;
         OWN_ADDR : std_logic_vector(15 downto 0) := "1000000000000000";
         DEST_ADDR : std_logic_vector(15 downto 0) := "0000000000000000";
         PACKET_MODE : integer := 1; --if enabled generates another packet size order to test further corner cases
         ROC_USE_CASES : integer := 0 --Enables the ROC command interpreter to write and read an ASIC RF with ROC use cases

      );
      port (
         clk : in std_logic;
         res_n : in std_logic;
         link_active : in std_logic;

         data_en : in std_logic;     -- enable data packet generation
         ctrl_en : in std_logic;     -- enable ctrl packet generation
         force_rec_ctrl_stop : in std_logic;  -- force ctrl flow to stop

         ctrl2send_stop : in std_logic;
         ctrl2send_start : out std_logic;
         ctrl2send_end : out std_logic;
         ctrl2send : out std_logic_vector(15 downto 0);

         data2send_stop : in std_logic;
         data2send_start : out std_logic;
         data2send_end : out std_logic;
         data2send : out std_logic_vector(15 downto 0);

         dlm2send_valid : out std_logic;
         dlm2send : out std_logic_vector(3 downto 0);

         dlm_rec : in std_logic_vector(3 downto 0);
         dlm_rec_valid : in std_logic;

         data_rec_start : in std_logic;
         data_rec_end : in std_logic;
         data_rec : in std_logic_vector(15 downto 0);
         data_rec_stop : out std_logic;

         ctrl_rec_start : in std_logic;
         ctrl_rec_end : in std_logic;
         ctrl_rec : in std_logic_vector(15 downto 0);
         ctrl_rec_stop : out std_logic;

         ctrl_valid : out std_logic;
         dlm_valid : out std_logic
      );
   end component;

   
   component CBMNET_READOUT is
      port (
      -- TrbNet
         CLK_IN   : in std_logic;
         RESET_IN : in std_logic;

         -- connect to hub
         HUB_CTS_NUMBER_IN              : in  std_logic_vector (15 downto 0);
         HUB_CTS_CODE_IN                : in  std_logic_vector (7  downto 0);
         HUB_CTS_INFORMATION_IN         : in  std_logic_vector (7  downto 0);
         HUB_CTS_READOUT_TYPE_IN        : in  std_logic_vector (3  downto 0);
         HUB_CTS_START_READOUT_IN       : in  std_logic;
         HUB_CTS_READOUT_FINISHED_OUT   : out std_logic;  --no more data, end transfer, send TRM
         HUB_CTS_STATUS_BITS_OUT        : out std_logic_vector (31 downto 0);
         HUB_FEE_DATA_IN                : in  std_logic_vector (15 downto 0);
         HUB_FEE_DATAREADY_IN           : in  std_logic;
         HUB_FEE_READ_OUT               : out std_logic;  --must be high when idle, otherwise you will never get a dataready
         HUB_FEE_STATUS_BITS_IN         : in  std_logic_vector (31 downto 0);
         HUB_FEE_BUSY_IN                : in  std_logic;   

         -- connect to GbE
         GBE_CTS_NUMBER_OUT             : out std_logic_vector (15 downto 0);
         GBE_CTS_CODE_OUT               : out std_logic_vector (7  downto 0);
         GBE_CTS_INFORMATION_OUT        : out std_logic_vector (7  downto 0);
         GBE_CTS_READOUT_TYPE_OUT       : out std_logic_vector (3  downto 0);
         GBE_CTS_START_READOUT_OUT      : out std_logic;
         GBE_CTS_READOUT_FINISHED_IN    : in  std_logic;      --no more data, end transfer, send TRM
         GBE_CTS_STATUS_BITS_IN         : in  std_logic_vector (31 downto 0);
         GBE_FEE_DATA_OUT               : out std_logic_vector (15 downto 0);
         GBE_FEE_DATAREADY_OUT          : out std_logic;
         GBE_FEE_READ_IN                : in  std_logic;  --must be high when idle, otherwise you will never get a dataready
         GBE_FEE_STATUS_BITS_OUT        : out std_logic_vector (31 downto 0);
         GBE_FEE_BUSY_OUT               : out std_logic;

         -- reg io
         REGIO_IN                       : in CTRLBUS_RX;
         REGIO_OUT                      : out CTRLBUS_TX;


      -- CBMNet
         CBMNET_CLK_IN     : in std_logic;
         CBMNET_RESET_IN   : in std_logic;
         CBMNET_LINK_ACTIVE_IN : in std_logic;         

         CBMNET_DATA2SEND_STOP_IN   : in std_logic;
         CBMNET_DATA2SEND_START_OUT : out std_logic;
         CBMNET_DATA2SEND_END_OUT   : out std_logic;
         CBMNET_DATA2SEND_DATA_OUT  : out std_logic_vector(15 downto 0)
      );
   end component;
   
   component CBMNET_READOUT_TRBNET_DECODER is
   port (
   -- TrbNet
      CLK_IN   : in std_logic;
      RESET_IN : in std_logic;
      ENABLED_IN : in std_logic;

      -- connect to hub
      HUB_CTS_START_READOUT_IN       : in  std_logic;
      HUB_FEE_DATA_IN                : in  std_logic_vector (15 downto 0);
      HUB_FEE_DATAREADY_IN           : in  std_logic;
      GBE_FEE_READ_IN                : in std_logic;
      
      -- Decode
      DEC_EVT_INFO_OUT               : out std_logic_vector(31 downto 0);
      DEC_LENGTH_OUT                 : out std_logic_vector(15 downto 0);
      DEC_SOURCE_OUT                 : out std_logic_vector(15 downto 0);
      DEC_DATA_OUT                   : out std_logic_vector(15 downto 0);
      DEC_DATA_READY_OUT             : out std_logic;
      DEC_DATA_READ_IN               : in  std_logic;
      
      DEC_ACTIVE_OUT                 : out std_logic;
      DEC_ERROR_OUT                  : out std_logic;
      
      DEBUG_OUT                      : out std_logic_vector(31 downto 0)
   );
   end component;
   
   component CBMNET_READOUT_EVENT_PACKER is
   port (
   -- TrbNet
      CLK_IN   : in std_logic;
      RESET_IN : in std_logic;

      -- connect to hub
      HUB_CTS_NUMBER_IN              : in  std_logic_vector (15 downto 0);
      HUB_CTS_CODE_IN                : in  std_logic_vector (7  downto 0);
      HUB_CTS_INFORMATION_IN         : in  std_logic_vector (7  downto 0);
      HUB_CTS_READOUT_TYPE_IN        : in  std_logic_vector (3  downto 0);
      HUB_FEE_STATUS_BITS_IN         : in  std_logic_vector (31 downto 0);
      
      
      -- connect to decoder
      DEC_EVT_INFO_IN                : in  std_logic_vector(31 downto 0);
      DEC_LENGTH_IN                  : in  std_logic_vector(15 downto 0);
      DEC_SOURCE_IN                  : in  std_logic_vector(15 downto 0);
      DEC_DATA_IN                    : in  std_logic_vector(15 downto 0);
      DEC_DATA_READY_IN              : in  std_logic;
      DEC_ACTIVE_IN                  : in  std_logic;
      DEC_ERROR_IN                   : in  std_logic;
      
      DEC_DATA_READ_OUT              : out std_logic;
      DEC_RESET_OUT                  : out std_logic;

      -- connect to fifo
      WADDR_STORE_OUT  : out std_logic;
      WADDR_RESTORE_OUT: out std_logic;
      WDATA_OUT        : out std_logic_vector(17 downto 0);
      WENQUEUE_OUT     : out std_logic;
      WPACKET_COMPLETE_OUT: out std_logic;
      WFULL_IN         : in  std_logic;
      
      DEBUG_OUT                      : out std_logic_vector(31 downto 0)
   );
   end component;
   
   component CBMNET_READOUT_FIFO is
      generic (
         ADDR_WIDTH : positive := 10;
         WATERMARK  : positive := 2
      );

      port (
         -- write port
         WCLK_IN   : in std_logic; -- not faster than rclk_in
         WRESET_IN : in std_logic;
         
         WADDR_STORE_IN   : in std_logic;
         WADDR_RESTORE_IN : in std_logic;
         
         WDATA_IN    : in std_logic_vector(17 downto 0);
         WENQUEUE_IN : in std_logic;
         WPACKET_COMPLETE_IN : in std_logic;
         
         WALMOST_FULL_OUT : out std_logic;
         WFULL_OUT        : out std_logic;
         
         -- read port
         RCLK_IN   : in std_logic;
         RRESET_IN : in std_logic;  -- has to active at least two clocks AFTER (or while) write port was (is being) initialised
         
         RDATA_OUT   : out std_logic_vector(17 downto 0);
         RDEQUEUE_IN : in std_logic;
         
         RPACKET_COMPLETE_OUT : out std_logic;   -- atleast one packet is completed in fifo
         RPACKET_COMPLETE_ACK_IN : in std_logic; -- mark one event as dealt with (effectively decrease number of completed packets by one)
         
         DEBUG_OUT  : out std_logic_vector(31 downto 0)
      );
   end component;
   
   component CBMNET_READOUT_FRAME_PACKER is
      port (
         CLK_IN   : in std_logic;
         RESET_IN : in std_logic; 

         -- fifo 
         FIFO_DATA_IN   : in std_logic_vector(17 downto 0);
         FIFO_DEQUEUE_OUT : out std_logic;
         FIFO_PACKET_COMPLETE_IN : in std_logic;  
         FIFO_PACKET_COMPLETE_ACK_OUT : out std_logic;

         -- cbmnet
         CBMNET_STOP_IN   : in std_logic;
         CBMNET_START_OUT : out std_logic;
         CBMNET_END_OUT   : out std_logic;
         CBMNET_DATA_OUT  : out std_logic_vector(15 downto 0);
      
         -- debug
         DEBUG_OUT : out std_logic_vector(31 downto 0)
      );
   end component;   
   
   component CBMNET_READOUT_OBUF is
      port(
         CLK_IN : std_logic;
         RESET_IN : std_logic;

         -- packer
         PACKER_STOP_OUT  : out std_logic;
         PACKER_START_IN  : in  std_logic;
         PACKER_END_IN    : in  std_logic;
         PACKER_DATA_IN   : in  std_logic_vector(15 downto 0);

         -- cbmnet
         CBMNET_STOP_IN   : in std_logic;
         CBMNET_START_OUT : out std_logic;
         CBMNET_END_OUT   : out std_logic;
         CBMNET_DATA_OUT  : out std_logic_vector(15 downto 0);
         
         DEBUG_OUT : out std_logic_vector(31 downto 0)
      );
   end component;
   
   component cbmnet_readout_tx_fifo is
      port (
         CLK_IN : in std_logic;
         RESET_IN : in std_logic;
         EMPTY_IN : in std_logic;   -- identical to reset_in
         
         DATA_IN  : in  std_logic_vector(15 downto 0);
         DATA_OUT : out std_logic_vector(15 downto 0);
         
         ENQUEUE_IN : in std_logic;
         DEQUEUE_IN : in std_logic;
         
         LAST_OUT : out std_logic;
         
         FILLED_IN : in std_logic;
         FILLED_OUT : out std_logic
      );
   end component;
   
   component pos_edge_strech_sync is
      generic (
         LENGTH : positive := 2
      );
      port (
         IN_CLK_IN : in std_logic;
         DATA_IN   : in std_logic;
         OUT_CLK_IN : in std_logic;
         DATA_OUT : out std_logic
      );
   end component;
  
   
   component cbmnet_sync_module is
      port(
      -- TRB
         TRB_CLK_IN     : in std_logic;  
         TRB_RESET_IN   : in std_logic;
         TRB_TRIGGER_OUT: out std_logic;

         --data output for read-out
         TRB_TRIGGER_IN       : in  std_logic;
         TRB_RDO_VALID_DATA_TRG_IN  : in  std_logic;
         TRB_RDO_VALID_NO_TIMING_IN : in  std_logic;
         TRB_RDO_DATA_OUT     : out std_logic_vector(31 downto 0);
         TRB_RDO_WRITE_OUT    : out std_logic;
         TRB_RDO_STATUSBIT_OUT: out std_logic_vector(31 downto 0);
         TRB_RDO_FINISHED_OUT : out std_logic;

         -- reg io
         TRB_REGIO_IN  : in  CTRLBUS_RX;
         TRB_REGIO_OUT : out CTRLBUS_TX;
         
      -- CBMNET
         CBM_CLK_IN           : in std_logic;
         CBM_CLK_250_IN       : in std_logic;
         CBM_RESET_IN         : in std_logic;
         CBM_PHY_BARREL_SHIFTER_POS_IN : in std_logic_vector(3 downto 0);
         CBM_LINK_ACTIVE_IN   : in std_logic;
         
         CBM_TIMING_TRIGGER_OUT : out std_logic;
         
         -- DLM port
         CBM_DLM_REC_IN       : in std_logic_vector(3 downto 0);
         CBM_DLM_REC_VALID_IN : in std_logic;
         CBM_DLM_SENSE_OUT    : out std_logic;
         CBM_PULSER_OUT       : out std_logic; -- connect to TDC
         
         -- Ctrl port
         CBM_CTRL_DATA_IN        : in std_logic_vector(15 downto 0);
         CBM_CTRL_DATA_START_IN  : in std_logic;
         CBM_CTRL_DATA_END_IN    : in std_logic;
         CBM_CTRL_DATA_STOP_OUT  : out std_logic;
         
         DEBUG_OUT      : out std_logic_vector(31 downto 0)    
      );
   end component;   
end package cbmnet_interface_pkg;

package body cbmnet_interface_pkg is
end package body;