# Pollen Diameter Batch Tool (ImageJ Macro)

[中文说明](#花粉粒直径批量统计工具imagej-宏)

This is a batch image-analysis macro for ImageJ / Fiji. It detects pollen grains in microscope images, measures grain area, converts area to equivalent circular diameter, and exports Excel-readable CSV tables.

Script file:

```text
Pollen_Diameter_Batch.ijm
```

## Features

- Batch-process pollen images from one input folder.
- Automatically detect the red `100 um` scale bar in the lower-right corner.
- Allow manual scale input when automatic scale detection is unreliable.
- Calculate equivalent circular diameter from measured area.
- Filter pollen candidates by circularity, default `Circularity = 0.50-1.00`.
- Filter objects outside the valid diameter range, default `20-100 um`.
- Export a main result table, particle detail table, summary table, and debug log.
- Optionally save outline preview images for visual quality control.

## Requirements

- ImageJ or Fiji

This tool is not a Python program. It is an ImageJ macro script with the `.ijm` extension.

## Usage

1. Open ImageJ.
2. Go to `Plugins > Macros > Run...`.
3. Select `Pollen_Diameter_Batch.ijm`.
4. Choose the input folder containing pollen images.
5. Choose the output folder.
6. Confirm or adjust parameters in the dialog.
7. Run the macro and wait for batch processing to finish.

The script does not have to be placed in the ImageJ `plugins` folder. You can keep it anywhere and run it through `Plugins > Macros > Run...`. Placing it in `plugins` only makes it easier to find later.

## Main Parameters

| Parameter | Default | Description |
| --- | ---: | --- |
| Scale bar length (um) | 100 | Real scale-bar length, matching the red `100 um` scale bar by default. |
| Manual pixels/pt for scale bar | 0 | Manual pixel length for the 100 um scale bar; use `0` for automatic detection. |
| Valid diameter min (um) | 20 | Lower valid diameter limit; users can adjust it. |
| Valid diameter max (um) | 100 | Upper valid diameter limit; users can adjust it. |
| Minimum circularity | 0.50 | Minimum circularity; objects in `0.50-1.00` are accepted by default. |
| Auto threshold | Default | Automatic thresholding method. |
| Save outline preview PNG | Optional | Save outline preview images for checking segmentation quality. |

## Output Files

The output folder will contain:

```text
pollen_diameter_table.csv
pollen_particles_detail.csv
pollen_summary.csv
pollen_debug_log.txt
pollen_previews/
```

| File | Description |
| --- | --- |
| pollen_diameter_table.csv | Main result table. Each image occupies three columns: index, area, and area-derived diameter. |
| pollen_particles_detail.csv | Per-particle detail table, including area-derived diameter, Feret diameter, coordinates, and scale information. |
| pollen_summary.csv | Per-image summary table, including valid count, mean diameter, standard deviation, minimum, and maximum. |
| pollen_debug_log.txt | Debug log for scale detection and segmentation steps. |
| pollen_previews/ | Optional outline preview images if preview saving is enabled. |

## Diameter Calculation

The macro measures pollen grain area first, then converts area to equivalent circular diameter:

```text
diameter = sqrt(4 * area / pi)
```

This method is used because:

- Pollen grains are usually close to circular, so area-derived diameter is stable.
- Direct Feret diameter can be enlarged by rough edges, shadows, or slight touching between grains.
- Area-derived diameter matches the common equivalent circular diameter calculation.

Feret diameter is still included in the detail table for manual review.

## Recommended Settings

```text
Scale bar length: 100 um
Manual pixels/pt for scale bar: 0
Valid diameter min: 20 um
Valid diameter max: 100 um
Minimum circularity: 0.50
Circularity range: 0.50-1.00
```

If automatic scale detection fails, manually enter the pixel length corresponding to `100 um`.

## Notes

- Put only pollen images in the input folder.
- Do not mix screenshots, instruction images, or unrelated images into the input folder.
- Severely overlapping pollen grains may not be perfectly separated; use outline previews for manual checking.
- Higher circularity thresholds are stricter but may miss true pollen grains.
- Lower `Minimum circularity` if too few objects are detected.
- Increase `Minimum circularity` if many merged objects or debris are included.
- The `20-100 um` diameter range is only the default and can be adjusted by users.


---

# 花粉粒直径批量统计工具（ImageJ 宏）

[English](#pollen-diameter-batch-tool-imagej-macro)

这是一个用于 ImageJ / Fiji 的批量花粉图片分析宏脚本。它可以自动识别显微图片中的花粉粒，统计花粉粒面积，并根据面积反推等效圆直径，最后导出 Excel 可打开的 CSV 表格。

脚本文件：

```text
Pollen_Diameter_Batch.ijm
```

## 功能特点

- 批量处理一个文件夹内的花粉图片。
- 自动识别图片右下角红色 `100 um` 标尺。
- 支持手动输入标尺像素值，避免自动标尺识别失败。
- 根据花粉粒面积反推等效圆直径。
- 使用圆度筛选花粉粒，默认 `Circularity = 0.50-1.00`。
- 过滤超出合理直径范围的对象，默认直径范围为 `20-100 um`。
- 导出主结果表、明细表、汇总表和调试日志。
- 可选择保存轮廓预览图，方便人工检查识别效果。

## 软件要求

- ImageJ 或 Fiji

本工具不是 Python 程序，而是 ImageJ 宏脚本，文件后缀为 `.ijm`。

## 使用方法

1. 打开 ImageJ。
2. 点击 `Plugins > Macros > Run...`。
3. 选择 `Pollen_Diameter_Batch.ijm`。
4. 选择花粉图片所在文件夹。
5. 选择结果输出文件夹。
6. 在参数窗口中确认或修改参数。
7. 点击运行，等待批量处理完成。

脚本文件不一定要放在 ImageJ 的 `plugins` 文件夹中；放在任意位置也可以通过 `Plugins > Macros > Run...` 手动选择运行。放入 `plugins` 文件夹只是为了以后更方便找到。

## 主要参数

| 参数 | 默认值 | 说明 |
| --- | ---: | --- |
| Scale bar length (um) | 100 | 标尺实际长度，默认对应图片中的红色 `100 um` 标尺。 |
| Manual pixels/pt for scale bar | 0 | 手动输入 100 um 对应的像素数；填 `0` 表示自动识别红色标尺。 |
| Valid diameter min (um) | 20 | 合理花粉直径下限，用户可自行调整。 |
| Valid diameter max (um) | 100 | 合理花粉直径上限，用户可自行调整。 |
| Minimum circularity | 0.50 | 最小圆度，默认识别圆度 `0.50-1.00` 的对象。 |
| Auto threshold | Default | 自动阈值方法。 |
| Save outline preview PNG | 可选 | 是否保存轮廓预览图，用于检查识别是否准确。 |

## 输出文件

运行结束后，输出文件夹中会生成：

```text
pollen_diameter_table.csv
pollen_particles_detail.csv
pollen_summary.csv
pollen_debug_log.txt
pollen_previews/
```

| 文件 | 说明 |
| --- | --- |
| pollen_diameter_table.csv | 主结果表，每张图片占 3 列：序号、面积、面积反推直径。 |
| pollen_particles_detail.csv | 每个候选花粉粒的明细，包含面积反推直径、Feret 直径、坐标、标尺信息等。 |
| pollen_summary.csv | 每张图片的汇总结果，包括有效数量、平均直径、标准差、最小值、最大值。 |
| pollen_debug_log.txt | 调试日志，用于排查标尺识别和分割步骤。 |
| pollen_previews/ | 如果勾选保存预览，会保存识别轮廓图。 |

## 直径计算方法

本工具默认先统计花粉粒面积，再根据面积反推等效圆直径：

```text
diameter = sqrt(4 * area / pi)
```

选择该方法的原因：

- 花粉粒通常接近圆形，面积反推直径更稳定。
- Feret 直接直径容易受边缘毛刺、阴影、轻微粘连影响而偏大。
- 面积反推直径与常见的“等效圆直径”计算方式一致。

明细表中仍保留 Feret 直径，方便人工复核。

## 推荐参数

```text
Scale bar length: 100 um
Manual pixels/pt for scale bar: 0
Valid diameter min: 20 um
Valid diameter max: 100 um
Minimum circularity: 0.50
Circularity range: 0.50-1.00
```

如果自动标尺识别失败，可以手动输入 `100 um` 对应的像素值。

## 注意事项

- 建议输入文件夹中只放待分析的花粉图片。
- 不要混入说明图、截图或其他无关图片。
- 如果花粉粒严重重叠，程序可能无法完全分开，需要结合轮廓预览图人工判断。
- 圆度阈值越高，结果越严格，但可能漏掉部分真实花粉粒。
- 如果识别结果偏少，可以适当降低 `Minimum circularity`。
- 如果识别结果包含较多粘连或杂质，可以适当提高 `Minimum circularity`。
- 直径范围 `20-100 um` 是默认值，用户可以根据实验材料自行调整。
