`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: WR_RD_REG_TOP
//
// 0. 读这个模块，先记住一句话：
//   WR_RD_REG_TOP 不解释“地址 0x0004 代表什么”，它只做协议胶合。
//   进入方向把 PC 的 UDP payload 字节流拆成 WR_REG/RD_REG 脉冲，
//   返回方向把 command_monitor_new 给出的 32-bit 读回值打包成 UDP payload。
//
// 为什么分成两个子模块：
//   LAN_WR_REG 负责请求侧，面向 PC -> FPGA 的“读/写寄存器命令”。
//   LAN_RD_REG 负责响应侧，面向 FPGA -> PC 的“读寄存器返回包”。
//   本层把二者接在同一个 eth_clk/user_axis_clk 时钟域里。
//
// 功能说明：
//   寄存器读写顶层封装。本模块将写命令解析（LAN_WR_REG）和读响应打包（LAN_RD_REG）
//   组合在一起，对外提供统一的寄存器读写接口。
//
// 数据模型：
//   输入：来自 ETH_LAN_RX 的 UDP payload 字节流（lan_data_valid_i + lan_data_i）
//   输出-写：WR_REG_VALID + WR_REG_ADDR[15:0] + WR_REG_DATA[31:0]（送给 command_monitor_new）
//   输出-读：RD_REG_VALID + RD_REG_ADDR[15:0]（送给 command_monitor_new）
//   输入-读回：RD_REG_DATA[31:0]（从 command_monitor_new 返回）
//   输出-读回包：lan_data_valid_o + lan_data_o（14 字节读回响应，送给 LAN_TX_MUX 发回 PC）
//
// 这里的单位要分清：
//   lan_data_i 是 8-bit 字节流；WR_REG_DATA/RD_REG_DATA 是 32-bit 寄存器值；
//   WR_REG_ADDR/RD_REG_ADDR 是 16-bit 控制地址，真正含义由 command_monitor_new 解码。
//
// 在 DL4 寄存器控制链路中的位置：
//   ETH_LAN_RX -> [本模块] -> command_monitor_new -> 控制参数
//                           -> LAN_TX_MUX -> PC（读回响应）
//
// 关键设计：
//   RD_REG_VALID 经过 3 拍延迟后才送给 LAN_RD_REG，
//   这是为了等待 command_monitor_new 完成读回数据的查表（RD_REG_DATA 需要时间稳定）。
//
//////////////////////////////////////////////////////////////////////////////////
module WR_RD_REG_TOP#( parameter ILA_DEBUG = 1'b0 )(
    input               tx_fifo_clock,       // 以太网时钟域（eth_clk）
    input               reset_n,             // 低电平复位

    // 寄存器写命令输出 -> command_monitor_new
    output              WR_REG_VALID,        // 写寄存器有效脉冲（1 拍）
    output      [15:0]  WR_REG_ADDR,         // 写寄存器地址
    output      [31:0]  WR_REG_DATA,         // 写寄存器数据

    // 寄存器读命令输出 -> command_monitor_new
    output              RD_REG_VALID,        // 读寄存器有效脉冲（1 拍）
    output      [15:0]  RD_REG_ADDR,         // 读寄存器地址

    // 寄存器读回数据输入 <- command_monitor_new
    input       [31:0]  RD_REG_DATA,         // 读回的 32-bit 寄存器值

    // 来自 ETH_LAN_RX 的 payload 字节流
    input      [15:0]   LAN_DATA_NUM_i,      // payload 长度
    input      [3:0]    LAN_RX_TYPE_i,       // 接收类型（只处理 type=1 寄存器读写）
    input               lan_data_valid_i,    // payload 字节有效
    input      [7:0]    lan_data_i,          // payload 字节数据

    // 读回响应发送接口 -> LAN_TX_MUX
    output              RD_REG_req_o,        // 请求发送读回响应包
    input               RD_ACK_i,            // LAN_TX_MUX 允许发送
    output              lan_data_valid_o,    // 读回响应字节有效
    output     [7:0]    lan_data_o           // 读回响应字节数据
    );


//------------------------------------------------------------------------------
// 1. 请求侧：从 payload 字节流中提取读/写寄存器命令
//
// LAN_WR_REG 的输出是“一拍命令合同”：
//   写：WR_REG_VALID=1 时，WR_REG_ADDR/WR_REG_DATA 同拍有效。
//   读：RD_REG_VALID=1 时，RD_REG_ADDR 同拍有效。
// command_monitor_new 只看这个合同，不再关心 UDP 包头和字节顺序。
//------------------------------------------------------------------------------
LAN_WR_REG LAN_WR_REG_inst (
    .tx_fifo_clock      (tx_fifo_clock),
    .reset_n            (reset_n),
    .lan_data_valid_i   (lan_data_valid_i),
    .lan_data_i         (lan_data_i[7:0]),
    .LAN_DATA_NUM_i     (LAN_DATA_NUM_i[15:0]),
    .LAN_RX_TYPE_i      (LAN_RX_TYPE_i[3:0]),
    .WR_REG_VALID_o     (WR_REG_VALID),
    .WR_REG_ADDR_o      (WR_REG_ADDR[15:0]),
    .WR_REG_DATA_o      (WR_REG_DATA[31:0]),
    .RD_REG_ADDR_o      (RD_REG_ADDR),
    .RD_REG_VALID_o     (RD_REG_VALID)
    );

//------------------------------------------------------------------------------
// 2. 读回定时：给 command_monitor_new 留出固定查表时间
//
// RD_REG_VALID 是读请求脉冲；RD_REG_DATA 是 command_monitor_new 的读回值。
// 本设计没有额外的 ready/valid 握手，而是把读请求延迟 3 拍后再触发 LAN_RD_REG。
// 换句话说，这里默认 command_monitor_new 在 3 个 eth_clk 内已经让 RD_REG_DATA 稳定。
// 如果以后把读回表改成多周期 RAM 或跨时钟返回，这个固定延迟就是需要一起复核的地方。
//------------------------------------------------------------------------------
reg [2:0] RD_REG_VALID_r;
always@(posedge tx_fifo_clock or negedge reset_n)
begin
    if(!reset_n)
        RD_REG_VALID_r <= 2'd0;
    else
        RD_REG_VALID_r <= {RD_REG_VALID_r[1:0],RD_REG_VALID};
end

//------------------------------------------------------------------------------
// 3. 响应侧：把读回值重新打包成 PC 能识别的 14 字节 payload
//
// LAN_RD_REG 不重新查表，它只消费已经稳定的 REG_ADDR/REG_DATA。
// 读回包格式固定为：
//   55 55 AA AA 00 03 00 06 ADDR[15:0] DATA[31:0]
// 随后 RD_REG_req_o 交给 LAN_TX_MUX 仲裁，真正的 UDP 发送端口仍由上层选择为 32000。
//------------------------------------------------------------------------------
LAN_RD_REG INST_LAN_RD_REG(
    .tx_fifo_clock      (tx_fifo_clock),
    .reset_n            (reset_n),
    .REG_VALID          (RD_REG_VALID_r[2]), // 延迟 3 拍后的读有效信号
    .REG_ADDR           (RD_REG_ADDR),
    .REG_DATA           (RD_REG_DATA),
    .RD_REG_req_o       (RD_REG_req_o),
    .RD_ACK_i           (RD_ACK_i),
    .lan_data_valid_o   (lan_data_valid_o),
    .lan_data_o         (lan_data_o)
    );

endmodule
