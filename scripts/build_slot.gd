@tool
extends Node2D

func _draw() -> void:
	# Draw a semi-transparent blue filled circle
	draw_circle(Vector2.ZERO, 24.0, Color(0.0, 0.9, 1.0, 0.10))
	# Draw a bright cyan circular outline
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 40, Color("#00f6ff"), 2.0)
	# Draw the crosshair lines
	draw_line(Vector2(-8, 0), Vector2(8, 0), Color("#66ffff"), 3.0)
	draw_line(Vector2(0, -8), Vector2(0, 8), Color("#66ffff"), 3.0)
