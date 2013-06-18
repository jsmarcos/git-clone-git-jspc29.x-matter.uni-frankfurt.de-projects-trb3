// --------------------------------------------------------------------
// >>>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<
// --------------------------------------------------------------------
// Copyright (c) 2001 - 2012 by Lattice Semiconductor Corporation  
// --------------------------------------------------------------------  
//  
// Permission:                    
//
// Lattice Semiconductor grants permission to use this code for use
// in synthesis for any Lattice programmable logic product. Other
// use of this code, including the selling or duplication of any
// portion is strictly prohibited.
//
// Disclaimer:
//
// This verilog source code is intended as a design reference
// which illustrates how these types of functions can be implemented.
// It is the user's responsibility to verify their design for
// consistency and functionality through the use of formal
// verification methods. Lattice Semiconductor provides no warranty
// regarding the use or functionality of this code.
//
// --------------------------------------------------------------------
//
// Lattice Semiconductor Corporation
// 5555 NE Moore Court
// Hillsboro, OR 97214
// U.S.A
//
// TEL: 1-800-Lattice (USA and Canada)
// 503-268-8001 (other locations)
//
// web: http://www.latticesemi.com/
// email: techsupport@latticesemi.com
//  
// --------------------------------------------------------------------
// Code Revision History :
// --------------------------------------------------------------------
// Ver: | Author  |Mod. Date |Changes Made:
// V1.0 | Vijay   |3/09/12    |Initial ver
// V1.1 | SHossner|6/08/12    |Added READ_DELAY parameter
//  
// --------------------------------------------------------------------

`timescale 1ns / 100ps
`include "efb_define_def.v"
//`include "/d/jspc29/lattice/diamond/2.0/ispfpga/verilog/data/machxo2/GSR.v"
//`include "/d/jspc29/lattice/diamond/2.0/ispfpga/verilog/data/machxo2/PUR.v"

