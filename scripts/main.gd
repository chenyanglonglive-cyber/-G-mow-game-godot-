extends Node2D

const TDConfig = preload("res://scripts/config.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const TowerScript = preload("res://scripts/tower.gd")

const GRID_SIZE := 64.0
const MAP_ORIGIN := Vector2(8, 176)
const CANVAS_SIZE := Vector2(720, 1280)

var gold := TDConfig.LEVEL.start_gold
var lives := TDConfig.LEVEL.start_lives
var selected_type := "piercing"
var selected_tower
var current_wave := -1
var wave_delay := 1.0
var spawn_timer := 0.0
var spawned_in_wave := 0
var wave_running := false
var path_toggle := false

# Sandbox multipliers
var enemy_speed_multiplier := 1.0
var enemy_hp_multiplier := 1.0

var enemies: Array = []
var towers: Array = []
var tower_by_slot := {}
var build_slots: Array[Vector2] = []

var is_dragging := false
var drag_type := ""
var drag_preview: Sprite2D = null

# Drag existing tower for fusion
var dragged_existing_tower = null
var is_dragging_existing_tower := false
var is_drag_existing_pending := false
var drag_start_mouse_pos := Vector2.ZERO

const TOWER_COLUMNS := {
	"piercing": 0,
	"blade": 1,
	"flame": 2,
	"frost": 3
}

const TOWER_OFFSETS := [
	[[23.0, 32.5], [10.0, 0.5], [-3.0, 37.0], [-16.0, 32.5]],
	[[0.5, 14.5], [7.5, 12.5], [-3.5, 20.5], [-16.0, 16.5]],
	[[0.0, -3.5], [5.5, -3.0], [-3.0, -4.0], [-16.0, 2.0]]
]

@onready var path1_node: Path2D = $Map/Path1
@onready var path2_node: Path2D = $Map/Path2


const TowerScene = preload("res://scenes/tower.tscn")

@onready var world_layer: Node2D = $WorldLayer
@onready var bullet_layer: Node2D = $BulletLayer
@onready var towers_container: Node2D = $WorldLayer/TowersContainer
@onready var enemies_container: Node2D = $WorldLayer/EnemiesContainer


@onready var gold_label: Label = $HUD/TopLabels/GoldLabel
@onready var lives_label: Label = $HUD/TopLabels/ShieldLabel
@onready var wave_label: Label = $HUD/TopLabels/WaveLabel
@onready var info_label: Label = $HUD/BottomContainer/ActionRow/InfoLabel
@onready var upgrade_button: Button = $HUD/BottomContainer/ActionRow/UpgradeButton

@onready var build_piercing: Button = $HUD/BottomContainer/BuildButtons/BuildPiercing
@onready var build_blade: Button = $HUD/BottomContainer/BuildButtons/BuildBlade
@onready var build_frost: Button = $HUD/BottomContainer/BuildButtons/BuildFrost
@onready var build_flame: Button = $HUD/BottomContainer/BuildButtons/BuildFlame

func _ready() -> void:
	_init_ui_connections()
	_prepare_level_data()
	_start_wave_countdown()

func _init_ui_connections() -> void:
	# Bind build tower drag-and-drop
	build_piercing.button_down.connect(_on_drag_start.bind("piercing"))
	build_piercing.button_up.connect(_on_drag_end)
	
	build_blade.button_down.connect(_on_drag_start.bind("blade"))
	build_blade.button_up.connect(_on_drag_end)
	
	build_frost.button_down.connect(_on_drag_start.bind("frost"))
	build_frost.button_up.connect(_on_drag_end)
	
	build_flame.button_down.connect(_on_drag_start.bind("flame"))
	build_flame.button_up.connect(_on_drag_end)
	
	# Bind upgrade button
	upgrade_button.pressed.connect(_upgrade_selected_tower)
	
	# Bind Sell button
	var sell_btn := get_node_or_null("HUD/BottomContainer/ActionRow/SellButton") as Button
	if sell_btn != null:
		sell_btn.pressed.connect(_sell_selected_tower)
		
	# Bind Sandbox controls
	var sandbox_btn := get_node_or_null("HUD/SandboxButton") as Button
	if sandbox_btn != null:
		sandbox_btn.pressed.connect(_toggle_sandbox)
		
	var close_btn := get_node_or_null("HUD/SandboxPanel/VBox/CloseSandbox") as Button
	if close_btn != null:
		close_btn.pressed.connect(_toggle_sandbox)
		
	var speed_slider := get_node_or_null("HUD/SandboxPanel/VBox/SpeedRow/SpeedSlider") as HSlider
	if speed_slider != null:
		speed_slider.value_changed.connect(_on_speed_slider_value_changed)
		
	var hp_slider := get_node_or_null("HUD/SandboxPanel/VBox/HPRow/HPSlider") as HSlider
	if hp_slider != null:
		hp_slider.value_changed.connect(_on_hp_slider_value_changed)
		
	var add_1000 := get_node_or_null("HUD/SandboxPanel/VBox/GoldRow/Add1000") as Button
	if add_1000 != null:
		add_1000.pressed.connect(_add_gold.bind(1000))
		
	var add_5000 := get_node_or_null("HUD/SandboxPanel/VBox/GoldRow/Add5000") as Button
	if add_5000 != null:
		add_5000.pressed.connect(_add_gold.bind(5000))
	
	# Initialize build buttons text (Name and Cost)
	var buttons = {
		"piercing": build_piercing,
		"blade": build_blade,
		"frost": build_frost,
		"flame": build_flame
	}
	for type in buttons:
		var btn: Button = buttons[type]
		var data: Dictionary = TDConfig.TOWERS[type]
		btn.text = "%s\n%dG" % [data.name, int(data.costs[0])]
	
	_update_ui()


func _prepare_level_data() -> void:
	var slots_node = get_node_or_null("WorldLayer/BuildSlots")
	if slots_node:
		for child in slots_node.get_children():
			if child is Node2D:
				build_slots.append(child.position)
	else:
		# Fallback to config if container not found
		for slot: Vector2i in TDConfig.LEVEL.build_slots:
			build_slots.append(_grid_to_world(Vector2(slot.x, slot.y)))
	queue_redraw()

func _grid_to_world(grid: Vector2) -> Vector2:
	return MAP_ORIGIN + Vector2(grid.x * GRID_SIZE + GRID_SIZE / 2.0, grid.y * GRID_SIZE + GRID_SIZE / 2.0)

func _process(delta: float) -> void:
	_clean_arrays()
	_update_waves(delta)
	for tower in towers:
		if is_instance_valid(tower):
			tower.step(delta, enemies, bullet_layer)
			
	# Update drag preview position
	if is_dragging and is_instance_valid(drag_preview):
		drag_preview.global_position = get_global_mouse_position()
		queue_redraw()
		
	_update_ui()

func _clean_arrays() -> void:
	enemies = enemies.filter(func(e): return is_instance_valid(e))
	towers = towers.filter(func(t): return is_instance_valid(t))

func _update_waves(delta: float) -> void:
	if wave_running:
		_spawn_wave(delta)
		return
	wave_delay -= delta
	if wave_delay <= 0.0 and current_wave < TDConfig.WAVES.size() - 1:
		current_wave += 1
		spawned_in_wave = 0
		spawn_timer = 0.0
		wave_running = true

func _start_wave_countdown() -> void:
	current_wave = -1
	wave_delay = 1.0
	wave_running = false

func _spawn_wave(delta: float) -> void:
	var wave: Dictionary = TDConfig.WAVES[current_wave]
	if spawned_in_wave >= int(wave.count):
		wave_running = false
		if current_wave < TDConfig.WAVES.size() - 1:
			wave_delay = float(wave.spawn_delay)
		return
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	var enemy_type := str(wave.type)
	if bool(wave.get("is_boss_wave", false)):
		enemy_type = _mixed_enemy_type(spawned_in_wave)
	_spawn_enemy(enemy_type)
	spawned_in_wave += 1
	spawn_timer = float(wave.interval)

func _mixed_enemy_type(index: int) -> String:
	if index < 15:
		return "scout"
	elif index < 25:
		return "predator"
	else:
		return "heavy"

func _spawn_enemy(enemy_type: String) -> void:
	var enemy := EnemyScript.new()
	var chosen_path_node := path2_node if path_toggle else path1_node
	path_toggle = not path_toggle
	enemy.setup(enemy_type, TDConfig.ENEMIES[enemy_type])
	enemy.died.connect(_on_enemy_died)
	enemy.reached_goal.connect(_on_enemy_reached_goal)
	enemy.exploded_ice_nova.connect(_on_exploded_ice_nova)
	chosen_path_node.add_child(enemy)
	enemies.append(enemy)

func _on_exploded_ice_nova(pos: Vector2) -> void:
	# Spawn visual expanding freeze ring
	var fx = load("res://scripts/visual_effect.gd").new()
	fx.setup(pos, "ice_nova", 0.4, 75.0, Color("#80e5ff"))
	bullet_layer.add_child(fx)
	
	# Deal 45 damage and 50% slow in a 75px radius
	for enemy in enemies:
		if is_instance_valid(enemy):
			var enemy_pos: Vector2 = enemy.global_position
			if "pull_offset" in enemy:
				enemy_pos += enemy.pull_offset
			if pos.distance_to(enemy_pos) <= 75.0:
				if enemy.has_method("take_damage"):
					enemy.take_damage(45.0)
				if enemy.has_method("apply_slow"):
					enemy.apply_slow(0.50, 1.5)


func _on_enemy_died(reward: int) -> void:
	gold += reward

func _on_enemy_reached_goal() -> void:
	lives = max(lives - 1, 0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var pos: Vector2 = event.position
			if pos.y > 1024.0:
				return
			
			var clicked_tower = _tower_at_position(pos)
			if clicked_tower != null and clicked_tower.level == 2:
				dragged_existing_tower = clicked_tower
				drag_start_mouse_pos = pos
				is_drag_existing_pending = true
			else:
				_handle_world_click(pos)
		else:
			# Release mouse button
			if is_dragging_existing_tower:
				if is_instance_valid(dragged_existing_tower):
					dragged_existing_tower.modulate = Color.WHITE
				is_dragging_existing_tower = false
				is_drag_existing_pending = false
				
				# Check if there is another level 3 tower under release pos
				var release_pos := get_global_mouse_position()
				var target_tower = _tower_at_position(release_pos)
				
				if target_tower != null and target_tower != dragged_existing_tower and target_tower.level == 2 and target_tower.tower_type == dragged_existing_tower.tower_type:
					_merge_towers(dragged_existing_tower, target_tower)
				
				if is_instance_valid(drag_preview):
					drag_preview.queue_free()
				drag_preview = null
				dragged_existing_tower = null
				queue_redraw()
			elif is_drag_existing_pending:
				is_drag_existing_pending = false
				_handle_world_click(drag_start_mouse_pos)
				dragged_existing_tower = null
				
	elif event is InputEventMouseMotion:
		if is_drag_existing_pending and event.position.distance_to(drag_start_mouse_pos) > 10.0:
			is_drag_existing_pending = false
			is_dragging_existing_tower = true
			
			# Create drag preview sprite
			drag_preview = Sprite2D.new()
			var texture_path := "res://assets/towers/all_tower.png"
			if ResourceLoader.exists(texture_path):
				var tex := load(texture_path)
				drag_preview.texture = tex
				drag_preview.region_enabled = true
				
				var col: int = TOWER_COLUMNS.get(dragged_existing_tower.tower_type, 0)
				var tex_w := float(tex.get_width())
				var tex_h := float(tex.get_height())
				var frame_w := tex_w / 4.0
				var frame_h := tex_h / 3.0
				
				drag_preview.region_rect = Rect2(col * frame_w, 2.0 * frame_h, frame_w, frame_h)
				drag_preview.scale = Vector2.ONE * min(230.4 / frame_w, 230.4 / frame_h)
				var offsets = TOWER_OFFSETS[2][col]
				drag_preview.offset = Vector2(offsets[0], offsets[1])
			
			drag_preview.modulate = Color(1.0, 1.0, 1.0, 0.6)
			drag_preview.global_position = event.position
			world_layer.add_child(drag_preview)
			
			# Semi-transparent original
			dragged_existing_tower.modulate = Color(1.0, 1.0, 1.0, 0.3)
			
		elif is_dragging_existing_tower and is_instance_valid(drag_preview):
			drag_preview.global_position = event.position
			queue_redraw()

func _merge_towers(tower_a, tower_b) -> void:
	var slot_a := -1
	var slot_b := -1
	for k in tower_by_slot:
		if tower_by_slot[k] == tower_a:
			slot_a = k
		if tower_by_slot[k] == tower_b:
			slot_b = k
			
	if slot_a < 0 or slot_b < 0:
		return
		
	var type = tower_b.tower_type
	var data = TDConfig.TOWERS[type]
	
	# Erase and free
	towers.erase(tower_a)
	towers.erase(tower_b)
	tower_by_slot.erase(slot_a)
	tower_by_slot.erase(slot_b)
	tower_a.queue_free()
	tower_b.queue_free()
	
	# Instantiate Level 4 (index 3)
	var tower := TowerScene.instantiate()
	tower.position = build_slots[slot_b]
	tower.setup(type, data)
	tower.level = 3
	tower._load_sprite()
	
	towers_container.add_child(tower)
	towers.append(tower)
	tower_by_slot[slot_b] = tower
	_select_tower(tower)
	
	# Spawn fusion visual wave
	var fx = load("res://scripts/visual_effect.gd").new()
	fx.setup(build_slots[slot_b], "fusion", 0.6, 120.0, Color("#ffff33"))
	bullet_layer.add_child(fx)
	
	# Spawn floating text
	var lbl := Label.new()
	lbl.text = "战神合体成功！"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color("#ffff33"))
	lbl.global_position = build_slots[slot_b] - Vector2(100, 60)
	lbl.custom_minimum_size = Vector2(200, 40)
	bullet_layer.add_child(lbl)
	
	var tween := create_tween()
	tween.tween_property(lbl, "global_position", lbl.global_position - Vector2(0, 80), 1.2)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tween.tween_callback(lbl.queue_free)
	
	info_label.text = "战神合体成功！"

func _handle_world_click(pos: Vector2) -> void:
	var tower = _tower_at_position(pos)
	if tower != null:
		_select_tower(tower)
	else:
		_select_tower(null)

func _on_drag_start(type: String) -> void:
	var cost = int(TDConfig.TOWERS[type].costs[0])
	if gold < cost:
		info_label.text = "Not enough gold"
		return
		
	is_dragging = true
	drag_type = type
	
	# Create drag preview sprite
	drag_preview = Sprite2D.new()
	var texture_path := "res://assets/towers/all_tower.png"
	if ResourceLoader.exists(texture_path):
		var tex := load(texture_path)
		drag_preview.texture = tex
		drag_preview.region_enabled = true
		
		var col: int = TOWER_COLUMNS.get(type, 0)
		var tex_w := float(tex.get_width())
		var tex_h := float(tex.get_height())
		var frame_w := tex_w / 4.0
		var frame_h := tex_h / 3.0
		
		drag_preview.region_rect = Rect2(col * frame_w, 0.0, frame_w, frame_h)
		drag_preview.scale = Vector2.ONE * min(230.4 / frame_w, 230.4 / frame_h)
		var offsets = TOWER_OFFSETS[0][col]
		drag_preview.offset = Vector2(offsets[0], offsets[1])
	
	# Make preview semi-transparent
	drag_preview.modulate = Color(1.0, 1.0, 1.0, 0.6)
	drag_preview.global_position = get_global_mouse_position()
	
	# Add preview to world layer so it shows under UI
	world_layer.add_child(drag_preview)
	
	selected_type = type
	info_label.text = "Dragging: %s" % TDConfig.TOWERS[type].name
	queue_redraw()

func _on_drag_end() -> void:
	if not is_dragging:
		return
		
	is_dragging = false
	
	var mouse_pos := get_global_mouse_position()
	var slot_index := _slot_index_at_position(mouse_pos)
	
	if slot_index >= 0:
		if tower_by_slot.has(slot_index):
			info_label.text = "Slot occupied"
		else:
			_try_build(slot_index)
	else:
		info_label.text = "Build cancelled"
		
	if is_instance_valid(drag_preview):
		drag_preview.queue_free()
	drag_preview = null
	
	queue_redraw()

func _tower_at_position(pos: Vector2):
	for tower in towers:
		if is_instance_valid(tower) and tower.global_position.distance_to(pos) < 44.8:
			return tower
	return null

func _slot_index_at_position(pos: Vector2) -> int:
	for i in build_slots.size():
		if build_slots[i].distance_to(pos) <= 44.8:
			return i
	return -1

func _try_build(slot_index: int) -> void:
	if tower_by_slot.has(slot_index):
		_select_tower(tower_by_slot[slot_index])
		return
	var data: Dictionary = TDConfig.TOWERS[selected_type]
	var cost := int(data.costs[0])
	if gold < cost:
		info_label.text = "Not enough gold"
		return
	gold -= cost
	var tower := TowerScene.instantiate()
	tower.position = build_slots[slot_index]
	tower.setup(selected_type, data)
	towers_container.add_child(tower)
	towers.append(tower)
	tower_by_slot[slot_index] = tower
	_select_tower(tower)

func _select_build_type(tower_type: String) -> void:
	selected_type = tower_type
	info_label.text = "Selected: %s" % TDConfig.TOWERS[tower_type].name

func _select_tower(tower) -> void:
	if is_instance_valid(selected_tower):
		selected_tower.set_selected(false)
	selected_tower = tower
	if is_instance_valid(selected_tower):
		selected_tower.set_selected(true)
	_update_ui()

func _upgrade_selected_tower() -> void:
	if not is_instance_valid(selected_tower):
		info_label.text = "Select a tower"
		return
	var cost: int = selected_tower.get_upgrade_cost()
	if cost < 0:
		info_label.text = "Max level"
		return
	if gold < cost:
		info_label.text = "Not enough gold"
		return
	gold -= cost
	selected_tower.upgrade()
	info_label.text = "Upgraded"
	_update_ui()

func _update_ui() -> void:
	gold_label.text = "%d G" % gold
	lives_label.text = "%d" % lives
	wave_label.text = "%d/%d" % [max(current_wave + 1, 1), TDConfig.WAVES.size()]
	if is_instance_valid(selected_tower):
		var cost: int = selected_tower.get_upgrade_cost()
		upgrade_button.disabled = cost < 0
		upgrade_button.text = "MAX" if cost < 0 else "Upgrade %dG" % cost
	elif upgrade_button != null:
		upgrade_button.disabled = true
		upgrade_button.text = "Upgrade"

func _draw() -> void:
	_draw_grid()
	_draw_paths()
	
	if is_dragging:
		var data: Dictionary = TDConfig.TOWERS[drag_type]
		var range = float(data.ranges[0]) * 1.6
		var mouse_pos = get_local_mouse_position()
		var color: Color = data.get("color", Color.CYAN)
		
		# Draw range circle
		draw_circle(mouse_pos, range, Color(color.r, color.g, color.b, 0.15))
		draw_arc(mouse_pos, range, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.5), 2.0)

