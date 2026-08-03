# DL5_UNIT_005 Architecture

## Current Fault

`adcdata_acq.v` uses one state machine for normal, ultrafast, and DL5 laser modes. In the laser-mode branch at the end of `state 2`, the current RTL does this when a row is not finished:

```verilog
state <= 4'd1;
```

Because `adc_interval_reg` is forced to zero in laser mode, returning to `state 1` immediately starts the next acquisition window. That makes the ADC path free-run after the first trigger.

## Fix

Only change the laser-mode non-row-end transition:

```verilog
state <= 4'd0;
```

This preserves `image_column_cnt`, so the next accepted `adc_tri` advances the next pixel. The row-end branch already returns to `state 0`, clears `image_column_cnt`, and pulses `line_count_en`.

## Verification

Add a focused standalone xsim testbench:

- `TC1`: in laser mode, after one `adc_tri`, exactly one acquisition window occurs and the DUT remains idle without a second trigger.
- `TC2`: a second `adc_tri` starts the second window, proving the row progress counter is preserved.
- `TC3`: after the third trigger with `image_column=3`, `line_count` increments and `image_column_cnt` clears.

The testbench compiles `adcdata_acq.v` with local simulation stubs for `sync_module`, `div_gen_0`, `fifo_generator_1`, `row_repeat_module`, and `ila_12`. This keeps the test focused on the state machine without relying on generated IP.

## Risk

Low. The RTL change is confined to the `laser_mode_en_r2` branch. Normal and ultrafast branches are not modified.