module UFM_WB(
              input clk_i
              , input rst_n
              , input[2:0] cmd
              , input[12:0] ufm_page
              , input GO
              , output reg BUSY
              , output reg ERR
   
              /***************** DPRAM port B signals *************/
              , output reg mem_clk
              , output reg mem_we
              , output reg mem_ce
              , output reg[3:0] mem_addr
              , output reg[7:0] mem_wr_data
              , input [7:0] mem_rd_data

              );

   //*****************
   // For clk_i speeds less than 16.6MHz, set READ_DELAY to zero for fastest UFM read operation
   // For clk_i speeds greater than 16.6MHz, set READ_DELAY as follows: 
   // Calculate minimum READ_DELAY as follows:
   //  READ_DELAY(min) = 240/PERIOD - 4
   //  Where PERIOD = clk_i period in ns
   //  Example, for clk_i = 45MHz, PERIOD = 22.22ns and READ_DELAY = 7 (6.8 rounded up)
   //
   // Or choose from the following table:
   //   READ_DELAY  |    Max Clk_i
   //   ------------+-------------
   //       0       |     16.6 Mhz
   //       2       |     25.0 Mhz
   //       4       |     33.3 Mhz
   //       8       |     50.0 Mhz
   //      12       |     66.6 Mhz
   //      14       |     75.0 Mhz

   parameter READ_DELAY = 4;
   //*****************

   wire             ufm_enable_cmd;
   wire             ufm_read_cmd;
   wire             ufm_write_cmd;
   wire             ufm_erase_cmd;
   wire             ufm_disable_cmd;
   reg                     ufm_enabled;
   reg                     n_ufm_enabled;
   wire             ufm_repeated_read;
   wire             ufm_repeated_write;
   


   reg [7:0]             wb_dat_i ;
   reg                     wb_stb_i ;
   wire             wb_cyc_i =  wb_stb_i ;
   reg [7:0]             wb_adr_i ;
   reg                     wb_we_i  ;
   wire [7:0]             wb_dat_o ;
   wire             wb_ack_o ;

   reg [7:0]             n_wb_dat_i ;
   reg                     n_wb_stb_i ;
   reg [7:0]             n_wb_adr_i ;
   reg                     n_wb_we_i  ;
   reg                     n_busy;
   reg                     n_error;
   reg [7:0]             c_state ,n_state;
   reg                     efb_flag,n_efb_flag;
   reg [7:0]             sm_wr_data;
   reg [3:0]             sm_addr;
   reg                     sm_ce;
   reg                     sm_we;
   reg [4:0]             count;
   reg                     sm_addr_MSB;
   reg [7:0]             sm_rd_data;


   reg [7:0]             n_data_frm_ufm;
   reg [3:0]             n_addr_ufm;
   reg                     n_clk_en_ufm;
   reg                     n_wr_en_ufm;
   reg [4:0]             n_count;
   reg                     n_ufm_addr_MSB;

   wire [7:0]  cmd_read;
   wire [7:0]  cmd_erase;
   wire [7:0]  cmd_program;
   wire [7:0]  cmd_select_sector;
   wire [12:0] real_address;
   
   
   PUR PUR_INST   (.PUR(1'b1));
   GSR GSR_INST   (.GSR(1'b1));

   flash inst1 (        .wb_clk_i(clk_i ),                                        // EFB with UFM enabled
                        .wb_rst_i(!rst_n ),
                        .wb_cyc_i(wb_cyc_i ),
                        .wb_stb_i(wb_stb_i ), 
                        .wb_we_i(wb_we_i ),
                        .wb_adr_i(wb_adr_i), 
                        .wb_dat_i(wb_dat_i ), 
                        .wb_dat_o(wb_dat_o ), 
                        .wb_ack_o(wb_ack_o ),
                        .wbc_ufm_irq( )
                        );
   
   // flashram inst2 (        .DataInA(sm_wr_data ),                                        // True dual port RAM. Port A controlled by internal SM and port B controlled by user.
     //                                 .DataInB(mem_wr_data ), 
   //                                 .AddressA({sm_addr_MSB,sm_addr} ), 
   //                                 .AddressB({!sm_addr_MSB,mem_addr} ), 
   //                                 .ClockA(clk_i ), 
   //                                 .ClockB(mem_clk ), 
   //                                 .ClockEnA(sm_ce ), 
   //                                 .ClockEnB(mem_ce ), 
   //                                 .WrA(sm_we ), 
   //                                 .WrB(mem_we ), 
   //                                 .ResetA(!rst_n ), 
   //                                 .ResetB(!rst_n ), 
   //                                 .QA(sm_rd_data ), 
   //                                 .QB(mem_rd_data ));                                


   always @ (*)
     begin
        sm_rd_data <= mem_rd_data;
        mem_we <= sm_we;
        mem_ce <= sm_ce;
        mem_clk <= clk_i;
        mem_addr <= sm_addr;
        mem_wr_data <= sm_wr_data;
     end
   
   assign ufm_enable_cmd = (cmd == 3'b100) ? 1'b1 : 1'b0 ;
   assign ufm_read_cmd = ((cmd == 3'b000) || (cmd == 3'b001)) ? 1'b1 : 1'b0 ;
   assign ufm_write_cmd = ((cmd == 3'b010) || (cmd == 3'b011)) ? 1'b1 : 1'b0 ;
   assign ufm_erase_cmd = (cmd == 3'b111) ? 1'b1 : 1'b0 ;
   assign ufm_disable_cmd = (cmd == 3'b101) ? 1'b1 : 1'b0 ;
   assign ufm_repeated_read = (cmd == 3'b001) ? 1'b1 : 1'b0 ;
   assign ufm_repeated_write = (cmd == 3'b011) ? 1'b1 : 1'b0 ;



  assign cmd_read    = (ufm_page[12:10] == 3'b111)? `CMD_UFM_READ : `CMD_CFG_READ ;  
  assign cmd_erase   = (ufm_page[12:10] == 3'b111)? `CMD_UFM_ERASE : `CMD_CFG_ERASE ;  
  assign cmd_program = (ufm_page[12:10] == 3'b111)? `CMD_UFM_PROGRAM : `CMD_CFG_PROGRAM ;  
  assign real_address= (ufm_page[12:10] == 3'b111)? {3'b000,ufm_page[9:0]} : ufm_page ;  
  assign cmd_select_sector = (ufm_page[12:10] == 3'b111)? 8'h40 : 8'h00 ;


   always @ (posedge clk_i or negedge rst_n)                        // generate clk enable and write enable signals for port A of the DPRAM
     begin
        if(!rst_n)
          begin
             sm_ce <= 1'b0;
             sm_we <= 1'b0;
          end
        else if (((c_state == `state58) && (n_state == `state59))  || ((c_state == `state51)))                        
          begin
             sm_ce <= 1'b0;
             sm_we <= 1'b0;
          end
        else if ((n_state == `state58) || ((c_state == `state50) && (n_state == `state51)))                
          begin
             sm_ce <= 1'b1;
             if (ufm_read_cmd)
               sm_we <= 1'b1;
             else
               sm_we <= 1'b0;
          end
        else 
          begin
             sm_ce <= 1'b0;
             sm_we <= 1'b0;
          end
     end
   
   
   always @ (posedge clk_i or negedge rst_n)
     begin 
        if(!rst_n)
          begin 
             wb_dat_i <= 8'h00;
             wb_stb_i <= 1'b0 ;
             wb_adr_i <= 8'h00;
             wb_we_i  <= 1'b0;   
          end   
        else 
          begin 
             wb_dat_i <=  n_wb_dat_i;
             wb_stb_i <=  #0.1 n_wb_stb_i;
             wb_adr_i <=  n_wb_adr_i;
             wb_we_i  <=  n_wb_we_i ;

          end 
     end 

   always @ (posedge clk_i or negedge rst_n)
     begin 
        if(!rst_n) begin 
           c_state  <= 10'h000;
           BUSY     <= 1'b1;
           efb_flag <= 1'b0 ;
           ERR           <= 1'b0;
           ufm_enabled <= 1'b0;
           sm_wr_data <= 8'h00;
           sm_addr <= 4'b0000;
           count <= 4'hF;
           sm_addr_MSB <= 1'b0;
        end  
        else begin  
           c_state  <= n_state   ;
           BUSY     <= n_busy;
           efb_flag <= n_efb_flag;
           ERR           <= n_error;
           ufm_enabled <= n_ufm_enabled;
           sm_wr_data <= n_data_frm_ufm;
           sm_addr <= n_addr_ufm;
           count <= n_count;
           sm_addr_MSB <= n_ufm_addr_MSB;
        end  
     end
   
   
   
   always @ (*)
     begin
        n_state = c_state;
        n_efb_flag   =  1'b0 ;
        n_busy  = BUSY;
        n_error = ERR;
        n_ufm_enabled = ufm_enabled;
        n_data_frm_ufm = sm_wr_data;
        n_addr_ufm = sm_addr;
        n_clk_en_ufm = sm_ce;
        n_wr_en_ufm = sm_we;
        n_count = count;
        n_ufm_addr_MSB = sm_addr_MSB;
        n_wb_dat_i = `ALL_ZERO ;
        n_wb_adr_i = `ALL_ZERO ;
        n_wb_we_i =  `LOW ;
        n_wb_stb_i = `LOW ;
        n_efb_flag = `LOW ;         
        case (c_state)
          
          `state0 : begin
             n_busy     =  1'b1;
             n_error    =  1'b0;
             n_ufm_enabled = 1'b0;
             n_state    =  `state1;                                        // (state1 - state8)--check if UFM is busy and deassert BUSY flag if free.
          end
          
          `state1: begin // enable WB-UFM interface
             if (wb_ack_o && efb_flag) begin
                n_state = `state2;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGCR;
                n_wb_dat_i = 8'h80;
                n_wb_stb_i = `HIGH ; 
                n_efb_flag   =  1'b1 ;
             end
          end
          
          
          `state2: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state3;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = `CMD_CHECK_BUSY_FLAG;
                n_wb_stb_i = `HIGH ; 
                n_efb_flag   =  1'b1 ;
             end
          end
          
          
          `state3: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state4;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ;
                n_efb_flag   =  1'b1 ;                   
             end
          end
          
          
          `state4: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state5;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_efb_flag   =  1'b1 ;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state5: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state6;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_efb_flag   =  1'b1 ;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ; 
                n_efb_flag   =  1'b1 ;
             end
          end
          
          
          `state6: begin // Return Back to State 2
             if (wb_ack_o && efb_flag) begin
                if(wb_dat_o & (8'h80) )
                  n_state = `state7;
                else
                  n_state = `state8;
             end
             else begin
                n_wb_we_i =  `READ_STATUS;
                n_wb_adr_i = `CFGRXDR;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ;
                n_efb_flag   =  1'b1 ;                   
             end
          end
          
          `state7: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state1;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_efb_flag   =  1'b1 ;
                n_wb_adr_i = `CFGCR;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ;
                n_busy     =  1'b1;                   
             end
          end         
          
          `state8: begin // 
             if (wb_ack_o && efb_flag) begin
                n_busy     =  1'b0;
                n_state = `state9;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_efb_flag   =  1'b1 ;
                n_wb_adr_i = `CFGCR;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ;
                n_busy     =  1'b1;                   
             end
          end
          
          `state9: begin
             if (GO)
               begin
                  n_busy     =  1'b1;
                  n_error    =  1'b0;
                  if (ufm_enabled && ufm_write_cmd)
                    n_ufm_addr_MSB = !sm_addr_MSB;        
                  n_state    =  `state10;
               end
             else
               begin
                  n_wb_dat_i = `ALL_ZERO ;
                  n_wb_adr_i = `ALL_ZERO ;
                  n_wb_we_i =  `LOW ;
                  n_wb_stb_i = `LOW ;
                  n_busy     =  1'b0;
                  n_error    =  ERR;
               end
          end
          
          
          `state10: begin         
             if(ufm_enable_cmd)                                        // enable UFM   
               n_state    =  `state11;
             else if (ufm_enabled)begin                        // decode command only if UFM is already enabled
                if (ufm_read_cmd)
                  n_state    =  `state35;
                else if (ufm_write_cmd)
                  n_state    =  `state35;
                else if (ufm_erase_cmd)
                  n_state    =  `state17;
                else if (ufm_disable_cmd)
                  n_state    =  `state23;
             end
             else begin                                                        // set ERR if a command is sent when UFM is disabled and go to previous state and wait for GO
                n_busy     =  1'b0;
                n_error    =  1'b1;
                n_state    =  `state9;
             end
          end        
          
          `state11: begin                                                         //  (state11 - state16) enable UFM        
             if (wb_ack_o && efb_flag) begin
                n_state = `state12;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGCR;
                n_efb_flag   =  1'b1 ;
                n_wb_dat_i = 8'h80;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state12: begin // enable configuration
             if (wb_ack_o && efb_flag) begin
                n_state = `state13;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_efb_flag   =  1'b1 ;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = `CMD_ENABLE_INTERFACE;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state13: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state14;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_efb_flag   =  1'b1 ;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h08;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state14: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state15;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h00;
                n_efb_flag   =  1'b1 ;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state15: begin //                                                 
             if (wb_ack_o && efb_flag) begin
                n_state = `state16;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_efb_flag   =  1'b1 ;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ;                   
             end
          end
          
          
          `state16: begin // 
             if (wb_ack_o && efb_flag) begin
                n_ufm_enabled = 1'b1;
                 n_state = `state1;                                // check for busy flag after enabling UFM
             end
             else begin
                n_efb_flag   =  1'b1 ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGCR ;
                n_wb_dat_i = 8'h00;
                n_busy     =  1'b1;
                n_wb_stb_i = `HIGH ;
                n_ufm_enabled = 1'b0;                   
             end
          end 
          
          
          `state17: begin                                                         // (state17- state22) erase UFM
             if (wb_ack_o && efb_flag) begin
                n_state = `state18;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGCR;
                n_efb_flag   =  1'b1 ;
                n_wb_dat_i = 8'h80;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state18: begin 
             if (wb_ack_o && efb_flag) begin
                n_state = `state19;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_efb_flag   =  1'b1 ;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = cmd_erase;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state19: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state20;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_efb_flag   =  1'b1 ;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h04;           //JM added for 0xE to erase CFG Flash
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state20: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state21;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h00;
                n_efb_flag   =  1'b1 ;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state21: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state22;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_efb_flag   =  1'b1 ;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          `state22: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state1;                        // check for busy flag after erasing UFM
             end
             else begin
                n_efb_flag   =  1'b1 ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGCR ;
                n_wb_dat_i = 8'h00;
                n_busy     =  1'b1;
                n_wb_stb_i = `HIGH ;                   
             end
          end 

          
          `state23: begin // open frame                        // (state23 - state 32) disable UFM
             if (wb_ack_o && efb_flag) begin
                n_state = `state24;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGCR;
                n_efb_flag   =  1'b1 ;
                n_wb_dat_i = 8'h80;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state24: begin // disable configuration
             if (wb_ack_o && efb_flag) begin
                n_state = `state25;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_efb_flag   =  1'b1 ;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = `CMD_DISABLE_INTERFACE;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state25: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state26;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_efb_flag   =  1'b1 ;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state26: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state27;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h00;
                n_efb_flag   =  1'b1 ;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state27: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state28;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_efb_flag   =  1'b1 ;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ; 
             end
          end
          `state28: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state29;
             end
             else begin
                n_efb_flag   =  1'b1 ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGCR ;
                n_wb_dat_i = 8'h00;
                n_busy     =  1'b1;
                n_wb_stb_i = `HIGH ;                   
             end
          end  
          
          `state29: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state30;
             end
             else begin
                n_efb_flag   =  1'b1 ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGCR ;
                n_wb_dat_i = 8'h80;
                n_busy     =  1'b1;
                n_wb_stb_i = `HIGH ;                   
             end
          end 
          `state30: begin                                                                 //  bypass command
             if (wb_ack_o && efb_flag) begin
                n_state = `state31;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_efb_flag   =  1'b1 ;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = `CMD_BYPASS;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state31: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state32;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_efb_flag   =  1'b1 ;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = `CMD_BYPASS;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state32: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state33;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = `CMD_BYPASS;
                n_efb_flag   =  1'b1 ;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state33: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state34;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_efb_flag   =  1'b1 ;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = `CMD_BYPASS;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state34: begin                                                                 // 
             if (wb_ack_o && efb_flag) begin
                n_busy     =  1'b0;
                n_ufm_enabled = 1'b0;
                n_state = `state9;
             end
             else begin
                n_efb_flag   =  1'b1 ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGCR ;
                n_wb_dat_i = 8'h00;
                n_busy     =  1'b1;
                n_wb_stb_i = `HIGH ;                   
             end
          end
          

          `state35: begin //                                                 (state35 - state60 ) UFM read/write operations
             if (wb_ack_o && efb_flag) begin
                if (ufm_repeated_read)
                  n_state = `state46;
                else if (ufm_repeated_write)
                  n_state = `state54;
                else
                  n_state = `state36;
             end
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGCR;
                n_wb_dat_i = 8'h80;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state36: begin                                                                 // Set UFM Page Address  
             if (wb_ack_o && efb_flag) begin
                n_state = `state37;
             end
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = `CMD_SET_ADDRESS;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state37: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state38;
             end
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state38: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state39;
             end
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state39: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state40;
             end
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state40: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state41;
             end
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = cmd_select_sector;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state41: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state42;
             end
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state42: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state43;
             end
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = {3'b000,real_address[12:8]};
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state43: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state44;
             end
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = real_address[7:0];
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          `state44: begin // 
             if (wb_ack_o && efb_flag) begin
                if (ufm_write_cmd)
                  n_state = `state53;
                else
                  n_state = `state45;
             end
             else begin
                n_efb_flag   =  1'b1 ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGCR ;
                n_wb_dat_i = 8'h00;
                n_busy     =  1'b1;
                n_wb_stb_i = `HIGH ;                   
             end
          end 
            
           `state45: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state46;
             end
             else begin
                n_efb_flag   =  1'b1 ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGCR ;
                n_wb_dat_i = 8'h80;
                n_busy     =  1'b1;
                n_wb_stb_i = `HIGH ;                   
             end
          end           
          
          `state46: begin // Read Operation
             if (wb_ack_o && efb_flag) begin
                n_count = READ_DELAY;
                n_state = `stateRD_delay;
             end
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = cmd_read;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          `stateRD_delay: begin
             if (count == 0)
               n_state = `state47;
             else begin
                n_count = count - 1;
             end
          end
          
          `state47: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state48;
             end
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h10;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state48: begin // 
             if (wb_ack_o && efb_flag)
               n_state = `state49;
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state49: begin // 
             if (wb_ack_o && efb_flag) begin
                n_count = 5'b10000;
                n_addr_ufm = 4'h0;
                n_clk_en_ufm = 1'b1;
                n_state = `state50;
             end
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h01;
                n_wb_stb_i = `HIGH ; 
             end
          end


          `state50: begin // 
             if (wb_ack_o && efb_flag) begin
                n_count = count - 1;
                n_data_frm_ufm = wb_dat_o;
                n_state = `state51;
             end
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `READ_DATA;
                n_wb_adr_i = `CFGRXDR;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ;
             end
          end                 

          `state51: begin // 
             n_addr_ufm = sm_addr + 1;
             if (count == 0)
               n_state = `state52;
             else begin
                n_state = `state50;
             end
          end
                 
          
          `state52: begin // 
             if (wb_ack_o && efb_flag) begin
                n_ufm_addr_MSB = !sm_addr_MSB;
                n_busy     =  1'b0;
                n_state = `state9;
             end
             else begin
                n_wb_we_i =  `WRITE;
                n_efb_flag   =  1'b1 ;
                n_wb_adr_i = `CFGCR;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ;
                n_busy     =  1'b1;                   
             end
          end        
          
             `state53: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state54;
             end
             else begin
                n_efb_flag   =  1'b1 ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGCR ;
                n_wb_dat_i = 8'h80;
                n_busy     =  1'b1;
                n_wb_stb_i = `HIGH ;                   
             end
          end
          `state54: begin // Write Operation
             if (wb_ack_o && efb_flag) begin
                     n_state = `state55;
             end
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = cmd_program;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state55: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state56;
             end
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state56: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state57;
             end
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h00;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state57: begin // 
             if (wb_ack_o && efb_flag) begin
                n_count = 5'b10000;
                n_addr_ufm = 4'h0;
                n_clk_en_ufm = 1'b1;
                n_wr_en_ufm = 1'b0;
                n_state = `state58;
             end
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = 8'h01;
                n_wb_stb_i = `HIGH ; 
             end
          end
          
          
          `state58: begin // 
             n_count = count - 1;
             n_state = `state59;
          end
          
          `state59: begin // 
             if (wb_ack_o && efb_flag) begin
                n_addr_ufm = sm_addr + 1;
                if (count == 0)
                  n_state = `state60;                                        
                else begin
                   n_state = `state58;
                end
             end
             else begin
                n_efb_flag = `HIGH ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGTXDR;
                n_wb_dat_i = sm_rd_data;
                n_wb_stb_i = `HIGH ;
             end
          end        
          
          `state60: begin // 
             if (wb_ack_o && efb_flag) begin
                n_state = `state1;
             end
             else begin
                n_efb_flag   =  1'b1 ;
                n_wb_we_i =  `WRITE;
                n_wb_adr_i = `CFGCR ;
                n_wb_dat_i = 8'h00;
                n_busy     =  1'b1;
                n_wb_stb_i = `HIGH ;                   
             end
          end        
        endcase
     end
   
   
   
endmodule  


