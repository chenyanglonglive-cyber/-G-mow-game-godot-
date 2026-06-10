extends Node2D

const BulletScript := preload("res://scripts/bullet.gd")

var tower_type := "piercing"
var cfg := {}
var level := 0
var fire_timer := 0.0
var selected := false
var sprite: Sprite2D

func setup(new_type: String, new_cfg: Dictionary) -> void:
	tower_type = new_type
	cfg = new_cfg
	_load_sprite()
	queue_redraw()

func _load_sprite() -> void:
	var prefix := str(cfg.get("texture_prefix", tower_type))
	var suffix := "lv%d" % (level + 1)
	if level >= 3:
		suffix = "mechgod"
	var texture_path := "res://assets/towers/cut/%s_%s.png" % [prefix, suffix]
	if not ResourceLoader.exists(texture_path):
		return
	var tex := load(texture_path)
	if tex == null:
		return
	if sprite == null:
		sprite = Sprite2D.new()
		add_child(sprite)
	sprite.texture = tex
	sprite.scale = Vector2.ONE * min(48.0 / max(tex.get_width(), 1), 48.0 / max(tex.get_height(), 1))

func get_range() -> float:
	return float(cfg.ranges[level])

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
	fire_timer -= delta
	if fire_timer > 0.0:
		return
	var target := _find_target(enemies)
	if target == null:
		return
	if tower_type == "blade":
		_do_blade_damage(enemies)
	else:
		_fire_bullet(target, bullet_parent)
	fire_timer = float(cfg.fire_rates[level])

func _find_target(enemies: Array) -> Node2D:
	var best: Node2D = null
	var best_score := -1.0
	var range := get_range()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= range and enemy.progress_score > best_score:
			best = enemy
			best_score = enemy.progress_score
	return best

func _do_blade_damage(enemies: Array) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= get_range():
			enemy.take_damage(float(cfg.damage[level]))

func _fire_bullet(target: Node2D, bullet_parent: Node) -> void:
	var bullet := BulletScript.new()
	bullet.global_position = global_position
	var options := {
		"speed": float(cfg.get("bullet_speed", 700.0)),
		"damage": float(cfg.damage[level]),
		"color": cfg.bullet_color,
		"tower_type": tower_type
	}
	if tower_type == "frost":
		options["slow_amount"] = float(cfg.slow[level])
		options["slow_duration"] = float(cfg.slow_duration)
	if tower_type == "flame":
		options["burn_damage"] = float(cfg.burn_damage[level])
		options["burn_duration"] = float(cfg.burn_duration)
	bullet.setup(target, options)
	bullet_parent.add_child(bullet)

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
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 36, Color("#ffff66"), 3.0)