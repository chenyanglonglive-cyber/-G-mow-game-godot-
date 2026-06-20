extends Node2D

const BulletScript = preload("res://scripts/bullet.gd")

const TOWER_COLUMNS := {
	"piercing": 0,
	"blade": 1,
	"flame": 2,
	"frost": 3
}


var tower_type := "piercing"
var cfg := {}
var level := 0
var fire_timer := 0.0
var selected := false

# Special weapons variables
var active_lasers: Array = []
var blade_pulse_timer := 0.0

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	if cfg.size() > 0:
		_load_sprite()

func setup(new_type: String, new_cfg: Dictionary) -> void:
	tower_type = new_type
	cfg = new_cfg
	if is_node_ready():
		_load_sprite()
	queue_redraw()

const TOWER_OFFSETS := [
	[[23.0, 32.5], [10.0, 0.5], [-3.0, 37.0], [-16.0, 32.5]],
	[[0.5, 14.5], [7.5, 12.5], [-3.5, 20.5], [-16.0, 16.5]],
	[[0.0, -3.5], [5.5, -3.0], [-3.0, -4.0], [-16.0, 2.0]]
]

const NOSE_DISTANCES := [
	[81.0, 101.0, 89.0, 86.0],
	[68.0, 101.0, 74.0, 79.0],
	[67.0, 94.0, 58.0, 95.0]
]

func _load_sprite() -> void:
	var texture_path := "res://assets/towers/all_tower.png"
	if not ResourceLoader.exists(texture_path):
		return
	var tex := load(texture_path)
	if tex == null:
		return
	sprite.texture = tex
	sprite.region_enabled = true
	
	var col: int = TOWER_COLUMNS.get(tower_type, 0)
	var row: int = clamp(level, 0, 2)
	
	var tex_w := float(tex.get_width())
	var tex_h := float(tex.get_height())
	var frame_w := tex_w / 4.0
	var frame_h := tex_h / 3.0
	
	sprite.region_rect = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
	sprite.scale = Vector2.ONE * min(230.4 / frame_w, 230.4 / frame_h)
	
	# Keep position at zero so sprite rotates around build slot center
	sprite.position = Vector2.ZERO
	# Use offset to shift drawing center visually
	var offsets = TOWER_OFFSETS[row][col]
	sprite.offset = Vector2(offsets[0], offsets[1])


func get_tower_name() -> String:
	if cfg.has("names") and level < cfg.names.size():
		var name_str = cfg.names[level]
		if level == 3:
			name_str += " 🤖 战神 MAX"
		return name_str
	return cfg.get("name", "Unknown Tower")

func get_sell_value() -> int:
	if level >= 3:
		return 800
	var total_spent := 0
	if cfg.has("costs"):
		for i in range(level + 1):
			total_spent += int(cfg.costs[i])
	return int(total_spent * 0.70)

func get_range() -> float:
	return float(cfg.ranges[level]) * 1.6

func get_upgrade_cost() -> int:
	if level >= 2:
		return -1
	return int(cfg.costs[level + 1])

func upgrade() -> bool:
	if level >= 2:
		return false
	level += 1
	_load_sprite()
	queue_redraw()
	return true

func step(delta: float, enemies: Array, bullet_parent: Node) -> void:
	# Update active lasers
	var i := active_lasers.size() - 1
	while i >= 0:
		active_lasers[i].time_left -= delta
		if active_lasers[i].time_left <= 0.0:
			active_lasers.remove_at(i)
		i -= 1
	if active_lasers.size() > 0:
		queue_redraw()

	# Special blade features: pull enemies and shoot 8-way blades
	if tower_type == "blade" and level == 2:
		_apply_gravity_pull(delta, enemies)
		blade_pulse_timer -= delta
		if blade_pulse_timer <= 0.0:
			_fire_8_way_blades(bullet_parent)
			blade_pulse_timer = 1.5

	# Smooth rotation to target or default 0.0
	var target := _find_target(enemies)
	if target != null:
		var target_pos: Vector2 = target.global_position
		var offset = target.get("pull_offset")
		if offset != null:
			target_pos += offset
		var dir_to_target := (target_pos - global_position).normalized()
		var target_rot := dir_to_target.angle() + PI / 2.0
		
		# Smoothly rotate sprite
		sprite.rotation = rotate_toward(sprite.rotation, target_rot, 12.0 * delta)
	else:
		# Smoothly return to 0 (default UP)
		sprite.rotation = rotate_toward(sprite.rotation, 0.0, 8.0 * delta)

	fire_timer -= delta
	if fire_timer > 0.0:
		return
		
	if target == null:
		return
		
	if tower_type == "piercing":
		_fire_laser(target, enemies)
	elif tower_type == "blade":
		_do_blade_damage(enemies)
	else:
		_fire_bullet(target, bullet_parent)
		
	fire_timer = float(cfg.fire_rates[level])

func _find_target(enemies: Array) -> Node2D:
	var best: Node2D = null
	var best_score := -1.0
	var range_val := get_range()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_pos: Vector2 = enemy.global_position
		if "pull_offset" in enemy:
			enemy_pos += enemy.pull_offset
		var dist := global_position.distance_to(enemy_pos)
		if dist <= range_val and enemy.progress_score > best_score:
			best = enemy
			best_score = enemy.progress_score
	return best

