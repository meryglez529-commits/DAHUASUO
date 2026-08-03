# ILA Artifact Control

## Observed Facts

On 2026-06-18 14:50:51, `D:\hw_ila_data_1` through `D:\hw_ila_data_21` were created in the D: drive root. They were empty directories.

The current Vivado GUI Tcl Console can report:

`pwd = C:/Users/Administrator/AppData/Roaming/Xilinx/Vivado`

That means the currently running GUI instance would not explain `D:\hw_ila_data_*` by Tcl `pwd` alone.

## Reproduced Behavior

The behavior was reproduced on 2026-06-22 with `AI-work/scripts/repro_ila_artifact_location.tcl`.

Evidence is under:

- `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/hw_debug/ila_artifact_repro/`

Observed runs:

| Log | Initial/active pwd | Action | Result |
|---|---|---|---|
| `01_droot_refresh.log` | `D:/` | `refresh_hw_device` only | New `D:/hw_ila_data_22` |
| `02_appdata_refresh.log` | `C:/Users/Administrator/AppData/Roaming/Xilinx/Vivado` | `refresh_hw_device` only | No new D-root or AppData dir |
| `03_droot_cd_controlled_refresh.log` | initial `D:/`, active controlled work dir | `refresh_hw_device` only | No new D-root dir |
| `04_droot_refresh_repeat.log` | `D:/` | repeat `refresh_hw_device` only after archiving previous test dir | New `D:/hw_ila_data_22` again |
| `05_controlled_upload_all.log` | controlled work dir | `upload_hw_ila_data` on all ILAs | New `D:/hw_ila_data_22` despite controlled pwd |
| `06_controlled_upload_ila19_props.log` | controlled work dir | `upload_hw_ila_data` on `hw_ila_19` | New `D:/hw_ila_data_22` despite controlled pwd |

The current Vivado GUI journal also shows bulk Hardware Manager commands:

```tcl
display_hw_ila_data [ get_hw_ila_data hw_ila_data_1 ...]
...
display_hw_ila_data [ get_hw_ila_data hw_ila_data_22 ...]
display_hw_ila_data [upload_hw_ila_data ...]
```

Those commands match the pattern that can create many `hw_ila_data_N` placeholders.

## Root Cause

`D:\hw_ila_data_*` is produced by Vivado Hardware Manager ILA data-object handling, especially `display_hw_ila_data`, `get_hw_ila_data`, and `upload_hw_ila_data`.

There are two separate mechanisms:

1. If a Vivado Hardware Manager batch starts with `pwd=D:/`, even `refresh_hw_device` can create a new D-root placeholder directory.
2. `upload_hw_ila_data` can create a D-root placeholder even when Tcl `pwd` is a controlled directory. This appears to be Vivado 2021.1 Hardware Manager state/default behavior rather than a normal output path selected by the script.

Therefore, changing Tcl `pwd` is necessary but not sufficient.

## Prevention Rule

Every ILA Tcl script must do all of the following before `open_hw_manager`, `refresh_hw_device`, or `upload_hw_ila_data`:

1. Resolve `proj_root` from `[info script]`, not from `[pwd]`.
2. Create a unit-local work directory, for example:
   `AI-work/features/<feature>/<UNIT>/out/ila/vivado_hw_work`
3. Run `cd $work_dir`.
4. Write exported `.csv`, `.vcd`, `.wdb`, logs, and summaries with absolute paths under the current unit `out/`.
5. Print `PROJECT_ROOT` and `HW_WORK_DIR` in the Vivado log.
6. Snapshot `D:/hw_ila_data_*` before Hardware Manager actions and archive any newly-created D-root directories into the current unit, for example `out/ila/droot_spill/`.

Do not run ILA scripts from `D:\` unless the script itself has already changed directory to a unit-local `vivado_hw_work` directory.

## Required Runner

For new AI-driven ILA work, launch Vivado through:

```powershell
powershell -ExecutionPolicy Bypass -File AI-work/scripts/run_vivado_ila_guarded.ps1 `
  -Tcl AI-work/features/DL5_laser_sync/DL5_UNIT_005/ila/capture_postfix_ila.tcl `
  -OutDir AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/ila `
  -RunName capture_postfix_ila `
  -TclArgs postfix_after_host 120
```

The runner:

- starts Vivado batch from a unit-local `vivado_batch_work/` directory;
- writes `.log` and `.jou` under the selected `OutDir`;
- snapshots `D:/hw_ila_data_*` before Vivado starts;
- moves only newly-created D-root `hw_ila_data_*` directories into `OutDir/droot_spill/<run>/`;
- writes a `.spill_manifest.txt` with the exact moved paths.

Direct `vivado.bat -mode batch -source <ila.tcl>` is no longer acceptable for AI-driven ILA captures in this project.

## Fixed Scripts

The following scripts were updated on 2026-06-22 to follow the prevention rule:

- `AI-work/scripts/list_hw_ila_dl5.tcl`
- `AI-work/scripts/report_hw_ila_props.tcl`
- `AI-work/scripts/capture_dl5_eth_ila.tcl`
- `AI-work/scripts/capture_dl5_acq_ila.tcl`
- `AI-work/scripts/capture_dl5_adc1_acq_ila.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_005/ila/capture_postfix_ila.tcl`

After reproduction, the capture scripts that call `upload_hw_ila_data` were also updated to archive newly-created D-root `hw_ila_data_*` spill directories into `out/ila/droot_spill/`.

Historical scripts under older units may still rely on `[pwd]`. Prefer the fixed UNIT_005 scripts for new ILA work.

## Legacy Risk

The following historical scripts still combine Vivado Hardware Manager/ILA commands with `proj_root` derived from `[pwd]`. They are preserved as old debug evidence, but they should not be used for new captures unless updated first:

- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/capture_dax.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/capture_diag.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/capture_dl5_debug_signals.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/capture_dl5_ila_project_hw.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/capture_ila18_now.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/capture_ila9_now.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/capture_laser_edge.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/capture_laser_final.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/capture_laser_v2.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/capture_trigin.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/check_dac_output.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/check_laser_in.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/check_normal_mode.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/diag_laser_chain.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/list_hw_ila.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/list_hw_vio.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/program_and_verify.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/refresh_and_list_ila.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/report_ila18_props.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_003/sim/test_laser_toggle.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_004/sim/capture_ila.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_004/sim/export_acq_ila_current.tcl`
- `AI-work/features/DL5_laser_sync/DL5_UNIT_004/sim/program_ila_unit004.tcl`
