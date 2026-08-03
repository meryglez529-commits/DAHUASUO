# DL5_UNIT_005 RTL Review

| File | Why changed | What changed | Risk |
|---|---|---|---|
| `AXI_DDR.srcs/sources_1/new/adcdata_acq.v` | Laser-mode ADC path free-runs after the first trigger. | In the laser-mode branch, return to trigger-wait state after each non-row-end acquisition window. | Low; isolated to laser-mode branch. |

## Verification

- 2026-06-18: `tb_dl5_unit_005_adc_trigger_wait` PASS. The regression covers one-window-per-trigger behavior, no spontaneous restart between triggers, and row completion on the third trigger with `image_column=3`.
- 2026-06-18: Board ILA PASS after programming the fixed bitstream. `hw_ila_9` captured one `adc_tri_r1` edge, one 10-sample `acq_en` window, and then `state=0` for the remainder of the 2048-sample capture.
