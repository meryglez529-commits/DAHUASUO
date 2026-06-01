`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2020/07/09 09:42:39
// Design Name:
// Module Name: parameter_dacdata_gen
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
module parameter_dacdata_gen(
    input           ui_clk,
    input           rstn,
    input [15:0]    row_repeat,
    input [23:0]    dac_sample,
    input [15:0]    image_row,
    input [15:0]    dacx_strat_level,
    input [63:0]    dacx_step,
    input [15:0]    dacx_tk_point,
    input [15:0]    dacx_recovery_time,
    input [15:0]    dacy_strat_level,
    input [63:0]    dacy_step,
    input [31:0]    frame_waiting_time,
    input [31:0]    dax_fall_time,
    input [15:0]    dacx_pp_level,
    //------new----------------
    input [15:0]    row_m,
    input [15:0]    row_n,
    input    clk_sel,
    input    TRIGGER_IN,
    //-----
    output reg      para_config_wr_en,
    output [32:0]   para_config_data,
    input           para_config_prog_full,
    input           para_config_wr_rst_busy
    );

wire[31:0] dacx_tb_point;
assign      dacx_tb_point = (dacx_recovery_time<<5)+(dacx_recovery_time<<4)+(dacx_recovery_time<<1);

reg [3:0]   current_state;

reg [31:0]  dacx_tb_point_cnt;
reg [23:0]  dac_sample_cnt;
reg [15:0]  dacx_tk_point_cnt;
reg [15:0]  row_repeat_cnt;
reg [15:0]  image_row_cnt;
reg [31:0]  frame_waiting_cnt;
reg [63:0]  dax_level;
reg [63:0]  day_level;
reg         adc_tri;            //fifo[32]
reg [15:0]  DAX_DATA;           //fifo[31:16]
reg [15:0]  DAY_DATA;           //fifo[15:0]
assign      para_config_data = {adc_tri,DAX_DATA,DAY_DATA};

wire        div1_valid;
wire[31:0]  div1_data;
wire        div2_valid;
wire[31:0]  div2_data;
wire[15:0]  step;
wire[15:0]  cycle;
wire[15:0]  remain;
assign      step    = div1_data[31:16];
assign      remain  = div1_data[15:0];
assign      cycle   = div2_data[31:16] + 1'b1;
//assign      step   = image_row/(row_m + row_n);
//assign      cycle = (row_m/row_n) + 1'b1;
//assign      remain = image_row%(row_m + row_n);

wire        div3_valid;
wire[95:0]  div3_data;
wire[63:0]  dax_fall_step;  //放大2^48
assign      dax_fall_step = div3_data[95:32];
div_gen_2 row_step_div (
    .aclk                   (ui_clk),
    .s_axis_divisor_tvalid  (1'b1),                     //除数16bit
    .s_axis_divisor_tdata   (row_m + row_n),
    .s_axis_dividend_tvalid (1'b1),
    .s_axis_dividend_tdata  (image_row),               //被除数16bit
    .m_axis_dout_tvalid     (div1_valid),
    .m_axis_dout_tdata      (div1_data)
    );
div_gen_2 row_cycle_div (
    .aclk                   (ui_clk),
    .s_axis_divisor_tvalid  (1'b1),                     //除数16bit
    .s_axis_divisor_tdata   (row_n),
    .s_axis_dividend_tvalid (1'b1),
    .s_axis_dividend_tdata  (row_m),                    //被除数16bit
    .m_axis_dout_tvalid     (div2_valid),
    .m_axis_dout_tdata      (div2_data)
    );

div_gen_3 dax_step_div (
    .aclk                   (ui_clk),
    .s_axis_divisor_tvalid  ( 1'b1),                    //除数32bit
    .s_axis_divisor_tdata   ( dax_fall_time + 1),
    .s_axis_dividend_tvalid ( 1'b1),
    .s_axis_dividend_tdata  ({dacx_pp_level,48'd0}),    //被除数64bit
    .m_axis_dout_tvalid     ( div3_valid),
    .m_axis_dout_tdata      ( div3_data)
    );


reg [15:0]  row_n_cnt;
reg [15:0]  step_cnt;
reg [15:0]  cycle_cnt;
reg [15:0]  remain_cnt;
reg [15:0]  step_count;

reg [31:0]  dax_fall_cnt;
always@(posedge ui_clk or negedge rstn)
begin
    if(!rstn) begin
        current_state       <= 0;

        dacx_tb_point_cnt   <= 32'd0;
        dac_sample_cnt      <= 0;
        dacx_tk_point_cnt   <= 16'd0;
        row_repeat_cnt      <= 16'd0;
        image_row_cnt       <= 16'd0;
        frame_waiting_cnt   <= 32'd0;

        para_config_wr_en   <= 1'b0;
        adc_tri             <= 1'b0;
        dax_level           <= 64'h8000_0000_0000_0000;
        day_level           <= 64'h8000_0000_0000_0000;
        DAX_DATA            <= 16'h8000;
        DAY_DATA            <= 16'h8000;

        row_n_cnt           <= 0;
        step_cnt            <= 0;
        cycle_cnt           <= 0;
        remain_cnt          <= 0;
        step_count          <= 0;

        dax_fall_cnt        <= 0;
    end
    else
        case (current_state)
        0:
        begin
            para_config_wr_en       <= 1'b0;
            adc_tri                 <= 1'b0;
            dax_level               <= {dacx_strat_level,48'd0};
            day_level               <= {dacy_strat_level,48'd0};
            current_state           <= 1;
        end
        1:
        begin
            para_config_wr_en       <= 1'b0;
            adc_tri                 <= 1'b0;
            if(clk_sel == 1)begin
                 if(TRIGGER_IN)begin
                         if(dacx_tb_point == 0)                              //Tb invalid,then Tk
                          current_state       <= 3;
                      else                                                //Tb valid,then Tb
                          current_state       <= 2;
                 end
                   else
                           current_state       <= 1;
            end
            else begin
                    if(dacx_tb_point == 0)                              //Tb invalid,then Tk
                        current_state       <= 3;
                    else                                                //Tb valid,then Tb
                        current_state       <= 2;
              end
        end
        2:                                                      //Tb
        begin
            if(para_config_prog_full==0 && para_config_wr_rst_busy==0) begin
                para_config_wr_en       <= 1'b1;
                adc_tri                 <= 1'b0;
                DAX_DATA                <= dax_level[63:48];
                DAY_DATA                <= day_level[63:48];
                if(dacx_tb_point_cnt < dacx_tb_point - 1) begin
                    dacx_tb_point_cnt   <= dacx_tb_point_cnt + 1'b1;
                    current_state       <= 2;
                end
                else begin
                    dacx_tb_point_cnt   <= 0;
                    current_state       <= 3;
                end
            end
            else
                para_config_wr_en       <= 1'b0;
        end
        3:                                                      //one Tk point
        begin
            if(para_config_prog_full==0 && para_config_wr_rst_busy==0) begin
                para_config_wr_en       <= 1'b1;
                adc_tri                 <= 1'b1;
                DAX_DATA                <= dax_level[63:48];
                DAY_DATA                <= day_level[63:48];
                if(dac_sample_cnt < dac_sample - 1) begin
                    dac_sample_cnt      <= dac_sample_cnt+1'b1;
                    current_state       <= 3;
                end
                else begin
                    dac_sample_cnt      <= 0;
                    current_state       <= 4;
                end
            end
            else
                para_config_wr_en       <= 1'b0;
        end
        4:
        begin
            para_config_wr_en       <= 1'b0;
            if(dacx_tk_point_cnt < dacx_tk_point - 1) begin         //one Tk is done,next tk
                dacx_tk_point_cnt   <= dacx_tk_point_cnt + 1'b1;
                dax_level           <= dax_level + dacx_step;
                day_level           <= day_level;
                current_state       <= 3;
            end
            else begin                                              //all Tk is done
                dacx_tk_point_cnt   <= 16'd0;
                current_state       <= 12;
            end
        end
        //-------------------新添下降沿时间参数--------------------//
        12:
        begin
            para_config_wr_en       <= 1'b0;
            adc_tri                 <= 1'b0;
            if(dax_fall_time == 0)
                current_state       <= 5;
            else begin
                current_state       <= 13;
                dax_level           <= dax_level - dax_fall_step;
                day_level           <= day_level;
            end
        end
        13:
        begin
            if(para_config_prog_full==0 && para_config_wr_rst_busy==0) begin
                para_config_wr_en       <= 1'b1;
                adc_tri                 <= 1'b0;
                DAX_DATA                <= dax_level[63:48];
                DAY_DATA                <= day_level[63:48];
                if(dax_fall_cnt < dax_fall_time - 1) begin
                    current_state       <= 12;
                    dax_fall_cnt        <= dax_fall_cnt + 1'b1;
                end
                else begin
                    current_state       <= 5;
                    dax_fall_cnt        <= 0;
                end
            end
            else
                para_config_wr_en       <= 1'b0;
        end
//----------------行重复扫描-------------------------------------------
        5:
        begin
            para_config_wr_en       <= 1'b0;
            if(row_repeat_cnt < row_repeat - 1) begin
                row_repeat_cnt      <= row_repeat_cnt + 1'b1;
                current_state       <= 1;
                dax_level           <= {dacx_strat_level,48'd0};
                day_level           <= day_level;
            end
            else begin
                row_repeat_cnt      <= 0;
                if(remain_cnt == 0)
                    current_state   <= 6;
                else
                    current_state   <= 10;
            end
        end
//-----------------6~9为隔行扫描功能模块----------------------------//
        6:
        begin
            para_config_wr_en       <= 1'b0;
            if(row_n_cnt < row_n - 1) begin
                row_n_cnt           <= row_n_cnt + 1'b1;
                dax_level           <= {dacx_strat_level,48'd0};
                day_level           <= day_level + dacy_step;
                current_state       <= 1;
            end
            else begin
                row_n_cnt           <= 0;
                current_state       <= 7;
            end
        end
        7:
        begin
            para_config_wr_en       <= 1'b0;
            if(step_cnt < step - 1) begin
                step_cnt            <= step_cnt + 1'b1;
                dax_level           <= {dacx_strat_level,48'd0};
                //day_level           <= day_level + row_m *dacy_step + dacy_step;
                day_level           <= day_level + ((row_m*dacy_step[63:32]<<32) + row_m*dacy_step[31:0]) + dacy_step;
                current_state       <= 1;
            end
            else begin
                step_cnt            <= 0;
                current_state       <= 8;
            end
        end
        8:
        begin
            para_config_wr_en       <= 1'b0;
            if(cycle_cnt < cycle - 1) begin
                cycle_cnt           <= cycle_cnt + 1'b1;
                step_count          <= (cycle_cnt + 1)*row_n;
                current_state       <= 9;
            end
            else begin
                cycle_cnt           <= 0;
                current_state       <= 10;
            end
        end
        9:
        begin
            para_config_wr_en       <= 1'b0;
            dax_level               <= {dacx_strat_level,48'd0};
         //   day_level               <= {dacy_strat_level,48'd0} + step_count*dacy_step;
            day_level               <= {dacy_strat_level,48'd0} + ((step_count*dacy_step[63:32]<<32) + step_count*dacy_step[31:0]);
            current_state           <= 1;
        end
        10:
        begin
            para_config_wr_en       <= 1'b0;
            if(remain_cnt < remain) begin
                remain_cnt          <= remain_cnt + 1'b1;
                dax_level           <= {dacx_strat_level,48'd0};
                day_level           <= day_level + dacy_step;
                current_state       <= 1;
            end
            else begin
                remain_cnt          <= 0;
                dax_level           <= {dacx_strat_level,48'd0};
                day_level           <= {dacy_strat_level,48'd0};
                if(frame_waiting_time == 0)                         // no frame waiting,return to Tb
                    current_state   <= 1;
                else                                                //frame waiting,run to next
                    current_state   <= 11;
            end
        end
//////////////////////
        11:
        begin
            if(para_config_prog_full==0 && para_config_wr_rst_busy==0) begin
                para_config_wr_en       <= 1'b1;
                adc_tri                 <= 1'b0;
                DAX_DATA                <= dax_level[63:48];
                DAY_DATA                <= day_level[63:48];
                if(frame_waiting_cnt < frame_waiting_time - 1) begin
                    frame_waiting_cnt   <= frame_waiting_cnt + 1'b1;
                    current_state       <= 11;
                end
                else begin
                    frame_waiting_cnt   <= 0;
                    current_state       <= 1;
                end
            end
            else
                para_config_wr_en       <= 1'b0;
        end
        default:
        begin
            current_state       <= 0;

            dacx_tb_point_cnt   <= 32'd0;
            dac_sample_cnt      <= 24'd0;
            dacx_tk_point_cnt   <= 16'd0;
            row_repeat_cnt      <= 16'd0;
            image_row_cnt       <= 16'd0;
            frame_waiting_cnt   <= 32'd0;

            para_config_wr_en   <= 1'b0;
            adc_tri             <= 1'b0;
            dax_level           <= 64'h8000_0000_0000_0000;
            day_level           <= 64'h8000_0000_0000_0000;
            DAX_DATA            <= 16'h8000;
            DAY_DATA            <= 16'h8000;

            row_n_cnt           <= 0;
            step_cnt            <= 0;
            cycle_cnt           <= 0;
            remain_cnt          <= 0;
            step_count          <= 0;

            dax_fall_cnt        <= 0;
        end
        endcase
end

// ila_1 dac_ila(
//   .clk        (ui_clk),
//   .probe0     (dax_fall_cnt),
//   .probe1     (dax_fall_time)
//   );


endmodule