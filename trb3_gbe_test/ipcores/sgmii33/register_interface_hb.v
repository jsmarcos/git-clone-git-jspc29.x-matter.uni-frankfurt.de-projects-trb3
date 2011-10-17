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

module register_interface_hb (

	// Control Signals
	rst_n,
	hclk,
	gbe_mode,
	sgmii_mode,

	// Host Bus
	hcs_n,
	hwrite_n,
	haddr,
	hdatain,

	hdataout,
	hready_n,

	// Register Inputs
	mr_an_enable,
	mr_restart_an,
	mr_adv_ability,

	// Register Outputs
	mr_main_reset,
	mr_an_complete,
	mr_page_rx,
	mr_lp_adv_ability
	);


input		rst_n ;
input		hclk ;
input		gbe_mode ;
input		sgmii_mode ;

input           hcs_n;
input           hwrite_n;
input    [3:0]  haddr;
input    [7:0]  hdatain;

output   [7:0]  hdataout;
output          hready_n;

input		mr_an_complete;
input		mr_page_rx;
input [15:0]	mr_lp_adv_ability;

output		mr_an_enable;
output		mr_restart_an;
output [15:0]	mr_adv_ability;
output		mr_main_reset;

regs_hb   regs (
	.rst_n (rst_n),
	.hclk (hclk),

	.gbe_mode (gbe_mode),
	.sgmii_mode (sgmii_mode),

	.hcs_n (hcs_n),
	.hwrite_n (hwrite_n),
	.haddr (haddr),
	.hdatain (hdatain),

	.hdataout (hdataout),
	.hready_n (hready_n),

	.mr_an_complete (mr_an_complete),
	.mr_page_rx (mr_page_rx),
	.mr_lp_adv_ability (mr_lp_adv_ability),

	.mr_main_reset (mr_main_reset),
	.mr_an_enable (mr_an_enable),
	.mr_restart_an (mr_restart_an),
	.mr_adv_ability (mr_adv_ability)
);
endmodule






module register_0_hb (
	rst_n,
	clk, 
	cs_0,
	cs_1,
	write,
	ready,
	data_in,

	data_out,
	mr_main_reset,
	mr_an_enable,
	mr_restart_an
);

input           rst_n;
input           clk;
input           cs_0;
input           cs_1;
input           write;
input           ready;
input  [15:0]   data_in;

output [15:0]   data_out;
output          mr_main_reset; // bit D15 // R/W // Self Clearing
output          mr_an_enable;  // bit D12 // R/W
output          mr_restart_an; // bit D09 // R/W // Self Clearing

reg [15:0]      data_out;
reg             mr_main_reset;
reg             mr_an_enable;
reg             mr_restart_an;
reg 		m_m_r;
reg 		m_r_a;


