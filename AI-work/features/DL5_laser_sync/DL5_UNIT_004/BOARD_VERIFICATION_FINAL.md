# DL5_UNIT_004 Board Verification Final

Date: 2026-06-05

## Summary

DL5_UNIT_004 has completed simulation, implementation, hardware programming, and ILA timing verification for the laser acquisition path.

| Item | Result | Evidence |
|---|---|---|
| Vivado/xsim regression | PASS | `out/regression/result.txt`, TC1-TC15, total errors 0 |
| Build and timing | PASS | `out/build/build_result.txt`, WNS=0.112080 ns, WHS=0.050655 ns |
| Bitstream programmed | PASS | FPGA enumerated 21 ILA cores after programming |
| ADC acquisition ILA integration | PASS | `U5/adcdata1_acq/test` includes `adc_valid_point`, `adc_valid_point_cnt`, `adc_sample_reg`, `adc_tri_r1` |
| DL5 acq timing ILA integration | PASS | `U6/N2/dl5_acq_timing_test` includes laser/acq config, status, and counters |
| Laser acq timing measurement | PASS | `ACQ_TIMING_MEASUREMENT.md` |

## Current Verified Case

| Parameter | Value |
|---|---:|
| `laser_mode_en` | 1 |
| `acq_delay` | 5 |
| `acq_time` | 10 |
| `rows` | 1 |
| `cols` | 4 |
| `adc_sample` / `dac_sample` | 50 |

Measured result:

- `dl5_ila_acq_cfg_1 = 0x0005000A`
- `laser_pulse_ui` first rising edge at sample 512
- `acq_pulse_ui` first rising edge at sample 533
- `acq_pulse_ui` first falling edge at sample 573
- delay counter ran `0..19`, matching `acq_delay=5` expanded by `<<2`
- acquisition counter ran `0..39`, matching `acq_time=10` expanded by `<<2`

## Conclusion

The laser acquisition timing path works as designed:

`laser_pulse_ui -> acq_delay -> acq_pulse_ui/acq_time`

The observed delay and pulse width match the RTL contract exactly in `ui_clk` cycles. UNIT_004 hardware verification is closed for this path.

Generated artifacts under `out/` are intentionally not committed. Rebuild and ILA export scripts are kept under `sim/`.
