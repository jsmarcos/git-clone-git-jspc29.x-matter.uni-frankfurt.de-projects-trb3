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

module rate_resolution (
	gbe_mode,
	sgmii_mode,
	an_enable,
	advertised_rate,
	link_partner_rate,
	non_an_rate,

	operational_rate
);

input gbe_mode;
input sgmii_mode;
input an_enable;
input [1:0] advertised_rate; // 00=10Mbps    01=100Mbps    10=1Gbps
input [1:0] link_partner_rate;
input [1:0] non_an_rate;

output [1:0] operational_rate;
reg [1:0] operational_rate;



always @(gbe_mode or sgmii_mode or an_enable or advertised_rate or link_partner_rate or non_an_rate) begin
	if (gbe_mode) begin
		operational_rate <= 2'b10; // 1Gbps
	end
	else begin
		if (an_enable) begin
			if (sgmii_mode) begin
				// PHY Mode
				operational_rate <= advertised_rate;
			end
			else begin
				// MAC Mode
				operational_rate <= link_partner_rate;
			end
		end
		else begin
			// If auto-negotiation disabled, then this becomes active rate
			operational_rate <= non_an_rate;
		end
	end
end



endmodule

