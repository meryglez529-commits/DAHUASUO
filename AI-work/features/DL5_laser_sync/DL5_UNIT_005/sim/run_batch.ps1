$ErrorActionPreference = 'Stop'

$projectRoot = 'D:\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_325T_V3_171\fpga_prj'
$vivado = 'D:\Xilinx\Vivado\2021.1\bin\vivado.bat'
$script = Join-Path $projectRoot 'AI-work\features\DL5_laser_sync\DL5_UNIT_005\sim\run_batch.tcl'

Set-Location $projectRoot
& $vivado -mode batch -source $script -nojournal -nolog
if ($LASTEXITCODE -ne 0) { throw "vivado batch simulation failed with exit code $LASTEXITCODE" }
