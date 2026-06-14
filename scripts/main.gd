extends Node2D

const TDConfig := preload("res://scripts/config.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const TowerScript := preload("res://scripts/tower.gd")

const GRID_SIZE := 64.0
const MAP_ORIGIN := Vector2(8, 176)
const CANVAS_SIZE := Vector2(720, 1280)

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

@onready var path1_node: Path2D = $Map/Path1
@onready var path2_node: Path2D = $Map/Path2


const TowerScene := preload("res://scenes/tower.tscn")

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
	# Bind build tower buttons
	build_piercing.pressed.connect(_select_build_type.bind("piercing"))
	build_blade.pressed.connect(_select_build_type.bind("blade"))
	build_frost.pressed.connect(_select_build_type.bind("frost"))
	build_flame.pressed.connect(_select_build_type.bind("flame"))
	
	# Bind upgrade button
	upgrade_button.pressed.connect(_upgrade_selected_tower)
	
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
	var chosen_path_node := path2_node if path_toggle else path1_node
	path_toggle = not path_toggle
	enemy.setup(enemy_type, TDConfig.ENEMIES[enemy_type])
	enemy.died.connect(_on_enemy_died)
	enemy.reached_goal.connect(_on_enemy_reached_goal)
	chosen_path_node.add_child(enemy)
	enemies.append(enemy)

func _on_enemy_died(reward: int) -> void:
	gold += reward

func _on_enemy_reached_goal() -> void:
	lives = max(lives - 1, 0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		if pos.y > 1024.0:
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
	_draw_build_slots()

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

func _draw_build_slots() -> void:
	for slot in build_slots:
		draw_circle(slot, 24.0, Color(0.0, 0.9, 1.0, 0.10))
		draw_arc(slot, 24.0, 0.0, TAU, 40, Color("#00f6ff"), 2.0)
		draw_line(slot + Vector2(-8, 0), slot + Vector2(8, 0), Color("#66ffff"), 3.0)
		draw_line(slot + Vector2(0, -8), slot + Vector2(0, 8), Color("#66ffff"), 3.0)
