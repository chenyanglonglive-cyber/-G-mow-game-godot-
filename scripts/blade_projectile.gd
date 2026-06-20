extends Node2D

var direction := Vector2.RIGHT
var speed := 400.0
var damage := 10.0
var max_range := 200.0
var traveled_distance := 0.0
var hit_enemies: Array = []

func setup(start_pos: Vector2, dir: Vector2, spd: float, dmg: float, rng: float) -> void:
	global_position = start_pos
	direction = dir.normalized()
	speed = spd * 1.6
	damage = dmg
	max_range = rng

func _process(delta: float) -> void:
	var move_amt := speed * delta
	global_position += direction * move_amt
	traveled_distance += move_amt
	if traveled_distance >= max_range:
		queue_free()
		return
		
	# Check collision with enemies
	var main_node = get_tree().current_scene
	if main_node and "enemies" in main_node:
		for enemy in main_node.enemies:
			if is_instance_valid(enemy) and not enemy in hit_enemies:
				var enemy_pos = enemy.global_position
				if "pull_offset" in enemy:
					enemy_pos += enemy.pull_offset
				var dist := global_position.distance_to(enemy_pos)
				if dist <= enemy.radius + 12.0: # 12.0 is blade visual radius
					hit_enemies.append(enemy)
					if enemy.has_method("take_damage"):
						enemy.take_damage(damage)
	queue_redraw()

func _draw() -> void:
	var time := Time.get_ticks_msec() / 1000.0
	var angle := time * 20.0
	var color := Color("#ff0055")
	for i in range(3):
		var a := angle + i * TAU / 3.0
		var offset := Vector2.from_angle(a) * 12.0
		draw_line(Vector2.ZERO, offset, color, 4.0)
