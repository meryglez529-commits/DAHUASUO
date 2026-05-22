`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/11 11:32:38
// Design Name: 
// Module Name: LAN_TX_MUX
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module LAN_TX_MUX(
    input                 fifo_wr_clk_i,
    input                 resetn_i,
	
	input                     tx_fifo_full_i,    //UDP port
    output reg    [31:0]      wr_num_o = 0,
    output reg    [7:0]       tx_fifo_din_o = 0,
    output reg                tx_fifo_wr_en_o = 0,
    output reg    [15:0]      DES_PORT_o = 0,
    
    input      [15:0]      test_wr_num_i,    //test port input
    input      [7:0]       test_tx_data_i,
    input                  test_tx_valid_i,
    input      [15:0]      test_port,
    
    input                  RD_REG_req_i,
    output     reg         RD_ACK_o =0,
    input      [15:0]      read_resp_wr_num_i,    //read reg resp port input
    input      [7:0]       read_resp_tx_data_i,
    input                  read_resp_tx_valid_i,
    input      [15:0]      read_resp_port,

    output reg   RD_EPROM_ACK = 1'b0,
    input        RD_EPROM_req,
    input [15:0] LAN_DATA_NUM_EPROM,
    input        lan_data_valid_EPROM,
    input [7:0]  lan_data_EPROM,
   
    output  reg            tx_data_done = 0,
    input                  data_req_i,
    output   reg           data_ACK_o = 0,
    input      [15:0]      data_wr_num_i,         //data port input
    input      [7:0]       data_tx_data_i,
    input                  data_tx_valid_i,
    input      [15:0]      data_port,
    
    input                 ARP_pc_req_i,
    output reg            ARP_ACK_o = 0,
    input  [7:0]          tx_axis_ARP_tdata, 
    input                 tx_axis_ARP_tvalid,
    input                 tx_axis_ARP_tlast,
    
    input                 ICMP_pc_req_i,
    output reg            ICMP_ACK_o = 0,
    input  [7:0]          tx_axis_ICMP_tdata, 
    input                 tx_axis_ICMP_tvalid,
    input                 tx_axis_ICMP_tlast,
    
    input                 wr_done_i,
    input  [7:0]          tx_axis_UDP_tdata,
    input                 tx_axis_UDP_tvalid,
    input                 tx_axis_UDP_tlast,
    
    output reg [7:0]      tx_axis_fifo_tdata = 0,
    output reg            tx_axis_fifo_tvalid = 0,
    output reg            tx_axis_fifo_tlast = 0
     
    );
    
  parameter S_IDLE    = 4'b0001;
  parameter S_TEST    = 4'b0010;
  parameter S_ARP     = 4'b0011;
  parameter S_ICMP    = 4'b0100;
  parameter S_RD_REG  = 4'b0101;
  parameter S_TX_DATA = 4'b0110;
  parameter S_RD_EPROM = 4'b0111;
 
   reg [3:0] state;
   always@(posedge fifo_wr_clk_i) 
      if(!resetn_i)
        begin
           wr_num_o         <= 0; 
           tx_fifo_din_o    <= 0;
           tx_fifo_wr_en_o  <= 0;
           DES_PORT_o       <= 0;
           RD_ACK_o         <= 0;
           data_ACK_o       <= 0;
           ARP_ACK_o        <= 0;
           ICMP_ACK_o       <= 0;
           RD_EPROM_ACK     <= 1'b0;
           state            <= S_IDLE;
        end
     else case(state)
        S_IDLE:begin
            if(RD_REG_req_i == 1'b1 && !wr_done_i) //read reg
              begin
                 RD_ACK_o <= 1'b1;
                 state <= S_RD_REG;
              end
            else if(data_req_i == 1'b1 && !wr_done_i)     //read data
              begin
                 tx_data_done <= 1'b0;
                 data_ACK_o <= 1'b1;
                 state <= S_TX_DATA;  
              end
            else if(ARP_pc_req_i == 1'b1) //ARP
              begin
                 ARP_ACK_o <= 1'b1;
                 state <= S_ARP;  
              end
           else if(ICMP_pc_req_i == 1'b1) //PING
              begin
                 ICMP_ACK_o <= 1'b1;
                 state <= S_ICMP; 
              end
           else if(RD_EPROM_req == 1'b1 && !wr_done_i) //read eprom
              begin
                 RD_EPROM_ACK <= 1'b1;
                 state <= S_RD_EPROM;
              end
           else if(test_tx_valid_i)   //TEST
                begin
                   state <= S_TEST;
                   wr_num_o        <= {16'd0,test_wr_num_i};
                   tx_fifo_wr_en_o <= test_tx_valid_i;
                   tx_fifo_din_o   <= test_tx_data_i;
                   DES_PORT_o      <= test_port;
                   
                   tx_axis_fifo_tdata  <= tx_axis_UDP_tdata;
                   tx_axis_fifo_tvalid <= tx_axis_UDP_tvalid;
                   tx_axis_fifo_tlast  <= tx_axis_UDP_tlast;
                end
           else
                 state <= S_IDLE;
        end
       S_RD_REG:begin
            wr_num_o        <= {16'd0,read_resp_wr_num_i};
            tx_fifo_wr_en_o <= read_resp_tx_valid_i;
            tx_fifo_din_o   <= read_resp_tx_data_i;
            DES_PORT_o      <= read_resp_port;
            
            tx_axis_fifo_tdata  <= tx_axis_UDP_tdata;
            tx_axis_fifo_tvalid <= tx_axis_UDP_tvalid;
            tx_axis_fifo_tlast  <= tx_axis_UDP_tlast;
            if(wr_done_i)
                begin
                    state <= S_IDLE;
                    RD_ACK_o <= 1'b0;
                end
            else
                state   <= S_RD_REG;  
       end
       S_TX_DATA:begin
           wr_num_o        <= {16'd0,data_wr_num_i};
           tx_fifo_wr_en_o <= data_tx_valid_i;
           tx_fifo_din_o   <= data_tx_data_i;
           DES_PORT_o      <= data_port;
            
           tx_axis_fifo_tdata  <= tx_axis_UDP_tdata;
           tx_axis_fifo_tvalid <= tx_axis_UDP_tvalid;
           tx_axis_fifo_tlast  <= tx_axis_UDP_tlast;
            if(wr_done_i)
                begin
                    tx_data_done <= 1'b1;
                    state <= S_IDLE;
                    data_ACK_o      <= 1'b0;
                end
            else
                state <= S_TX_DATA;                    
       end
       S_ARP:begin
           tx_axis_fifo_tdata  <= tx_axis_ARP_tdata;
           tx_axis_fifo_tvalid <= tx_axis_ARP_tvalid;
           tx_axis_fifo_tlast  <= tx_axis_ARP_tlast;
           if(ARP_pc_req_i)
              state <= S_ARP;  
           else begin
              state <= S_IDLE;
              ARP_ACK_o <= 1'b0;
           end
       end
       S_ICMP:begin
           tx_axis_fifo_tdata  <= tx_axis_ICMP_tdata;
           tx_axis_fifo_tvalid <= tx_axis_ICMP_tvalid;
           tx_axis_fifo_tlast  <= tx_axis_ICMP_tlast;
           if(ICMP_pc_req_i)
              state <= S_ICMP;  
           else begin
              state <= S_IDLE;
              ICMP_ACK_o <= 1'b0;
           end
       end
       S_TEST:begin
           wr_num_o        <= {16'd0,test_wr_num_i};
           tx_fifo_wr_en_o <= test_tx_valid_i;
           tx_fifo_din_o   <= test_tx_data_i;
           DES_PORT_o      <= test_port; 
           
           tx_axis_fifo_tdata  <= tx_axis_UDP_tdata;
           tx_axis_fifo_tvalid <= tx_axis_UDP_tvalid;
           tx_axis_fifo_tlast  <= tx_axis_UDP_tlast;
           if(wr_done_i)
                state <= S_IDLE;
            else
               state <= S_TEST;
       end
       S_RD_EPROM:begin
            wr_num_o        <= {16'd0,LAN_DATA_NUM_EPROM};
            tx_fifo_wr_en_o <= lan_data_valid_EPROM;
            tx_fifo_din_o   <= lan_data_EPROM;
            DES_PORT_o      <= read_resp_port;
            
            tx_axis_fifo_tdata  <= tx_axis_UDP_tdata;
            tx_axis_fifo_tvalid <= tx_axis_UDP_tvalid;
            tx_axis_fifo_tlast  <= tx_axis_UDP_tlast;
            if(wr_done_i)
                begin
                    state <= S_IDLE;
                    RD_EPROM_ACK <= 1'b0;
                end
            else
                state   <= S_RD_EPROM;  
       end
       default:begin
           wr_num_o         <= 0; 
           tx_fifo_din_o    <= 0;
           tx_fifo_wr_en_o  <= 0;
           DES_PORT_o       <= 0;
           RD_ACK_o         <= 0;
           data_ACK_o       <= 0;
           ARP_ACK_o        <= 0;
           ICMP_ACK_o       <= 0;
           state            <= S_IDLE; 
       end
     endcase

//ila_3 inst_LAN_TX_MUX (                                          
//	.clk(fifo_wr_clk_i), // input wire clk                                                                                                                                                                                   
//	.probe0(wr_num_o), // input wire [31:0]  probe0                   
//	.probe1(tx_fifo_din_o), // input wire [7:0]  probe1                
//	.probe2(tx_fifo_wr_en_o), // input wire [0:0]  probe2                      
//	.probe3(DES_PORT_o), // input wire [15:0]  probe3                              
//	.probe4(test_wr_num_i), // input wire [15:0]  probe4                  
//	.probe5(test_tx_data_i), // input wire [7:0]  probe5                       
//	.probe6(test_tx_valid_i), // input wire [0:0]  probe6             
//	.probe7(test_port), // input wire [15:0]  probe7                  
//	.probe8(RD_REG_req_i), // input wire [0:0]  probe8                
//	.probe9(RD_ACK_o), // input wire [0:0]  probe9                    
//	.probe10(read_resp_wr_num_i), // input wire [15:0]  probe10                           
//	.probe11(read_resp_tx_data_i), // input wire [7:0]  probe11                  
//	.probe12(read_resp_tx_valid_i), // input wire [0:0]  probe12                  
//	.probe13(read_resp_port), // input wire [15:0]  probe13              
//	.probe14(data_req_i), // input wire [0:0]  probe14                
//	.probe15(data_ACK_o), // input wire [0:0]  probe15                
//	.probe16(data_wr_num_i), // input wire [15:0]  probe16                  
//	.probe17(data_tx_data_i), // input wire [7:0]  probe17                            
//	.probe18(data_tx_valid_i), // input wire [0:0]  probe18                
//	.probe19(data_port), // input wire [15:0]  probe19                  
//	.probe20(ARP_pc_req_i), // input wire [0:0]  probe20              
//	.probe21(ARP_ACK_o), // input wire [0:0]  probe21                 
//	.probe22(tx_axis_ARP_tdata), // input wire [7:0]  probe22           
//	.probe23(tx_axis_ARP_tvalid), // input wire [0:0]  probe23                            
//	.probe24(tx_axis_ARP_tlast), // input wire [0:0]  probe24               
//	.probe25(ICMP_pc_req_i), // input wire [0:0]  probe25                  
//	.probe26(ICMP_ACK_o), // input wire [0:0]  probe26                
//	.probe27(tx_axis_ICMP_tdata), // input wire [7:0]  probe27         
//	.probe28(tx_axis_ICMP_tvalid), // input wire [0:0]  probe28          
//	.probe29(tx_axis_ICMP_tlast), // input wire [0:0]  probe29                            
//	.probe30(wr_done_i), // input wire [0:0]  probe30                   
//	.probe31(tx_axis_UDP_tdata), // input wire [7:0]  probe31           
//	.probe32(tx_axis_UDP_tvalid), // input wire [0:0]  probe32          
//	.probe33(tx_axis_UDP_tlast), // input wire [0:0]  probe33           
//	.probe34(tx_axis_fifo_tdata), // input wire [7:0]  probe34                            
//	.probe35(tx_axis_fifo_tvalid), // input wire [0:0]  probe35          
//	.probe36(tx_axis_fifo_tlast), // input wire [0:0]  probe36          
//	.probe37(state)              // input wire [3:0]  probe36          
//);                                                


    
    
endmodule
