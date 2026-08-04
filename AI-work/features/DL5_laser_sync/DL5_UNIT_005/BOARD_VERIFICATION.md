# DL5_UNIT_005 Board Verification

## Build And Program

- Date: 2026-06-18
- Build command: `AI-work/scripts/run_synth.tcl AXI_DDR.xpr bit 4`
- Result: `BUILD PASS`
- Final timing:
  - WNS: `0.007947 ns`
  - TNS: `0.000000 ns`
  - WHS: `0.049464 ns`
  - THS: `0.000000 ns`
- Program result: PASS, 21/21 ILA cores resolved with the generated LTX.

## Evidence Paths

- Bitstream: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/bitstream/ETH_TOP_unit005.bit`
- LTX: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/bitstream/ETH_TOP_unit005.ltx`
- Build log: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/bitstream/vivado_build_bit.log`
- Timing metrics: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/impl/metrics.txt`
- Program log: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/hw_debug/program_unit005.log`
- ILA capture script: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/ila/capture_postfix_ila.tcl`

## ILA Capture After Host Parameters

- Scenario: `postfix_after_host`
- Summary: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/ila/postfix_after_host_capture_summary_20260618_161744.txt`
- UI capture: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/ila/postfix_after_host_UI_ACQ_TRIG_20260618_161744.csv`
- ADC capture: `AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/ila/postfix_after_host_ADC_ACQ_TRIG_20260618_161744.csv`

### UI_ACQ Result

- `laser_pulse_ui_1` triggered at sample `128`.
- One `laser_pulse_ui_1` pulse was captured.
- `dl5_ila_acq_cfg_1 = 0x000a000a`.
- `dl5_ila_acq_cfg = 0x000a`.
- Enable/status bit `dl5_ila_acq_status[3] = 1`.

### ADC_ACQ Result

- `adc_tri_r1` rising edge at sample `512`.
- `acq_en` window: sample `515` through `524`.
- `acq_en` width: `10` ADC clock samples.
- Captured configuration:
  - `adc_valid_point = 10`
  - `adc_sample_reg = 10`
  - `adc_sample_r2 = 50`
  - `adc_acq_delay_r2 = 0`
  - `acq_dead_time_r2 = 0`
- State distribution in the 2048-sample capture:
  - `state 0`: 2036 samples
  - `state 1`: 1 sample
  - `state 2`: 11 samples
- After `acq_en` falls at sample `525`, `state` returns to `0` and remains there for the rest of the capture.

## Conclusion

The board capture matches the intended fix: in DL5 laser mode, one `adc_tri` produces exactly one ADC acquisition window, then `adcdata_acq` returns to trigger-wait state instead of free-running into additional windows.

## Live Retest (2026-08-04)

- The project host application applied and read back the complete DL5 sequence: stop scan, disable laser, write `0x0206..0x020A = 100/20/80/30/60`, enable `0x020B = 1`, then start scan with `0x0009 = 0x1311`.
- The historical single-probe ILA method captured `U6/laser_sync_in` in `out/ila/laser_in_check_HIT_20260804_190952.csv`. It has four rising edges spaced by 250 eth-clock samples (about 2 us), and every edge produces one `laser_sync_rise_eth` pulse.
- The proven `capture_postfix_ila.tcl` then captured UI and ADC evidence in `out/ila/postfix_dl5_acq_*_20260804_191234.csv`: `laser_pulse_ui_1` rises every 400 UI-clock samples (about 2 us); `adc_tri_r1` rises every 100 ADC-clock samples (about 2 us).
- `acq_en` windows are 60 ADC-clock samples each (apart from capture edges), matching `acq_time = 60`. This confirms the live chain `J9/D15 -> laser_sync_in -> CDC -> laser_pulse_ui -> adc_tri -> ADC acquisition` is functioning.
