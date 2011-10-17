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
// This module forces a RESET to the SERDES CDR
//	when the CDR either loses lock  or loses signal
////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

module reset_controller_cdr (

	rst_n,
	clk,

	cdr_lol,

	cdr_rst_out
	);

input rst_n;
input clk; // 125Mhz clock

input cdr_lol;

output cdr_rst_out;


///////////////////////////////////////

reg cdr_rst_out;

reg cdr_lol_mstb_1;
reg cdr_lol_mstb_2;


reg sht_mx;
reg [5:0] sht_count;

reg lng_mx;
reg [22:0] lng_count;

reg cnt_rst;
parameter
	ASSRT_RST           = 3'd0,
	WAIT_SHORT          = 3'd1,
	DSSRT_RST           = 3'd2,
	WAIT_LONG           = 3'd3,
	SEEK_CDR_ERR        = 3'd4,
	SEEK_SIGNAL_RESTORE = 3'd5;
reg[2:0] fsm;

//////////////////////////////////////
//  Mestastability Filter
//////////////////////////////////////
always @(posedge clk or negedge rst_n)
begin
	if (rst_n == 1'b0) begin
		cdr_lol_mstb_1 <= 1'b1;
		cdr_lol_mstb_2 <= 1'b1;


	end
	else begin
		cdr_lol_mstb_1 <= cdr_lol;
		cdr_lol_mstb_2 <= cdr_lol_mstb_1;

	end
end 



///////////////////////////////////////
//  Operate Short Timer (256 nsec)
///////////////////////////////////////
always @(posedge clk or negedge rst_n)
begin
	if (rst_n == 1'b0) begin
		sht_mx <= 1'b0;
		sht_count <= 6'd0;
	end
	else begin

		// define max count
		if (sht_count[5] && (!cnt_rst)) begin
			sht_mx <= 1'b1;
		end
		else begin
			sht_mx <= 1'b0;
		end

		// operate counter
		if (cnt_rst) begin
			sht_count <= 6'd0; //clear
		end
		else if (sht_mx) begin
			sht_count <= sht_count; //hold
		end
		else begin
			sht_count <= sht_count + 1; //count
		end
	end
end 


/////////////////////////////////////
//  Operate Long Timer (33 msec)
/////////////////////////////////////
always @(posedge clk or negedge rst_n)
begin
	if (rst_n == 1'b0) begin
		lng_mx <= 1'b0;
		lng_count <= 23'd0;
	end
	else begin

		// define max count
		if (lng_count[22] && (!cnt_rst)) begin
			lng_mx <= 1'b1;
		end
		else begin
			lng_mx <= 1'b0;
		end

		// operate counter
		if (cnt_rst) begin
			lng_count <= 6'd0; //clear
		end
		else if (lng_mx) begin
			lng_count <= lng_count; //hold
		end
		else begin
			lng_count <= lng_count + 1; //count
		end
	end
end 


/////////////////////////////////////
//  State Machine
/////////////////////////////////////
always @(posedge clk or negedge rst_n)
begin
	if (rst_n == 1'b0) begin
		cdr_rst_out <= 1'b1;
		cnt_rst <= 1'b1;
		fsm <= ASSRT_RST;
	end
	else begin

		// defaults
		cnt_rst <= 1'b0;

		case (fsm)
			ASSRT_RST: begin
				cdr_rst_out <= 1'b1; // assert
				cnt_rst <= 1'b1;
				fsm <= WAIT_SHORT;
			end

			WAIT_SHORT: begin
				// wait for 256 nsec
				if (sht_mx && (!cnt_rst)) begin
					fsm <= DSSRT_RST;
				end
			end

			DSSRT_RST: begin
				cdr_rst_out <= 1'b0; // de-assert
				fsm <= WAIT_LONG;
			end

			WAIT_LONG: begin
				// wait for 33 msec
				if (lng_mx && (!cnt_rst)) begin
					fsm <= SEEK_CDR_ERR;
				end
			end

			SEEK_CDR_ERR: begin

				cnt_rst <= 1'b1;


				// Wait for CDR to fail
				if (cdr_lol_mstb_2) begin
					fsm <= ASSRT_RST;
				end
				else begin
					fsm <= SEEK_CDR_ERR;
				end
			end



			default: begin
				fsm <= ASSRT_RST;
			end
		endcase

	end
end 



endmodule

