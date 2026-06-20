extends Node2D

var type := "ice_nova" # "ice_nova" or "fusion"
var duration := 0.4
var max_radius := 75.0
var current_radius := 0.0
var elapsed := 0.0
var effect_color := Color("#00aaff")

func setup(start_pos: Vector2, eff_type: String, dur: float, rad: float, col: Color) -> void:
	global_position = start_pos
	type = eff_type
	duration = dur
	max_radius = rad
	effect_color = col

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	current_radius = (elapsed / duration) * max_radius
	queue_redraw()

func _draw() -> void:
	var alpha := 1.0 - (elapsed / duration)
	var col := effect_color
	col.a = alpha
	if type == "ice_nova":
		draw_circle(Vector2.ZERO, current_radius, Color(col.r, col.g, col.b, alpha * 0.15))
		draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 32, col, 4.0)
	elif type == "fusion":
		draw_circle(Vector2.ZERO, current_radius, Color(col.r, col.g, col.b, alpha * 0.3))
		draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 48, col, 6.0)
