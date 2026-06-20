extends Node2D

var duration := 1.0
var radius := 25.0
var damage_per_tick := 15.0
var tick_interval := 0.3
var level := 2

var elapsed := 0.0
var tick_timer := 0.0
var color := Color("#ff6600")

func setup(pos: Vector2, dur: float, rad: float, tick_dmg: float, lvl: int) -> void:
	global_position = pos
	duration = dur
	radius = rad
	damage_per_tick = tick_dmg
	level = lvl
	tick_timer = 0.0
	color = Color("#ffaa00") if lvl == 2 else Color("#ff3300")
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
		
	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer = tick_interval
		_deal_tick_damage()
	queue_redraw()

func _deal_tick_damage() -> void:
	var main_node = get_tree().current_scene
	if main_node and "enemies" in main_node:
		for enemy in main_node.enemies:
			if is_instance_valid(enemy):
				var enemy_pos = enemy.global_position
				if "pull_offset" in enemy:
					enemy_pos += enemy.pull_offset
				if global_position.distance_to(enemy_pos) <= radius:
					if enemy.has_method("take_damage"):
						enemy.take_damage(damage_per_tick)
					if enemy.has_method("apply_burn"):
						var burn_val = 20.0 if level == 2 else 80.0
						enemy.apply_burn(burn_val, 3.0)

func _draw() -> void:
	var alpha := 1.0 - (elapsed / duration)
	var c := color
	c.a = alpha * (0.25 if level == 2 else 0.45)
	draw_circle(Vector2.ZERO, radius, c)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color.r, color.g, color.b, alpha * 0.8), 2.0)
