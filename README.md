# Pollen-diameter-calculation
Pollen diameter calculation based on the imagej
# Pollen Diameter Batch for ImageJ

This ImageJ macro batch-measures pollen grain area and diameter from microscope images.

## Requirements

- ImageJ or Fiji

## Usage

1. Open ImageJ.
2. Go to `Plugins > Macros > Run...`.
3. Select `Pollen_Diameter_Batch.ijm`.
4. Choose the input image folder.
5. Choose the output folder.
6. Set parameters and run.

## Main Parameters

- Scale bar length: default `100 um`
- Manual pixels/pt for scale bar: use `0` for auto detection
- Valid diameter range: default `20-80 um`
- Minimum circularity: default `0.60`, using `0.60-1.00`

## Output

- `pollen_diameter_table.csv`
- `pollen_particles_detail.csv`
- `pollen_summary.csv`
- `pollen_debug_log.txt`

## Diameter Calculation

Diameter is calculated from area:

```text
diameter = sqrt(4 * area / pi)
