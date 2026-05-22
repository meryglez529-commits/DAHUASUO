`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: ETH_LAN_RX
//
// 功能说明：
//   以太网 UDP 接收分类器。本模块接收已经通过 SGMII/MAC 层的字节流，解析以太网帧、
//   IP 包和 UDP 包头，根据目标 UDP 端口号将 payload 分流到不同的业务链路。
//
// 数据模型：
//   输入：逐字节的以太网帧（lan_data_in[7:0]，由 lan_data_en 指示有效）
//   输出：已分类的 UDP payload 字节流（lan_data_out[7:0]，由 lan_data_valid 指示有效）
//         + 分类标签 LAN_RX_TYPE（1=寄存器读写，2=扫描控制1，3=扫描控制2，4=远程数据）
//         + payload 长度 LAN_DATA_NUM（UDP payload 字节数，不含以太网/IP/UDP 头）
//
// 主合同：
//   当收到的 UDP 包目标端口匹配 DES_PORT_UDP_RX0~3 之一，且源 MAC/IP/端口匹配配置时，
//   本模块拉高 lan_data_valid，逐字节输出 payload，同时给出 LAN_RX_TYPE 和 LAN_DATA_NUM。
//   下游模块（如 WR_RD_REG_TOP）根据 LAN_RX_TYPE 选择是否消费这些字节。
//
// 在 DL4 寄存器控制链路中的位置：
//   PC UDP 包 -> [本模块] -> lan_data_out + LAN_RX_TYPE=1 -> LAN_WR_REG -> WR_REG_VALID/ADDR/DATA
//
// 不做的事：
//   - 不解析寄存器地址和数据（由 LAN_WR_REG 负责）
//   - 不校验 IP/UDP checksum（假设 MAC 层已过滤错误帧）
//   - 不重组分片 IP 包（假设上位机发送完整单包）
//
//////////////////////////////////////////////////////////////////////////////////
module ETH_LAN_RX#(
 parameter ILA_DEBUG = 1'b0
)(
			// 时钟和复位
			input                   clk,           // 以太网时钟域（通常是 user_axis_clk，125MHz）
			input                   reset_n,       // 低电平复位
			input                   init_done,     // 初始化完成标志，来自上层模块

			// 来自 MAC 层的字节流输入
			input                   lan_data_en,   // 字节有效使能，下降沿表示一帧结束
			input          [7:0]    lan_data_in,   // 输入字节数据（以太网帧，从目标 MAC 开始）
			input                   rx_axis_fifo_tlast,  // AXI Stream 帧尾标志（当前未使用）

			// 本板配置：用于过滤目标是本板的包
			input          [47:0]   SOR_MAC_i,      // 本板 MAC 地址（Source MAC in reply = Destination MAC in request）
			input          [31:0]   SOR_IP_i,       // 本板 IP 地址
			input          [15:0]   SOR_PORT_UDP_i, // 本板 UDP 端口（通常是 32000 = 0x7D00）

			// 上位机端口配置：用于区分不同业务类型
            input          [15:0]     DES_PORT_UDP_RX0_i, // LAN_RX_TYPE=1  寄存器读写端口（通常 32000）
            input          [15:0]     DES_PORT_UDP_RX1_i, // LAN_RX_TYPE=2  扫描控制1端口
            input          [15:0]     DES_PORT_UDP_RX2_i, // LAN_RX_TYPE=3  扫描控制2端口（含写扫描参数）
            input          [15:0]     DES_PORT_UDP_RX3_i, // LAN_RX_TYPE=4  远程数据/文件传输端口

			// 输出：已分类的 UDP payload
            output   reg   [15:0]   LAN_DATA_NUM = 0,    // UDP payload 字节数（IP 包长 - 28）
            output   reg   [3:0]    LAN_RX_TYPE  = 0,    // 接收类型：1=寄存器，2/3=扫描，4=远程
			output   reg            lan_data_valid = 0,  // payload 字节有效标志
			output   reg   [7:0]    lan_data_out   = 0   // payload 字节数据

			);


//*********************************************************//
//                  状态机定义
//*********************************************************//
// 状态机功能：逐步解析以太网帧结构，提取 UDP payload
//
// 状态转换流程：
//   idle -> start -> frame_type_judge -> data_resolution -> port_type_judge -> data_rx -> (回到 start 或 idle)
//
// 为什么需要这个状态机：
//   以太网帧是逐字节到达的，需要按固定偏移量提取各层协议字段。
//   状态机通过 byte_cnt 计数器在正确位置采样 MAC/IP/UDP 头字段，
//   然后根据端口匹配结果决定是否输出 payload。
//
	localparam      idle                  = 5'b00001;  // 等待新帧到达
	localparam      start                 = 5'b00010;  // 解析以太网头（14 字节：目标 MAC + 源 MAC + 帧类型）
	localparam      frame_type_judge      = 5'b00011;  // 判断帧类型是否为 IP（0x0800）
	localparam      data_resolution       = 5'b00100;  // 解析 IP 头（20 字节）和 UDP 头（8 字节）
	localparam      port_type_judge       = 5'b00101;  // 判断 UDP 端口是否匹配本板配置
	localparam      data_rx               = 5'b00110;  // 输出 UDP payload 字节流

	reg   [4:0]    state;

	// 输入字节的延迟链：用于构造 6 字节滑动窗口
	// 为什么需要延迟链：MAC 地址是 6 字节，需要同时观察连续 6 个字节才能判断地址匹配
	reg            lan_data_en_r;
	reg   [7:0]    lan_data_in_r;
	reg   [7:0]    lan_data_in_2r;
	reg   [7:0]    lan_data_in_3r;
	reg   [7:0]    lan_data_in_4r;
	reg   [7:0]    lan_data_in_5r;

	reg   [3:0]     wait_cnt;   // start 状态等待计数器
	reg   [4:0]     byte_cnt;   // data_resolution 状态字节计数器（0~27）
	reg   [15:0]    data_cnt;   // data_rx 状态 payload 字节计数器

	//*********************************************************//
	//          以太网/IP/UDP 协议字段寄存器
	//*********************************************************//
	// 这些寄存器在解析过程中逐步填充，用于后续的过滤判断
	//
	// 以太网头（14 字节）
    reg [47:0] DES_MAC_REC = 0;          // 目标 MAC 地址（应等于本板 MAC）
    reg [47:0] SOR_MAC_REC = 0;          // 源 MAC 地址（上位机 MAC）
    reg [15:0] FRAME_TYPE_REC = 0;       // 帧类型（应为 0x0800 表示 IP）

    // IP 头（20 字节，这里只记录关键字段）
    reg [15:0] IP_VERSION_REC = 0;       // IP 版本和头长度
    reg [15:0] IP_PACKET_LENGTH_REC = 0; // IP 包总长度（含 IP 头 + UDP 头 + payload）
    reg [15:0] IP_ID_REC = 0;            // IP 标识
    reg [15:0] FRAGMENT_OFFSET_REC = 0;  // 分片偏移
    reg [15:0] IP_TYPE_REC = 0;          // 协议类型（应为 0x0011 表示 UDP）
    reg [15:0] IP_HEAD_CHECKSUM_REC = 0; // IP 头校验和
    reg [31:0] SOR_IP_REC = 0;           // 源 IP 地址（上位机 IP）
    reg [31:0] DES_IP_REC = 0;           // 目标 IP 地址（应等于本板 IP）

    // UDP 头（8 字节）
    reg [15:0] SOR_PORT_REC = 0;         // 源端口（上位机端口，用于匹配 DES_PORT_UDP_RX0~3）
    reg [15:0] DES_PORT_REC = 0;         // 目标端口（应等于本板 SOR_PORT_UDP_i）
    reg [15:0] UDP_PACKET_LENGTH_REC = 0;// UDP 包长度（含 UDP 头 8 字节 + payload）
    reg [15:0] UDP_CHECKSUM_REC = 0;     // UDP 校验和

    // 6 字节滑动窗口：用于同时观察连续 6 个输入字节
    wire  [47:0]   judge_array;
			
//*********************************************************//
//                  ChipScope ILA 调试
//*********************************************************//
// 当 ILA_DEBUG=1 时，实例化 ILA 核用于在线观察关键信号
generate    
    if(ILA_DEBUG) begin:ila_debug   
    lan_rx_lia inst_lan_rx_lia (
        .clk(clk), // input wire clk
        .probe0(lan_data_en), // input wire [0:0]  probe0  
        .probe1(lan_data_in), // input wire [7:0]  probe1 
        .probe2(lan_data_valid), // input wire [0:0]  probe2 
        .probe3(lan_data_out), // input wire [7:0]  probe3 
        .probe4(state), // input wire [4:0]  probe4 
        .probe5(wait_cnt), // input wire [3:0]  probe5 
        .probe6(byte_cnt), // input wire [4:0]  probe6 
        .probe7(data_cnt), // input wire [15:0]  probe7 
        .probe8(DES_MAC_REC), // input wire [47:0]  probe8 
        .probe9(SOR_MAC_REC), // input wire [47:0]  probe9 
        .probe10(FRAME_TYPE_REC), // input wire [15:0]  probe10 
        .probe11(IP_VERSION_REC), // input wire [15:0]  probe11 
        .probe12(IP_PACKET_LENGTH_REC), // input wire [15:0]  probe12 
        .probe13(IP_ID_REC), // input wire [15:0]  probe13 
        .probe14(FRAGMENT_OFFSET_REC), // input wire [15:0]  probe14 
        .probe15(IP_TYPE_REC), // input wire [15:0]  probe15 
        .probe16(IP_HEAD_CHECKSUM_REC), // input wire [15:0]  probe16 
        .probe17(SOR_IP_REC), // input wire [31:0]  probe17 
        .probe18(DES_IP_REC), // input wire [31:0]  probe18 
        .probe19(SOR_PORT_REC), // input wire [15:0]  probe19 
        .probe20(DES_PORT_REC), // input wire [15:0]  probe20 
        .probe21(UDP_PACKET_LENGTH_REC), // input wire [15:0]  probe21 
        .probe22(UDP_CHECKSUM_REC), // input wire [15:0]  probe22 
        .probe23(judge_array), // input wire [47:0]  probe23
        .probe24(LAN_DATA_NUM), // input wire [15:0]  probe24
        .probe25(LAN_RX_TYPE), // input wire [3:0]  probe25
        .probe26(rx_axis_fifo_tlast) // input wire [0:0]  probe26
    ); 
end
endgenerate 


//*********************************************************//
//              主状态机和数据解析逻辑
//*********************************************************//

// 输入字节延迟链：构造 6 字节滑动窗口
	always@(posedge clk)begin
		if(!reset_n)begin
			lan_data_en_r     <= 1'd0;
			lan_data_in_r     <= 8'd0;
			lan_data_in_2r    <= 8'd0;
			lan_data_in_3r    <= 8'd0;
			lan_data_in_4r    <= 8'd0;
			lan_data_in_5r    <= 8'd0;
		end
        else begin
			lan_data_en_r     <= lan_data_en;
			lan_data_in_r     <= lan_data_in;
			lan_data_in_2r    <= lan_data_in_r;
			lan_data_in_3r    <= lan_data_in_2r;
			lan_data_in_4r    <= lan_data_in_3r;
			lan_data_in_5r    <= lan_data_in_4r;
        end
    end

    // lan_data_en 下降沿检测：表示一帧结束
    wire lan_data_en_p;
    assign  lan_data_en_p   = !lan_data_en && lan_data_en_r;

    // 6 字节滑动窗口：最新字节在低位，最旧字节在高位
    // 用途：同时观察 MAC 地址（6 字节）或其它多字节字段
    assign  judge_array     = {lan_data_in_5r,lan_data_in_4r,lan_data_in_3r,lan_data_in_2r,lan_data_in_r,lan_data_in};

	// 主状态机：解析以太网帧并提取 UDP payload
	always@(posedge clk)begin
		if(!reset_n)begin
            wait_cnt        <= 4'b0;
            byte_cnt        <= 5'd0;
            data_cnt        <= 16'd0;
			// 复位所有协议字段寄存器
            DES_MAC_REC <= 0;
            SOR_MAC_REC <= 0;
            FRAME_TYPE_REC <= 0;
            IP_VERSION_REC <= 0;
            IP_PACKET_LENGTH_REC <= 0;
            IP_ID_REC <= 0;
            FRAGMENT_OFFSET_REC <= 0;
            IP_TYPE_REC <= 0;
            IP_HEAD_CHECKSUM_REC <= 0;
            SOR_IP_REC <= 0;
            DES_IP_REC <= 0;
            SOR_PORT_REC <= 0;
            DES_PORT_REC <= 0;
            UDP_PACKET_LENGTH_REC <= 0;
            UDP_CHECKSUM_REC <= 0;
			state           <= idle;
		end
		else begin
			case(state)
				// 状态 1：idle - 等待新帧到达
				idle:
					begin
                        wait_cnt     <= 4'b0;
                        byte_cnt     <= 5'd0;
                        data_cnt     <= 16'd0;
						// 检测到帧结束（lan_data_en 下降沿）且初始化完成，进入 start 状态
						if(init_done && lan_data_en_p)
							state   <= start;
						else
							state   <= idle;
					end

				// 状态 2：start - 解析以太网头（14 字节）
				// 以太网帧结构：目标 MAC(6) + 源 MAC(6) + 帧类型(2) = 14 字节
				// 为什么用 wait_cnt：lan_data_en 下降后，延迟链中还有 6 个字节未处理完
				start:
					begin
					    wait_cnt  <= wait_cnt + 1'b1;
						if(lan_data_en == 0)begin  // 帧已结束，处理延迟链中的剩余字节
                            if(wait_cnt == 4'd11)begin
                                wait_cnt  <= 0;
                                state     <= frame_type_judge;
                            end
                            else if(wait_cnt == 4'd4)
                                DES_MAC_REC <= judge_array;  // 采样目标 MAC（前 6 字节）
                            else if(wait_cnt == 4'd10)
                                SOR_MAC_REC <= judge_array;  // 采样源 MAC（第 7~12 字节）
                            else begin
                                 state     <= start;
                            end
                        end
                        else
                            state    <= idle;  // 如果 lan_data_en 重新拉高，说明新帧到达，回到 idle
					end

				// 状态 3：frame_type_judge - 判断帧类型
				// 只处理 IP 包（帧类型 = 0x0800）
				frame_type_judge:
					begin
                        if(judge_array[15:0] == 16'h0800)  // 帧类型字段在以太网头的最后 2 字节
                            state    <= data_resolution;
                        else
                            state    <= idle;  // 非 IP 包，丢弃
                    end

                // 状态 4：data_resolution - 解析 IP 头和 UDP 头
                // IP 头 20 字节 + UDP 头 8 字节 = 28 字节
                // byte_cnt 从 0 计数到 27，在特定位置采样各字段
                data_resolution:
                    begin
                        byte_cnt <= byte_cnt + 1'b1;
                        if(byte_cnt == 5'd27)begin
                            byte_cnt <= 6'd0;
                            state    <= port_type_judge;
                            // 在 byte_cnt=27 时，judge_array 包含 UDP 头的最后 6 字节
                            DES_PORT_REC <= judge_array[47:32];          // 目标端口（UDP 头字节 2~3）
                            UDP_PACKET_LENGTH_REC <= judge_array[31:16]; // UDP 长度（UDP 头字节 4~5）
                            UDP_CHECKSUM_REC <= judge_array[15:0];       // UDP 校验和（UDP 头字节 6~7）
                        end
                        else case(byte_cnt)
                            3:begin  // IP 头字节 0~5
                                FRAME_TYPE_REC <= judge_array[47:32];       // 帧类型（以太网头最后 2 字节）
                                IP_VERSION_REC <= judge_array[31:16];       // IP 版本和头长度
                                IP_PACKET_LENGTH_REC <= judge_array[15:0];  // IP 包总长度
                            end
                            9:begin  // IP 头字节 6~11
                                IP_ID_REC <= judge_array[47:32];            // IP 标识
                                FRAGMENT_OFFSET_REC <= judge_array[31:16];  // 分片偏移
                                IP_TYPE_REC <= judge_array[15:0];           // 协议类型（0x0011=UDP）
                            end
                            15:begin  // IP 头字节 12~17
                               IP_HEAD_CHECKSUM_REC <= judge_array[47:32];  // IP 头校验和
                               SOR_IP_REC <= judge_array[31:0];             // 源 IP 地址（4 字节）
                            end
                            21:begin  // IP 头字节 18~19 + UDP 头字节 0~1
                               DES_IP_REC  <= judge_array[47:16];  // 目标 IP 地址（4 字节）
                               SOR_PORT_REC <= judge_array[15:0];  // 源端口（UDP 头字节 0~1）
                            end
                            default:begin
                                state    <= data_resolution;
                            end
                        endcase
                    end							
					// 状态 5：port_type_judge - 根据 UDP 源端口分类业务类型
				// 过滤条件：目标 MAC == 本板 MAC && 目标 IP == 本板 IP && 目标端口 == 本板端口
				// 分类依据：上位机源端口匹配 DES_PORT_UDP_RX0~3 中的哪一个
				// 匹配成功后：开始输出 payload 第一个字节，设置 LAN_RX_TYPE
				// LAN_DATA_NUM = IP_PACKET_LENGTH - 28（减去 IP 头 20 + UDP 头 8）
				port_type_judge:
					begin
                        if(DES_MAC_REC == SOR_MAC_i && DES_IP_REC == SOR_IP_i && DES_PORT_REC == SOR_PORT_UDP_i && SOR_PORT_REC == DES_PORT_UDP_RX0_i)
                            begin  // 匹配端口 0：寄存器读写（DL4 主链路）
                                data_cnt       <= data_cnt + 1'b1;
							    lan_data_valid <= 1;
							    lan_data_out   <= lan_data_in;
                                LAN_RX_TYPE <= 4'd1;
                                state    <= data_rx;
                                LAN_DATA_NUM <= IP_PACKET_LENGTH_REC - 5'd28;
                            end
                        else if(DES_MAC_REC == SOR_MAC_i && DES_IP_REC == SOR_IP_i && DES_PORT_REC == SOR_PORT_UDP_i && SOR_PORT_REC == DES_PORT_UDP_RX1_i)
                            begin  // 匹配端口 1：扫描控制1
                                data_cnt       <= data_cnt + 1'b1;
							    lan_data_valid <= 1;
							    lan_data_out   <= lan_data_in;
                                state    <= data_rx;
                                LAN_RX_TYPE <= 4'd2;
                                LAN_DATA_NUM <= IP_PACKET_LENGTH_REC - 5'd28;
                            end
                        else if(DES_MAC_REC == SOR_MAC_i && DES_IP_REC == SOR_IP_i && DES_PORT_REC == SOR_PORT_UDP_i && SOR_PORT_REC == DES_PORT_UDP_RX2_i)
                            begin  // 匹配端口 2：扫描控制2（含写扫描参数）
                                data_cnt       <= data_cnt + 1'b1;
							    lan_data_valid <= 1;
							    lan_data_out   <= lan_data_in;
                                state        <= data_rx;
                                LAN_RX_TYPE  <= 4'd3;
                                LAN_DATA_NUM <= IP_PACKET_LENGTH_REC - 5'd28;
                            end
                        else if(DES_MAC_REC == SOR_MAC_i && DES_IP_REC == SOR_IP_i && DES_PORT_REC == SOR_PORT_UDP_i && SOR_PORT_REC == DES_PORT_UDP_RX3_i)
                            begin  // 匹配端口 3：远程数据/文件传输
                                data_cnt       <= data_cnt + 1'b1;
							    lan_data_valid <= 1;
							    lan_data_out   <= lan_data_in;
                                state        <= data_rx;
                                LAN_RX_TYPE  <= 4'd4;
                                LAN_DATA_NUM <= IP_PACKET_LENGTH_REC - 5'd28;
                            end
                        else begin
                            state    <= idle;       // 端口不匹配，丢弃此包
                            LAN_RX_TYPE <= 4'b0000;
                        end
                    end

                // 状态 6：data_rx - 逐字节输出 UDP payload
                // 持续输出 lan_data_out 直到 data_cnt 达到 LAN_DATA_NUM
                // 输出完成后清除 valid 和 type，准备接收下一帧
                data_rx:
                    begin
						if(data_cnt == LAN_DATA_NUM)begin
							// payload 输出完毕
							data_cnt       <= 16'd0;
							lan_data_valid <= 1'b0;
							LAN_RX_TYPE    <= 4'b0000;
							lan_data_out   <= 8'd0;
							if(!lan_data_en)
							   state <= start;   // 如果还有后续帧数据在延迟链中，继续解析
							else
							   state <= idle;
                        end
                        else begin
                            // 继续输出 payload 字节
                            data_cnt       <= data_cnt + 1'b1;
							lan_data_valid <= 1;
							lan_data_out   <= lan_data_in;
							state          <= data_rx;
                        end
                    end
				default:
					begin
                        wait_cnt     <= 4'b0;
                        byte_cnt     <= 5'd0;
                        data_cnt     <= 16'd0;
						state        <= idle;
					end
			endcase
		end
	end
	
						
endmodule
