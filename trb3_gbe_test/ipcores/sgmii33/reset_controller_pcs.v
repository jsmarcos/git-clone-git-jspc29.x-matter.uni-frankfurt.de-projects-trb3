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

////////////////////////////////////////////////////////////////////////
// This module implements the SERDES/PCS reset sequence as specified
// in Figure 47 of Lattice Technical Note TN1176
////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

module reset_controller_pcs (

	rst_n,
	clk,

	tx_plol,
	rx_cdr_lol,

	quad_rst_out,
	tx_pcs_rst_out,
	rx_pcs_rst_out
	);

input rst_n;
input clk; // 125Mhz clock

input tx_plol;
input rx_cdr_lol;

output quad_rst_out;
output tx_pcs_rst_out;
output rx_pcs_rst_out;


///////////////////////////////////////

reg quad_rst_out;
reg tx_pcs_rst_out;
reg rx_pcs_rst_out;

reg q_mx;
reg [3:0] q_count;

reg rx_cdr_lol_mstb_1;
reg rx_cdr_lol_mstb_2;

reg wd_mx;
reg wd_mx_d1;
reg wd_mx_re;
reg [22:0] wd_count;
reg watchdog_flag;

////////////////////////////////////////////////////////
//  Assert Quad RST For 8 Clocks After Device Hard Reset
////////////////////////////////////////////////////////
always @(posedge clk or negedge rst_n)
begin
	if (rst_n == 1'b0) begin
		q_mx <= 1'b0;
		q_count <= 4'd0;
		quad_rst_out <= 1'b1; // assert
	end
	else begin

		// define max count
		if (q_count[3]) begin
			q_mx <= 1'b1;
		end
		else begin
			q_mx <= 1'b0;
		end

		// operate counter
		if (q_mx) begin
			q_count <= q_count; //hold
		end
		else begin
			q_count <= q_count + 1; //count
		end

		// operate quad reset
		if (q_mx) begin
			quad_rst_out <= 1'b0; //de-assert on max-count
		end
		else begin
			quad_rst_out <= 1'b1; //assert otherwise
		end
	end
end 


////////////////////////////////////////////////////////////////////
//  Watchdog Timer -- In Case PLLs Don't Acquire Lock Within 33msec
////////////////////////////////////////////////////////////////////
always @(posedge clk or negedge rst_n)
begin
	if (rst_n == 1'b0) begin
		wd_mx <= 1'b0;
		wd_mx_d1 <= 1'b0;
		wd_mx_re <= 1'b0;
		wd_count <= 23'd0;
		watchdog_flag <= 1'b0;
	end
	else begin

		// define max count
		if (wd_count[22]) begin
			wd_mx <= 1'b1;
		end
		else begin
			wd_mx <= 1'b0;
		end

		// operate counter
		if (quad_rst_out) begin
			wd_count <= 23'd0; //clear
		end
		else if (wd_mx) begin
			wd_count <= wd_count; //hold
		end
		else begin
			wd_count <= wd_count + 1; //count
		end

		// detect rising edge of max_count flag
		wd_mx_d1 <= wd_mx;

		wd_mx_re <= wd_mx & (!wd_mx_d1);

		// generate watchdog flag
		watchdog_flag <= wd_mx_re;
	end
end 




////////////////////////////////////////////////
//  De-Assert TX PCS After TX PLL Acquires Lock
////////////////////////////////////////////////
always @(posedge clk or negedge rst_n)
begin
	if (rst_n == 1'b0) begin
		tx_pcs_rst_out <= 1'b1; // assert
	end
	else begin

		case (tx_pcs_rst_out)
			1'b1: begin
				// if asserted, wait for PLL to acquire lock
				if ((!quad_rst_out && (!tx_plol))   ||   watchdog_flag) begin
					tx_pcs_rst_out <= 1'b0; // deassert
				end
			end

			1'b0: begin
				// if de-asserted, stay that way
				tx_pcs_rst_out <= 1'b0; // deassert
			end

			default: begin
				tx_pcs_rst_out <= 1'b1; // assert
			end
		endcase

	end
end 





///////////////////////////////////////////////////////
//  De-Assert RX PCS-Chan-0 After RX CDR Acquires Lock
///////////////////////////////////////////////////////
always @(posedge clk or negedge rst_n)
begin
	if (rst_n == 1'b0) begin
		rx_pcs_rst_out <= 1'b1; // assert
		rx_cdr_lol_mstb_1 <= 1'b1;
		rx_cdr_lol_mstb_2 <= 1'b1;
	end
	else begin

		// metastability - filter
		rx_cdr_lol_mstb_1 <= rx_cdr_lol;
		rx_cdr_lol_mstb_2 <= rx_cdr_lol_mstb_1;

		case (rx_pcs_rst_out)
			1'b1: begin
				// if asserted, wait for CDR to acquire lock
				if ((!quad_rst_out && (!rx_cdr_lol_mstb_2))   ||   watchdog_flag) begin
					rx_pcs_rst_out <= 1'b0; // deassert
				end
			end

			1'b0: begin
				// if de-asserted, stay that way
				rx_pcs_rst_out <= 1'b0; // deassert
			end

			default: begin
				rx_pcs_rst_out <= 1'b1; // assert
			end
		endcase

	end
end 




endmodule

