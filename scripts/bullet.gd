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

func setup(new_target: Node2D, options: Dictionary) -> void:
	target = new_target
	speed = float(options.get("speed", speed))
	damage = float(options.get("damage", damage))
	bullet_color = options.get("color", bullet_color)
	tower_type = str(options.get("tower_type", tower_type))
	slow_amount = float(options.get("slow_amount", 0.0))
	slow_duration = float(options.get("slow_duration", 0.0))
	burn_damage = float(options.get("burn_damage", 0.0))
	burn_duration = float(options.get("burn_duration", 0.0))
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var to_target := target.global_position - global_position
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
	if burn_damage > 0.0 and target.has_method("apply_burn"):
		target.apply_burn(burn_damage, burn_duration)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, bullet_color)
	draw_circle(Vector2.ZERO, 9.0, Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.25))