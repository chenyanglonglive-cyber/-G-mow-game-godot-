extends Node2D

var target: Node2D
var speed := 600.0
var damage := 10.0
var bullet_color := Color.CYAN
var tower_type := "piercing"
var slow_amount := 0.0
var slow_duration := 0.0
var burn_damage := 0.0
var burn_duration := 0.0

var freeze_chance := 0.0
var freeze_duration := 0.0
var tower_level := 0

func setup(new_target: Node2D, options: Dictionary) -> void:
	target = new_target
	speed = float(options.get("speed", speed)) * 1.6
	damage = float(options.get("damage", damage))
	bullet_color = options.get("color", bullet_color)
	tower_type = str(options.get("tower_type", tower_type))
	slow_amount = float(options.get("slow_amount", 0.0))
	slow_duration = float(options.get("slow_duration", 0.0))
	burn_damage = float(options.get("burn_damage", 0.0))
	burn_duration = float(options.get("burn_duration", 0.0))
	freeze_chance = float(options.get("freeze_chance", 0.0))
	freeze_duration = float(options.get("freeze_duration", 0.0))
	tower_level = int(options.get("tower_level", 0))
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var target_pos := target.global_position
	var offset = target.get("pull_offset")
	if offset != null:
		target_pos += offset
	var to_target := target_pos - global_position
	var dist := to_target.length()
	if dist < 10.0:
		_hit_target()
		return
	global_position += to_target.normalized() * min(speed * delta, dist)

func _hit_target() -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	if target.has_method("take_damage"):
		target.take_damage(damage)
	if slow_amount > 0.0 and target.has_method("apply_slow"):
		target.apply_slow(slow_amount, slow_duration)
	if freeze_chance > 0.0 and randf() < freeze_chance:
		if target.has_method("apply_freeze"):
			target.apply_freeze(freeze_duration)
	if burn_damage > 0.0 and target.has_method("apply_burn"):
		target.apply_burn(burn_damage, burn_duration)
	if tower_type == "flame" and tower_level >= 2:
		_spawn_lava_pool()
	queue_free()

func _spawn_lava_pool() -> void:
	var pool = load("res://scripts/lava_pool.gd").new()
	var duration = 1.0 if tower_level == 2 else 2.5
	var radius = 25.0 if tower_level == 2 else 60.0
	var tick_dmg = 12.0 if tower_level == 2 else 15.0
	pool.setup(global_position, duration, radius, tick_dmg, tower_level)
	if get_parent() != null:
		get_parent().add_child(pool)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 8.0, bullet_color)
	draw_circle(Vector2.ZERO, 14.4, Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.25))