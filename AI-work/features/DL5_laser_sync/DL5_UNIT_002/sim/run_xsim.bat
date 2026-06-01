@echo off
set PATH=D:\Xilinx\Vivado\2021.1\bin;%PATH%
cd /d D:\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_325T_V3_171\fpga_prj\AXI_DDR.sim\sim_1\behav\xsim

echo === XVLOG ===
call xvlog --relax -prj tb_dl5_unit_002_vlog.prj -log xvlog.log
if errorlevel 1 (echo XVLOG FAILED & exit /b 1)

echo === XELAB ===
call xelab --debug typical --relax --mt 2 -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip -L xpm -L fifo_generator_v13_2_5 --snapshot tb_dl5_unit_002_behav xil_defaultlib.tb_dl5_unit_002 xil_defaultlib.glbl -log xelab.log
if errorlevel 1 (echo XELAB FAILED & exit /b 1)

echo === XSIM ===
call xsim tb_dl5_unit_002_behav --runall --wdb waveform.wdb -log xsim.log
if errorlevel 1 (echo XSIM FAILED & exit /b 1)

echo === DONE ===
