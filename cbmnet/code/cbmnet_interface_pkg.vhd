-- Hardware Independent CBMNet components (merely an interface definition for the Verilog modules)

library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

package cbmnet_interface_pkg is
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
         
   component gtp_rx_ready_module is
      generic (
         READY_CHAR0  : std_logic_vector(7 downto 0) :=  K284;
         READY_CHAR1  : std_logic_vector(7 downto 0) :=  K287;
         ALIGN_CHAR  : std_logic_vector(7 downto 0) :=  K285;
         DATAWIDTH  : integer :=  16;
         WORDS : integer := 2; --DATAWIDTH/8;
         
         INCL_8B10B_DEC : integer range 0 to 1 := 1
      );
      port (
         clk : in std_logic;
         res_n : in std_logic;
         ready_MGT2RM : in std_logic;
         rxdata_in : in std_logic_vector((WORDS*10)-1 downto 0);

         tx_ready : in std_logic;
         tx_almost_ready : in std_logic;

         ready_RM2LP : out std_logic;
         almost_ready_OUT : out std_logic;
         rxdata_out : out std_logic_vector((DATAWIDTH-1) downto 0);
         charisk_out : out std_logic_vector((WORDS-1) downto 0);
         see_ready0 : out std_logic;
         saw_ready1 : out std_logic;
         valid_char : out std_logic;
         reset_rx : out std_logic
      );
   end component;

   component gtp_tx_ready_module is
      generic (
         READY_CHAR0  : std_logic_vector(7 downto 0) :=  K284;
         READY_CHAR1  : std_logic_vector(7 downto 0) :=  K287;
         ALIGN_CHAR  : std_logic_vector(7 downto 0) :=  K285;
         DATAWIDTH  : integer :=  16;
         WORDS :integer := 2 --DATAWIDTH/8;
      );
      port (
         clk : in std_logic;
         res_n : in std_logic;
         restart_link : in std_logic;
         ready_MGT2RM : in std_logic;
         txdata_in : in std_logic_vector((DATAWIDTH-1) downto 0);
         txcharisk_in : in std_logic_vector((WORDS-1) downto 0);

         see_ready0 : in std_logic;
         saw_ready1 : in std_logic;
         valid_char : in std_logic;
         rx_rm_ready : in std_logic;

         ready_RM2LP : out std_logic;
         txdata_out : out std_logic_vector((WORDS*9)-1 downto 0);
         almost_ready : out std_logic;
         gt11_reinit : out std_logic
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

         SERDES_ready      : in  std_logic    -- signalize when PHY ready
      );
   end component;
   
   
   
end package cbmnet_interface_pkg;

package body cbmnet_interface_pkg is
end package body;