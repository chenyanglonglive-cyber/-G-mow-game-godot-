# 实施计划 PLAN.md —— 防御塔中心精准对齐与攻击旋转转向

本计划旨在解决防御塔（飞机形态）贴图在 3 倍缩放后存在的 X/Y 轴视觉偏移问题，并新增“攻击时机头旋转朝向敌人，并从机头枪口发射子弹/激光”的机制，大幅提升战斗真实感。

## 用户审核要点
> [!IMPORTANT]
> - **旋转方式**：在无敌人时，飞机会保持向上（默认朝向）或保留在最后一次射击的角度。有敌人时，飞机的 Sprite 会平滑/瞬间转向敌人。
> - **发射位置**：子弹和激光的起点将从飞机机头（Nose）射出，而不是槽位中心。

## 待解决问题
无。

## 拟修改文件

- `[MODIFY]` [tower.gd](file:///e:/AIcode/-G-mow-game-godot-/scripts/tower.gd)
- `[MODIFY]` [main.gd](file:///e:/AIcode/-G-mow-game-godot-/scripts/main.gd)

## 逐步任务清单

- [ ] **任务 1：在 tower.gd 和 main.gd 中引入 X/Y 偏移和机头距离配置**
  - 在两个脚本中定义 `TOWER_OFFSETS` 与 `NOSE_DISTANCES` 二维配置数组。
- [ ] **任务 2：重写精灵加载与对齐逻辑 (使用 offset 代替 position)**
  - 在 `tower.gd` 的 `_load_sprite()` 中，将 `sprite.position` 重置为 `Vector2.ZERO`，使用 `sprite.offset = Vector2(shift_x, shift_y)` 偏移贴图。
  - 在 `main.gd` 的 `drag_preview` 精灵中同步应用 `offset.x` 和 `offset.y` 偏移。
- [ ] **任务 3：实现攻击时旋转朝向敌人逻辑**
  - 在 `tower.gd` 中，如果有有效目标，计算目标与塔的相对角度，使 `sprite.rotation` 转向目标（`dir.angle() + PI / 2.0`）。
- [ ] **任务 4：实现从机头（Nose）发射子弹/激光**
  - 计算局部机头点在旋转后的全局坐标 `launch_pos`。
  - 将 `_fire_laser` 的激光起点和 `_fire_bullet` 的子弹生成点全部改为 `launch_pos`。

## 验证计划
### 手动验证
- 拖拽建造 1~4 级防御塔，验证其贴图是否与准星 "+" 完美重合。
- 观察敌机进入射程时，防御塔是否准确旋转指向敌人。
- 确认激光和子弹是从飞机前端的机头射出，而非飞机下方或尾部。
