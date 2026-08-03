# DL5_UNIT_005 Requirements

## Goal

Fix the DL5 laser-mode ADC acquisition state machine so that each pixel acquisition window is started by one accepted `adc_tri` pulse. After one laser-mode acquisition window finishes, the ADC path must return to the trigger-wait state and must not start the next pixel by itself.

## Evidence

- Scope verification: `TRIG_BLANK` delay and width respond correctly to DL5 parameters, proving the laser input and blanker timing path are alive.
- ILA `U6/dl5_eth_debug`: `parameter_dacdata_gen` correctly runs `State14 -> State15 -> State16 -> State4 -> State14`; `dac_sample_cnt` runs `0..49` when `dac_sample=50`.
- ILA `U6/N2/dl5_acq_timing_test`: `laser_pulse_ui -> acq_pulse_ui` works; current capture shows `acq_delay=10` and `acq_time=50`.
- ILA `U5/adcdata1_acq/test`: after the first DL5 `adc_tri`, `adcdata_acq` continues generating acquisition windows without waiting for the next `adc_tri`.

## Required Behavior

- In laser mode:
  - `state 0` waits for `adc_tri` rising edge.
  - `state 1` applies the configured trigger-to-acquisition delay, which is currently forced to zero for laser mode.
  - `state 2` asserts `acq_en` for `acq_time` ADC DCO cycles.
  - After one window, if the row is not complete, return to `state 0` and wait for the next `adc_tri`.
  - After `image_column` windows, pulse `line_count_en`, increment `line_count`, clear `image_column_cnt`, then return to `state 0`.
- Preserve non-laser behavior:
  - Normal mode still captures a whole row after one trigger.
  - Ultrafast mode still uses its existing window/dead-time loop.

## Out Of Scope

- Changing DL5 DAC timing, blanker timing, `dac_output.v`, or physical IO constraints.
- Rebuilding bitstream in this unit unless requested after simulation passes.
