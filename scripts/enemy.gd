extends Node2D

signal died(reward: int)
signal reached_goal

var path: Array[Vector2] = []
var type_data := {}
var max_hp := 1.0
var hp := 1.0
var speed := 80.0
var reward := 0
var radius := 18.0
var color := Color.WHITE
var segment_index := 0
var slow_factor := 0.0
var slow_time := 0.0
var burn_damage := 0.0
var burn_time := 0.0
var burn_tick := 0.0
var sprite: Sprite2D
var progress_score := 0.0

func setup(enemy_type: String, world_path: Array[Vector2], data: Dictionary) -> void:
	path = world_path
	type_data = data
	max_hp = float(data.hp)
	hp = max_hp
	speed = float(data.speed)
	reward = int(data.reward)
	radius = float(data.radius)
	color = data.color
	position = path[0]
	_load_sprite(str(data.texture))
	queue_redraw()

func _load_sprite(path_name: String) -> void:
	if not ResourceLoader.exists(path_name):
		return
	var tex := load(path_name)
	if tex == null:
		return
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2.ONE * min((radius * 2.0) / max(tex.get_width(), 1), (radius * 2.0) / max(tex.get_height(), 1))
	add_child(sprite)

func _process(delta: float) -> void:
	_update_status_effects(delta)
	_move_along_path(delta)
	queue_redraw()

func _update_status_effects(delta: float) -> void:
	if slow_time > 0.0:
		slow_time -= delta
	else:
		slow_factor = 0.0
	if burn_time > 0.0:
		burn_time -= delta
		burn_tick -= delta
		if burn_tick <= 0.0:
			burn_tick = 1.0
			take_damage(burn_damage)

func _move_along_path(delta: float) -> void:
	if path.size() < 2:
		return
	var actual_speed := speed * (1.0 - slow_factor)
	var remaining := actual_speed * delta
	while remaining > 0.0 and segment_index < path.size() - 1:
		var target := path[segment_index + 1]
		var to_target := target - position
		var dist := to_target.length()
		if dist <= 0.001:
			segment_index += 1
			continue
		if remaining >= dist:
			position = target
			progress_score += dist
			remaining -= dist
			segment_index += 1
		else:
			position += to_target.normalized() * remaining
			progress_score += remaining
			remaining = 0.0
	if segment_index >= path.size() - 1:
		reached_goal.emit()
		queue_free()

func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		died.emit(reward)
		queue_free()

func apply_slow(amount: float, duration: float) -> void:
	slow_factor = max(slow_factor, amount)
	slow_time = max(slow_time, duration)

func apply_burn(amount: float, duration: float) -> void:
	burn_damage = max(burn_damage, amount)
	burn_time = max(burn_time, duration)
	burn_tick = min(burn_tick, 0.15)

func _draw() -> void:
	if sprite == null:
		draw_circle(Vector2.ZERO, radius, color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color.WHITE, 2.0)
	var width := radius * 2.0
	var y := -radius - 10.0
	draw_rect(Rect2(Vector2(-radius, y), Vector2(width, 4)), Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(Rect2(Vector2(-radius, y), Vector2(width * clamp(hp / max_hp, 0.0, 1.0), 4)), Color("#33ff66"))
	if slow_time > 0.0:
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 32, Color("#80ffff"), 2.0)
	if burn_time > 0.0:
		draw_arc(Vector2.ZERO, radius + 8.0, 0.0, TAU, 32, Color("#ff6633"), 2.0)