# 研究与发现：防御塔大图集 Region 动态裁剪方案

## 1. 核心发现：现有资源分析
- [2026-06-14 23:34]：检测发现，在项目的 [assets/towers/cut/](file:///d:/AIcode-hub/mow-game-godot/assets/towers/cut/) 目录中，其实**已经有了**当初裁剪好的 12 张防御塔贴图（例如 `blade_lv1.png`，`frost_lv2.png` 等）。
- 现有的 [tower.gd](file:///d:/AIcode-hub/mow-game-godot/scripts/tower.gd) 的 `_load_sprite()` 正在正常加载这些 `cut/` 目录下的小图作为防御塔贴图。

---

## 2. 演进方案：使用大图 `tower3lev.png` 进行 Region 动态裁剪

为了方便导演（美术）后续一键更新防御塔资源，我们将探讨放弃零散的 `cut/` 小图，直接用大图进行动态切片的方案。

### 2.1 大图基本尺寸
- 文件路径：[tower3lev.png](file:///d:/AIcode-hub/mow-game-godot/assets/towers/tower3lev.png)
- 尺寸：宽 `649` 像素，高 `531` 像素。

### 2.2 理论分帧测绘 (4行3列 / 3行4列)
如果大图中有 12 个塔（4种类型，每种3级）：
- **假设 4行3列**（X轴为等级，Y轴为塔种）：
  - 每一帧的估算宽度 = `649 / 3 ≈ 216.3`
  - 每一帧的估算高度 = `531 / 4 ≈ 132.7`
- **假设 3行4列**（X轴为塔种，Y轴为等级）：
  - 每一帧的估算宽度 = `649 / 4 ≈ 162.2`
  - 每一帧的估算高度 = `531 / 3 = 177.0`

> [!NOTE]
> 由于估算的宽高非正方形，且不是标准的 2 的幂次方，我们需要向用户（导演）确认大图的排列方式（是横排等级还是竖排等级），或者由我们提取其原始设计参数进行自适应区域划分。

---

## 3. 核心文件结构
- 塔场景：[tower.tscn](file:///d:/AIcode-hub/mow-game-godot/scenes/tower.tscn) (将开启 region 属性)
- 塔脚本：[tower.gd](file:///d:/AIcode-hub/mow-game-godot/scripts/tower.gd) (将使用 `region_rect` 动态指定坐标)