func _do_blade_damage(enemies: Array) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			var enemy_pos: Vector2 = enemy.global_position
			if "pull_offset" in enemy:
				enemy_pos += enemy.pull_offset
			if global_position.distance_to(enemy_pos) <= get_range():
				enemy.take_damage(float(cfg.damage[level]))

func _fire_laser(target: Node2D, enemies: Array) -> void:
	var launch_pos := _get_launch_position()
	var dir := Vector2.UP.rotated(sprite.rotation)
	var rng := get_range()
	
	var laser_count := 1
	var angle_step := 15.0
	var width := 4.0
	
	if level == 1:
		width = 12.0
	elif level == 2:
		laser_count = 3
		width = 8.0
	elif level == 3:
		width = 40.0
		
	var laser_dirs: Array = []
	if laser_count == 3:
		laser_dirs.append(dir.rotated(-deg_to_rad(angle_step)))
		laser_dirs.append(dir)
		laser_dirs.append(dir.rotated(deg_to_rad(angle_step)))
	else:
		laser_dirs.append(dir)
		
	for l_dir in laser_dirs:
		var start_pos = launch_pos
		var end_pos = launch_pos + l_dir * rng
		
		var laser_color: Color = Color("#ff6666") if level == 3 else cfg.bullet_color
		active_lasers.append({
			"start": start_pos,
			"end": end_pos,
			"width": width,
			"color": laser_color,
			"time_left": 0.15
		})
		
		# Check laser line segment collision against all enemies
		for enemy in enemies:
			if is_instance_valid(enemy):
				var enemy_pos: Vector2 = enemy.global_position
				if "pull_offset" in enemy:
					enemy_pos += enemy.pull_offset
				
				# Point-to-segment distance projection
				var ab = end_pos - start_pos
				var ap = enemy_pos - start_pos
				var t = ap.dot(ab) / ab.length_squared()
				t = clamp(t, 0.0, 1.0)
				var projection = start_pos + ab * t
				var dist = enemy_pos.distance_to(projection)
				
				if dist <= enemy.radius + (width / 2.0):
					enemy.take_damage(float(cfg.damage[level]))
	queue_redraw()

func _apply_gravity_pull(delta: float, enemies: Array) -> void:
	var range_val := get_range()
	for enemy in enemies:
		if is_instance_valid(enemy):
			var enemy_pos: Vector2 = enemy.global_position + enemy.pull_offset
			var dist := global_position.distance_to(enemy_pos)
			if dist <= range_val:
				var dir := (global_position - enemy_pos).normalized()
				var pull_dist := 80.0 * delta
				if pull_dist > dist:
					pull_dist = dist
				enemy.pull_offset += dir * pull_dist
				enemy.was_pulled_this_frame = true

func _fire_8_way_blades(bullet_parent: Node) -> void:
	var dmg := float(cfg.damage[level]) * 0.55
	var range_val := get_range() * 1.5
	for i in range(8):
		var angle := i * TAU / 8.0
		var dir := Vector2.from_angle(angle)
		var proj = load("res://scripts/blade_projectile.gd").new()
		proj.setup(global_position, dir, 300.0, dmg, range_val)
		bullet_parent.add_child(proj)

func _fire_bullet(target: Node2D, bullet_parent: Node) -> void:
	var bullet = BulletScript.new()
	bullet.global_position = _get_launch_position()
	var options := {
		"speed": float(cfg.get("bullet_speed", 700.0)),
		"damage": float(cfg.damage[level]),
		"color": cfg.bullet_color,
		"tower_type": tower_type,
		"tower_level": level
	}
	if tower_type == "frost":
		options["slow_amount"] = float(cfg.slow[level])
		options["slow_duration"] = float(cfg.slow_duration)
		if level == 2:
			options["freeze_chance"] = 0.30
			options["freeze_duration"] = 1.2
	if tower_type == "flame":
		options["burn_damage"] = float(cfg.burn_damage[level])
		options["burn_duration"] = float(cfg.burn_duration)
	bullet.setup(target, options)
	bullet_parent.add_child(bullet)

func _get_launch_position() -> Vector2:
	if sprite == null:
		return global_position
	var col: int = TOWER_COLUMNS.get(tower_type, 0)
	var row: int = clamp(level, 0, 2)
	var offsets = TOWER_OFFSETS[row][col]
	var nose_dist = NOSE_DISTANCES[row][col]
	var local_nose_y := -(float(nose_dist) - float(offsets[1])) * sprite.scale.y
	return global_position + Vector2(0, local_nose_y).rotated(sprite.rotation)

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

func _draw() -> void:
	var base_color: Color = cfg.get("color", Color.CYAN)
	if sprite == null:
		draw_circle(Vector2.ZERO, 18.0, base_color)
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Color.WHITE, 2.0)
	if selected:
		draw_arc(Vector2.ZERO, get_range(), 0.0, TAU, 72, Color(base_color.r, base_color.g, base_color.b, 0.25), 2.0)
		draw_arc(Vector2.ZERO, 84.0, 0.0, TAU, 36, Color("#ffff66"), 3.0)
		
	# Draw active lasers fading out
	for laser in active_lasers:
		var alpha: float = clamp(laser.time_left / 0.15, 0.0, 1.0)
		var col: Color = laser.color
		col.a = alpha * 0.8
		var local_start = laser.start - global_position
		var local_end = laser.end - global_position
		draw_line(local_start, local_end, col, laser.width)
