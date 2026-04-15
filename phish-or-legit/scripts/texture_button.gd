extends TextureButton



@onready var home_button: TextureButton = $"."




func _on_home_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/desktop.tscn")
