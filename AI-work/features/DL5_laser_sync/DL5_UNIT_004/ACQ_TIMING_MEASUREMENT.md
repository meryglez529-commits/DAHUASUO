# DL5_UNIT_004 Acq Timing ILA Measurement

Date: 2026-06-05
Bitstream: `AI-work/features/DL5_laser_sync/DL5_UNIT_004/out/build/ETH_TOP_unit004.bit`
LTX: `AI-work/features/DL5_laser_sync/DL5_UNIT_004/out/build/ETH_TOP_unit004.ltx`

## Configuration

| Parameter | Value |
|---|---:|
| `laser_mode_en` | 1 |
| `rows` | 1 |
| `cols` | 4 |
| `adc_sample` / `dac_sample` | 50 |
| `acq_delay` | 5 |
| `acq_time` | 10 |
| `scan_mode` | 1 |
| `adc_interval` | 0 |

## Probe Decode

| ILA net | Meaning |
|---|---|
| `U6/N2/laser_pulse_ui_1` | Laser edge pulse in `ui_clk` domain |
| `U6/N2/dl5_ila_acq_cfg_1[31:16]` | `acq_delay_ui` |
| `U6/N2/dl5_ila_acq_cfg_1[15:0]` | `acq_time_ui` |
| `U6/N2/dl5_ila_acq_counts[31:16]` | `acq_delay_cnt` |
| `U6/N2/dl5_ila_acq_counts[15:0]` | `acq_time_cnt` |
| `U6/N2/dl5_ila_acq_status_1[3]` | `laser_mode_en_ui` |
| `U6/N2/dl5_ila_acq_status_1[2]` | `acq_pulse_ui` |
| `U6/N2/dl5_ila_acq_status_1[1:0]` | `acq_state` |

## Measurement

The exported current ILA buffer showed `dl5_ila_acq_cfg_1 = 0x0005000A`, confirming `acq_delay=5` and `acq_time=10`.

| Event | First pulse sample | Second pulse sample |
|---|---:|---:|
| `laser_pulse_ui` rising edge | 512 | 912 |
| `laser_pulse_ui` falling edge | 513 | 913 |
| `acq_pulse_ui` rising edge | 533 | 933 |
| `acq_pulse_ui` falling edge | 573 | 973 |
| `acq_pulse_ui` high width | 40 `ui_clk` cycles | 40 `ui_clk` cycles |

The delay phase after the first laser edge occupied samples `513..532`, with `acq_delay_cnt=0..19`, for 20 `ui_clk` cycles.

The acquisition high phase occupied samples `533..572`, with `acq_time_cnt=0..39`, for 40 `ui_clk` cycles.

## Result

PASS.

`acq_delay=5` expands to `5 << 2 = 20` `ui_clk` cycles, and `acq_time=10` expands to `10 << 2 = 40` `ui_clk` cycles. Assuming `ui_clk=200 MHz`, this is approximately 100 ns delay and 200 ns acquisition pulse width.
