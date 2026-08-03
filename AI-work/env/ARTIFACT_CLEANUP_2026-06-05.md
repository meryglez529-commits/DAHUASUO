# Artifact Cleanup 2026-06-05

## Summary

2026-06-05 12:37 cleaned scattered runtime/test artifacts from `D:\`, `D:\SGSC_SEM_dahuasuo_325T_V3_172`, and the FPGA project root.

Archive root:

```text
AI-work/reports/artifact-cleanup-2026-06-05/
```

Detailed move manifest:

```text
AI-work/reports/artifact-cleanup-2026-06-05/MANIFEST.csv
```

`AI-work/reports/` is ignored by `AI-work/.gitignore`, so these runtime artifacts are preserved locally without being committed as source.

## Moved Artifacts

| Count | Size MB | Archive group | Original source class |
|---:|---:|---|---|
| 22 | 0.00 | `D_root/hw_ila_data/` | `D:\hw_ila_data_*` empty Vivado ILA directories |
| 5 | 187.52 | `D_root/capture_csv/` | `D:\saveLine_*.csv` capture/test output files |
| 2 | 0.09 | `D_SGSC_SEM_dahuasuo_325T_V3_172_root/sim/` | top-level `xsim.dir` and `xvlog.pb` |
| 13 | 0.95 | `fpga_prj_root/vivado_logs/` | project-root `vivado*.log`, `vivado*.jou`, `vivado*.str` |
| 7 | 0.35 | `fpga_prj_root/hw_ila_btree/` | project-root `hw_ila_data_*.btree` |
| 2 | 0.16 | `fpga_prj_root/sim/` | project-root `xsim.dir` and `xvlog.pb` |
| 6 | 1.65 | `fpga_prj_root/crash_replay_logs/` | `hs_err_pid*.log`, `replay_pid*.log`, `ip_upgrade.log` |

Total moved: 57 items, about 190.72 MB.

## Deliberately Left In Place

- Vivado-managed project directories such as `.Xil/`, `AXI_DDR.runs/`, `AXI_DDR.hw/`, `AXI_DDR.cache/`, `AXI_DDR.gen/`, and `AXI_DDR.sim/`.
- Tool installs, archives, and reference documents under `D:\`, including Xilinx installers, `.rar`/`.zip`, protocol documents, and PDFs.
- Python environment `D:\fpga_host_venv`.

## Validation

After cleanup:

```text
python C:\Users\Administrator\.codex\skills\fpga-cowork\scripts\scan-artifact-spill.py D:\ --max-depth 2
PASS: no spilled runtime artifacts under D:\
```

Project-root top-level check also found no remaining `vivado*`, `hw_ila_data_*`, `hs_err_pid*`, `replay_pid*`, `xsim.dir`, `xvlog.pb`, or `ip_upgrade.log`.
