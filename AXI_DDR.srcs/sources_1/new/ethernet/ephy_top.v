`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/12/23 10:40:11
// Design Name: 
// Module Name: ephy_top
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


module ephy_top#(
 parameter ILA_DEBUG = 1'b0
)(
    input        clk_config,  //100M
    input        locked,

    output reg [1:0] phy_speed = 2'b10,
    output reg       update = 0,     

    output       PHY_RESETn,
    output       PHY_INTn,
    output       PHY_MDC,
    inout        PHY_MDIO

    );


assign PHY_INTn = 1'b1;

wire clk_i;
wire rst_i;

assign clk_i = clk_config;
assign rst_i      = !locked;
assign PHY_RESETn = locked;

wire test_mode;
wire w_cmd_vio;
wire r_cmd_vio;
wire   [4:0]   addr_vio;
wire   [15:0]  w_data_vio;

reg   [4:0]   addr     = 0 ;
reg   [15:0]  w_data_i = 0 ;
wire  [15:0]  r_data_o;

reg w_cmd_r0 = 0;   
reg w_cmd_r1 = 0;   
reg r_cmd_r0 = 0;   
reg r_cmd_r1 = 0;   
always@(posedge clk_i)
    begin
      w_cmd_r0 <=  w_cmd_vio; 
      w_cmd_r1 <=  w_cmd_r0; 
      r_cmd_r0 <=  r_cmd_vio; 
      r_cmd_r1 <=  r_cmd_r0;
    end

reg [1:0] en_sig_i  = 0;
reg [4:0] fsm =0;
reg [31:0] cnt_time = 0;
always@(posedge clk_i)
    if(rst_i)begin
        en_sig_i <= 0;
        addr     <= 0 ;
        w_data_i <= 0 ;
        cnt_time <= 0;
        phy_speed <= 2'b10;
        update <= 1'b0;
        fsm <= 0;
    end
    else case(fsm)
        0:begin
            if(cnt_time < 32'd10000000)begin //wait 100ms
                cnt_time <= cnt_time + 1'b1;
                fsm <= 0;
            end
            else begin
                cnt_time <= 0;
                fsm <= 1;
            end
        end
        1:begin
           if(done_sig_o) begin en_sig_i <= 2'b00;addr <= 0;w_data_i <= 0;fsm <= 2;end
           else begin en_sig_i <= 2'b01;addr <= 5'd24;w_data_i <= 16'h4148;fsm <= 1;end //config led
        end
        2:begin
           if(done_sig_o) begin en_sig_i <= 2'b00;addr <= 0;fsm <= 3;end
           else begin en_sig_i <= 2'b10;addr <= 5'd24;fsm <= 2;end 
        end
        3:begin
            if(r_data_o == 16'h4148)
                fsm <= 4;
            else 
                fsm <= 0;
        end
        4:begin
            if(test_mode)
                fsm <= 7;
            else 
                fsm <= 5;
        end
        5:begin
          if(done_sig_o) begin en_sig_i <= 2'b00;addr <= 0;update <= 1'b1;phy_speed <= r_data_o[15:14];fsm <= 6;end
           else begin en_sig_i <= 2'b10;addr <= 5'd17;fsm <= 5;end  
        end
        6:begin
           if(cnt_time < 32'd200000000)begin //wait 2s
                cnt_time <= cnt_time + 1'b1;
                fsm <= 6;
            end
            else begin
                update <= 1'b0;
                cnt_time <= 0;
                fsm <= 4;
            end 
        end
        7:begin
            if(w_cmd_r0 && !w_cmd_r1)
                fsm <= 8;
            else if(r_cmd_r0 && !r_cmd_r1)
            begin
                fsm <= 9;
            end
            else begin
                fsm <= 7;
            end
        end
        8:begin
            if(done_sig_o) begin en_sig_i <= 2'b00;addr <= 0;w_data_i <= 0;fsm <= 4;end
            else begin en_sig_i <= 2'b01;addr <= addr_vio;w_data_i <= w_data_vio;fsm <= 8;end
        end
        9:begin
            if(done_sig_o) begin en_sig_i <= 2'b00;addr <= 0;w_data_i <= 0;fsm <= 4;end
            else begin en_sig_i <= 2'b10;addr <= addr_vio;fsm <= 9;end
        end
        default:begin
            en_sig_i <= 0;
            addr     <= 0 ;
            w_data_i <= 0 ;
            cnt_time <= 0;
            phy_speed <= 2'b10;
            update <= 1'b0;
            fsm <= 0; 
        end
    endcase

wire sclk_o;
wire sdo_o;
wire sdi_i;
wire tri_dir;

assign PHY_MDC = sclk_o;
assign PHY_MDIO = tri_dir? sdo_o:1'bz;
assign sdi_i = PHY_MDIO;


phy_mdio_wr  u_phy_mdio_wr (
    .clk_i                   ( clk_i              ),
    .rst_i                   ( rst_i              ),
    .en_sig_i                ( en_sig_i    [1:0]  ),
    .addr                    ( addr        [4:0]  ),
    .w_data_i                ( w_data_i    [15:0] ),

    .r_data_o                ( r_data_o    [15:0] ),
    .done_sig_o              ( done_sig_o         ),
    .sclk_o                  ( sclk_o             ),
    .sdo_o                   ( sdo_o              ),
    .sdi_i                   ( sdi_i              ),
    .tri_dir                 ( tri_dir            ),
    .busy                    (                    ),
    .dg_fsm_o                (  )
);

generate if( ILA_DEBUG) begin

vio_ephy vio_ephy_inst (
  .clk(clk_i),                // input wire clk
  .probe_out0(w_cmd_vio),  // output wire [0 : 0] probe_out0
  .probe_out1(r_cmd_vio),  // output wire [0 : 0] probe_out1
  .probe_out2(addr_vio),  // output wire [4 : 0] probe_out2
  .probe_out3(w_data_vio),  // output wire [15 : 0] probe_out3
  .probe_out4(test_mode)  // output wire [0 : 0] probe_out4
);

ila_ephy ila_ephy_inst (
	.clk(clk_i), // input wire clk
	.probe0(en_sig_i), // input wire [1:0]  probe0  
	.probe1(addr), // input wire [4:0]  probe1 
	.probe2(w_data_i), // input wire [15:0]  probe2 
	.probe3(r_data_o), // input wire [15:0]  probe3 
	.probe4(done_sig_o), // input wire [0:0]  probe4 
	.probe5(sclk_o), // input wire [0:0]  probe5 
	.probe6(sdo_o), // input wire [0:0]  probe6 
	.probe7(sdi_i), // input wire [0:0]  probe7 
	.probe8(tri_dir), // input wire [0:0]  probe8 
	.probe9(fsm) // input wire [4:0]  probe9
);
end
else begin
    assign w_cmd_vio = 1'b0;
    assign r_cmd_vio = 1'b0;
    assign addr_vio = 5'd0;
    assign w_data_vio = 16'd0;
    assign test_mode = 1'b0;
end
endgenerate



endmodule
