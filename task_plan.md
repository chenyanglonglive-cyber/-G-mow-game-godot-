# 任务规划：基于单张大图 Region 动态裁剪的防御塔美术更新流

## 目标声明
- 最终要达成的可验证成功标准：
  - 彻底淘汰 `assets/towers/cut/` 下的 12 张零散防御塔贴图。
  - 直接在 [tower.tscn](file:///d:/AIcode-hub/mow-game-godot/scenes/tower.tscn) 中使用大图 `assets/towers/tower3lev.png` 作为唯一数据源，在 [tower.gd](file:///d:/AIcode-hub/mow-game-godot/scripts/tower.gd) 中利用 `Region` 属性动态裁剪出 4 类塔在 3 个等级下的贴图。
  - 美术（导演）后续更新防御塔外观时只需在 OneDrive 中替换这一张大图即可，无需再进行费时的人工切割。
- 项目边界与非目标：
  - 仅重构防御塔的 Sprite 渲染方式。防御塔的数值、攻击逻辑、子弹不受影响。

## 开发阶段
- [ ] 阶段 1：[大图切片坐标测绘] - 状态: `TODO`
  - [ ] 详细测绘大图 `tower3lev.png` (649x531) 的行列排布规律，计算出 4 行 3 列下每一帧的精确 `Rect2` 裁剪框。
- [ ] 阶段 2：[防御塔脚本与场景重构] - 状态: `TODO`
  - [ ] 在 `tower.tscn` 里的 `Sprite` 节点上开启 `region_enabled = true`。
  - [ ] 修改 `tower.gd` 中的 `_load_sprite()` 方法，废弃原本的小图预载逻辑，改用 `region_rect` 动态定位像素块。
- [ ] 阶段 3：[功能测试与资源清理] - 状态: `TODO`
  - [ ] 用 CLI 运行测试游戏，验证 12 个形态的塔显示和升级外观均完好。
