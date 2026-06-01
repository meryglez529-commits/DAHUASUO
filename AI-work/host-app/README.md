# FPGA Host App

This is the first host-app workspace for the SGSC SEM FPGA project.

The first version focuses on DL4 register control:

- GUI for manual operation.
- CLI for AI/scripts.
- Mock mode for development without hardware.
- DL2 data-plane placeholders for upcoming ADC data reception.

## Run From Source

From `AI-work/host-app`:

```powershell
D:\fpga_host_venv\Scripts\fpga-host.exe --help
D:\fpga_host_venv\Scripts\fpga-host.exe version --mock --json
```

## Test

```powershell
D:\fpga_host_venv\Scripts\python.exe -m unittest discover -s tests
```

## GUI

PySide6 is the preferred Qt binding. PyQt6/PyQt5 are fallback options.

Install the GUI dependency when the machine is ready for GUI work. The project uses `PySide6-Essentials` because the first GUI only needs QtCore/QtWidgets and does not need the much larger Qt Addons package.

```powershell
D:\fpga_host_venv\Scripts\python.exe -m pip install -e .[gui]
```

```powershell
D:\fpga_host_venv\Scripts\python.exe -m fpga_host.gui.app
```

The prepared GUI/CLI virtual environment is `D:\fpga_host_venv`.
