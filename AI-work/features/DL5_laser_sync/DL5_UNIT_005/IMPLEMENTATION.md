# DL5_UNIT_005 Implementation

## Status

- 2026-06-18: Created unit after ILA showed `adcdata_acq` free-runs in laser mode after the first trigger.
- 2026-06-18: Planned one-line RTL fix in `AXI_DDR.srcs/sources_1/new/adcdata_acq.v`.
- 2026-06-18: Applied RTL fix and added focused regression testbench.
- 2026-06-18: Vivado batch simulation PASS.
- 2026-06-18: Synth/implementation/bitstream PASS; programmed the board and rechecked with ILA.

## Files

| File | Status | Purpose |
|---|---|---|
| `AXI_DDR.srcs/sources_1/new/adcdata_acq.v` | Done | Change laser-mode non-row-end transition from `state 1` to `state 0`. |
| `AI-work/features/DL5_laser_sync/DL5_UNIT_005/sim/tb_dl5_unit_005_adc_trigger_wait.v` | Done | Focused xsim testbench for trigger-wait behavior. |
| `AI-work/features/DL5_laser_sync/DL5_UNIT_005/sim/dl5_unit_005_stubs.v` | Done | Local simulation stubs for IP/modules outside the tested control path. |
| `AI-work/features/DL5_laser_sync/DL5_UNIT_005/sim/run_batch.tcl` | Done | Batch simulation replay using the project Vivado simulation SOP. |
| `AI-work/features/DL5_laser_sync/DL5_UNIT_005/sim/run_batch.ps1` | Done | Direct PowerShell replay wrapper. |
| `AI-work/features/DL5_laser_sync/DL5_UNIT_005/ila/capture_postfix_ila.tcl` | Done | Board ILA capture after programming the fixed bitstream. |
| `AI-work/features/DL5_laser_sync/DL5_UNIT_005/BOARD_VERIFICATION.md` | Done | Build, program, and ILA verification record. |

## Evidence

- ILA captures from the debug pass were archived from `AI-work/features/DL5_laser_sync/ila/` to `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/artifact_cleanup_20260622/legacy_feature_ila/`.
- Simulation result: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/sim/result.txt` = `PASS`.
- Simulation logs: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/sim/xvlog_unit005.log`, `xelab_unit005.log`, `xsim_unit005.log`.
- Wave database: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/sim/tb_dl5_unit_005_adc_trigger_wait_behav.wdb`.
- Testbench result marker: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/sim/dl5_unit005_tb_result.txt`.
- Bitstream: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/bitstream/ETH_TOP_unit005.bit`.
- LTX: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/bitstream/ETH_TOP_unit005.ltx`.
- Build metrics: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/impl/metrics.txt` (`WNS=0.007947 ns`, `WHS=0.049464 ns`).
- Program log: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/hw_debug/program_unit005.log`.
- ILA board verification: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/BOARD_VERIFICATION.md`.

## Open Items

- Continue image-level DL5 validation from the host application using the fixed bitstream.

## Log

- 2026-06-18: First Tcl-hosted run compiled and elaborated, but nested `xsim.bat` failed to initialize Tcl. Read `AI-work/guide/VIVADO_SIM_SOP.md` and updated the runner to use Vivado Tcl's built-in `xsim` command.
- 2026-06-18: Refactored runner to mirror the known-good UNIT_002 flow: open project, compile in `AXI_DDR.sim/sim_1/behav/xsim`, include `glbl.v`, use built-in `xsim`, and run a finite 200 us window.
- 2026-06-18: First regression run exposed a testbench sampling race: it measured `acq_en` at the same positive edge where DUT state changed. Updated checks to sample on `adc_dco` negative edges and wait for `acq_en` high before counting width.
- 2026-06-18: Added `dl5_unit005_tb_result.txt` marker because XSim log content is not always flushed before Tcl reads it.
- 2026-06-18: Final regression PASS: TC1 one trigger produces one window; TC2 no free-run before second trigger; TC3 third trigger completes the line.
- 2026-06-18: Built fresh bitstream. `impl_1` completed `write_bitstream`; final metrics were `WNS=0.007947 ns`, `TNS=0`, `WHS=0.049464 ns`, `THS=0`.
- 2026-06-18: Programmed the board with `AXI_DDR.runs/impl_1/ETH_TOP.bit` and matched `ETH_TOP.ltx`; 21/21 ILAs resolved.
- 2026-06-18: ILA after host parameter setup PASS: `adc_tri_r1` at sample 512, one `acq_en` window from 515 to 524, then `state` returned to 0 and stayed there.
- 2026-08-05: Reapplied the 16x16 laser-to-DAX scope profile and verified all 18 register readbacks before capture. Guarded ILA run `acq_timing_reconfigured` triggered both UI and ADC cores. UI capture shows `laser_pulse_ui_1` at samples 128/528/928; immediately after each edge, status `9` holds counts `0x00000000`, `0x00010000`, `0x00020000`, `0x00030000` (four UI clocks = 20 ns acquisition delay), then status `e` holds `0x00000000` through `0x00000003` (four UI clocks = 20 ns acquisition time). ADC capture repeatedly shows `adc_tri_r1` then `acq_en` three ADC clock samples later for one ADC clock. Evidence: `out/ila/acq_timing_reconfigured_UI_ACQ_TRIG_20260805_101217.csv` and `out/ila/acq_timing_reconfigured_ADC_ACQ_TRIG_20260805_101217.csv`.