// Write Operations

	// Low Portion of Register[D7:D0] has no
	// implemented bits.  Therefore, no write
	// operations here.

	// High Portion of Register[D15:D8]
	always @(posedge clk or negedge rst_n) begin
		if (rst_n == 1'b0) begin
			mr_main_reset <= 0; // default value
			mr_an_enable <= 1;  // default value
			mr_restart_an <= 0; // default value
			m_m_r <= 0;
			m_r_a <= 0;
		end
		else begin

			// Do the Writes
			if (cs_1 && ready && write) begin
				mr_main_reset <= data_in[15];
				mr_an_enable <= data_in[12];
				mr_restart_an <= data_in[9];
			end

			// Delay the Self Clearing Register Bits
			m_m_r <= mr_main_reset;
			m_r_a <= mr_restart_an;

			// Do the Self Clearing
			if (m_m_r)
				mr_main_reset <= 0;

			if (m_r_a)
				mr_restart_an <= 0;
		end
	end





// Read Operations
	always @(*) begin
			data_out[7:0] = 8'b00000000;
			data_out[15] = mr_main_reset;
			data_out[14] = 0;
			data_out[13] = 0;
			data_out[12] = mr_an_enable;
			data_out[11] = 0;
			data_out[10] = 0;
			data_out[9]  = mr_restart_an;
			data_out[8]  = 0;
	end
endmodule

module register_1_hb (
	rst_n,
	cs_0,
	cs_1,
	mr_an_complete,

	data_out
);

input           rst_n;
input           cs_0;
input           cs_1;
input           mr_an_complete; // bit D5 // Read-Only

output [15:0]   data_out;

reg [15:0]      data_out;


// Read Operations

	always @(*) begin
			data_out[7] <= 0;
			data_out[6] <= 0;
			data_out[5] <= mr_an_complete;
			data_out[4] <= 0;
			data_out[3] <= 0;
			data_out[2] <= 0;
			data_out[1] <= 0;
			data_out[0] <= 0;
			data_out[15:8] <= 8'b00000000;
	end
endmodule

module register_4_hb (
	rst_n,
	clk, 
	gbe_mode,
	sgmii_mode,
	cs_0,
	cs_1,
	write,
	ready,
	data_in,

	data_out,
	mr_adv_ability
);

parameter [15:0] initval_gbe = 16'h0020;
parameter [15:0] initval_phy = 16'hd801;
parameter [15:0] initval_mac = 16'h4001;

input           rst_n;
input           clk;
input           gbe_mode;
input           sgmii_mode;
input           cs_0;
input           cs_1;
input           write;
input           ready;
input  [15:0]   data_in;

output [15:0]   data_out;
output [15:0]   mr_adv_ability; // When sgmii_mode == 1 == PHY
				// all bits D15-D0 are R/W,
				///////////////////////////////////
				// D15 = Link Status (1=up, 0=down)
				// D14 = Can be written but has no effect
				//           on autonegotiation.  Instead
				//           the autonegotiation state machine
				//           controls the utilization of this bit.
				// D12 = Duplex Mode (1=full, 0=half)
				// D11:10 = Speed (11=reserved)
				//                (10=1000Mbps)
				//                (01=100 Mbps)
				//                (00=10  Mbps)
				// D0 = 1
				// all other bits = 0
				///////////////////////////////////
				//When sgmii_mode == 0 = MAC
				// all bits D15-D0 are R/W,
				// D14 = Can be written but has no effect
				//           on autonegotiation.  Instead
				//           the autonegotiation state machine
				//           controls the utilization of this bit.
				// D0 = 1
				// all other bits = 0
				///////////////////////////////////


reg [15:0]      data_out;
reg [15:0]      mr_adv_ability;
reg             rst_d1;
reg             rst_d2;
reg             rst_d3;
reg             rst_d4;
reg             rst_d5;
reg             rst_d6;
reg             rst_d7;
reg             rst_d8;
reg             sync_reset;
reg             sgmii_mode_d1;
reg             sgmii_mode_d2;
reg             sgmii_mode_d3;
reg             sgmii_mode_d4;
reg             sgmii_mode_change;
reg		gbe_mode_d1;
reg		gbe_mode_d2;
reg		gbe_mode_d3;
reg		gbe_mode_d4;
reg		gbe_mode_change;

// generate a synchronous reset signal
//    note: this method is used so that
//          an initval can be applied during
//	    device run-time, instead of at compile time
always @(posedge clk or negedge rst_n) begin
	if (rst_n == 1'b0) begin
		rst_d1 <= 0;
		rst_d2 <= 0;
		rst_d3 <= 0;
		rst_d4 <= 0;
		rst_d5 <= 0;
		rst_d6 <= 0;
		rst_d7 <= 0;
		rst_d8 <= 0;
		sync_reset <= 0;
	end
	else begin
		rst_d1 <= 1;
		rst_d2 <= rst_d1;
		rst_d3 <= rst_d2;
		rst_d4 <= rst_d3;
		rst_d5 <= rst_d4;
		rst_d6 <= rst_d5;
		rst_d7 <= rst_d6;
		rst_d8 <= rst_d7;

		// asserts on rising edge of rst_d8
		sync_reset <= !rst_d8 & rst_d7; 
	end
end


// Detect change in sgmii_mode
always @(posedge clk or negedge rst_n) begin
	if (rst_n == 1'b0) begin
		sgmii_mode_d1 <= 0;
		sgmii_mode_d2 <= 0;
		sgmii_mode_d3 <= 0;
		sgmii_mode_d4 <= 0;
		sgmii_mode_change <= 0;
	end
	else begin

		// deboggle
		sgmii_mode_d1 <= sgmii_mode;
		sgmii_mode_d2 <= sgmii_mode_d1;

		// delay 
		sgmii_mode_d3 <= sgmii_mode_d2;
		sgmii_mode_d4 <= sgmii_mode_d3;

		// detect change
		if (sgmii_mode_d3 != sgmii_mode_d4)
			sgmii_mode_change <= 1;
		else
			sgmii_mode_change <= 0;
	end
end


// Detect change in gbe_mode
always @(posedge clk or negedge rst_n) begin
	if (rst_n == 1'b0) begin
		gbe_mode_d1 <= 0;
		gbe_mode_d2 <= 0;
		gbe_mode_d3 <= 0;
		gbe_mode_d4 <= 0;
		gbe_mode_change <= 0;
	end
	else begin

		// deboggle
		gbe_mode_d1 <= gbe_mode;
		gbe_mode_d2 <= gbe_mode_d1;

		// delay 
		gbe_mode_d3 <= gbe_mode_d2;
		gbe_mode_d4 <= gbe_mode_d3;

		// detect change
		if (gbe_mode_d3 != gbe_mode_d4)
			gbe_mode_change <= 1;
		else
			gbe_mode_change <= 0;
	end
end


// Write Operations
	// Low Portion of Register[D7:D0]
	always @(posedge clk or negedge rst_n) begin
		if (rst_n == 1'b0) begin
			mr_adv_ability[7:0] <= 8'h01;
		end
		else if (sync_reset || sgmii_mode_change || gbe_mode_change) begin
			if (gbe_mode_d4)
				mr_adv_ability[7:0] <= initval_gbe[7:0];
			else if (sgmii_mode)
				mr_adv_ability[7:0] <= initval_phy[7:0];
			else
				mr_adv_ability[7:0] <= initval_mac[7:0];
		end
		else begin
			if (cs_0 && ready && write && (sgmii_mode || gbe_mode)) begin
				mr_adv_ability[7:0] <= data_in[7:0];
			end
		end
	end


	// High Portion of Register[D15:D8]
	always @(posedge clk or negedge rst_n) begin
		if (rst_n == 1'b0) begin
			mr_adv_ability[15:8] <= 8'h40; // default
		end
		else if (sync_reset || sgmii_mode_change || gbe_mode_change) begin
			if (gbe_mode_d4)
				mr_adv_ability[15:8] <= initval_gbe[15:8];
			else if (sgmii_mode)
				mr_adv_ability[15:8] <= initval_phy[15:8];
			else
				mr_adv_ability[15:8] <= initval_mac[15:8];
		end
		else begin
			if (cs_1 && ready && write && (sgmii_mode || gbe_mode)) begin
				mr_adv_ability[15:8] <= data_in[15:8];
			end
		end
	end









// Read Operations

	always @(*) begin
			data_out[7:0] <= mr_adv_ability[7:0];
			data_out[15:8] <= mr_adv_ability[15:8];
	end

endmodule






module register_5_hb (
	rst_n,
	mr_lp_adv_ability,
	cs_0,
	cs_1,
	ready,

	data_out
);

input           rst_n;
input           cs_0;
input           cs_1;
input           ready;
input  [15:0]   mr_lp_adv_ability;
				// This entire register is read-only
				///////////////////////////////////
				// When sgmii_mode == 0 == MAC
				///////////////////////////////////
				// D15 = PHY Link Status (1=up, 0=down)
				// D14 = PHY Autonegotiation Handshake
				// D12 = PHY Duplex Mode (1=full, 0=half)
				// D11:10 = PHY Speed (11=reserved)
				//                    (10=1000Mbps)
				//                    (01=100 Mbps)
				//                    (00=10  Mbps)
				// D0 = 1
				// all other bits = 0
				///////////////////////////////////
				//When sgmii_mode == 1 = PHY
				// D14 = MAC Autonegotiation Handshake
				// D0 = 1
				// all other bits = 0
				///////////////////////////////////
output [15:0]   data_out;

reg [15:0]      data_out;

// Read Operations

	always @(*) begin
			data_out[7:0] <= mr_lp_adv_ability[7:0];
			data_out[15:8] <= mr_lp_adv_ability[15:8];
	end
endmodule

module register_6_hb (
	rst_n,
	clk,
	mr_page_rx,
	cs_0,
	cs_1,
	write,
	ready,

	data_out
);

input           rst_n;
input           clk;
input           cs_0;
input           cs_1;
input           write;
input           ready;
input           mr_page_rx;
output [15:0]   data_out;

reg [15:0]      data_out;
reg             mr_page_rx_latched;
reg             clear_on_read;
reg             read_detect;
reg             rd_d1;
reg             rd_d2;

// generate clear-on-read signal
	always @(posedge clk or negedge rst_n) begin
		if (rst_n == 1'b0) begin
			clear_on_read <= 0;
			read_detect <= 0;
			rd_d1 <= 0;
			rd_d2 <= 0;
		end
		else begin
			if (!write && ready && cs_0)
				read_detect <= 1;
			else 
				read_detect <= 0;

			rd_d1 <= read_detect;
			rd_d2 <= rd_d1;

			// assert on falling edge of rd_d2
			clear_on_read <= !rd_d1 & rd_d2;
		end
	end


// Latch and Clear
	always @(posedge clk or negedge rst_n) begin
		if (rst_n == 1'b0) begin
			mr_page_rx_latched <= 0;
		end
		else begin
			if (clear_on_read)
				mr_page_rx_latched <= 0;
			else if (mr_page_rx)
				mr_page_rx_latched <= 1;
		end
	end


// Read Operations

	always @(*) begin
			data_out[15:2] <= 14'd0;
			data_out[1] <= mr_page_rx_latched;
			data_out[0] <= 0;
	end
endmodule


module regs_hb (
	rst_n,
	hclk,
 	gbe_mode,
	sgmii_mode,
	hcs_n,
	hwrite_n,
	haddr,
	hdatain,

	hdataout,
	hready_n,

	mr_an_complete,
	mr_page_rx,
	mr_lp_adv_ability,

	mr_main_reset,
	mr_an_enable,
	mr_restart_an,
	mr_adv_ability
);

input           rst_n;
input           hclk;
input           gbe_mode;
input           sgmii_mode;
input           hcs_n;
input           hwrite_n;
input    [3:0]  haddr;
input    [7:0]  hdatain;

output   [7:0]  hdataout;
output          hready_n;

input           mr_an_complete;
input           mr_page_rx;
input    [15:0] mr_lp_adv_ability;

output          mr_main_reset;
output          mr_an_enable;
output          mr_restart_an;
output   [15:0] mr_adv_ability;

///////////////////////////////////



reg   [7:0]  hdataout;
reg hr;
reg hready_n;

reg hcs_n_delayed;

wire reg0_cs_0;
wire reg0_cs_1;

wire reg1_cs_0;
wire reg1_cs_1;

wire reg4_cs_0;
wire reg4_cs_1;

wire reg5_cs_0;
wire reg5_cs_1;

wire reg6_cs_0;
wire reg6_cs_1;

wire [15:0] data_out_reg_0;
wire [15:0] data_out_reg_1;
wire [15:0] data_out_reg_4;
wire [15:0] data_out_reg_5;
wire [15:0] data_out_reg_6;



register_addr_decoder ad_dec (
	.rst_n(rst_n),
	.addr(haddr),
	.cs_in(~hcs_n),

	.reg0_cs_0 (reg0_cs_0),
	.reg0_cs_1 (reg0_cs_1),
	.reg1_cs_0 (reg1_cs_0),
	.reg1_cs_1 (reg1_cs_1),
	.reg4_cs_0 (reg4_cs_0),
	.reg4_cs_1 (reg4_cs_1),
	.reg5_cs_0 (reg5_cs_0),
	.reg5_cs_1 (reg5_cs_1),
	.reg6_cs_0 (reg6_cs_0),
	.reg6_cs_1 (reg6_cs_1)
);


register_0_hb   register_0 (
	.rst_n (rst_n),
	.clk (hclk), 
	.cs_0 (reg0_cs_0),
	.cs_1 (reg0_cs_1),
	.write (~hwrite_n),
	.ready (1'b1),
	.data_in ({hdatain, hdatain}),

	.data_out (data_out_reg_0),
	.mr_main_reset (mr_main_reset),
	.mr_an_enable (mr_an_enable),
	.mr_restart_an (mr_restart_an)
);


register_1_hb   register_1 (
	.rst_n (rst_n),
	.cs_0 (reg1_cs_0),
	.cs_1 (reg1_cs_1),
	.mr_an_complete (mr_an_complete),

	.data_out (data_out_reg_1)
);


register_4_hb   register_4 (
	.rst_n (rst_n),
	.clk (hclk), 
	.gbe_mode (gbe_mode),
	.sgmii_mode (sgmii_mode),
	.cs_0 (reg4_cs_0),
	.cs_1 (reg4_cs_1),
	.write (~hwrite_n),
	.ready (1'b1),
	.data_in ({hdatain, hdatain}),

	.data_out (data_out_reg_4),
	.mr_adv_ability (mr_adv_ability)
);


register_5_hb   register_5 (
	.rst_n (rst_n),
	.mr_lp_adv_ability (mr_lp_adv_ability),
	.cs_0 (reg5_cs_0),
	.cs_1 (reg5_cs_1),
	.ready (1'b1),

	.data_out (data_out_reg_5)
);


register_6_hb   register_6 (
	.rst_n (rst_n),
	.clk (hclk), 
	.mr_page_rx (mr_page_rx),
	.cs_0 (reg6_cs_0),
	.cs_1 (reg6_cs_1),
	.write (~hwrite_n),
	.ready (1'b1),

	.data_out (data_out_reg_6)
);



// generate an ack
always @(posedge hclk or negedge rst_n) begin
	if (rst_n == 1'b0) begin
		hcs_n_delayed <= 1'b1;
		hr <= 1'b1;
		hready_n <= 1'b1;
	end
	else begin
		hcs_n_delayed <= hcs_n;

		//assert on falling edge of delayed chip select
		hr <= ~hcs_n & hcs_n_delayed;
		hready_n <= ~hr;
	end
end



// Mux Register Read-Data Outputs
always @(posedge hclk or negedge rst_n)
begin
	if (rst_n == 1'b0) begin
		hdataout <= 8'd0;
	end
	else begin
		case (haddr[3:0])

			4'd0:
			  begin
				hdataout <= data_out_reg_0[7:0];
			  end


			4'd1:
			  begin
				hdataout <= data_out_reg_0[15:8];
			  end

			/////////////////////////////////////////////

			4'd2:
			  begin
				hdataout <= data_out_reg_1[7:0];
			  end


			4'd3:
			  begin
				hdataout <= data_out_reg_1[15:8];
			  end

			/////////////////////////////////////////////

			4'd8:
			  begin
				hdataout <= data_out_reg_4[7:0];
			  end


			4'd9:
			  begin
				hdataout <= data_out_reg_4[15:8];
			  end

			/////////////////////////////////////////////

			4'd10:
			  begin
				hdataout <= data_out_reg_5[7:0];
			  end


			4'd11:
			  begin
				hdataout <= data_out_reg_5[15:8];
			  end

			/////////////////////////////////////////////

			4'd12:
			  begin
				hdataout <= data_out_reg_6[7:0];
			  end


			4'd13:
			  begin
				hdataout <= data_out_reg_6[15:8];
			  end

			/////////////////////////////////////////////

			default:
			  begin
				hdataout <= 8'd0;
			  end
		endcase
	end
end

endmodule

module register_addr_decoder (
	rst_n,
	addr,
	cs_in,

	reg0_cs_0,
	reg0_cs_1,

	reg1_cs_0,
	reg1_cs_1,

	reg4_cs_0,
	reg4_cs_1,

	reg5_cs_0,
	reg5_cs_1,

	reg6_cs_0,
	reg6_cs_1
);

input           rst_n;
input           cs_in;
input [3:0]     addr;

output          reg0_cs_0;
output          reg0_cs_1;

output          reg1_cs_0;
output          reg1_cs_1;

output          reg4_cs_0;
output          reg4_cs_1;

output          reg5_cs_0;
output          reg5_cs_1;

output          reg6_cs_0;
output          reg6_cs_1;

//////////////////////////

wire             reg0_cs_0;
wire             reg0_cs_1;

wire             reg1_cs_0;
wire             reg1_cs_1;

wire             reg4_cs_0;
wire             reg4_cs_1;

wire             reg5_cs_0;
wire             reg5_cs_1;

wire             reg6_cs_0;
wire             reg6_cs_1;

//////////////////////////

assign reg0_cs_0 = (addr == 4'h0) ? cs_in : 1'b0;
assign reg0_cs_1 = (addr == 4'h1) ? cs_in : 1'b0;

assign reg1_cs_0 = (addr == 4'h2) ? cs_in : 1'b0;
assign reg1_cs_1 = (addr == 4'h3) ? cs_in : 1'b0;

assign reg4_cs_0 = (addr == 4'h8) ? cs_in : 1'b0;
assign reg4_cs_1 = (addr == 4'h9) ? cs_in : 1'b0;

assign reg5_cs_0 = (addr == 4'ha) ? cs_in : 1'b0;
assign reg5_cs_1 = (addr == 4'hb) ? cs_in : 1'b0;

assign reg6_cs_0 = (addr == 4'hc) ? cs_in : 1'b0;
assign reg6_cs_1 = (addr == 4'hd) ? cs_in : 1'b0;


endmodule

