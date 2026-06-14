extends Node2D

func _ready() -> void:
	print("====================================")
	print("Hello from Antigravity! Godot CLI is working perfectly.")
	print("====================================")
	
	# Create a Label node to display on the screen
	var label = Label.new()
	label.text = "Godot CLI & Antigravity Link Active!"
	label.position = Vector2(100, 100)
	add_child(label)
	
	# Create a timer to quit after 3 seconds
	await get_tree().create_timer(3.0).timeout
	print("Closing test scene...")
	get_tree().quit()
