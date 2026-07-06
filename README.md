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
-

## Diameter Calculation

Diameter is calculated from area:

```text
diameter = sqrt(4 * area / pi)
```

# 花粉粒直径批量统计工具（ImageJ 宏）

这是一个用于 ImageJ / Fiji 的批量花粉图片分析宏脚本，可以自动识别显微图片中的花粉粒，统计花粉粒面积，并根据面积反推花粉粒直径，最后导出 Excel 可打开的 CSV 表格。

脚本文件：

```text
Pollen_Diameter_Batch.ijm
```

## 功能特点

- 批量处理一个文件夹内的花粉图片。
- 自动识别图片右下角红色 `100 um` 标尺。
- 支持手动输入标尺像素值，避免自动标尺识别失败。
- 根据花粉粒面积反推等效圆直径。
- 使用圆度筛选较圆的花粉粒，默认 `Circularity = 0.60-1.00`。
- 过滤超出合理直径范围的对象，默认直径范围为 `20-80 um`。
- 可导出主结果表、明细表、汇总表和调试日志。
- 可选择保存轮廓预览图，方便人工检查识别效果。

## 软件要求

- ImageJ 或 Fiji

本工具不是 Python 程序，而是 ImageJ 宏脚本，文件后缀为 `.ijm`。

## 安装方法
需自行下载好ImageJ

方法：直接运行

1. 打开 ImageJ。
2. 点击 `Plugins > Macros > Run...`。
3. 选择脚本文件 `Pollen_Diameter_Batch.ijm`。

## 使用方法

1. 启动 ImageJ。
2. 运行 `Pollen_Diameter_Batch.ijm`。
3. 选择花粉图片所在文件夹。
4. 选择结果输出文件夹。
5. 在参数窗口中确认或修改参数。
6. 点击运行，等待批量处理完成。

## 主要参数说明

| 参数 | 默认值 | 说明 |
| --- | ---: | --- |
| Scale bar length (um) | 100 | 标尺实际长度，默认对应图片中的红色 `100 um` 标尺。 |
| Manual pixels/pt for scale bar | 0 | 手动输入 100 um 对应的像素数；填 `0` 表示自动识别红色标尺。 |
| Valid diameter min (um) | 20 | 合理花粉直径下限。 |
| Valid diameter max (um) | 80 | 合理花粉直径上限。 |
| Minimum circularity | 0.60 | 最小圆度，只识别圆度 `0.60-1.00` 的对象。 |
| Auto threshold | Default | 自动阈值方法。 |
| Save outline preview PNG | 可选 | 是否保存轮廓预览图，用于检查识别是否准确。 |

## 输出文件

运行结束后，输出文件夹中会生成以下文件：

```text
pollen_diameter_table.csv
pollen_particles_detail.csv
pollen_summary.csv
pollen_debug_log.txt
pollen_previews/
```

文件说明：

| 文件 | 说明 |
| --- | --- |
| pollen_diameter_table.csv | 主结果表，按样本横向排列，每张图片占 3 列：序号、面积、面积反推直径。 |
| pollen_particles_detail.csv | 每个候选花粉粒的明细，包含面积反推直径、Feret 直径、坐标、标尺信息等。 |
| pollen_summary.csv | 每张图片的汇总结果，包括有效数量、平均直径、标准差、最小值、最大值。 |
| pollen_debug_log.txt | 调试日志，用于排查标尺识别和分割步骤。 |
| pollen_previews/ | 如果勾选保存预览，会在这里保存识别轮廓图。 |

## 直径计算方法

本工具默认先统计花粉粒面积，再根据面积反推等效圆直径：

```text
diameter = sqrt(4 * area / pi)
```

选择该方法的原因：

- 花粉粒通常接近圆形，面积反推直径更稳定。
- Feret 直接直径容易受边缘毛刺、阴影、轻微粘连影响而偏大。
