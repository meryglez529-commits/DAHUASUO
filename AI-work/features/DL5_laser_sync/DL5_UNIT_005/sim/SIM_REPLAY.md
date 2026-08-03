# DL5_UNIT_005 Simulation Replay

## Testbench

- Top: `tb_dl5_unit_005_adc_trigger_wait`
- Testbench: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/sim/tb_dl5_unit_005_adc_trigger_wait.v`
- Stubs: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/sim/dl5_unit_005_stubs.v`
- DUT: `AXI_DDR.srcs/sources_1/new/adcdata_acq.v`

## Command

From the project root:

```powershell
powershell -ExecutionPolicy Bypass -File AI-work/features/DL5_laser_sync/DL5_UNIT_005/sim/run_batch.ps1
```

Equivalent direct Vivado command:

```powershell
vivado -mode batch -source AI-work/features/DL5_laser_sync/DL5_UNIT_005/sim/run_batch.tcl -nojournal -nolog
```

This follows the project SOP in `AI-work/guide/VIVADO_SIM_SOP.md`: `xvlog` and `xelab` are external commands, then simulation uses the Vivado Tcl built-in `xsim` command. Do not call `xsim.bat` directly in this environment.

## Checks

- `TC1`: one laser-mode `adc_tri` creates exactly one `acq_en` window and returns to trigger wait.
- `TC2`: no new window starts until a second `adc_tri` arrives.
- `TC3`: the third trigger with `image_column=3` increments `line_count` and clears `image_column_cnt`.

## Pass Criteria

The testbench writes `dl5_unit005_tb_result.txt`; the replay script passes only when that file contains `PASS`. Any spontaneous `acq_en` restart without a new `adc_tri` is a failure.

## Output

Simulation output directory:

`AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/sim/`

The SOP-compatible runner uses `AXI_DDR.sim/sim_1/behav/xsim` as the live simulator working directory and then copies `xvlog_unit005.log`, `xelab_unit005.log`, `xsim_unit005.log`, `dl5_unit005_tb_result.txt`, and the WDB into the unit `out/sim/` directory.

## Result

- 2026-06-18: `powershell -ExecutionPolicy Bypass -File AI-work/features/DL5_laser_sync/DL5_UNIT_005/sim/run_batch.ps1`
- Result: `PASS`
- Evidence: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/sim/result.txt`
- Transcript highlights:
  - `TC1: one trigger creates exactly one window`
  - `TC2: second trigger starts second pixel, no free-run`
  - `TC3: third trigger finishes the line`
  - `PASS`
