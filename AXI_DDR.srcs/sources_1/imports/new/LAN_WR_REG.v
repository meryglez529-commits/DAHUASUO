`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: LAN_WR_REG
//
// 0. 读这个模块，先记住一句话：
//   LAN_WR_REG 把 PC 发来的“寄存器命令字节流”翻译成 command_monitor_new 能直接消费的
//   一拍 WR_REG/RD_REG 控制脉冲。
//
// 它不做的事：
//   不解释寄存器地址的业务含义，不产生读回 payload，也不处理其它 UDP 业务类型。
//   地址含义在 command_monitor_new，读回打包在 LAN_RD_REG。
//
// 功能说明：
//   UDP payload 寄存器命令解析器。从逐字节的 payload 中识别固定格式的命令包，
//   提取出写寄存器命令（地址 + 数据）或读寄存器命令（地址）。
//
// 数据模型：
//   输入：来自 ETH_LAN_RX 的 payload 字节流（仅处理 LAN_RX_TYPE=1 的寄存器包）
//   输出：写命令 WR_REG_VALID + WR_REG_ADDR[15:0] + WR_REG_DATA[31:0]（1 拍脉冲）
//         读命令 RD_REG_VALID + RD_REG_ADDR[15:0]（1 拍脉冲）
//
// 上位机 payload 命令格式（大端字节序）：
//
//   写寄存器（14 字节）：
//   | 字节 0-3      | 字节 4-5  | 字节 6-7  | 字节 8-9    | 字节 10-13    |
//   | 55 55 AA AA   | 00 01     | 00 06     | ADDR[15:0]  | DATA[31:0]    |
//   | 包头          | 写命令    | 长度=6    | 寄存器地址  | 寄存器数据    |
//
//   读寄存器（10 字节）：
//   | 字节 0-3      | 字节 4-5  | 字节 6-7  | 字节 8-9    |
//   | 55 55 AA AA   | 00 02     | 00 02     | ADDR[15:0]  |
//   | 包头          | 读命令    | 长度=2    | 寄存器地址  |
//
// 解析原理：
//   使用 4 字节移位寄存器（data_type）作为滑动窗口，逐字节移入 payload。
//   状态机在特定 byte_cnt 位置从 data_type 中提取包头、命令类型、长度、地址、数据。
//
// 输入合同：
//   ETH_LAN_RX 需要把一个 payload 内的字节连续送出。状态机进入包解析后主要靠 byte_cnt
//   前进，只有滑动窗口本身受 lan_data_valid_r 保护；如果包中间插入无效拍，字段会错位。
//   LAN_DATA_NUM_i 当前没有参与状态机判断，真正的长度保护来自命令内部的 LEN_TYPE。
//
//////////////////////////////////////////////////////////////////////////////////
module LAN_WR_REG(
    input               tx_fifo_clock,       // 以太网时钟域（eth_clk）
    input               reset_n,             // 低电平复位

    // 来自 ETH_LAN_RX 的 payload 字节流
    input       [15:0]  LAN_DATA_NUM_i,      // payload 长度（当前未使用，靠命令内 LEN_TYPE 判断）
    input       [3:0]   LAN_RX_TYPE_i,       // 接收类型（只处理 type=1）
    input               lan_data_valid_i,    // payload 字节有效
    input       [7:0]   lan_data_i,          // payload 字节数据

    // 写寄存器命令输出 -> command_monitor_new
    output  reg         WR_REG_VALID_o,      // 写有效脉冲（1 拍）
    output  reg [15:0]  WR_REG_ADDR_o,       // 写地址
    output  reg [31:0]  WR_REG_DATA_o,       // 写数据

    // 读寄存器命令输出 -> command_monitor_new
    output  reg         RD_REG_VALID_o,      // 读有效脉冲（1 拍）
    output  reg [15:0]  RD_REG_ADDR_o        // 读地址
    );

 //------------------------------------------------------------------------------
 // 1. 类型过滤：只让寄存器端口的 payload 进入解析器
 //
 // LAN_RX_TYPE=1 来自 ETH_LAN_RX 对 UDP 32000 端口的分类。
 // 其它类型可能是 ADC 上传、remote、ARP/ICMP 等业务，本模块必须把它们挡在外面，
 // 否则随机 payload 也可能凑出 55 55 AA AA 这样的字节序列。
 //------------------------------------------------------------------------------
 reg        lan_data_valid_r;
 reg [7:0]  lan_data_r;
 always@(posedge tx_fifo_clock or negedge reset_n)
 begin
    if(!reset_n) begin
        lan_data_valid_r <= 0;
        lan_data_r       <= 8'd0;
    end
    else if(LAN_RX_TYPE_i == 4'd1 && lan_data_valid_i) begin
        lan_data_valid_r <= lan_data_valid_i;
        lan_data_r       <= lan_data_i;
    end
    else begin
       lan_data_valid_r <= 0;
       lan_data_r       <= 8'd0;
    end
 end

 //------------------------------------------------------------------------------
 // 2. 4 字节滑动窗口：不用缓存整包，也能在关键时刻取出 16/32 bit 字段
 //
 // 每拍移入 1 个新字节，data_type 始终包含最近 4 个字节。
 // 排列：r3(最旧) | r2 | r1 | r0(最新)。
 //
 // 例子：
 //   收到 55 55 AA AA 后，data_type = 32'h5555AAAA，可直接校验包头。
 //   收到地址高字节、地址低字节后，地址正好落在 data_type[15:0]。
 //   收到 4 个数据字节后，32-bit 写数据正好等于整个 data_type。
 //------------------------------------------------------------------------------
reg  [7:0]  lan_data_i_r0;
reg  [7:0]  lan_data_i_r1;
reg  [7:0]  lan_data_i_r2;
reg  [7:0]  lan_data_i_r3;
wire [31:0] data_type;
assign data_type = {lan_data_i_r3,lan_data_i_r2,lan_data_i_r1,lan_data_i_r0};
always@(posedge tx_fifo_clock or negedge reset_n)
begin
    if(!reset_n) begin
        lan_data_i_r0 <= 8'd0;
        lan_data_i_r1 <= 8'd0;
        lan_data_i_r2 <= 8'd0;
        lan_data_i_r3 <= 8'd0;
    end
    else if(lan_data_valid_r) begin
        lan_data_i_r0 <= lan_data_r;       // 最新字节移入 r0
        lan_data_i_r1 <= lan_data_i_r0;    // r0 -> r1
        lan_data_i_r2 <= lan_data_i_r1;    // r1 -> r2
        lan_data_i_r3 <= lan_data_i_r2;    // r2 -> r3
    end
    else begin
        lan_data_i_r0 <= lan_data_i_r0;    // 无新数据时保持不变
        lan_data_i_r1 <= lan_data_i_r1;
        lan_data_i_r2 <= lan_data_i_r2;
        lan_data_i_r3 <= lan_data_i_r3;
    end
end

 //------------------------------------------------------------------------------
 // 3. 命令解析状态机：把“一个网络包”变成“一拍寄存器命令”
 //
 // 状态转换（写命令路径）：
 //   0(等待0x55) -> 1(等包头) -> 2(校验包头) -> 3(等CMD) -> 4(判断读/写)
 //   -> 5(等LEN) -> 6(取地址) -> 7(取数据) -> 8(输出WR_REG_VALID) -> 回到 0
 //
 // 状态转换（读命令路径）：
 //   0 -> 1 -> 2 -> 3 -> 4
 //   -> 9(等LEN) -> 10(取地址) -> 11(输出RD_REG_VALID) -> 回到 0
 //
 // byte_cnt 记录当前字段已经走过多少字节，在关键位置从 data_type 提取字段。
 // 对新读者最容易混淆的是“大端字节序”和“滑窗低位”：
 //   网络包先来高字节，再来低字节；等字段到齐时，最后来的低字节在 r0，
 //   所以 16-bit 字段取 data_type[15:0]，32-bit 数据取完整 data_type。
 //------------------------------------------------------------------------------
reg  [3:0]  fsm_r;
reg  [15:0] byte_cnt;
reg  [31:0] HEAD_TYPE;  // 包头（应为 32'h5555AAAA）
reg  [15:0] CMD_TYPE;   // 命令类型（0x0001=写，0x0002=读）
reg  [15:0] LEN_TYPE;   // 后续数据长度（写=0x0006，读=0x0002）
always@(posedge tx_fifo_clock)
begin
    if(!reset_n) begin
        fsm_r    <= 0;
        byte_cnt <= 0;
        HEAD_TYPE <= 0;
        CMD_TYPE <= 0;
        LEN_TYPE <= 0;
        WR_REG_VALID_o <= 1'b0;
        WR_REG_ADDR_o <= 16'd0;
        WR_REG_DATA_o <= 32'd0;
        RD_REG_VALID_o <= 1'b0;
        RD_REG_ADDR_o <= 16'd0;
    end
    else
        case(fsm_r)

        // 状态 0：等待包头起始字节 0x55
        0:begin
            WR_REG_VALID_o <= 1'b0;
            RD_REG_VALID_o <= 1'b0;
            if(lan_data_valid_r && lan_data_r == 8'h55) begin
                fsm_r <= 1;
                byte_cnt <= byte_cnt + 1'b1;
            end
            else begin
                fsm_r <= 0;
                byte_cnt <= 0;
            end
        end

        // 状态 1：继续接收包头字节，等 4 字节到齐
        1:begin
            byte_cnt <= byte_cnt + 1'b1;
            if(byte_cnt == 5'd4) begin
                fsm_r <= 2;
                HEAD_TYPE <= data_type;  // 此时 data_type = {byte0, byte1, byte2, byte3}
            end
            else
               fsm_r <= 1;
        end

        // 状态 2：校验包头是否为 55 55 AA AA
        2:begin
            byte_cnt <= byte_cnt + 1'b1;
            if(HEAD_TYPE == 32'h5555AAAA)
                fsm_r <= 3;  // 包头正确，继续解析
            else
                fsm_r <= 0;  // 包头错误，丢弃
        end

        // 状态 3：等待命令类型字段到齐（2 字节）
        3:begin
            byte_cnt <= byte_cnt + 1'b1;
            if(byte_cnt == 5'd6) begin
                CMD_TYPE <= data_type[15:0];  // 取低 16 位作为命令类型
                fsm_r <= 4;
            end
            else
                fsm_r <= 3;
        end

        // 状态 4：根据命令类型分支
        4:begin
            byte_cnt <= byte_cnt + 1'b1;
            if(CMD_TYPE == 16'h0001)         // 0x0001 = 写寄存器
                fsm_r <= 5;
            else if(CMD_TYPE == 16'h0002)    // 0x0002 = 读寄存器
                fsm_r <= 9;
            else
                fsm_r <= 0;                  // 未知命令，丢弃
        end

        //===== 写寄存器路径（状态 5~8）=====
        // 写命令后续长度必须是 6 字节：2 字节地址 + 4 字节数据。
        // 状态 8 只在 byte_cnt 与 LEN_TYPE 对上时给出 WR_REG_VALID_o，
        // 因此 command_monitor_new 看到的永远是一拍、同拍携带地址和数据的写命令。

        // 状态 5：等待长度字段到齐（写命令长度应为 0x0006）
        5:begin
            if(byte_cnt == 5'd8) begin
                byte_cnt <= 0;
                LEN_TYPE <= data_type[15:0];  // 提取长度字段
                fsm_r <= 6;
            end
            else begin
                fsm_r <= 5;
                byte_cnt <= byte_cnt + 1'b1;
            end
        end

        // 状态 6：提取写寄存器地址（2 字节）
        6:begin
            byte_cnt <= byte_cnt + 1'b1;
            if(byte_cnt == 5'd1) begin
                WR_REG_ADDR_o <= data_type[15:0];  // 从滑窗低 16 位取地址
                fsm_r <= 7;
            end
            else
                fsm_r <= 6;
        end

        // 状态 7：提取写寄存器数据（4 字节）
        7:begin
            byte_cnt <= byte_cnt + 1'b1;
            if(byte_cnt == 5'd5) begin
                WR_REG_DATA_o <= data_type;  // 从滑窗取完整 32 位数据
                fsm_r <= 8;
            end
            else
                fsm_r <= 7;
        end

        // 状态 8：输出写有效脉冲（长度校验通过才有效）
        8:begin
            fsm_r <= 0;
            byte_cnt <= 0;
            if(byte_cnt == LEN_TYPE)         // byte_cnt 此时应等于 LEN_TYPE(6)
                WR_REG_VALID_o <= 1'b1;      // 校验通过，产生 1 拍写脉冲
            else
                WR_REG_VALID_o <= 1'b0;      // 长度不匹配，不产生写命令
        end

        //===== 读寄存器路径（状态 9~11）=====
        // 读命令后续长度必须是 2 字节：只有寄存器地址，没有数据字段。
        // 状态 11 只在长度匹配时给出 RD_REG_VALID_o，后续读回数据由 command_monitor_new
        // 根据 RD_REG_ADDR_o 查表产生，再由 WR_RD_REG_TOP/LAN_RD_REG 打包返回。

        // 状态 9：等待长度字段到齐（读命令长度应为 0x0002）
        9:begin
            if(byte_cnt == 5'd8) begin
                byte_cnt <= 0;
                LEN_TYPE <= data_type[15:0];
                fsm_r <= 10;
            end
            else begin
                fsm_r <= 9;
                byte_cnt <= byte_cnt + 1'b1;
            end
        end

        // 状态 10：提取读寄存器地址（2 字节）
        10:begin
            byte_cnt <= byte_cnt + 1'b1;
            if(byte_cnt == 5'd1) begin
                RD_REG_ADDR_o <= data_type[15:0];  // 从滑窗低 16 位取地址
                fsm_r <= 11;
            end
            else
                fsm_r <= 10;
        end

        // 状态 11：输出读有效脉冲（长度校验通过才有效）
        11:begin
            fsm_r <= 0;
            byte_cnt <= 0;
            if(byte_cnt == LEN_TYPE)         // byte_cnt 此时应等于 LEN_TYPE(2)
                RD_REG_VALID_o <= 1'b1;      // 校验通过，产生 1 拍读脉冲
            else
                RD_REG_VALID_o <= 1'b0;      // 长度不匹配，不产生读命令
        end

        default:begin
           fsm_r    <= 0;
           byte_cnt <= 0;
        end
        endcase
end

endmodule
