//**************************************************************************
// *************************************************************************
// *                LATTICE SEMICONDUCTOR CONFIDENTIAL                     *
// *                         PROPRIETARY NOTE                              *
// *                                                                       *
// *  This software contains information confidential and proprietary      *
// *  to Lattice Semiconductor Corporation.  It shall not be reproduced    *
// *  in whole or in part, or transferred to other documents, or disclosed *
// *  to third parties, or used for any purpose other than that for which  *
// *  it was obtained, without the prior written consent of Lattice        *
// *  Semiconductor Corporation.  All rights reserved.                     *
// *                                                                       *
// *************************************************************************
//**************************************************************************

`timescale 1ns/100ps

module sgmii_channel_smi (

	// Control Interface
	rst_n,
	gbe_mode,
	sgmii_mode,
	signal_detect,
	debug_link_timer_short,
	rx_compensation_err,
	non_an_rate,

	// G/MII Interface
	in_clk_gmii,
	in_clk_mii,
	data_in_mii,
	en_in_mii,
	err_in_mii,

	out_clk_gmii,
	out_clk_mii,
	data_out_mii,
	dv_out_mii,
	err_out_mii,
	col_out_mii,
	crs_out_mii,

	// 8-bit Interface
	data_out_8bi,
	kcntl_out_8bi,
	disparity_cntl_out_8bi,

	serdes_recovered_clk,
	data_in_8bi,
	kcntl_in_8bi,
	even_in_8bi,
	disp_err_in_8bi,
	cv_err_in_8bi,
	err_decode_mode_8bi,

	// MDIO Port
	mdc,
	mdio,
	port_id
   );



// I/O Declarations
input         rst_n ;       // System Reset, Active Low
input         signal_detect ;
input         gbe_mode ;  // GBE Mode   (0=SGMII    1=GBE)
input         sgmii_mode ;  // SGMII PCS Mode   (0=MAC    1=PHY)
input         debug_link_timer_short ;  // (0=NORMAL    1=SHORT)
output        rx_compensation_err;  // Active high pulse indicating RX_CTC_FIFO either underflowed or overflowed
input [1:0]   non_an_rate ; // MII Rate Used When Autonegotiation is Disabled (00=10Mbps; 01=100Mbps; 10=1Gbps)

input         in_clk_mii ;      // G/MII Transmit clock 2.5Mhz/25Mhz/125Mhz 
input [7:0]   data_in_mii ;        // G/MII Tx data
input         en_in_mii ;       // G/MII data valid
input         err_in_mii ;       // G/MII Tx error

input         out_clk_mii ;      // G/MII Receice clock 2.5Mhz/25Mhz/125MHz 
output [7:0]   data_out_mii ;       // G/MII Rx data
output         dv_out_mii ;      // G/MII Rx data valid
output         err_out_mii ;      // G/MII Rx error
output         col_out_mii ;        // G/MII collision detect 
output         crs_out_mii ;        // G/MII carrier sense detect 

output [7:0]   data_out_8bi ;            // 8BI Tx Data
output         kcntl_out_8bi ;           // 8BI Tx Kcntl
output         disparity_cntl_out_8bi ;  // 8BI Tx Kcntl

input         serdes_recovered_clk ;
input [7:0]   data_in_8bi  ;     // 8BI Rx Data
input         kcntl_in_8bi ;     // 8BI Rx Kcntl
input         even_in_8bi ;      // 8BI Rx Even
input         disp_err_in_8bi ;  // 8BI Rx Disparity Error
input         cv_err_in_8bi ;    // 8BI Rx Coding Violation Error
input         err_decode_mode_8bi ; // 8BI Error Decode Mode (0=NORMAL,  1=DECODE_MODE)

input         in_clk_gmii ;     // GMII Transmit clock 125Mhz
input         out_clk_gmii ;     // GMII Receive clock 125Mhz

input		mdc;
inout		mdio;
input [4:0]	port_id;


wire		mdin;
wire		mdout;
wire		mdout_en;

// Internal Signals 

wire		mr_an_complete;
wire		mr_page_rx;
wire [15:0]	mr_lp_adv_ability;

wire		mr_main_reset;
wire		mr_an_enable;
wire		mr_restart_an;
wire [15:0]	mr_adv_ability;

wire [1:0]	operational_rate;








// SGMII PCS
sgmii33 sgmii33_U (
	// Clock and Reset
	.rst_n (rst_n ),
	.signal_detect (signal_detect),
	.gbe_mode (gbe_mode),
	.sgmii_mode (sgmii_mode),
	.debug_link_timer_short (debug_link_timer_short), 
	.operational_rate (operational_rate),
	.rx_compensation_err (rx_compensation_err),
	.tx_clk_125 (in_clk_gmii),
	.serdes_recovered_clk (serdes_recovered_clk),
	.rx_clk_125 (out_clk_gmii),

	// Control


	// (G)MII TX Port
	.tx_clk_mii (in_clk_mii),
	.tx_d (data_in_mii),
	.tx_en (err_in_mii),
	.tx_er (en_in_mii),

	// (G)MII RX Port
	.rx_clk_mii (out_clk_mii),
	.rx_d (data_out_mii),
	.rx_dv (dv_out_mii),
	.rx_er (err_out_mii),
	.col (col_out_mii),
	.crs (crs_out_mii),
                  
	// 8BI TX Port
	.tx_data (data_out_8bi),
	.tx_kcntl (kcntl_out_8bi),
	.tx_disparity_cntl (disparity_cntl_out_8bi),

	// 8BI RX Port
	.rx_data (data_in_8bi),
	.rx_kcntl (kcntl_in_8bi),
	.rx_even (even_in_8bi),
	.rx_disp_err (disp_err_in_8bi),
	.rx_cv_err (cv_err_in_8bi),
	.rx_err_decode_mode (err_decode_mode_8bi),

	// Management Interface  I/O
	.mr_adv_ability (mr_adv_ability),
	.mr_an_enable (mr_an_enable), 
	.mr_main_reset (mr_main_reset),  
	.mr_restart_an (mr_restart_an),   

	.mr_an_complete (mr_an_complete),   
	.mr_lp_adv_ability (mr_lp_adv_ability), 
	.mr_page_rx (mr_page_rx)
	);



// SMI Register Interface for SGMII IP Core
register_interface_smi   ri (

	// Control Signals
	.rst_n (rst_n),
	.gbe_mode (gbe_mode),
	.sgmii_mode (sgmii_mode),

	// MDIO Port
	.mdc (mdc),
	.mdin (mdin),
	.mdout (mdout),
	.mdout_en (mdout_en),
	.port_id (port_id),

	// Register Outputs
	.mr_an_enable (mr_an_enable),
	.mr_restart_an (mr_restart_an),
	.mr_main_reset (mr_main_reset),
	.mr_adv_ability (mr_adv_ability),

	// Register Inputs
	.mr_an_complete (mr_an_complete),
	.mr_page_rx (mr_page_rx),
	.mr_lp_adv_ability (mr_lp_adv_ability)
	);



// (G)MII Rate Resolution for SGMII IP Core
rate_resolution   rate_resolution (
	.gbe_mode (gbe_mode),
	.sgmii_mode (sgmii_mode),
	.an_enable (mr_an_enable),
	.advertised_rate (mr_adv_ability[11:10]),
	.link_partner_rate (mr_lp_adv_ability[11:10]),
	.non_an_rate (non_an_rate),

	.operational_rate (operational_rate)
);





// Bidirectional Assignments
assign mdio = mdout_en ? mdout : 1'bz; // MDIO Output
assign mdin = mdio; 		       // MDIO Input

endmodule

