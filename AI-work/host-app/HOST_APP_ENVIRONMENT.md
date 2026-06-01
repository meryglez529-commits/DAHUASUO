# 上位机 Python 环境记录

> 日期：2026-06-01 09:40
> 目的：为 FPGA 实板联调准备 GUI/CLI/mock/real UDP 运行环境。

## 1. 系统 Python

| 项 | 当前值 |
|---|---|
| Python | `3.12.10` |
| 位宽 | `64bit` |
| 可执行文件 | `C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe` |
| pip | 系统 pip 可用 |
| py launcher | `-V:3.12` 指向 Python 3.12.10 |

系统 Python 未安装 PySide6/PyQt。为避免污染系统环境，上位机使用独立虚拟环境。

## 2. 上位机虚拟环境

| 项 | 当前值 |
|---|---|
| venv 路径 | `D:\fpga_host_venv` |
| venv Python | `D:\fpga_host_venv\Scripts\python.exe` |
| CLI console script | `D:\fpga_host_venv\Scripts\fpga-host.exe` |
| 上位机包 | `fpga-host 0.1.0`，editable 安装 |
| Qt 绑定 | `PySide6_Essentials 6.11.1` |
| shiboken | `shiboken6 6.11.1` |

说明：最初尝试在工程长路径下创建 `.venv`，安装 PySide6-Essentials 时触发 Windows long path 问题。因此改用短路径 `D:\fpga_host_venv`。源码仍在 `AI-work/host-app/`。

## 3. 已验证命令

在 `AI-work/host-app` 目录执行：

```powershell
D:\fpga_host_venv\Scripts\python.exe -c "import PySide6.QtCore as QC, PySide6.QtWidgets as QW; print(QC.__version__)"
D:\fpga_host_venv\Scripts\python.exe -m fpga_host.cli.main version --mock --json
D:\fpga_host_venv\Scripts\fpga-host.exe version --mock --json
D:\fpga_host_venv\Scripts\python.exe -m unittest discover -s tests
D:\fpga_host_venv\Scripts\python.exe -c "from fpga_host.gui.main_window import MainWindow; print('GUI import OK')"
```

验证结果：

```text
PySide6 QtCore: 6.11.1
fpga-host: 0.1.0
unittest: 17 tests OK
GUI import / window object creation: OK
UDP 0.0.0.0:32000 bind: OK
```

## 4. 当前网卡信息

| 网卡 | IPv4 | 前缀 | 状态 |
|---|---|---:|---|
| `以太网 2` | `192.168.1.10` | `/24` | `Deprecated` |
| `以太网` | `172.16.32.105` | `/24` | `Preferred` |

FPGA 默认 IP 是 `192.168.1.8`，因此 `192.168.1.10/24` 与 FPGA 在同一网段。实测时建议显式指定：

```powershell
--host-ip 192.168.1.10 --fpga-ip 192.168.1.8
```

如果读版本号超时，优先检查：

1. 网线是否接到 `192.168.1.10` 所在网卡。
2. Windows 防火墙是否拦截 Python/UDP。
3. 本地 IP `192.168.1.10` 是否仍在该网卡上。
4. FPGA 是否已经完成上电和网口链路。

## 5. 实板测试命令

读版本号：

```powershell
cd D:\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_325T_V3_171\fpga_prj\AI-work\host-app
D:\fpga_host_venv\Scripts\fpga-host.exe version --host-ip 192.168.1.10 --fpga-ip 192.168.1.8 --json
```

停止扫描：

```powershell
D:\fpga_host_venv\Scripts\fpga-host.exe stop --host-ip 192.168.1.10 --fpga-ip 192.168.1.8 --yes --json
```

DL5 dry-run，不写硬件：

```powershell
D:\fpga_host_venv\Scripts\fpga-host.exe dl5 apply --host-ip 192.168.1.10 --fpga-ip 192.168.1.8 --laser-mode 1 --scan-delay 100 --blanker-delay 20 --blanker-time 80 --acq-delay 30 --acq-time 60 --dry-run --json
```

DL5 实际写入硬件：

```powershell
D:\fpga_host_venv\Scripts\fpga-host.exe dl5 apply --host-ip 192.168.1.10 --fpga-ip 192.168.1.8 --laser-mode 1 --scan-delay 100 --blanker-delay 20 --blanker-time 80 --acq-delay 30 --acq-time 60 --yes --json
```

启动 GUI：

```powershell
cd D:\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_dahuasuo_325T_V3_172\SGSC_SEM_325T_V3_171\fpga_prj\AI-work\host-app
D:\fpga_host_venv\Scripts\python.exe -m fpga_host.gui.app
```