func _draw_grid() -> void:
	# Increase visibility: thickness 2.0, alpha 0.40
	var grid_color := Color(0.15, 0.65, 1.0, 0.40)
	for x in range(0, int(TDConfig.LEVEL.cols) + 1):
		var gx := MAP_ORIGIN.x + x * GRID_SIZE
		draw_line(Vector2(gx, MAP_ORIGIN.y), Vector2(gx, MAP_ORIGIN.y + TDConfig.LEVEL.rows * GRID_SIZE), grid_color, 2.0)
	for y in range(0, int(TDConfig.LEVEL.rows) + 1):
		var gy := MAP_ORIGIN.y + y * GRID_SIZE
		draw_line(Vector2(MAP_ORIGIN.x, gy), Vector2(MAP_ORIGIN.x + TDConfig.LEVEL.cols * GRID_SIZE, gy), grid_color, 2.0)

func _draw_paths() -> void:
	var p1_points := path1_node.curve.get_baked_points()
	var p2_points := path2_node.curve.get_baked_points()
	for points in [p1_points, p2_points]:
		if points.size() < 2:
			continue
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], Color(0.0, 0.75, 1.0, 0.35), 54.4)
			draw_line(points[i], points[i + 1], Color("#00e5ff"), 11.2)

func _sell_selected_tower() -> void:
	if not is_instance_valid(selected_tower):
		info_label.text = "Select a tower to sell"
		return
	
	var refund = selected_tower.get_sell_value()
	gold += refund
	
	var slot_idx := -1
	for k in tower_by_slot:
		if tower_by_slot[k] == selected_tower:
			slot_idx = k
			break
			
	if slot_idx >= 0:
		tower_by_slot.erase(slot_idx)
		
	towers.erase(selected_tower)
	selected_tower.queue_free()
	selected_tower = null
	
	info_label.text = "Sold for %d G" % refund
	_update_ui()

func _toggle_sandbox() -> void:
	var panel := $HUD/SandboxPanel as PanelContainer
	if panel != null:
		panel.visible = not panel.visible

func _on_speed_slider_value_changed(value: float) -> void:
	enemy_speed_multiplier = value
	var val_lbl := get_node_or_null("HUD/SandboxPanel/VBox/SpeedRow/ValueLabel") as Label
	if val_lbl != null:
		val_lbl.text = "%.1fx" % value

func _on_hp_slider_value_changed(value: float) -> void:
	var old_mult := enemy_hp_multiplier
	enemy_hp_multiplier = value
	var val_lbl := get_node_or_null("HUD/SandboxPanel/VBox/HPRow/ValueLabel") as Label
	if val_lbl != null:
		val_lbl.text = "%.1fx" % value
		
	for enemy in enemies:
		if is_instance_valid(enemy) and "base_max_hp" in enemy:
			var ratio := value / old_mult
			enemy.max_hp = enemy.base_max_hp * value
			enemy.hp = enemy.hp * ratio

func _add_gold(amount: int) -> void:
	gold += amount
	info_label.text = "+%d G战备金已到账" % amount
	_update_ui()
