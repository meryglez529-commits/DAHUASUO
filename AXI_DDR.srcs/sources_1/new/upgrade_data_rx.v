`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/03/17 11:03:01
// Design Name: 
// Module Name: upgrade_data_rx
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
module upgrade_data_rx(
    input               clk,
    input               rstn,
    input       [3:0]   LAN_RX_TYPE_i,      //receive type sel
    input               lan_data_valid_i,   //byte data valid
    input       [7:0]   lan_data_i,         //byte data
    
    
    output reg  [31:0]  remote_len,
    output reg          remote_wr_en,
    output reg  [15:0]  remote_wr_data,
    output reg          remote_rx_done,
    input               remote_rstn,
    input                remote_complete
    );

reg        lan_data_valid_r;  
reg [7:0]  lan_data_r;
always@(posedge clk or negedge rstn)
begin
   if(!rstn) begin
       lan_data_valid_r <= 0;
       lan_data_r       <= 8'd0; 
   end
   else if(LAN_RX_TYPE_i == 4'd4 && lan_data_valid_i) begin
       lan_data_valid_r <= lan_data_valid_i;
       lan_data_r       <= lan_data_i;
   end
   else begin
      lan_data_valid_r <= 0;
      lan_data_r       <= 8'd0; 
   end
end   

reg [31:0] byte_cnt;
always@(posedge clk or negedge rstn)
begin
    if(!rstn) 
        byte_cnt <= 32'd0;
    else if(remote_rstn==0)
        byte_cnt <= 32'd0;
    else if(lan_data_valid_r)
        byte_cnt <= byte_cnt + 1'b1;
    else
        byte_cnt <= byte_cnt;
end 

//判断远程升级的帧头
reg  [95:0]  lan_data;
always@(posedge clk or negedge rstn)
begin
   if(!rstn) 
       lan_data <= 96'd0; 
   else if(lan_data_valid_r) 
       lan_data <= {lan_data[87:0],lan_data_r};
   else 
       lan_data <= lan_data; 
end

reg  [3:0]  fsm_r;
reg  [31:0] remote_len_cnt;
reg         wr_fifo_en;
reg  [7:0]  wr_fifo_data;
always@(posedge clk or negedge rstn)
begin
   if(!rstn) begin
       fsm_r    <= 0;
       remote_len <= 32'd0;
       remote_len_cnt <= 32'd0;
       wr_fifo_en   <= 1'b0;
       wr_fifo_data <= 128'd0;
       remote_rx_done <= 1'b0;
   end
   else
    if(remote_rstn==0) begin
        fsm_r    <= 0;
        remote_len <= 32'd0;
        remote_len_cnt <= 32'd0;
        wr_fifo_en   <= 1'b0;
        wr_fifo_data <= 128'd0;
        remote_rx_done <= 1'b0;
    end
    else
        case(fsm_r)
        0:begin
            if(lan_data_valid_r && lan_data[87:24]==64'h55AA55AA00000000 && {lan_data[23:0],lan_data_r} > 100) begin  //远程升级文件过小，不予处理
                fsm_r <= 1;
                remote_len <= {lan_data[23:0],lan_data_r};
            end
            else begin
                fsm_r <= 0;
                remote_len <= 32'd0; 
            end
        end
        1:begin 
            if(lan_data_valid_r) begin
                wr_fifo_en <= 1'b1; 
                wr_fifo_data <= lan_data_r; 
                if(remote_len_cnt < remote_len - 1) 
                    remote_len_cnt <= remote_len_cnt + 1'b1; 
                else 
                    begin remote_len_cnt <= 32'd0; fsm_r <= 2; end 
            end
            else
                wr_fifo_en <= 1'b0;
        end
        2:begin                                                                 //补无效数，使得数据是1024字节的整数倍
            if(remote_len[9:0]==0) begin
                wr_fifo_en <= 1'b0; 
                wr_fifo_data <= 8'd0;
                fsm_r <= 3; 
                remote_rx_done <= 1'b1;
            end
            else 
                if(remote_len_cnt < 1024 - remote_len[9:0]) begin
                    remote_len_cnt <= remote_len_cnt + 1'b1;
                    wr_fifo_en <= 1'b1; 
                    wr_fifo_data <= 8'd0;
                end
                else begin
                    remote_len_cnt <= 32'd0;
                    wr_fifo_en <= 1'b0; 
                    wr_fifo_data <= 8'd0;
                    fsm_r <= 3; 
                    remote_rx_done <= 1'b1;
                end     
        end
        3:begin
            if(remote_complete) begin
                fsm_r <= 0;
                remote_rx_done <= 1'b0;
            end
            else 
                fsm_r <= 3;
        end
        default:begin fsm_r <= 0; end
        endcase           
end  

reg bir;
reg [7:0] data_reg;
always@(posedge clk or negedge rstn)
begin
    if(!rstn) begin
        bir <= 1'b0;
        data_reg <= 8'd0;
        remote_wr_en <= 1'b0;
        remote_wr_data <= 16'd0;
    end
    else begin
        if(wr_fifo_en) begin
            bir <= ~bir;
            data_reg <= wr_fifo_data;
            if(bir) begin
                remote_wr_en <= 1'b1;
                remote_wr_data <= {data_reg, wr_fifo_data};
            end
            else
                remote_wr_en <= 1'b0;   
        end   
        else
            remote_wr_en <= 1'b0;    
    end
end

ila_11 zc_data_ila(
.clk        (clk),
.probe0     (lan_data_valid_r),
.probe1     (lan_data_r),
.probe2     (byte_cnt)
);


endmodule