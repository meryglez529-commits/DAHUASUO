# DL5 寄存器检查脚本
# 用于验证FPGA上的DL5相关寄存器配置是否正确

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "DL5 Register Configuration Check" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

# 假设你有fpga-host命令行工具或类似的寄存器读写工具
# 如果没有，可以用Python脚本或其他UDP工具

Write-Host "`n1. 检查关键寄存器:" -ForegroundColor Yellow

$registers = @(
    @{Addr="0x0205"; Name="laser_mode_en"; Expected="1"; Desc="激光模式使能"}
    @{Addr="0x0206"; Name="scan_delay_time"; Expected="10"; Desc="扫描延迟(×8ns)"}
    @{Addr="0x0207"; Name="blanker_delay_time"; Expected="100"; Desc="blanker延迟(×5ns)"}
    @{Addr="0x0208"; Name="blanker_time"; Expected="100"; Desc="blanker宽度(×5ns)"}
    @{Addr="0x0209"; Name="acq_data_delay_time"; Expected="30"; Desc="acq延迟(×20ns)"}
    @{Addr="0x020A"; Name="acq_time"; Expected="25"; Desc="acq宽度(×20ns)"}
    @{Addr="0x0009"; Name="scan_control"; Expected="running"; Desc="扫描状态"}
)

Write-Host "`n请手动执行以下命令检查寄存器:" -ForegroundColor Green
Write-Host "如果你有fpga-host工具:" -ForegroundColor Gray

foreach ($reg in $registers) {
    Write-Host "  fpga-host read $($reg.Addr)  # $($reg.Name) - $($reg.Desc), 期望值: $($reg.Expected)" -ForegroundColor White
}

Write-Host "`n2. 如果寄存器读出来都是0或异常值:" -ForegroundColor Yellow
Write-Host "   → 说明板上运行的是旧版bitstream，需要重新烧录" -ForegroundColor Red

Write-Host "`n3. 如果0x0205 (laser_mode_en) = 0:" -ForegroundColor Yellow
Write-Host "   → 执行: fpga-host write 0x0205 1" -ForegroundColor Green

Write-Host "`n4. 配置完整的DL5参数（推荐值）:" -ForegroundColor Yellow
Write-Host @"
fpga-host write 0x0205 1      # 使能激光模式
fpga-host write 0x0206 10     # scan_delay = 80ns
fpga-host write 0x0207 20     # blanker_delay = 100ns (20×5ns)
fpga-host write 0x0208 20     # blanker_width = 100ns (20×5ns)
fpga-host write 0x0209 5      # acq_delay = 100ns (5×20ns)
fpga-host write 0x020A 5      # acq_width = 100ns (5×20ns)
"@ -ForegroundColor White

Write-Host "`n5. 然后用示波器观察:" -ForegroundColor Yellow
Write-Host "   CH1: laser_sync_in (TRIGGER_IN/D15)" -ForegroundColor White
Write-Host "   CH2: TRIG_BLANK (blanker输出)" -ForegroundColor White
Write-Host "   CH3: TRIGGER_OUT (acq输出)" -ForegroundColor White
Write-Host "   期望: laser in上升沿后 ~100ns，TRIG_BLANK应该有100ns脉冲" -ForegroundColor Green

Write-Host "`n==================================" -ForegroundColor Cyan
