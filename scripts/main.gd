extends Node2D

const TDConfig := preload("res://scripts/config.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const TowerScript := preload("res://scripts/tower.gd")

const GRID_SIZE := 40.0
const MAP_ORIGIN := Vector2(5, 110)
const CANVAS_SIZE := Vector2(450, 800)

var gold := TDConfig.LEVEL.start_gold
var lives := TDConfig.LEVEL.start_lives
var selected_type := "piercing"
var selected_tower: Node2D
var current_wave := -1
var wave_delay := 1.0
var spawn_timer := 0.0
var spawned_in_wave := 0
var wave_running := false
var path_toggle := false

var enemies: Array = []
var towers: Array = []
var tower_by_slot := {}
var build_slots: Array[Vector2] = []
var path1: Array[Vector2] = []
var path2: Array[Vector2] = []

var world_layer: Node2D
var bullet_layer: Node2D
var ui_layer: CanvasLayer
var gold_label: Label
var lives_label: Label
var wave_label: Label
var info_label: Label
var upgrade_button: Button

func _ready() -> void:
	_init_world()
	_init_ui()
	_prepare_level_data()
	_start_wave_countdown()

func _init_world() -> void:
	_add_background()
	world_layer = Node2D.new()
	add_child(world_layer)
	bullet_layer = Node2D.new()
	add_child(bullet_layer)

func _add_background() -> void:
	var bg_path := "res://assets/ui/background.jpg"
	if ResourceLoader.exists(bg_path):
		var sprite := Sprite2D.new()
		sprite.texture = load(bg_path)
		sprite.centered = true
		sprite.position = CANVAS_SIZE / 2.0
		sprite.scale = Vector2(CANVAS_SIZE.x / sprite.texture.get_width(), CANVAS_SIZE.y / sprite.texture.get_height())
		add_child(sprite)
	else:
		var rect := ColorRect.new()
		rect.size = CANVAS_SIZE
		rect.color = Color("#061126")
		add_child(rect)

func _init_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var root := Control.new()
	root.size = CANVAS_SIZE
	ui_layer.add_child(root)

	var top := PanelContainer.new()
	top.position = Vector2(12, 12)
	top.size = Vector2(426, 62)
	root.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 30)
	top.add_child(top_row)
	gold_label = _make_label("")
	lives_label = _make_label("")
	wave_label = _make_label("")
	top_row.add_child(gold_label)
	top_row.add_child(lives_label)
	top_row.add_child(wave_label)

	var bottom := PanelContainer.new()
	bottom.position = Vector2(12, 648)
	bottom.size = Vector2(426, 128)
	root.add_child(bottom)
	var bottom_col := VBoxContainer.new()
	bottom_col.add_theme_constant_override("separation", 8)
	bottom.add_child(bottom_col)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 8)
	bottom_col.add_child(button_row)
	for tower_type in ["piercing", "blade", "frost", "flame"]:
		var data: Dictionary = TDConfig.TOWERS[tower_type]
		var button := Button.new()
		button.custom_minimum_size = Vector2(96, 50)
		button.text = "%s\n%dG" % [data.name, int(data.costs[0])]
		button.pressed.connect(_select_build_type.bind(tower_type))
		button_row.add_child(button)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 8)
	bottom_col.add_child(action_row)
	upgrade_button = Button.new()
	upgrade_button.custom_minimum_size = Vector2(120, 34)
	upgrade_button.text = "Upgrade"
	upgrade_button.pressed.connect(_upgrade_selected_tower)
	action_row.add_child(upgrade_button)
	info_label = _make_label("")
	info_label.custom_minimum_size = Vector2(260, 34)
	action_row.add_child(info_label)
	_update_ui()

func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	return label

func _prepare_level_data() -> void:
	for slot: Vector2i in TDConfig.LEVEL.build_slots:
		build_slots.append(_grid_to_world(Vector2(slot.x, slot.y)))
	path1 = _path_to_world(TDConfig.LEVEL.path1)
	path2 = _path_to_world(TDConfig.LEVEL.path2)
	queue_redraw()

func _grid_to_world(grid: Vector2) -> Vector2:
	return MAP_ORIGIN + Vector2(grid.x * GRID_SIZE + GRID_SIZE / 2.0, grid.y * GRID_SIZE + GRID_SIZE / 2.0)

