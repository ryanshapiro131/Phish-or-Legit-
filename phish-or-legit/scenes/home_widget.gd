extends TextureButton

@onready var home_button = $"."




func _on_pressed():
	get_tree().change_scene_to_file("res://scenes/desktop.tscn")