func _path_to_world(path: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point: Vector2 in path:
		result.append(_grid_to_world(point))
	return result

func _process(delta: float) -> void:
	_clean_arrays()
	_update_waves(delta)
	for tower in towers:
		if is_instance_valid(tower):
			tower.step(delta, enemies, bullet_layer)
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
	if index % 6 == 5:
		return "heavy"
	if index % 3 == 2:
		return "predator"
	return "scout"

func _spawn_enemy(enemy_type: String) -> void:
	var enemy := EnemyScript.new()
	var chosen_path := path2 if path_toggle else path1
	path_toggle = not path_toggle
	enemy.setup(enemy_type, chosen_path, TDConfig.ENEMIES[enemy_type])
	enemy.died.connect(_on_enemy_died)
	enemy.reached_goal.connect(_on_enemy_reached_goal)
	world_layer.add_child(enemy)
	enemies.append(enemy)

func _on_enemy_died(reward: int) -> void:
	gold += reward

func _on_enemy_reached_goal() -> void:
	lives = max(lives - 1, 0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		if pos.y > 640.0:
			return
		_handle_world_click(pos)

func _handle_world_click(pos: Vector2) -> void:
	var tower := _tower_at_position(pos)
	if tower != null:
		_select_tower(tower)
		return
	var slot_index := _slot_index_at_position(pos)
	if slot_index >= 0:
		_try_build(slot_index)
	else:
		_select_tower(null)

func _tower_at_position(pos: Vector2) -> Node2D:
	for tower in towers:
		if is_instance_valid(tower) and tower.global_position.distance_to(pos) < 28.0:
			return tower
	return null

func _slot_index_at_position(pos: Vector2) -> int:
	for i in build_slots.size():
		if build_slots[i].distance_to(pos) <= 28.0:
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
	var tower := TowerScript.new()
	tower.position = build_slots[slot_index]
	tower.setup(selected_type, data)
	world_layer.add_child(tower)
	towers.append(tower)
	tower_by_slot[slot_index] = tower
	_select_tower(tower)

func _select_build_type(tower_type: String) -> void:
	selected_type = tower_type
	info_label.text = "Selected: %s" % TDConfig.TOWERS[tower_type].name

func _select_tower(tower: Node2D) -> void:
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
	gold_label.text = "Gold: %d G" % gold
	lives_label.text = "Shield: %d" % lives
	wave_label.text = "Wave: %d/%d" % [max(current_wave + 1, 1), TDConfig.WAVES.size()]
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
	_draw_build_slots()

func _draw_grid() -> void:
	var grid_color := Color(0.15, 0.65, 1.0, 0.18)
	for x in range(0, int(TDConfig.LEVEL.cols) + 1):
		var gx := MAP_ORIGIN.x + x * GRID_SIZE
		draw_line(Vector2(gx, MAP_ORIGIN.y), Vector2(gx, MAP_ORIGIN.y + TDConfig.LEVEL.rows * GRID_SIZE), grid_color, 1.0)
	for y in range(0, int(TDConfig.LEVEL.rows) + 1):
		var gy := MAP_ORIGIN.y + y * GRID_SIZE
		draw_line(Vector2(MAP_ORIGIN.x, gy), Vector2(MAP_ORIGIN.x + TDConfig.LEVEL.cols * GRID_SIZE, gy), grid_color, 1.0)

func _draw_paths() -> void:
	for path in [path1, path2]:
		if path.size() < 2:
			continue
		for i in range(path.size() - 1):
			draw_line(path[i], path[i + 1], Color(0.0, 0.75, 1.0, 0.35), 34.0)
			draw_line(path[i], path[i + 1], Color("#00e5ff"), 7.0)

func _draw_build_slots() -> void:
	for slot in build_slots:
		draw_circle(slot, 24.0, Color(0.0, 0.9, 1.0, 0.10))
		draw_arc(slot, 24.0, 0.0, TAU, 40, Color("#00f6ff"), 2.0)
		draw_line(slot + Vector2(-8, 0), slot + Vector2(8, 0), Color("#66ffff"), 3.0)
		draw_line(slot + Vector2(0, -8), slot + Vector2(0, 8), Color("#66ffff"), 3.0)